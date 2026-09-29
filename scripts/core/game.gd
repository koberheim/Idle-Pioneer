## The running game: owns the state, drives the fixed-step simulation, and is
## the only place state is changed. UI calls the command functions below and
## listens to the signals; it never writes to state directly.
extends Node

signal run_started
signal gold_earned(amount: float)
signal shipment_arrived(colony_id: String, resource_id: String, qty: float)
signal resource_discovered(resource_id: String)
signal colony_founded(colony_id: String)
signal workshop_built(recipe_id: String)
signal father_joined(father_id: String)
signal independence_declared(liberty: int)
signal offline_progress(seconds: float, ev: SimEvents)
signal purchased
signal market_changed
signal treasure_collected(amount: float)
## An upgrade crossed a milestone. `what` is a colony id or a recipe id.
signal milestone_reached(what: String, track: String, level: int)
signal relic_found(relic_id: String, source: String)
signal almanac_gained(count: int, source: String)
signal almanac_read(seconds: float, ev: SimEvents)
signal studied(study_id: String)
## Saving started failing (false) or recovered (true).
signal save_status_changed(ok: bool)

var save_path: String = "user://save.json"
const AUTOSAVE_SECONDS := 15.0
## Gaps longer than this between frames (the app was suspended) are treated
## as time away rather than a slow frame.
const SUSPEND_GAP_SECONDS := 3.0

var meta: MetaState = MetaState.new()
var run: RunState = null
## Shared buy-quantity selector: 1, 10, 100, or -1 for "as many as affordable".
var buy_amount: int = 1
var running: bool = false
## Smoothed gold per second, for display.
var income_rate: float = 0.0

var _accum: float = 0.0
var _autosave_timer: float = 0.0
var _last_frame_unix: float = 0.0
var _income_window: float = 0.0
var _income_time: float = 0.0
var _rng := RandomNumberGenerator.new()
var _market_period: int = -1
## Whether the last save reached the disk; while false, saving is retried.
var save_ok: bool = true
var _save_retry: float = 0.0
const SAVE_RETRY_SECONDS := 5.0


func _ready() -> void:
	_rng.randomize()
	process_mode = Node.PROCESS_MODE_ALWAYS


## Called once by the main scene. Returns true when a run is in progress
## (loaded from disk); false means the player must choose a nation first.
## True when the save on disk comes from a newer version of the game: it is
## left untouched (never loaded or overwritten) until the game is updated.
var save_from_newer_version: bool = false


func boot() -> bool:
	var data: Dictionary = SaveIO.read(save_path)
	if data.is_empty():
		return false
	if SaveIO.is_newer(data):
		save_from_newer_version = true
		return false
	meta = MetaState.from_dict(data.get("meta", {}))
	meta.add_stat("app_opens")
	var run_data: Variant = data.get("run")
	if run_data is Dictionary and not (run_data as Dictionary).is_empty():
		run = RunState.from_dict(run_data)
		if run == null:
			return false
		running = true
		_last_frame_unix = Time.get_unix_time_from_system()
		var since: float = maxf(float(data.get("saved_unix", _last_frame_unix)), meta.max_seen_unix)
		_catch_up(_last_frame_unix - since)
		return true
	return false


func start_run(nation_id: String, map_style: String = WorldMap.STYLE_RANDOM) -> void:
	run = RunState.create(nation_id, map_style, _rng.randi())
	run.gold = Balance.v("start_gold")
	running = true
	income_rate = 0.0
	_last_frame_unix = Time.get_unix_time_from_system()
	save()
	run_started.emit()


func _process(delta: float) -> void:
	# A failed save is retried on its own clock, even between expeditions.
	if not save_ok:
		_save_retry += delta
		if _save_retry >= SAVE_RETRY_SECONDS:
			_save_retry = 0.0
			save()
	if not running or run == null:
		return
	var now: float = Time.get_unix_time_from_system()
	if _last_frame_unix > 0.0 and now - _last_frame_unix > SUSPEND_GAP_SECONDS:
		_catch_up(now - _last_frame_unix)
		_last_frame_unix = now
		return
	_last_frame_unix = now

	if catching_up:
		# Live play resumes once the time away has been worked through.
		_advance_catch_up(CATCH_UP_SLICE_USEC)
		_last_frame_unix = now
		return
	var tick: float = Balance.v("tick_seconds")
	_accum += minf(delta, SUSPEND_GAP_SECONDS)
	var ev := SimEvents.new()
	while _accum >= tick:
		_accum -= tick
		Sim.step(run, meta, tick, ev)
	_dispatch(ev)
	_track_income(ev.gold_earned, delta)
	meta.add_stat("seconds_played", minf(delta, 1.0))
	var period: int = int(Balance.market_state(run)["period"])
	if period != _market_period:
		if _market_period >= 0:
			market_changed.emit()
		_market_period = period

	_autosave_timer += delta
	if _autosave_timer >= AUTOSAVE_SECONDS:
		_autosave_timer = 0.0
		save()


func _dispatch(ev: SimEvents) -> void:
	_record(ev)
	for id: String in ev.discovered:
		resource_discovered.emit(id)
	for s: Dictionary in ev.shipments:
		shipment_arrived.emit(s["colony"], s["resource"], s["qty"])
	if ev.gold_earned > 0.0:
		gold_earned.emit(ev.gold_earned)


## Adds a batch of simulation results to the Ledger's lifetime counters.
func _record(ev: SimEvents) -> void:
	if ev.gold_earned > 0.0:
		meta.add_stat("gold_earned", ev.gold_earned)
	for s: Dictionary in ev.shipments:
		var trips: int = int(s.get("trips", 1))
		meta.add_stat("shipments", trips)
		var c: RunState.ColonyState = run.colony(str(s["colony"])) if run != null else null
		if c != null:
			var leagues: float = Balance.route_length(run, c) * 2.0 * trips
			meta.add_stat("sea_leagues" if Balance.is_sea(run, c) else "land_leagues", leagues)
	for id: String in ev.delivered.keys():
		meta.add_stat("delivered_" + id, float(ev.delivered[id]))
	for id: String in ev.crafted.keys():
		meta.add_stat("crafted", float(ev.crafted[id]))
		meta.add_stat("crafted_" + id, float(ev.crafted[id]))


func _track_income(earned: float, delta: float) -> void:
	_income_window += earned
	_income_time += delta
	if _income_time >= 1.0:
		var sample: float = _income_window / _income_time
		income_rate = sample if income_rate == 0.0 else lerpf(income_rate, sample, 0.25)
		_income_window = 0.0
		_income_time = 0.0


## Catching up on time away. Long catch-ups run in slices across frames so
## the app stays responsive (the UI shows progress); short ones, and
## headless runs, finish at once.
signal catch_up_progress(fraction: float)
var catching_up: bool = false
var _catch: Dictionary = {}
const CATCH_UP_SLICE_USEC := 8000
const CATCH_UP_SYNC_SECONDS := 900.0


func _catch_up(seconds: float) -> void:
	if run == null or seconds < 1.0 or catching_up:
		return
	var capped: float = minf(seconds, Balance.offline_cap_seconds(run, meta))
	_catch = {"seconds": seconds, "capped": capped, "remaining": capped, "ev": SimEvents.new()}
	catching_up = true
	if capped <= CATCH_UP_SYNC_SECONDS or DisplayServer.get_name() == "headless":
		_advance_catch_up(-1)


## Runs catch-up steps for up to `budget_usec` (all of it when negative).
func _advance_catch_up(budget_usec: int) -> void:
	var start: int = Time.get_ticks_usec()
	var chunk: float = Balance.v("offline_step_seconds")
	var ev: SimEvents = _catch["ev"]
	# Colonies left to themselves work at a reduced pace.
	run.sim_rate = Balance.v("offline_efficiency")
	while float(_catch["remaining"]) > 0.0:
		var s: float = minf(chunk, float(_catch["remaining"]))
		Sim.step(run, meta, s, ev)
		_catch["remaining"] = float(_catch["remaining"]) - s
		if budget_usec >= 0 and Time.get_ticks_usec() - start > budget_usec:
			break
	run.sim_rate = 1.0
	var capped: float = _catch["capped"]
	catch_up_progress.emit(1.0 - float(_catch["remaining"]) / maxf(capped, 0.001))
	if float(_catch["remaining"]) <= 0.0:
		_finish_catch_up()


func _finish_catch_up() -> void:
	catching_up = false
	var seconds: float = _catch["seconds"]
	var capped: float = _catch["capped"]
	var ev: SimEvents = _catch["ev"]
	_catch = {}
	_record(ev)
	meta.add_stat("offline_seconds", capped)
	for id: String in ev.discovered:
		resource_discovered.emit(id)
	if seconds >= 60.0:
		offline_progress.emit(seconds, ev)
	save()


func _notification(what: int) -> void:
	match what:
		NOTIFICATION_WM_CLOSE_REQUEST, NOTIFICATION_APPLICATION_PAUSED, NOTIFICATION_APPLICATION_FOCUS_OUT:
			if running:
				save()
		NOTIFICATION_APPLICATION_RESUMED:
			if running and _last_frame_unix > 0.0:
				var now: float = Time.get_unix_time_from_system()
				_catch_up(now - _last_frame_unix)
				_last_frame_unix = now


## Writes the game to disk. Returns false (and keeps retrying, and tells the
## UI) if it couldn't; the last good save on disk is never damaged.
func save() -> bool:
	if save_from_newer_version:
		return false
	meta.max_seen_unix = maxf(meta.max_seen_unix, Time.get_unix_time_from_system())
	var data: Dictionary = {
		"meta": meta.to_dict(),
		"run": run.to_dict() if run != null else {},
		"saved_unix": Time.get_unix_time_from_system(),
	}
	var ok: bool = SaveIO.write(save_path, data)
	if ok != save_ok:
		save_ok = ok
		_save_retry = 0.0
		save_status_changed.emit(ok)
	return ok


## The whole save as a text code the player can copy somewhere safe.
func export_code() -> String:
	save()
	var data: Dictionary = {"meta": meta.to_dict(), "run": run.to_dict() if run != null else {}, "saved_unix": Time.get_unix_time_from_system()}
	return "IP1:" + Marshalls.utf8_to_base64(JSON.stringify(data))


## Restores a save from export_code(). Returns false for anything invalid;
## the current save is untouched in that case.
func import_code(code: String) -> bool:
	code = code.strip_edges()
	if not code.begins_with("IP1:"):
		return false
	var text: String = Marshalls.base64_to_utf8(code.substr(4))
	var parsed: Variant = JSON.parse_string(text)
	if not SaveIO.valid(parsed) or SaveIO.is_newer(parsed):
		return false
	var data: Dictionary = parsed
	# Rebuild it completely in memory first; only a save that reconstructs
	# cleanly may replace the one on disk.
	MetaState.from_dict(data["meta"])
	var rd: Dictionary = data.get("run", {})
	if not rd.is_empty() and RunState.from_dict(rd) == null:
		return false
	# Imported progress doesn't earn offline time for the gap before import.
	data["saved_unix"] = Time.get_unix_time_from_system()
	if not SaveIO.write(save_path, data):
		return false
	running = false
	run = null
	return true


func reset_all_progress() -> void:
	SaveIO.delete(save_path)
	var keep_music: bool = meta.music_on
	var keep_sfx: bool = meta.sfx_on
	meta = MetaState.new()
	meta.music_on = keep_music
	meta.sfx_on = keep_sfx
	run = null
	running = false


# --- Buy-amount helpers -----------------------------------------------------

## Resolves the shared buy selector against a geometric cost curve.
func levels_to_buy(base: float, growth: float, level: int, cap: int = 100000) -> int:
	if buy_amount > 0:
		return mini(buy_amount, cap)
	return maxi(1, Balance.affordable_levels(base, growth, level, run.gold, cap))


func colony_track_levels(c: RunState.ColonyState, track: String) -> int:
	return levels_to_buy(Balance.upgrade_base(run, track, c), Balance.v(track + "_cost_growth"), Balance.track_level(c, track))


func workshop_levels(w: RunState.WorkshopState) -> int:
	return levels_to_buy(Balance.workshop_upgrade_base(run, w), Balance.v("workshop_cost_growth"), w.level)


func colonist_count_to_buy() -> int:
	return levels_to_buy(Balance.colonist_base(run, meta), Balance.v("colonist_cost_growth"), run.colonists_owned)


# --- Commands ---------------------------------------------------------------

func _spend(amount: float) -> bool:
	if run == null or amount > run.gold + 0.0001:
		return false
	run.gold -= amount
	return true


func upgrade_colony(colony_id: String, track: String) -> bool:
	var c: RunState.ColonyState = run.colony(colony_id)
	if c == null:
		return false
	var n: int = colony_track_levels(c, track)
	if not _spend(Balance.colony_upgrade_cost(run, track, c, n)):
		return false
	var before: int = Balance.track_level(c, track)
	match track:
		"prod": c.prod_level += n
		"cargo": c.cargo_level += n
		"speed": c.speed_level += n
	meta.add_stat("upgrades_bought", n)
	_check_milestone(colony_id, track, before, before + n)
	purchased.emit()
	return true


func _check_milestone(what: String, track: String, before: int, after: int) -> void:
	if Balance.milestone_count(after) > Balance.milestone_count(before):
		meta.add_stat("milestones")
		milestone_reached.emit(what, track, after)


## Founds the next colony on its pre-rolled site.
func found_colony() -> bool:
	if run == null or run.next_site() < 0:
		return false
	if not _spend(Balance.found_cost(run, meta)):
		return false
	var c: RunState.ColonyState = run.found_next()
	meta.add_stat("colonies_founded")
	meta.add_stat("sea_colonies" if Balance.is_sea(run, c) else "land_colonies")
	colony_founded.emit(c.id)
	_check_colony_record()
	purchased.emit()
	save()
	return true


## A new record for colonies in one run can turn up a relic or an almanac page.
func _check_colony_record() -> void:
	var n: int = run.colonies.size()
	if n > meta.best_colonies:
		meta.best_colonies = n
	claim_record_rewards()


## Pays any colony-record rewards earned but not yet given, including records
## set before relics or the Almanac had unlocked.
func claim_record_rewards() -> void:
	if Balance.unlocked(meta, "relics"):
		for t: Variant in Balance.k.get("relic_colony_records", []):
			var threshold: int = int(t)
			if meta.best_colonies >= threshold and not meta.record_relics_claimed.has(threshold):
				meta.record_relics_claimed.append(threshold)
				grant_relic("record")
	if Balance.unlocked(meta, "almanac"):
		var from: int = maxi(int(Balance.v("almanac_record_from")), meta.record_almanac_claimed + 1)
		for n in range(from, meta.best_colonies + 1):
			meta.record_almanac_claimed = n
			grant_almanac(1, "record")


func recruit_colonists() -> bool:
	var n: int = colonist_count_to_buy()
	if not _spend(Balance.colonist_cost(run, meta, n)):
		return false
	run.colonists_owned += n
	meta.add_stat("colonists_recruited", n)
	purchased.emit()
	return true


func assign_to_colony(colony_id: String, delta: int) -> bool:
	var c: RunState.ColonyState = run.colony(colony_id)
	if c == null:
		return false
	if delta > 0 and run.colonists_idle() < delta:
		return false
	if c.colonists + delta < 0:
		return false
	c.colonists += delta
	purchased.emit()
	return true


func assign_to_workshop(recipe_id: String, delta: int) -> bool:
	var w: RunState.WorkshopState = run.workshop(recipe_id)
	if w == null or not w.built:
		return false
	if delta > 0 and run.colonists_idle() < delta:
		return false
	if w.colonists + delta < 0:
		return false
	w.colonists += delta
	# A staffed workshop needs its inputs kept rather than sold; once the
	# last worker leaves, inputs no other staffed workshop uses go back to sale.
	if w.colonists > 0:
		for input_id: String in Balance.recipe_inputs(run, recipe_id).keys():
			run.hold[input_id] = true
	elif delta < 0:
		for input_id: String in Balance.recipe_inputs(run, recipe_id).keys():
			if not _staffed_user(input_id):
				run.hold[input_id] = false
	purchased.emit()
	return true


func _staffed_user(resource_id: String) -> bool:
	for w: RunState.WorkshopState in run.workshops.values():
		if w.built and w.colonists > 0 and Balance.recipe_inputs(run, w.id).has(resource_id):
			return true
	return false


func workshop_unlocked(recipe_id: String) -> bool:
	for input_id: String in Balance.recipe_inputs(run, recipe_id).keys():
		if not run.discovered.has(input_id):
			return false
	return true


func build_workshop(recipe_id: String) -> bool:
	var w: RunState.WorkshopState = run.workshop(recipe_id)
	if w == null or w.built or not workshop_unlocked(recipe_id):
		return false
	if not _spend(Balance.workshop_build_cost(recipe_id)):
		return false
	w.built = true
	workshop_built.emit(recipe_id)
	purchased.emit()
	return true


func upgrade_workshop(recipe_id: String) -> bool:
	var w: RunState.WorkshopState = run.workshop(recipe_id)
	if w == null or not w.built:
		return false
	var n: int = workshop_levels(w)
	if not _spend(Balance.workshop_upgrade_cost(run, w, n)):
		return false
	var before: int = w.level
	w.level += n
	meta.add_stat("upgrades_bought", n)
	_check_milestone(recipe_id, "workshop", before, w.level)
	purchased.emit()
	return true


func set_hold(resource_id: String, held: bool) -> void:
	run.hold[resource_id] = held
	if not held:
		sell_stock(resource_id)
	purchased.emit()


func sell_stock(resource_id: String) -> void:
	var keep: float = Balance.militia_reserve(run, resource_id)
	var qty: float = run.stock_of(resource_id) - keep
	if qty <= 0.0:
		return
	run.warehouse[resource_id] = keep
	var ev := SimEvents.new()
	Sim.sell(run, meta, resource_id, qty, ev)
	_dispatch(ev)
	purchased.emit()


func sell_all_stock() -> void:
	var ev := SimEvents.new()
	for id: String in run.warehouse.keys():
		var keep: float = Balance.militia_reserve(run, id)
		var qty: float = run.stock_of(id) - keep
		if qty > 0.0:
			run.warehouse[id] = keep
			Sim.sell(run, meta, id, qty, ev)
	_dispatch(ev)
	purchased.emit()


func father_affordable(father_id: String) -> bool:
	var cost: Dictionary = Balance.father_cost(run, father_id)
	for key: String in cost.keys():
		var have: float = run.gold if key == "gold" else run.stock_of(key)
		if have + 0.0001 < float(cost[key]):
			return false
	return true


func father_offered(father_id: String) -> bool:
	for f: Dictionary in Balance.fathers_offered(run):
		if f["id"] == father_id:
			return true
	return false


func join_father(father_id: String) -> bool:
	if run.has_father(father_id) or not father_offered(father_id) or not father_affordable(father_id):
		return false
	var cost: Dictionary = Balance.father_cost(run, father_id)
	for key: String in cost.keys():
		if key == "gold":
			run.gold -= float(cost[key])
		else:
			run.warehouse[key] = run.stock_of(key) - float(cost[key])
	run.fathers.append(father_id)
	meta.add_stat("fathers_joined")
	meta.add_stat("father_" + father_id)
	var def: Dictionary = Content.father(father_id)
	if def.get("effect", "") == "free_colonists":
		run.colonists_owned += int(def["value"])
	father_joined.emit(father_id)
	purchased.emit()
	save()
	return true


func declare_independence() -> int:
	if run == null or not Balance.independence_ready(run):
		return 0
	var liberty: int = Balance.liberty_payout(run, meta)
	var extra_relics: int = int(Balance.research_add(run, "extra_relic"))
	meta.add_stat("liberty_earned", liberty)
	meta.liberty += liberty
	meta.lifetime_liberty += liberty
	meta.runs_completed += 1
	meta.best_run_gold = maxf(meta.best_run_gold, run.lifetime_gold)
	if meta.fastest_run_seconds <= 0.0 or run.play_seconds < meta.fastest_run_seconds:
		meta.fastest_run_seconds = run.play_seconds
	run = null
	running = false
	# Every declaration brings home a keepsake and a page of the almanac.
	if Balance.unlocked(meta, "relics"):
		for i in 1 + extra_relics:
			grant_relic("independence")
	if Balance.unlocked(meta, "almanac"):
		grant_almanac(int(Balance.v("almanac_per_independence")), "independence")
	claim_record_rewards()
	save()
	independence_declared.emit(liberty)
	return liberty


func buy_liberty_upgrade(upgrade_id: String) -> bool:
	var cost: int = Balance.liberty_upgrade_cost(meta, upgrade_id)
	if cost < 0 or meta.liberty < cost:
		return false
	meta.liberty -= cost
	meta.upgrades[upgrade_id] = meta.level(upgrade_id) + 1
	purchased.emit()
	save()
	return true


func charter_affordable(colony_id: String) -> bool:
	var c: RunState.ColonyState = run.colony(colony_id)
	var cost: Dictionary = Balance.charter_cost(run, c, c.charter + 1)
	if cost.is_empty():
		return false
	for key: String in cost.keys():
		if run.stock_of(key) + 0.0001 < float(cost[key]):
			return false
	return true


func charter_colony(colony_id: String) -> bool:
	var c: RunState.ColonyState = run.colony(colony_id)
	if c == null or not charter_affordable(colony_id):
		return false
	var cost: Dictionary = Balance.charter_cost(run, c, c.charter + 1)
	for key: String in cost.keys():
		run.warehouse[key] = run.stock_of(key) - float(cost[key])
	c.charter += 1
	purchased.emit()
	save()
	return true


func commission_governor(type_id: String) -> bool:
	var cost: int = Balance.governor_commission_cost(meta)
	if meta.liberty < cost or Content.governor_type(type_id).is_empty():
		return false
	meta.liberty -= cost
	var used: Array = []
	for g: Dictionary in meta.governors:
		used.append(g["name"])
	var names: Array = Content.governor_names.filter(func(n: Variant) -> bool: return not used.has(n))
	var name: String = str(names[_rng.randi_range(0, names.size() - 1)]) if not names.is_empty() else "Governor %d" % meta.next_governor_id
	meta.governors.append({"id": meta.next_governor_id, "name": name, "type": type_id, "rank": 1})
	meta.next_governor_id += 1
	purchased.emit()
	save()
	return true


func promote_governor(governor_id: int) -> bool:
	var g: Dictionary = meta.governor(governor_id)
	if g.is_empty():
		return false
	var cost: int = Balance.governor_rank_cost(int(g["rank"]))
	if cost < 0 or meta.liberty < cost:
		return false
	meta.liberty -= cost
	g["rank"] = int(g["rank"]) + 1
	purchased.emit()
	save()
	return true


## Posts a governor to a colony, moving them from wherever they were and
## sending home whoever held the post before.
func post_governor(colony_id: String, governor_id: int) -> bool:
	var c: RunState.ColonyState = run.colony(colony_id)
	if c == null or meta.governor(governor_id).is_empty():
		return false
	var prev: String = run.colony_of_governor(governor_id)
	if prev != "":
		run.governors.erase(prev)
	run.governors[colony_id] = governor_id
	purchased.emit()
	return true


func recall_governor(colony_id: String) -> void:
	run.governors.erase(colony_id)
	purchased.emit()


## Reward for tapping the treasure that drifts past on the map.
func treasure_value() -> float:
	var base: float = maxf(Balance.v("treasure_min_gold"), income_rate * Balance.v("treasure_income_seconds"))
	return base * Balance.bonus(run, meta, "treasure") * Balance.research_mult(run, "treasure")


func collect_treasure() -> float:
	if run == null:
		return 0.0
	var amount: float = treasure_value()
	run.gold += amount
	run.lifetime_gold += amount
	meta.add_stat("treasures")
	meta.add_stat("treasure_gold", amount)
	treasure_collected.emit(amount)
	if Balance.unlocked(meta, "relics") and _rng.randf() < Balance.v("relic_treasure_chance"):
		grant_relic("treasure")
	elif Balance.unlocked(meta, "almanac") and _rng.randf() < Balance.v("almanac_treasure_chance"):
		grant_almanac(1, "treasure")
	return amount


func favor_ready_in() -> float:
	# Capped at one cooldown, so a clock that ran fast can't lock the Favor away.
	return clampf(meta.favor_ready_unix - Time.get_unix_time_from_system(), 0.0, Balance.v("favor_cooldown_seconds"))


## Royal Favor: a free, timed production boost on a real-time cooldown.
func request_favor() -> bool:
	if run == null or favor_ready_in() > 0.0:
		return false
	run.favor_seconds += Balance.v("favor_seconds") * Balance.research_mult(run, "favor_duration")
	meta.add_stat("favors")
	meta.favor_ready_unix = Time.get_unix_time_from_system() + Balance.v("favor_cooldown_seconds")
	purchased.emit()
	save()
	return true


# --- The Philosophical Society ---------------------------------------------------

func study_affordable(id: String) -> bool:
	var cost: Dictionary = Balance.study_cost(run, id)
	for key: String in cost.keys():
		var have: float = run.gold if key == "gold" else run.stock_of(key)
		if have + 0.0001 < float(cost[key]):
			return false
	return true


## Pays for and completes a study at once.
func study(id: String) -> bool:
	if run == null or Balance.study_block(run, meta, id) != "" or not study_affordable(id):
		return false
	var cost: Dictionary = Balance.study_cost(run, id)
	for key: String in cost.keys():
		if key == "gold":
			run.gold -= float(cost[key])
		else:
			run.warehouse[key] = run.stock_of(key) - float(cost[key])
	run.research[id] = run.study_level(id) + 1
	run.research_version += 1
	meta.add_stat("studies")
	studied.emit(id)
	purchased.emit()
	save()
	return true


# --- Specializations, relics and the almanac ----------------------------------

func choose_specialization(colony_id: String, spec_id: String) -> bool:
	var c: RunState.ColonyState = run.colony(colony_id) if run != null else null
	if c == null or c.spec != "" or c.charter < 1 or not Balance.unlocked(meta, "specializations"):
		return false
	var ok: bool = false
	for s: Dictionary in Balance.specs_offered(run, c):
		if s["id"] == spec_id:
			ok = true
	if not ok:
		return false
	c.spec = spec_id
	meta.add_stat("specializations")
	purchased.emit()
	save()
	return true


## Gives a random relic not yet found; once all are found, a page of the
## almanac instead. Returns the relic id or "".
func grant_relic(source: String) -> String:
	var missing: Array[String] = []
	for r: Dictionary in Content.relics:
		if not meta.has_relic(str(r["id"])):
			missing.append(str(r["id"]))
	if missing.is_empty():
		grant_almanac(1, source)
		return ""
	var id: String = missing[_rng.randi_range(0, missing.size() - 1)]
	meta.relics.append(id)
	meta.add_stat("relics_found")
	relic_found.emit(id, source)
	save()
	return id


func grant_almanac(count: int, source: String) -> void:
	if count <= 0:
		return
	meta.almanacs += count
	meta.add_stat("almanacs_found", count)
	almanac_gained.emit(count, source)


## Reads a page of the almanac: an hour of the colonies' work, at once and
## without the offline cap.
func read_almanac() -> bool:
	if run == null or meta.almanacs <= 0 or not Balance.unlocked(meta, "almanac"):
		return false
	meta.almanacs -= 1
	meta.add_stat("almanacs_read")
	_skip_ahead(Balance.v("almanac_seconds"))
	return true


## Runs `seconds` of the colonies' work at once, at full pace.
func _skip_ahead(seconds: float) -> void:
	var ev := SimEvents.new()
	var chunk: float = Balance.v("offline_step_seconds")
	var remaining: float = seconds
	while remaining > 0.0:
		var s: float = minf(chunk, remaining)
		Sim.step(run, meta, s, ev)
		remaining -= s
	_record(ev)
	for id: String in ev.discovered:
		resource_discovered.emit(id)
	almanac_read.emit(seconds, ev)
	purchased.emit()
	save()


func consult_ready_in() -> float:
	return clampf(meta.ad_skip_ready_unix - Time.get_unix_time_from_system(), 0.0, Balance.v("ad_skip_cooldown_seconds"))


## "Consult the Almanac": the optional rewarded bonus, a short skip ahead on a
## real-time cooldown. Granted once per cooldown however often it's called,
## so a duplicated ad callback can't pay twice.
func consult_almanac() -> bool:
	if run == null or consult_ready_in() > 0.0:
		return false
	meta.ad_skip_ready_unix = Time.get_unix_time_from_system() + Balance.v("ad_skip_cooldown_seconds")
	meta.add_stat("almanac_consulted")
	_skip_ahead(Balance.v("ad_skip_seconds"))
	return true


func mark_hint_seen(hint_id: String) -> void:
	if not meta.hints_seen.has(hint_id):
		meta.hints_seen.append(hint_id)
