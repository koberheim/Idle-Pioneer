## Campaign pacing bot: simulates a player's whole career across many
## expeditions (the reset loop) with the real simulation, and prints an
## expedition-by-expedition log plus colony-record milestones. Dev tool only;
## never touches Game or the save file (it works on its own RunState and
## MetaState, like tools/balance_bot.gd, whose greedy in-run logic it copies).
##
## Usage (Godot console exe, headless):
##   godot --headless --path . res://tools/campaign/campaign_bot.tscn -- <args>
## Args (key=value):
##   pattern=active|casual   active: continuous play. casual: `on` hours played,
##                           then `off` hours away (offline at offline_efficiency
##                           pace, offline cap applies), repeating.
##   seed=1                  campaign seed (map seeds and relic draws follow it)
##   on=1 off=7              casual session / absence lengths in hours
##   target=25               stop once a run has reached this many colonies
##   max_exp=60              stop after this many expeditions
##   max_hours=400           stop after this many wall-clock hours (casual: days*24)
##   max_days=0              alternative wall limit in days (overrides max_hours)
##   policy=marginal|asap    when to declare once independence is ready:
##                           asap = at once (after min_hours); marginal = keep
##                           going until marginal Liberty/hour (30 min window,
##                           active-equivalent time) falls below frac x its peak
##                           since the gate, or the run reaches run_max hours.
##   frac=0.6 run_max=8 min_hours=0
##   decision=5              seconds between decisions while buying
##   treasure=0.5            share of drifting treasure tapped during play
##   ads=1                   use "Consult the Almanac" (30 min skip) when ready
##                           (casual: once per absence; active: whenever ready)
##   charter_max=2           charter levels the bot works towards per colony
##   verbose=0               1 = print every colony founded
##   What-ifs (in memory only, data files untouched):
##   bal.<key>=v             override a balance.json number, e.g. bal.liberty_base=10
##   reform.<id|*>.<field>=v override a reform field, e.g. reform.*.growth=1.6
##   liberty_exp=v           same as bal.liberty_exponent=v
## Output lines: "COL" (new colony record), "EXP" (one per declaration),
## "MILESTONE", and a final "SUMMARY". Every number comes from data/*.json via
## Balance/Content, so the bot follows whatever retune is in the data files.
extends Node

const WINDOW_SECONDS := 1800.0
const IDLE_STEP_MAX := 120.0

var run: RunState
var meta: MetaState
var rng := RandomNumberGenerator.new()

# Parameters.
var pattern: String = "active"
var on_hours: float = 1.0
var off_hours: float = 7.0
var target: int = 25
var max_exp: int = 60
var max_wall: float = 400.0 * 3600.0
var policy: String = "marginal"
var frac: float = 0.6
var run_max: float = 8.0
var min_hours: float = 0.0
var decision: float = 5.0
var treasure_catch: float = 0.5
var use_ads: bool = true
var charter_max: int = 2
var verbose: bool = false
## Exponent on (gold earned / gate) in the Liberty payout; 0.5 is the game's
## sqrt. Other values simulate a code change to Balance.liberty_payout.

# Campaign clocks (seconds).
var wall: float = 0.0
var active_total: float = 0.0
var favor_ready: float = 0.0
var consult_ready: float = 0.0
var consult_pending: bool = false

# Per-expedition state.
var exp_index: int = 0
var exp_wall_start: float = 0.0
var exp_active_start: float = 0.0
var progress: float = 0.0  # active-equivalent seconds this run
var ready_progress: float = -1.0
var stall_reported: bool = false
var lib_samples: Array = []  # [progress, raw liberty less skip windfalls]
var skip_liberty: float = 0.0
var peak_marginal: float = 0.0
var income_ema: float = 0.0
var treasure_timer: float = 120.0
var sell_timer: float = 0.0
var last_best_cost: float = INF
var father_wants: Dictionary = {}
var study_wants: Dictionary = {}
var charter_wants: Dictionary = {}
var studies_bought: int = 0
var treasures: int = 0
var skips_used: int = 0
var pages_read: int = 0
var known_colonies: int = 0

var milestones: Dictionary = {}
var rows: Array = []
var done: bool = false


func _ready() -> void:
	var seed_value: int = 1
	var max_days: float = 0.0
	for arg: String in OS.get_cmdline_user_args():
		var kv: PackedStringArray = arg.split("=")
		if kv.size() != 2:
			continue
		match kv[0]:
			"pattern": pattern = kv[1]
			"seed": seed_value = int(kv[1])
			"on": on_hours = float(kv[1])
			"off": off_hours = float(kv[1])
			"target": target = int(kv[1])
			"max_exp": max_exp = int(kv[1])
			"max_hours": max_wall = float(kv[1]) * 3600.0
			"max_days": max_days = float(kv[1])
			"policy": policy = kv[1]
			"frac": frac = float(kv[1])
			"run_max": run_max = float(kv[1])
			"min_hours": min_hours = float(kv[1])
			"decision": decision = float(kv[1])
			"treasure": treasure_catch = float(kv[1])
			"ads": use_ads = kv[1] != "0"
			"charter_max": charter_max = int(kv[1])
			"verbose": verbose = kv[1] == "1"
			"liberty_exp": Balance.k["liberty_exponent"] = float(kv[1])
			_:
				# What-if overrides, in memory only (the data files are untouched):
				#   bal.<balance.json key>=value
				#   reform.<id|*>.<field>=value   e.g. reform.*.growth=1.6
				if kv[0].begins_with("bal."):
					Balance.k[kv[0].substr(4)] = float(kv[1])
					print("OVERRIDE %s=%s" % [kv[0], kv[1]])
				elif kv[0].begins_with("reform."):
					var parts: PackedStringArray = kv[0].split(".")
					for d: Dictionary in Content.liberty_upgrades:
						if parts.size() == 3 and (parts[1] == "*" or parts[1] == d["id"]):
							d[parts[2]] = float(kv[1])
					print("OVERRIDE %s=%s" % [kv[0], kv[1]])
	if max_days > 0.0:
		max_wall = max_days * 86400.0
	rng.seed = hash(["campaign", seed_value])
	meta = MetaState.new()
	print("CAMPAIGN pattern=%s seed=%d on=%.1f off=%.1f policy=%s frac=%.2f run_max=%.1f treasure=%.2f ads=%s liberty_base=%s liberty_exp=%s growth=%s" % [
		pattern, seed_value, on_hours, off_hours, policy, frac, run_max, treasure_catch, str(use_ads),
		str(Balance.v("liberty_base")), str(Balance.v("liberty_exponent")), str(Content.liberty_upgrade("industry")["growth"])])
	print("EXP  #  | exp act h | exp wall h | cum act h | cum wall d | cols | gate@h | liberty | reforms | govs | relics | studies | fathers | skips pages")
	_start_expedition()
	if pattern == "casual":
		_casual_loop()
	else:
		_active_loop()
	_summary()
	get_tree().quit()


# --- Campaign loops --------------------------------------------------------------

func _stop() -> bool:
	return done or exp_index > max_exp or wall >= max_wall


func _active_loop() -> void:
	while not _stop():
		_active_tick()


func _casual_loop() -> void:
	while not _stop():
		_login()
		var session_end: float = wall + on_hours * 3600.0
		while wall < session_end and not _stop():
			_active_tick(session_end - wall)
		if _stop():
			break
		_away(off_hours * 3600.0)


## Time away: the colonies work at offline pace up to the offline cap.
func _away(seconds: float) -> void:
	var capped: float = minf(seconds, Balance.offline_cap_seconds(run, meta))
	var ev := SimEvents.new()
	run.sim_rate = Balance.v("offline_efficiency")
	var chunk: float = Balance.v("offline_step_seconds")
	var left: float = capped
	while left > 0.0:
		var s: float = minf(chunk, left)
		Sim.step(run, meta, s, ev)
		left -= s
		progress += s * run.sim_rate
		_sample_liberty()
	run.sim_rate = 1.0
	wall += seconds


## Back in the game: sell surplus, take the Favor and one rewarded skip.
func _login() -> void:
	_sell_excess()
	_favor()
	consult_pending = use_ads


## A skip ahead at full pace (Almanac page or Consult), as Game._skip_ahead.
func _skip(seconds: float) -> void:
	var lib_before: float = _raw_liberty()
	var ev := SimEvents.new()
	var chunk: float = Balance.v("offline_step_seconds")
	var left: float = seconds
	while left > 0.0:
		var s: float = minf(chunk, left)
		Sim.step(run, meta, s, ev)
		left -= s
		progress += s
	# A skip's Liberty is a windfall, not the run's pace: kept out of the
	# marginal rate the declare policy watches.
	skip_liberty += _raw_liberty() - lib_before
	_sample_liberty()


func _favor() -> void:
	if wall >= favor_ready:
		run.favor_seconds += Balance.v("favor_seconds") * Balance.research_mult(run, "favor_duration")
		favor_ready = wall + Balance.v("favor_cooldown_seconds")


## One stretch of live play followed by the player's decisions.
func _active_tick(limit: float = INF) -> void:
	var dt: float = minf(_next_dt(), limit)
	if dt <= 0.0:
		dt = minf(decision, maxf(limit, 0.1))
	var ev := SimEvents.new()
	Sim.step(run, meta, dt, ev)
	wall += dt
	active_total += dt
	progress += dt
	var sample: float = ev.gold_earned / dt / (Balance.v("favor_multiplier") if run.favor_seconds > 0.0 else 1.0)
	income_ema = sample if income_ema <= 0.0 else lerpf(income_ema, sample, clampf(dt / 20.0, 0.05, 1.0))
	_treasure(dt)
	_favor()
	# The rewarded skip: active players take it whenever it is ready, casual
	# ones once per absence; neither bothers in a run's first half hour.
	if (consult_pending or (pattern == "active" and use_ads)) and wall >= consult_ready and progress >= 1800.0:
		consult_pending = false
		consult_ready = wall + Balance.v("ad_skip_cooldown_seconds")
		_skip(Balance.v("ad_skip_seconds"))
		skips_used += 1
	sell_timer += dt
	if sell_timer >= 300.0:
		sell_timer = 0.0
		_sell_excess()
	_play()
	_sample_liberty()
	if not stall_reported and progress >= run_max * 3600.0 and not Balance.independence_ready(run):
		stall_reported = true
		_report_stall()
	if Balance.independence_ready(run) and ready_progress < 0.0:
		ready_progress = progress
	if Balance.independence_ready(run) and _should_declare():
		# Almanac pages are saved for the end of the run: an hour each at full
		# pace, then one more round of purchases, then the Declaration.
		if meta.almanacs > 0 and Balance.unlocked(meta, "almanac"):
			_read_pages()
			_play()
		_declare()


var _bought_last: int = 0


func _next_dt() -> float:
	if _bought_last > 0 or last_best_cost == INF:
		return decision
	var inc: float = maxf(maxf(income_ema, _income()), 0.01)
	var wait: float = (last_best_cost - run.gold) / inc
	return clampf(wait, decision, IDLE_STEP_MAX)


## All in-run decisions for one tick.
func _play() -> void:
	_bought_last = 0
	_post_governors()
	_musket_push()
	_research()
	_charters()
	for i in 200:
		if not _decide():
			break
		_bought_last += 1
		_check_new_colony()
	_apply_holds()


func _treasure(dt: float) -> void:
	treasure_timer -= dt
	while treasure_timer <= 0.0:
		treasure_timer += rng.randf_range(Balance.v("treasure_min_seconds"), Balance.v("treasure_max_seconds"))
		if rng.randf() >= treasure_catch:
			continue
		var amount: float = maxf(Balance.v("treasure_min_gold"), income_ema * Balance.v("treasure_income_seconds"))
		amount *= Balance.bonus(run, meta, "treasure") * Balance.research_mult(run, "treasure")
		run.gold += amount
		run.lifetime_gold += amount
		treasures += 1
		if Balance.unlocked(meta, "relics") and meta.relics.size() < Content.relics.size() and rng.randf() < Balance.v("relic_treasure_chance"):
			_grant_relic()
		elif Balance.unlocked(meta, "almanac") and rng.randf() < Balance.v("almanac_treasure_chance"):
			meta.almanacs += 1


func _read_pages() -> void:
	while meta.almanacs > 0 and Balance.unlocked(meta, "almanac"):
		meta.almanacs -= 1
		pages_read += 1
		_skip(Balance.v("almanac_seconds"))


# --- Declaring ---------------------------------------------------------------------

## Liberty_payout without the gate or the rounding, so its rate is smooth.
func _raw_liberty() -> float:
	return Balance.v("liberty_base") * pow(run.lifetime_gold / Balance.v("independence_gold"), Balance.v("liberty_exponent")) \
		* Balance.nation_bonus(run, "liberty") * Balance.bonus(run, meta, "liberty") * Balance.research_mult(run, "liberty")


func _sample_liberty() -> void:
	if lib_samples.is_empty() or progress - float(lib_samples[-1][0]) >= 60.0:
		lib_samples.append([progress, _raw_liberty() - skip_liberty])
		while lib_samples.size() > 2 and progress - float(lib_samples[1][0]) >= WINDOW_SECONDS:
			lib_samples.pop_front()


## Liberty per active-equivalent hour over the trailing window.
func _marginal() -> float:
	if lib_samples.size() < 2:
		return 0.0
	var a: Array = lib_samples[0]
	var span: float = progress - float(a[0])
	if span < WINDOW_SECONDS * 0.5:
		return 0.0
	return (_raw_liberty() - skip_liberty - float(a[1])) / (span / 3600.0)


func _should_declare() -> bool:
	if progress < min_hours * 3600.0:
		return false
	if policy == "asap":
		return true
	if progress >= run_max * 3600.0:
		return true
	var since: float = progress - ready_progress
	var m: float = _marginal()
	if since < WINDOW_SECONDS:
		peak_marginal = maxf(peak_marginal, m)
		return false
	peak_marginal = maxf(peak_marginal, m)
	return m < frac * peak_marginal


func _declare() -> void:
	var liberty: int = Balance.liberty_payout(run, meta)
	var extra_relics: int = int(Balance.research_add(run, "extra_relic"))
	meta.liberty += liberty
	meta.lifetime_liberty += liberty
	meta.runs_completed += 1
	meta.best_run_gold = maxf(meta.best_run_gold, run.lifetime_gold)
	if Balance.unlocked(meta, "relics"):
		for i in 1 + extra_relics:
			_grant_relic()
	if Balance.unlocked(meta, "almanac"):
		meta.almanacs += int(Balance.v("almanac_per_independence"))
	_claim_records()
	var spent: Array = _spend_liberty()
	var reforms: int = 0
	for d: Dictionary in Content.liberty_upgrades:
		reforms += meta.level(d["id"])
	var exp_act: float = (active_total - exp_active_start) / 3600.0
	var exp_wall: float = (wall - exp_wall_start) / 3600.0
	var row: Dictionary = {
		"i": exp_index, "exp_act": exp_act, "exp_wall": exp_wall, "cum_act": active_total / 3600.0,
		"cum_wall": wall / 3600.0, "cols": run.colonies.size(), "gate": ready_progress / 3600.0,
		"progress": progress / 3600.0, "liberty": liberty, "reforms": reforms, "govs": meta.governors.size(),
		"relics": meta.relics.size(), "studies": studies_bought, "fathers": run.fathers.size(),
	}
	rows.append(row)
	print("EXP %3d | %9.2f | %10.2f | %9.2f | %10.2f | %4d | %6.2f | %7d | %7d | %4d | %6d | %7d | %7d | %d %d  lvls=%s gov_ranks=%s run_h=%.2f" % [
		exp_index, exp_act, exp_wall, active_total / 3600.0, wall / 86400.0, run.colonies.size(), ready_progress / 3600.0,
		liberty, reforms, meta.governors.size(), meta.relics.size(), studies_bought, run.fathers.size(), skips_used, pages_read,
		_levels_str(), str(spent), progress / 3600.0])
	if exp_index >= max_exp:
		done = true
		return
	_start_expedition()


func _levels_str() -> String:
	var parts: Array = []
	for d: Dictionary in Content.liberty_upgrades:
		parts.append("%s%d" % [str(d["id"]).substr(0, 3), meta.level(d["id"])])
	return ",".join(parts)


## Spends Liberty cheapest-first across the five reforms, commissioning and
## promoting governors (Surveyors, production) when they are the cheapest.
func _spend_liberty() -> Array:
	var guard: int = 0
	while guard < 10000:
		guard += 1
		var best_cost: int = -1
		var best_action: Callable = Callable()
		for d: Dictionary in Content.liberty_upgrades:
			var id: String = d["id"]
			var c: int = Balance.liberty_upgrade_cost(meta, id)
			if c >= 0 and (best_cost < 0 or c < best_cost):
				best_cost = c
				best_action = func() -> void: meta.upgrades[id] = meta.level(id) + 1
		var cc: int = Balance.governor_commission_cost(meta)
		if best_cost < 0 or cc < best_cost:
			best_cost = cc
			best_action = func() -> void:
				meta.governors.append({"id": meta.next_governor_id, "name": "G%d" % meta.next_governor_id, "type": "prod", "rank": 1})
				meta.next_governor_id += 1
		for g: Dictionary in meta.governors:
			var rc: int = Balance.governor_rank_cost(int(g["rank"]))
			if rc >= 0 and rc < best_cost:
				best_cost = rc
				var gg: Dictionary = g
				best_action = func() -> void: gg["rank"] = int(gg["rank"]) + 1
		if best_cost < 0 or best_cost > meta.liberty:
			break
		meta.liberty -= best_cost
		best_action.call()
	var ranks: Array = []
	for g: Dictionary in meta.governors:
		ranks.append(int(g["rank"]))
	return ranks


func _grant_relic() -> void:
	var missing: Array[String] = []
	for r: Dictionary in Content.relics:
		if not meta.has_relic(str(r["id"])):
			missing.append(str(r["id"]))
	if missing.is_empty():
		meta.almanacs += 1
		return
	meta.relics.append(missing[rng.randi_range(0, missing.size() - 1)])


func _claim_records() -> void:
	if Balance.unlocked(meta, "relics"):
		for t: Variant in Balance.k.get("relic_colony_records", []):
			var threshold: int = int(t)
			if meta.best_colonies >= threshold and not meta.record_relics_claimed.has(threshold):
				meta.record_relics_claimed.append(threshold)
				_grant_relic()
	if Balance.unlocked(meta, "almanac"):
		var from: int = maxi(int(Balance.v("almanac_record_from")), meta.record_almanac_claimed + 1)
		for n in range(from, meta.best_colonies + 1):
			meta.record_almanac_claimed = n
			meta.almanacs += 1


func _start_expedition() -> void:
	exp_index += 1
	if exp_index > max_exp:
		return
	run = RunState.create("english", WorldMap.STYLE_RANDOM, rng.randi())
	run.gold = Balance.v("start_gold")
	# The market follows the run's start time; fix it so a campaign replays.
	run.started_unix = float(rng.randi())
	_offered = []
	exp_wall_start = wall
	exp_active_start = active_total
	progress = 0.0
	ready_progress = -1.0
	stall_reported = false
	lib_samples.clear()
	skip_liberty = 0.0
	peak_marginal = 0.0
	income_ema = 0.0
	father_wants.clear()
	study_wants.clear()
	charter_wants.clear()
	studies_bought = 0
	known_colonies = 1
	last_best_cost = INF
	_post_governors()


func _check_new_colony() -> void:
	var n: int = run.colonies.size()
	if n == known_colonies:
		return
	known_colonies = n
	_post_governors()
	if verbose:
		print("    exp %d colony %d at exp act %.2fh" % [exp_index, n, (active_total - exp_active_start) / 3600.0])
	if n > meta.best_colonies:
		meta.best_colonies = n
		_claim_records()
		print("COL %2d  exp %d  cum act %.2fh  wall %.2fh (%.2fd)" % [n, exp_index, active_total / 3600.0, wall / 3600.0, wall / 86400.0])
		if n in [5, 10, 15, 20, 25]:
			milestones[n] = {"exp": exp_index, "act": active_total / 3600.0, "wall": wall / 3600.0}
			print("MILESTONE colony %d  exp %d  active %.2fh  wall %.2fh = %.2f days" % [n, exp_index, active_total / 3600.0, wall / 3600.0, wall / 86400.0])
		if n >= target:
			done = true


func _summary() -> void:
	print("SUMMARY pattern=%s expeditions=%d active=%.2fh wall=%.2fh (%.2fd) best_colonies=%d reforms=%s govs=%d relics=%d" % [
		pattern, rows.size(), active_total / 3600.0, wall / 3600.0, wall / 86400.0, meta.best_colonies, _levels_str(),
		meta.governors.size(), meta.relics.size()])
	if not rows.is_empty():
		print("SUMMARY first independence: active %.2fh wall %.2fh" % [float(rows[0]["cum_act"]), float(rows[0]["cum_wall"])])
	for n: int in [5, 10, 15, 20, 25]:
		if milestones.has(n):
			var m: Dictionary = milestones[n]
			print("SUMMARY colony %d: exp %d active %.2fh wall %.2fh (%.2fd)" % [n, int(m["exp"]), float(m["act"]), float(m["wall"]), float(m["wall"]) / 24.0])
		else:
			print("SUMMARY colony %d: not reached" % n)


# --- Holds and selling ---------------------------------------------------------------

func _wants() -> Dictionary:
	var w: Dictionary = {}
	for d: Dictionary in [father_wants, study_wants, charter_wants]:
		for key: String in d.keys():
			w[key] = float(w.get(key, 0.0)) + float(d[key])
	return w


## Keeps what staffed workshops and pending purchases need; anything no longer
## needed is released and its stock sold (as Game.set_hold does).
func _apply_holds() -> void:
	var wants: Dictionary = _wants()
	for r: Dictionary in Content.resources:
		var id: String = r["id"]
		var h: bool = _needed_by_workshop(id) or wants.has(id)
		if run.is_held(id) and not h:
			run.hold[id] = false
			_sell(id, 0.0)
		elif h:
			run.hold[id] = true


## Periodically sells held stock beyond what the workshops use in 10 minutes
## and what pending purchases need, like a player tapping Sell on a pile.
func _sell_excess() -> void:
	var wants: Dictionary = _wants()
	for id: String in run.warehouse.keys():
		if not run.is_held(id):
			continue
		var keep: float = float(wants.get(id, 0.0)) + _consumption(id) * 600.0
		_sell(id, keep)


func _sell(id: String, keep: float) -> void:
	keep = maxf(keep, Balance.militia_reserve(run, id))
	var qty: float = run.stock_of(id) - keep
	if qty <= 0.0:
		return
	run.warehouse[id] = keep
	Sim.sell(run, meta, id, qty, SimEvents.new())


func _consumption(res: String) -> float:
	var s: float = 0.0
	for w: RunState.WorkshopState in run.workshops.values():
		if w.built and w.colonists > 0:
			var inputs: Dictionary = Balance.recipe_inputs(run, w.id)
			if inputs.has(res):
				s += float(inputs[res]) / Balance.craft_seconds(run, meta, w)
	return s


## The raw good bringing in the most gold; never held back for a purchase.
func _primary_raw() -> String:
	var by: Dictionary = {}
	for c: RunState.ColonyState in run.colonies:
		var r: String = run.resource_of(c)
		by[r] = float(by.get(r, 0.0)) + _colony_income(c)
	var best: String = ""
	var best_v: float = -1.0
	var total: float = 0.0
	for r: String in by.keys():
		total += float(by[r])
		if float(by[r]) > best_v:
			best_v = float(by[r])
			best = r
	return best


var _share_cache: Dictionary = {}
var _offered: Array[Dictionary] = []


func _raw_share_cached(res: String) -> float:
	if not _share_cache.has(res):
		_share_cache[res] = _raw_share(res)
	return _share_cache[res]


func _raw_share(res: String) -> float:
	var s: float = 0.0
	var total: float = 0.0
	for c: RunState.ColonyState in run.colonies:
		var inc: float = _colony_income(c)
		total += inc
		if run.resource_of(c) == res:
			s += inc
	return s / maxf(total, 0.0001)


## Whether `res` can be gathered for a purchase within an hour without
## starving the run of its main income.
func _gatherable(res: String, need: float, primary: String) -> bool:
	var have: float = Balance.spendable(run, res)
	if have >= need:
		return true
	if not Content.is_crafted(res) and (res == primary or _raw_share(res) > 0.25):
		return false
	var sup: float = _supply(res)
	if sup <= 0.0:
		return false
	return (need - have) / sup <= 3600.0


# --- Research (improved picker) --------------------------------------------------------

## Picks the cheapest open study (gold plus goods at sale value) whose goods
## the run produces or crafts, holds those goods until it is bought.
func _research() -> void:
	study_wants.clear()
	if not Balance.unlocked(meta, "research"):
		return
	var primary: String = _primary_raw()
	var best: String = ""
	var best_val: float = INF
	for def: Dictionary in Content.research:
		var id: String = str(def["id"])
		if Balance.study_block(run, meta, id) != "":
			continue
		var cost: Dictionary = Balance.study_cost(run, id)
		var val: float = float(cost.get("gold", 0.0))
		var ok: bool = true
		for key: String in cost.keys():
			if key == "gold":
				continue
			if not _gatherable(key, float(cost[key]), primary):
				ok = false
				break
			val += float(cost[key]) * Balance.sell_price(run, meta, key)
		if ok and val < best_val:
			best_val = val
			best = id
	if best == "":
		return
	var cost2: Dictionary = Balance.study_cost(run, best)
	var afford: bool = true
	for key: String in cost2.keys():
		var have: float = run.gold if key == "gold" else Balance.spendable(run, key)
		if have + 0.0001 < float(cost2[key]):
			afford = false
		if key != "gold":
			study_wants[key] = float(cost2[key])
	if not afford:
		return
	for key: String in cost2.keys():
		if key == "gold":
			run.gold -= float(cost2[key])
		else:
			run.warehouse[key] = run.stock_of(key) - float(cost2[key])
	run.research[best] = run.study_level(best) + 1
	run.research_version += 1
	studies_bought += 1
	study_wants.clear()


# --- Charters and specializations ------------------------------------------------------

## Works towards the next charter of the most valuable colony whose goods the
## run makes, then picks its specialization when unlocked.
func _charters() -> void:
	charter_wants.clear()
	var primary: String = _primary_raw()
	for i in range(run.colonies.size() - 1, -1, -1):
		var c: RunState.ColonyState = run.colonies[i]
		if c.charter >= mini(charter_max, Content.charters.size()):
			continue
		var cost: Dictionary = Balance.charter_cost(run, c, c.charter + 1)
		var ok: bool = true
		for key: String in cost.keys():
			if not _gatherable(key, float(cost[key]), primary):
				ok = false
		if not ok:
			continue
		var afford: bool = true
		for key: String in cost.keys():
			if Balance.spendable(run, key) + 0.0001 < float(cost[key]):
				afford = false
		if afford:
			for key: String in cost.keys():
				run.warehouse[key] = run.stock_of(key) - float(cost[key])
			c.charter += 1
			_choose_spec(c)
			return
		charter_wants = cost.duplicate()
		return


func _choose_spec(c: RunState.ColonyState) -> void:
	if c.spec != "" or c.charter < 1 or not Balance.unlocked(meta, "specializations"):
		return
	var best: String = ""
	var best_v: float = -1.0
	for s: Dictionary in Balance.specs_offered(run, c):
		c.spec = s["id"]
		var v: float = _income()
		if v > best_v:
			best_v = v
			best = s["id"]
	c.spec = best


# --- Valuation (from balance_bot) ------------------------------------------------------

func _colony_income(c: RunState.ColonyState) -> float:
	return minf(Balance.production_rate(run, meta, c), Balance.route_throughput(run, meta, c)) * Balance.sell_price(run, meta, run.resource_of(c))


func _income() -> float:
	var s: float = 0.0
	for c: RunState.ColonyState in run.colonies:
		s += _cinc(c) if _cache_on else _colony_income(c)
	for w: RunState.WorkshopState in run.workshops.values():
		s += _margin_base(w) if _cache_on else _craft_margin(w)
	return s


## Within a decision pass a colony's production, route throughput, price and
## colonist multiplier are worked out once; a one-level bump scales them by
## the level formulas in Balance (same result, a fraction of the cost).
var _parts: Dictionary = {}
var _margins: Dictionary = {}


func _part(c: RunState.ColonyState) -> Array:
	if not _parts.has(c.id):
		var res: String = run.resource_of(c)
		_parts[c.id] = [Balance.production_rate(run, meta, c), Balance.route_throughput(run, meta, c),
			Balance.sell_price(run, meta, res),
			Balance.v("colonist_production_bonus") * Balance.spec_mult(c, "colonist") * Balance.research_mult(run, "colonist_bonus", [res])]
	return _parts[c.id]


func _cinc(c: RunState.ColonyState, pmul: float = 1.0, tmul: float = 1.0) -> float:
	var p: Array = _part(c)
	return minf(float(p[0]) * pmul, float(p[1]) * tmul) * float(p[2])


func _lvl_factor(track: String, lvl: int) -> float:
	match track:
		"cargo": return (1.0 + Balance.v("cargo_per_level") * lvl) * Balance.milestone_mult(lvl, Balance.v("milestone_cargo_mult"))
		"speed": return (1.0 + Balance.v("speed_per_level") * lvl) * Balance.milestone_mult(lvl, Balance.v("milestone_speed_mult"))
	return (1.0 + Balance.v("prod_per_level") * lvl) * Balance.milestone_mult(lvl, Balance.v("milestone_prod_mult"))


## Income of `c` with each track raised by the given number of levels and
## `extra` more colonists.
func _cinc_bumped(c: RunState.ColonyState, dp: int, dc: int, ds: int, extra: int = 0) -> float:
	var pm: float = _lvl_factor("prod", c.prod_level + dp) / _lvl_factor("prod", c.prod_level)
	var tm: float = _lvl_factor("cargo", c.cargo_level + dc) / _lvl_factor("cargo", c.cargo_level)
	tm *= _lvl_factor("speed", c.speed_level + ds) / _lvl_factor("speed", c.speed_level)
	if extra != 0:
		var k: float = float(_part(c)[3])
		pm *= (1.0 + k * (c.colonists + extra)) / (1.0 + k * c.colonists)
	return _cinc(c, pm, tm)


func _margin_base(w: RunState.WorkshopState) -> float:
	if not _margins.has(w.id):
		_margins[w.id] = _craft_margin(w)
	return _margins[w.id]


## Supply is memoized within one decision pass (cleared whenever state
## changes for real); perturbations only touch a workshop's own rate or a
## colony's income, never an upstream supply.
var _supply_cache: Dictionary = {}
var _cache_on: bool = false


func _supply(res: String) -> float:
	if _cache_on and _supply_cache.has(res):
		return _supply_cache[res]
	var s: float = _supply_raw(res)
	if _cache_on:
		_supply_cache[res] = s
	return s


func _supply_raw(res: String) -> float:
	var s: float = 0.0
	for c: RunState.ColonyState in run.colonies:
		if run.resource_of(c) == res:
			s += minf(Balance.production_rate(run, meta, c), Balance.route_throughput(run, meta, c))
	var w: RunState.WorkshopState = run.workshop(res)
	if w != null and w.built and w.colonists > 0:
		s += _craft_rate(w)
	return s


func _craft_rate(w: RunState.WorkshopState) -> float:
	var inputs: Dictionary = Balance.recipe_inputs(run, w.id)
	var r: float = 1.0 / Balance.craft_seconds(run, meta, w)
	for input_id: String in inputs.keys():
		r = minf(r, _supply(input_id) / float(inputs[input_id]))
	return r


func _craft_margin(w: RunState.WorkshopState) -> float:
	if not w.built or w.colonists <= 0:
		return 0.0
	var inputs: Dictionary = Balance.recipe_inputs(run, w.id)
	var in_val: float = 0.0
	for input_id: String in inputs.keys():
		in_val += float(inputs[input_id]) * Balance.sell_price(run, meta, input_id)
	return _craft_rate(w) * (Balance.sell_price(run, meta, w.id) - in_val)


# --- Greedy decisions (from balance_bot) ---------------------------------------------------

func _decide() -> bool:
	_supply_cache.clear()
	_share_cache.clear()
	_parts.clear()
	_margins.clear()
	_cache_on = true
	var r: bool = _decide_inner()
	_cache_on = false
	_supply_cache.clear()
	_parts.clear()
	_margins.clear()
	return r


func _decide_inner() -> bool:
	var base_income: float = maxf(_income(), 0.01)

	# Every option is scored as in balance_bot; the best few that touch
	# different things are bought in one pass (re-scoring after each buy
	# is what made long campaigns slow).
	var cands: Array = []
	var consider := func(gain: float, cost: float, action: Callable, key: String) -> void:
		if cost <= 0.0 or gain <= 0.0:
			return
		var wait: float = maxf(0.0, (cost - run.gold) / base_income)
		var score: float = gain / (cost / base_income + wait + 1.0) / cost * base_income
		cands.append([score, cost, action, key])

	if run.next_site() >= 0:
		var fc: float = Balance.found_cost(run, meta)
		var gain: float = Balance.tier_value(run.colonies.size()) * 1.2
		consider.call(gain * 3.0, fc, func() -> void:
			run.gold -= fc
			run.found_next(), "found")

	for c: RunState.ColonyState in run.colonies:
		var before: float = _cinc(c)
		var tracks: Array = ["prod"] if c.tier == 0 else ["prod", "cargo", "speed"]
		for track: String in tracks:
			var cost: float = Balance.colony_upgrade_cost(run, track, c)
			var gain: float = _cinc_bumped(c, 1 if track == "prod" else 0, 1 if track == "cargo" else 0, 1 if track == "speed" else 0) - before
			var cc: RunState.ColonyState = c
			var tr: String = track
			consider.call(gain, cost, func() -> void:
				run.gold -= cost
				_bump(cc, tr, 1), cc.id)
		if c.tier > 0:
			var bundle: float = 0.0
			for tr2: String in ["prod", "cargo", "speed"]:
				bundle += Balance.colony_upgrade_cost(run, tr2, c)
			var gb: float = _cinc_bumped(c, 1, 1, 1) - before
			var cb: RunState.ColonyState = c
			consider.call(gb, bundle, func() -> void:
				run.gold -= bundle
				for tr3: String in ["prod", "cargo", "speed"]:
					_bump(cb, tr3, 1), cb.id)
		if run.colonists_idle() > 0:
			var g2: float = _cinc_bumped(c, 0, 0, 0, 1) - before
			var cc2: RunState.ColonyState = c
			consider.call(g2, 0.001, func() -> void: cc2.colonists += 1, "assign")

	var ccost: float = Balance.colonist_cost(run, meta)
	var best_col_gain: float = 0.0
	for c: RunState.ColonyState in run.colonies:
		best_col_gain = maxf(best_col_gain, _cinc_bumped(c, 0, 0, 0, 1) - _cinc(c))
	for w: RunState.WorkshopState in run.workshops.values():
		if w.built:
			var b3: float = _margin_base(w)
			w.colonists += 1
			best_col_gain = maxf(best_col_gain, _craft_margin(w) - b3)
			w.colonists -= 1
	consider.call(best_col_gain, ccost, func() -> void:
		run.gold -= ccost
		run.colonists_owned += 1, "recruit")

	for def: Dictionary in Content.recipes:
		var w: RunState.WorkshopState = run.workshop(def["id"])
		var inputs: Dictionary = Balance.recipe_inputs(run, w.id)
		var ok: bool = true
		for input_id: String in inputs.keys():
			if _supply(input_id) <= 0.0:
				ok = false
		if not ok:
			continue
		if not w.built:
			var bc: float = Balance.workshop_build_cost(w.id)
			w.built = true
			w.colonists = 1
			var g: float = _craft_margin(w)
			w.built = false
			w.colonists = 0
			var ww: RunState.WorkshopState = w
			consider.call(maxf(g, 1.0), bc, func() -> void:
				run.gold -= bc
				ww.built = true, "w" + ww.id)
		else:
			var b: float = _margin_base(w)
			var uc: float = Balance.workshop_upgrade_cost(run, w)
			w.level += 1
			var g4: float = _craft_margin(w) - b
			w.level -= 1
			var w2: RunState.WorkshopState = w
			consider.call(g4, uc, func() -> void:
				run.gold -= uc
				w2.level += 1, "w" + w2.id)
			if run.colonists_idle() > 0:
				w.colonists += 1
				var g5: float = _craft_margin(w) - b
				w.colonists -= 1
				if w.colonists == 0:
					g5 = maxf(g5, 1.0)
				consider.call(g5, 0.001, func() -> void:
					w2.colonists += 1
					for input_id: String in inputs.keys():
						run.hold[input_id] = true, "assign")

	# Founding Fathers: the first affordable one joins; goods for the others
	# are kept once half their gold is in hand (balance_bot's rule).
	father_wants.clear()
	if _offered.is_empty():
		_offered = Balance.fathers_offered(run)
	for f: Dictionary in _offered:
		if run.has_father(f["id"]):
			continue
		var cost_f: Dictionary = Balance.father_cost(run, f["id"])
		var afford: bool = true
		for key: String in cost_f.keys():
			var have: float = run.gold if key == "gold" else Balance.spendable(run, key)
			if have < float(cost_f[key]):
				afford = false
		for key: String in cost_f.keys():
			if key == "gold" or _needed_by_workshop(key):
				continue
			var gold_ok: bool = run.gold >= float(cost_f.get("gold", 0.0)) * 0.5
			if gold_ok and Balance.spendable(run, key) < float(cost_f[key]) and _supply(key) > 0.0 and (Content.is_crafted(key) or _raw_share_cached(key) <= 0.25):
				father_wants[key] = maxf(float(father_wants.get(key, 0.0)), float(cost_f[key]))
		if afford:
			for key: String in cost_f.keys():
				if key == "gold":
					run.gold -= float(cost_f[key])
				else:
					run.warehouse[key] = run.stock_of(key) - float(cost_f[key])
			run.fathers.append(f["id"])
			if f["effect"] == "free_colonists":
				run.colonists_owned += int(f["value"])
			return true

	if cands.is_empty():
		last_best_cost = INF
		return false
	cands.sort_custom(func(a: Array, b: Array) -> bool: return float(a[0]) > float(b[0]))
	last_best_cost = float(cands[0][1])
	var used: Dictionary = {}
	var bought: int = 0
	for cnd: Array in cands:
		var key: String = cnd[3]
		if used.has(key):
			continue
		if float(cnd[1]) > run.gold:
			break
		used[key] = true
		(cnd[2] as Callable).call()
		bought += 1
		if bought >= 12:
			break
	return bought > 0


func _bump(c: RunState.ColonyState, track: String, d: int) -> void:
	match track:
		"prod": c.prod_level += d
		"cargo": c.cargo_level += d
		"speed": c.speed_level += d


## Governors (all Surveyors) go to the most valuable colonies, best rank first.
func _post_governors() -> void:
	run.governors.clear()
	var gs: Array = meta.governors.duplicate()
	gs.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return int(a["rank"]) > int(b["rank"]))
	var i: int = run.colonies.size() - 1
	for g: Dictionary in gs:
		if i < 0:
			break
		run.governors[run.colonies[i].id] = int(g["id"])
		i -= 1


## A real player is told to arm the militia; the bot does it once the gold
## gate is a third of the way reached.
func _musket_push() -> void:
	if run.lifetime_gold < Balance.v("independence_gold") * 0.3:
		return
	for id: String in ["lumber", "charcoal", "pig_iron", "tools", "muskets"]:
		var w: RunState.WorkshopState = run.workshop(id)
		for input_id: String in Balance.recipe_inputs(run, id).keys():
			if _supply(input_id) <= 0.0 and run.stock_of(input_id) <= 0.0:
				return
		if not w.built:
			if run.gold < Balance.workshop_build_cost(id):
				return
			run.gold -= Balance.workshop_build_cost(id)
			w.built = true
		if w.colonists == 0:
			if run.colonists_idle() == 0:
				if run.gold < Balance.colonist_cost(run, meta):
					return
				run.gold -= Balance.colonist_cost(run, meta)
				run.colonists_owned += 1
			w.colonists = 1
		for input_id: String in Balance.recipe_inputs(run, id).keys():
			run.hold[input_id] = true


func _needed_by_workshop(res: String) -> bool:
	for w: RunState.WorkshopState in run.workshops.values():
		if w.built and w.colonists > 0 and Balance.recipe_inputs(run, w.id).has(res):
			return true
	return false


## Why a run past run_max still can't declare: the gold goal and the musket chain.
func _report_stall() -> void:
	var parts: PackedStringArray = []
	for id: String in ["lumber", "charcoal", "pig_iron", "tools", "muskets"]:
		var w: RunState.WorkshopState = run.workshop(id)
		var ins: PackedStringArray = []
		for input_id: String in Balance.recipe_inputs(run, id).keys():
			ins.append("%s sup=%s stock=%s" % [input_id, str(snappedf(_supply(input_id), 0.001)), str(snappedf(run.stock_of(input_id), 0.01))])
		parts.append("%s built=%s col=%d stock=%s [%s]" % [id, str(w.built), w.colonists, str(snappedf(run.stock_of(id), 0.01)), ", ".join(ins)])
	var cols: PackedStringArray = []
	for c: RunState.ColonyState in run.colonies:
		cols.append("%s:%s(site %s) col=%d" % [c.id, run.resource_of(c), str(run.site_of(c)["resource"]), c.colonists])
	print("STALL colonies " + ", ".join(cols))
	var iron: Array = []
	for i in run.world.sites.size():
		if str(run.world.sites[i]["resource"]) == "iron_ore":
			iron.append(i)
	var order: PackedStringArray = []
	for si: Variant in run.world.colony_order:
		order.append(str(run.world.sites[int(si)]["resource"]))
	print("STALL sites=%d iron_sites=%s style=%s order=%s" % [run.world.sites.size(), str(iron), str(run.world.style), ",".join(order)])
	print("STALL exp %d progress %.1fh lifetime_gold %s gold %s muskets %s | %s" % [
		exp_index, progress / 3600.0, str(run.lifetime_gold), str(run.gold), str(run.stock_of("muskets")), " | ".join(parts)])
