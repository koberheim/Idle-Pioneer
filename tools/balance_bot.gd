## Headless pacing check: a greedy "reasonable player" bot plays a run using
## the real simulation and prints a timeline. Not part of the game.
##   godot --headless --path . res://tools/balance_bot.tscn -- nation=english liberty=0
extends Node

const DECISION_SECONDS := 2.0
const MAX_HOURS := 8.0

var run: RunState
var meta: MetaState
var log_marks: Dictionary = {}


func _ready() -> void:
	var nation: String = "english"
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("nation="):
			nation = arg.substr(7)
	var liberty_levels: int = 0
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("liberty="):
			liberty_levels = int(arg.substr(8))
	meta = MetaState.new()
	for id: String in ["industry", "navigation", "settlement", "commerce"]:
		meta.upgrades[id] = liberty_levels
	var rng := RandomNumberGenerator.new()
	rng.seed = 7
	run = RunState.create(nation, rng)
	var t: float = 0.0
	var ev := SimEvents.new()
	while t < MAX_HOURS * 3600.0:
		Sim.step(run, meta, DECISION_SECONDS, ev)
		t += DECISION_SECONDS
		_musket_push()
		for i in 20:
			if not _decide():
				break
		_milestones(t)
		if Balance.independence_ready(run):
			print("INDEPENDENCE READY at %s  liberty=%d" % [_fmt_t(t), Balance.liberty_payout(run)])
			break
	_summary(t)
	get_tree().quit()


func _fmt_t(t: float) -> String:
	return "%dh%02dm" % [int(t / 3600.0), int(fmod(t, 3600.0) / 60.0)]


func _milestones(t: float) -> void:
	for c: RunState.ColonyState in run.colonies:
		var key: String = "found_" + c.id
		if c.founded and not log_marks.has(key):
			log_marks[key] = t
			print("%s  founded %-14s gold/s~%s colonists=%d" % [_fmt_t(t), c.id, Format.num(_income()), run.colonists_owned])
	for id: String in run.workshops.keys():
		var w: RunState.WorkshopState = run.workshop(id)
		var key: String = "ws_" + id
		if w.built and not log_marks.has(key):
			log_marks[key] = t
			print("%s  built workshop %s" % [_fmt_t(t), id])
	for id: String in run.fathers:
		if not log_marks.has("f_" + id):
			log_marks["f_" + id] = t
			print("%s  father %s" % [_fmt_t(t), id])
	for mark: float in [1e3, 1e4, 1e5, 1e6, 1e7, 1e8, 1e9]:
		var key: String = "g%d" % int(log(mark) / log(10))
		if run.lifetime_gold >= mark and not log_marks.has(key):
			log_marks[key] = t
			print("%s  lifetime gold %s" % [_fmt_t(t), Format.num(mark)])


func _summary(t: float) -> void:
	print("--- after %s: lifetime %s, colonists %d, muskets %d" % [_fmt_t(t), Format.num(run.lifetime_gold), run.colonists_owned, int(run.crafted.get("muskets", 0))])
	for c: RunState.ColonyState in run.colonies:
		if c.founded:
			print("  %-14s sea=%s col=%d prod=%d cargo=%d speed=%d rate=%.1f tp=%.1f stock=%.0f" % [c.id, Balance.is_sea(c), c.colonists, c.prod_level, c.cargo_level, c.speed_level, Balance.production_rate(run, meta, c), Balance.route_throughput(run, meta, c), c.stock])
	for id: String in run.workshops.keys():
		var w: RunState.WorkshopState = run.workshop(id)
		if w.built:
			print("  ws %-10s col=%d lvl=%d crafted=%d" % [id, w.colonists, w.level, int(run.crafted.get(id, 0))])


# --- Valuation ----------------------------------------------------------------

func _eff(c: RunState.ColonyState, rate: float, tp: float) -> float:
	return minf(rate, tp)


func _colony_income(c: RunState.ColonyState) -> float:
	var res: String = Content.colony(c.id)["resource"]
	return _eff(c, Balance.production_rate(run, meta, c), Balance.route_throughput(run, meta, c)) * Balance.sell_price(run, meta, res)


func _income() -> float:
	var s: float = 0.0
	for c: RunState.ColonyState in run.colonies:
		if c.founded:
			s += _colony_income(c)
	s += _craft_margin_total()
	return s


## Supply rate of a resource into the warehouse.
func _supply(res: String) -> float:
	for c: RunState.ColonyState in run.colonies:
		if c.founded and Content.colony(c.id)["resource"] == res:
			return _eff(c, Balance.production_rate(run, meta, c), Balance.route_throughput(run, meta, c))
	var w: RunState.WorkshopState = run.workshop(res)
	if w != null and w.built and w.colonists > 0:
		return _craft_rate(w)
	return 0.0


func _craft_rate(w: RunState.WorkshopState) -> float:
	var def: Dictionary = Content.recipe(w.id)
	var r: float = 1.0 / Balance.craft_seconds(run, w)
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


func _craft_margin_total() -> float:
	var s: float = 0.0
	for w: RunState.WorkshopState in run.workshops.values():
		s += _craft_margin(w)
	return s


# --- Decisions ----------------------------------------------------------------

## Buys the single best-value option if affordable; returns true if it bought.
func _decide() -> bool:
	var best: Dictionary = {"score": 0.0, "cost": INF, "action": Callable()}
	var base_income: float = maxf(_income(), 0.01)

	var consider := func(gain: float, cost: float, action: Callable) -> void:
		if cost <= 0.0 or gain <= 0.0:
			return
		# Payback time in seconds, plus the wait to afford it.
		var wait: float = maxf(0.0, (cost - run.gold) / base_income)
		var score: float = gain / (cost / base_income + wait + 1.0) / cost * base_income
		if score > float(best["score"]):
			best["score"] = score
			best["cost"] = cost
			best["action"] = action

	var next: RunState.ColonyState = run.next_unfounded()
	if next != null:
		var fc: float = Balance.found_cost(run, meta, next.id)
		var gain: float = minf(Balance.v("base_rate"), Balance.route_throughput(run, meta, next)) * Balance.sell_price(run, meta, Content.colony(next.id)["resource"])
		consider.call(gain * 3.0, fc, func() -> void:
			run.gold -= fc
			next.founded = true)

	for c: RunState.ColonyState in run.colonies:
		if not c.founded:
			continue
		var before: float = _colony_income(c)
		for track: String in ["prod", "cargo", "speed"]:
			if c.id == "capital" and track != "prod":
				continue
			var cost: float = Balance.colony_upgrade_cost(track, c)
			_bump(c, track, 1)
			var gain: float = _colony_income(c) - before
			_bump(c, track, -1)
			var cc: RunState.ColonyState = c
			var tr: String = track
			consider.call(gain, cost, func() -> void:
				run.gold -= cost
				_bump(cc, tr, 1))
		if c.id != "capital":
			var bundle: float = Balance.colony_upgrade_cost("prod", c) + Balance.colony_upgrade_cost("cargo", c) + Balance.colony_upgrade_cost("speed", c)
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

	# Recruit: value as the best colonist placement.
	var ccost: float = Balance.colonist_cost(run, meta)
	var best_col_gain: float = 0.0
	for c: RunState.ColonyState in run.colonies:
		if c.founded:
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
		var unlocked: bool = true
		for input_id: String in (def["inputs"] as Dictionary).keys():
			if _supply(input_id) <= 0.0:
				unlocked = false
		if not unlocked:
			continue
		if not w.built:
			var bc: float = Balance.workshop_build_cost(w.id)
			w.built = true
			w.colonists = 1
			var g: float = _craft_margin(w)
			w.built = false
			w.colonists = 0
			var ww: RunState.WorkshopState = w
			var boost: float = 4.0 if w.id == "muskets" or w.id == "tools" else 1.0
			consider.call(maxf(g, 1.0) * boost, bc, func() -> void:
				run.gold -= bc
				ww.built = true)
		else:
			var b: float = _craft_margin(w)
			var uc: float = Balance.workshop_upgrade_cost(w)
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

	var target: Dictionary = {}
	for f: Dictionary in Content.fathers:
		if not run.has_father(f["id"]):
			target = f
			break
	if not target.is_empty():
		for key: String in (target["cost"] as Dictionary).keys():
			if key != "gold" and _supply(key) > 0.0 and run.stock_of(key) < float(target["cost"][key]):
				run.hold[key] = true
			elif key != "gold" and run.stock_of(key) >= float(target["cost"][key]) and not _needed_by_workshop(key):
				run.hold[key] = false
	for f: Dictionary in Content.fathers:
		if not run.has_father(f["id"]):
			var ok: bool = true
			for key: String in (f["cost"] as Dictionary).keys():
				var have: float = run.gold if key == "gold" else run.stock_of(key)
				if have < float(f["cost"][key]):
					ok = false
			if ok:
				for key: String in (f["cost"] as Dictionary).keys():
					if key == "gold":
						run.gold -= float(f["cost"][key])
					else:
						run.warehouse[key] = run.stock_of(key) - float(f["cost"][key])
				run.fathers.append(f["id"])
				return true

	var act: Callable = best["action"]
	if act.is_valid() and float(best["cost"]) <= run.gold:
		act.call()
		return true
	return false


func _bump(c: RunState.ColonyState, track: String, d: int) -> void:
	match track:
		"prod": c.prod_level += d
		"cargo": c.cargo_level += d
		"speed": c.speed_level += d


func _needed_by_workshop(res: String) -> bool:
	for w: RunState.WorkshopState in run.workshops.values():
		if w.built and w.colonists > 0 and (Content.recipe(w.id)["inputs"] as Dictionary).has(res):
			return true
	return false


## A real player is told to arm the militia; the bot just does it once the
## gold gate is half-way reached.
func _musket_push() -> void:
	if run.lifetime_gold < Balance.v("independence_gold") * 0.5:
		return
	for id: String in ["planks", "pig_iron", "tools", "muskets"]:
		var w: RunState.WorkshopState = run.workshop(id)
		var ok: bool = true
		for input_id: String in (Content.recipe(id)["inputs"] as Dictionary).keys():
			if not run.discovered.has(input_id) and _supply(input_id) <= 0.0:
				ok = false
		if not ok:
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
			run.hold[id] = true
		if id != "muskets":
			run.hold[id] = true
