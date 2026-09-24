## Headless pacing check: a greedy "reasonable player" bot plays a run using
## the real simulation and prints a timeline. Not part of the game.
##   godot --headless --path . res://tools/balance_bot.tscn -- seed=1 liberty=0 hours=8 map=random
extends Node

const DECISION_SECONDS := 2.0

var run: RunState
var meta: MetaState
var log_marks: Dictionary = {}
var max_hours: float = 8.0
var stop_at_independence: bool = true


func _ready() -> void:
	var seed_value: int = 1
	var liberty_levels: int = 0
	var style: String = WorldMap.STYLE_RANDOM
	var governors: int = 0
	var runs: int = -1
	for arg: String in OS.get_cmdline_user_args():
		var kv: PackedStringArray = arg.split("=")
		if kv.size() != 2:
			continue
		match kv[0]:
			"seed": seed_value = int(kv[1])
			"liberty": liberty_levels = int(kv[1])
			"hours": max_hours = float(kv[1])
			"map": style = kv[1]
			"governors": governors = int(kv[1])
			"continue": stop_at_independence = kv[1] != "1"
			"runs": runs = int(kv[1])
	meta = MetaState.new()
	# Reform levels imply earlier independences; research opens after three.
	meta.runs_completed = runs if runs >= 0 else (3 if liberty_levels > 0 else 0)
	for d: Dictionary in Content.liberty_upgrades:
		meta.upgrades[d["id"]] = liberty_levels
	for g in governors:
		meta.governors.append({"id": g + 1, "name": "G%d" % g, "type": ["prod", "cargo", "speed"][g % 3], "rank": 3})
	run = RunState.create("english", style, seed_value)
	run.gold = Balance.v("start_gold")
	var t: float = 0.0
	var ev := SimEvents.new()
	var announced: bool = false
	while t < max_hours * 3600.0:
		Sim.step(run, meta, DECISION_SECONDS, ev)
		t += DECISION_SECONDS
		_post_governors()
		_musket_push()
		for i in 25:
			if not _decide():
				break
		_research()
		_milestones(t)
		if Balance.independence_ready(run) and not announced:
			announced = true
			print("INDEPENDENCE READY at %s  liberty=%d" % [_fmt_t(t), Balance.liberty_payout(run)])
			if stop_at_independence:
				break
	_summary(t)
	get_tree().quit()


func _fmt_t(t: float) -> String:
	if t >= 86400.0:
		return "%dd%02dh" % [int(t / 86400.0), int(fmod(t, 86400.0) / 3600.0)]
	return "%dh%02dm" % [int(t / 3600.0), int(fmod(t, 3600.0) / 60.0)]


func _milestones(t: float) -> void:
	var key: String = "col%d" % run.colonies.size()
	if not log_marks.has(key):
		log_marks[key] = t
		var c: RunState.ColonyState = run.colonies[run.colonies.size() - 1]
		print("%s  colony %2d %-10s %-4s gold/s~%s colonists=%d" % [_fmt_t(t), c.tier, run.resource_of(c), run.site_of(c)["route"], Format.num(_income()), run.colonists_owned])
	for id: String in run.workshops.keys():
		var w: RunState.WorkshopState = run.workshop(id)
		if w.built and not log_marks.has("ws_" + id):
			log_marks["ws_" + id] = t
			print("%s      built %s" % [_fmt_t(t), id])
	for id: String in run.fathers:
		if not log_marks.has("f_" + id):
			log_marks["f_" + id] = t
			print("%s      father %s" % [_fmt_t(t), id])


func _summary(t: float) -> void:
	print("--- after %s: lifetime %s, colonies %d, colonists %d, muskets %d, liberty %d, studies %d" % [_fmt_t(t), Format.num(run.lifetime_gold), run.colonies.size(), run.colonists_owned, int(run.crafted.get("muskets", 0)), Balance.liberty_payout(run, meta), run.research.size()])


# --- Valuation ----------------------------------------------------------------

func _colony_income(c: RunState.ColonyState) -> float:
	return minf(Balance.production_rate(run, meta, c), Balance.route_throughput(run, meta, c)) * Balance.sell_price(run, meta, run.resource_of(c))


func _income() -> float:
	var s: float = 0.0
	for c: RunState.ColonyState in run.colonies:
		s += _colony_income(c)
	for w: RunState.WorkshopState in run.workshops.values():
		s += _craft_margin(w)
	return s


func _supply(res: String) -> float:
	var s: float = 0.0
	for c: RunState.ColonyState in run.colonies:
		if run.resource_of(c) == res:
			s += minf(Balance.production_rate(run, meta, c), Balance.route_throughput(run, meta, c))
	var w: RunState.WorkshopState = run.workshop(res)
	if w != null and w.built and w.colonists > 0:
		s += _craft_rate(w)
	return s


func _craft_rate(w: RunState.WorkshopState) -> float:
	var def: Dictionary = Content.recipe(w.id)
	var r: float = 1.0 / Balance.craft_seconds(run, meta, w)
	for input_id: String in (def["inputs"] as Dictionary).keys():
		r = minf(r, _supply(input_id) / float(def["inputs"][input_id]))
	return r


func _craft_margin(w: RunState.WorkshopState) -> float:
	if not w.built or w.colonists <= 0:
		return 0.0
	var def: Dictionary = Content.recipe(w.id)
	var in_val: float = 0.0
	for input_id: String in (def["inputs"] as Dictionary).keys():
		in_val += float(def["inputs"][input_id]) * Balance.sell_price(run, meta, input_id)
	return _craft_rate(w) * (Balance.sell_price(run, meta, w.id) - in_val)


# --- Decisions ----------------------------------------------------------------

func _decide() -> bool:
	var best: Dictionary = {"score": 0.0, "cost": INF, "action": Callable()}
	var base_income: float = maxf(_income(), 0.01)

	var consider := func(gain: float, cost: float, action: Callable) -> void:
		if cost <= 0.0 or gain <= 0.0:
			return
		var wait: float = maxf(0.0, (cost - run.gold) / base_income)
		var score: float = gain / (cost / base_income + wait + 1.0) / cost * base_income
		if score > float(best["score"]):
			best["score"] = score
			best["cost"] = cost
			best["action"] = action

	if run.next_site() >= 0:
		var fc: float = Balance.found_cost(run, meta)
		var gain: float = Balance.tier_value(run.colonies.size()) * 1.2
		consider.call(gain * 3.0, fc, func() -> void:
			run.gold -= fc
			run.found_next())

	for c: RunState.ColonyState in run.colonies:
		var before: float = _colony_income(c)
		var tracks: Array = ["prod"] if c.tier == 0 else ["prod", "cargo", "speed"]
		for track: String in tracks:
			var cost: float = Balance.colony_upgrade_cost(run, track, c)
			_bump(c, track, 1)
			var gain: float = _colony_income(c) - before
			_bump(c, track, -1)
			var cc: RunState.ColonyState = c
			var tr: String = track
			consider.call(gain, cost, func() -> void:
				run.gold -= cost
				_bump(cc, tr, 1))
		if c.tier > 0:
			var bundle: float = 0.0
			for tr2: String in ["prod", "cargo", "speed"]:
				bundle += Balance.colony_upgrade_cost(run, tr2, c)
			for tr2: String in ["prod", "cargo", "speed"]:
				_bump(c, tr2, 1)
			var gb: float = _colony_income(c) - before
			for tr2: String in ["prod", "cargo", "speed"]:
				_bump(c, tr2, -1)
			var cb: RunState.ColonyState = c
			consider.call(gb, bundle, func() -> void:
				run.gold -= bundle
				for tr3: String in ["prod", "cargo", "speed"]:
					_bump(cb, tr3, 1))
		if run.colonists_idle() > 0:
			c.colonists += 1
			var g2: float = _colony_income(c) - before
			c.colonists -= 1
			var cc2: RunState.ColonyState = c
			consider.call(g2, 0.001, func() -> void: cc2.colonists += 1)

	var ccost: float = Balance.colonist_cost(run, meta)
	var best_col_gain: float = 0.0
	for c: RunState.ColonyState in run.colonies:
		var before2: float = _colony_income(c)
		c.colonists += 1
		best_col_gain = maxf(best_col_gain, _colony_income(c) - before2)
		c.colonists -= 1
	for w: RunState.WorkshopState in run.workshops.values():
		if w.built:
			var b3: float = _craft_margin(w)
			w.colonists += 1
			best_col_gain = maxf(best_col_gain, _craft_margin(w) - b3)
			w.colonists -= 1
	consider.call(best_col_gain, ccost, func() -> void:
		run.gold -= ccost
		run.colonists_owned += 1)

	for def: Dictionary in Content.recipes:
		var w: RunState.WorkshopState = run.workshop(def["id"])
		var ok: bool = true
		for input_id: String in (def["inputs"] as Dictionary).keys():
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
				ww.built = true)
		else:
			var b: float = _craft_margin(w)
			var uc: float = Balance.workshop_upgrade_cost(run, w)
			w.level += 1
			var g4: float = _craft_margin(w) - b
			w.level -= 1
			var w2: RunState.WorkshopState = w
			consider.call(g4, uc, func() -> void:
				run.gold -= uc
				w2.level += 1)
			if run.colonists_idle() > 0:
				w.colonists += 1
				var g5: float = _craft_margin(w) - b
				w.colonists -= 1
				if w.colonists == 0:
					g5 = maxf(g5, 1.0)
				consider.call(g5, 0.001, func() -> void:
					w2.colonists += 1
					for input_id: String in (def["inputs"] as Dictionary).keys():
						run.hold[input_id] = true)

	for f: Dictionary in Balance.fathers_offered(run):
		if run.has_father(f["id"]):
			continue
		var afford: bool = true
		for key: String in (f["cost"] as Dictionary).keys():
			var have: float = run.gold if key == "gold" else run.stock_of(key)
			if have < float(f["cost"][key]):
				afford = false
		for key: String in (f["cost"] as Dictionary).keys():
			if key == "gold" or _needed_by_workshop(key):
				continue
			var gold_ok: bool = run.gold >= float(f["cost"].get("gold", 0.0)) * 0.5
			run.hold[key] = gold_ok and run.stock_of(key) < float(f["cost"][key]) and _supply(key) > 0.0
		if afford:
			for key: String in (f["cost"] as Dictionary).keys():
				if key == "gold":
					run.gold -= float(f["cost"][key])
				else:
					run.warehouse[key] = run.stock_of(key) - float(f["cost"][key])
			run.fathers.append(f["id"])
			if f["effect"] == "free_colonists":
				run.colonists_owned += int(f["value"])
			return true

	var act: Callable = best["action"]
	if act.is_valid() and float(best["cost"]) <= run.gold:
		act.call()
		return true
	return false


## Studies the cheapest open study it can pay for, and keeps the goods the
## next one needs once half its gold is in hand.
func _research() -> void:
	if not Balance.unlocked(meta, "research"):
		return
	var best: String = ""
	var best_gold: float = INF
	for def: Dictionary in Content.research:
		var id: String = str(def["id"])
		if Balance.study_block(run, meta, id) != "":
			continue
		var cost: Dictionary = Balance.study_cost(run, id)
		var reachable: bool = true
		for k: String in cost.keys():
			if k != "gold" and _supply(k) <= 0.0 and run.stock_of(k) < float(cost[k]):
				reachable = false
		if reachable and float(cost["gold"]) < best_gold:
			best_gold = float(cost["gold"])
			best = id
	if best == "":
		return
	var cost: Dictionary = Balance.study_cost(run, best)
	var afford: bool = true
	for k: String in cost.keys():
		var have: float = run.gold if k == "gold" else run.stock_of(k)
		if have < float(cost[k]):
			afford = false
			# Only finished goods are held back for studies; a raw good is
			# usually the colony's income and holding it would starve the run.
			if k != "gold" and Content.is_crafted(k) and run.gold >= float(cost["gold"]) * 0.5:
				run.hold[k] = true
	if afford:
		for k: String in cost.keys():
			if k == "gold":
				run.gold -= float(cost[k])
			else:
				run.warehouse[k] = run.stock_of(k) - float(cost[k])
		run.research[best] = run.study_level(best) + 1
		run.research_version += 1
		for k: String in cost.keys():
			if k != "gold" and not _needed_by_workshop(k):
				run.hold[k] = false
		log_marks["studies"] = int(log_marks.get("studies", 0)) + 1


func _bump(c: RunState.ColonyState, track: String, d: int) -> void:
	match track:
		"prod": c.prod_level += d
		"cargo": c.cargo_level += d
		"speed": c.speed_level += d


func _post_governors() -> void:
	for g: Dictionary in meta.governors:
		if run.colony_of_governor(int(g["id"])) != "":
			continue
		for i in range(run.colonies.size() - 1, -1, -1):
			var c: RunState.ColonyState = run.colonies[i]
			if run.governor_at(c.id) < 0:
				run.governors[c.id] = int(g["id"])
				break


## A real player is told to arm the militia; the bot does it once the gold
## gate is half-way reached.
func _musket_push() -> void:
	if run.lifetime_gold < Balance.v("independence_gold") * 0.3:
		return
	for id: String in ["lumber", "charcoal", "pig_iron", "tools", "muskets"]:
		var w: RunState.WorkshopState = run.workshop(id)
		for input_id: String in (Content.recipe(id)["inputs"] as Dictionary).keys():
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
		for input_id: String in (Content.recipe(id)["inputs"] as Dictionary).keys():
			run.hold[input_id] = true
		if id != "muskets":
			run.hold[id] = true


func _needed_by_workshop(res: String) -> bool:
	for w: RunState.WorkshopState in run.workshops.values():
		if w.built and w.colonists > 0 and (Content.recipe(w.id)["inputs"] as Dictionary).has(res):
			return true
	return false
