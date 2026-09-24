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


func _ready() -> void:
	_rng.randomize()
	process_mode = Node.PROCESS_MODE_ALWAYS


## Called once by the main scene. Returns true when a run is in progress
## (loaded from disk); false means the player must choose a nation first.
func boot() -> bool:
	var data: Dictionary = SaveIO.read(save_path)
	if data.is_empty():
		return false
	meta = MetaState.from_dict(data.get("meta", {}))
	var run_data: Variant = data.get("run")
	if run_data is Dictionary and not (run_data as Dictionary).is_empty():
		run = RunState.from_dict(run_data)
		if run == null:
			return false
		running = true
		_last_frame_unix = Time.get_unix_time_from_system()
		var away: float = _last_frame_unix - float(data.get("saved_unix", _last_frame_unix))
		_catch_up(away)
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
	if not running or run == null:
		return
	var now: float = Time.get_unix_time_from_system()
	if _last_frame_unix > 0.0 and now - _last_frame_unix > SUSPEND_GAP_SECONDS:
		_catch_up(now - _last_frame_unix)
		_last_frame_unix = now
		return
	_last_frame_unix = now

	var tick: float = Balance.v("tick_seconds")
	_accum += minf(delta, 1.0)
	var ev := SimEvents.new()
	while _accum >= tick:
		_accum -= tick
		Sim.step(run, meta, tick, ev)
	_dispatch(ev)
	_track_income(ev.gold_earned, delta)
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
	for id: String in ev.discovered:
		resource_discovered.emit(id)
	for s: Dictionary in ev.shipments:
		shipment_arrived.emit(s["colony"], s["resource"], s["qty"])
	if ev.gold_earned > 0.0:
		gold_earned.emit(ev.gold_earned)


func _track_income(earned: float, delta: float) -> void:
	_income_window += earned
	_income_time += delta
	if _income_time >= 1.0:
		var sample: float = _income_window / _income_time
		income_rate = sample if income_rate == 0.0 else lerpf(income_rate, sample, 0.25)
		_income_window = 0.0
		_income_time = 0.0


func _catch_up(seconds: float) -> void:
	if run == null or seconds < 1.0:
		return
	var capped: float = minf(seconds, Balance.offline_cap_seconds(run))
	var ev := SimEvents.new()
	var chunk: float = Balance.v("offline_step_seconds")
	var remaining: float = capped
	while remaining > 0.0:
		var s: float = minf(chunk, remaining)
		Sim.step(run, meta, s, ev)
		remaining -= s
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


func save() -> void:
	var data: Dictionary = {
		"meta": meta.to_dict(),
		"run": run.to_dict() if run != null else {},
		"saved_unix": Time.get_unix_time_from_system(),
	}
	SaveIO.write(save_path, data)


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
	match track:
		"prod": c.prod_level += n
		"cargo": c.cargo_level += n
		"speed": c.speed_level += n
	purchased.emit()
	return true


## Founds the next colony on its pre-rolled site.
func found_colony() -> bool:
	if run == null or run.next_site() < 0:
		return false
	if not _spend(Balance.found_cost(run, meta)):
		return false
	var c: RunState.ColonyState = run.found_next()
	colony_founded.emit(c.id)
	purchased.emit()
	save()
	return true


func recruit_colonists() -> bool:
	var n: int = colonist_count_to_buy()
	if not _spend(Balance.colonist_cost(run, meta, n)):
		return false
	run.colonists_owned += n
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
	# A staffed workshop needs its inputs kept rather than sold.
	if w.colonists > 0:
		for input_id: String in (Content.recipe(recipe_id)["inputs"] as Dictionary).keys():
			run.hold[input_id] = true
	purchased.emit()
	return true


func workshop_unlocked(recipe_id: String) -> bool:
	for input_id: String in (Content.recipe(recipe_id)["inputs"] as Dictionary).keys():
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
	w.level += n
	purchased.emit()
	return true


func set_hold(resource_id: String, held: bool) -> void:
	run.hold[resource_id] = held
	if not held:
		sell_stock(resource_id)
	purchased.emit()


func sell_stock(resource_id: String) -> void:
	var qty: float = run.stock_of(resource_id)
	if qty <= 0.0:
		return
	run.warehouse[resource_id] = 0.0
	var ev := SimEvents.new()
	Sim.sell(run, meta, resource_id, qty, ev)
	_dispatch(ev)
	purchased.emit()


func sell_all_stock() -> void:
	var ev := SimEvents.new()
	for id: String in run.warehouse.keys():
		var qty: float = run.stock_of(id)
		if qty > 0.0:
			run.warehouse[id] = 0.0
			Sim.sell(run, meta, id, qty, ev)
	_dispatch(ev)
	purchased.emit()


func father_affordable(father_id: String) -> bool:
	var cost: Dictionary = Content.father(father_id)["cost"]
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
	var cost: Dictionary = Content.father(father_id)["cost"]
	for key: String in cost.keys():
		if key == "gold":
			run.gold -= float(cost[key])
		else:
			run.warehouse[key] = run.stock_of(key) - float(cost[key])
	run.fathers.append(father_id)
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
	var liberty: int = Balance.liberty_payout(run)
	meta.liberty += liberty
	meta.lifetime_liberty += liberty
	meta.runs_completed += 1
	meta.best_run_gold = maxf(meta.best_run_gold, run.lifetime_gold)
	if meta.fastest_run_seconds <= 0.0 or run.play_seconds < meta.fastest_run_seconds:
		meta.fastest_run_seconds = run.play_seconds
	run = null
	running = false
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
	return base * Balance.father_bonus(run, "treasure")


func collect_treasure() -> float:
	if run == null:
		return 0.0
	var amount: float = treasure_value()
	run.gold += amount
	run.lifetime_gold += amount
	treasure_collected.emit(amount)
	return amount


func favor_ready_in() -> float:
	return maxf(0.0, meta.favor_ready_unix - Time.get_unix_time_from_system())


## Royal Favor: a free, timed production boost on a real-time cooldown.
func request_favor() -> bool:
	if run == null or favor_ready_in() > 0.0:
		return false
	run.favor_seconds += Balance.v("favor_seconds")
	meta.favor_ready_unix = Time.get_unix_time_from_system() + Balance.v("favor_cooldown_seconds")
	purchased.emit()
	save()
	return true


func mark_hint_seen(hint_id: String) -> void:
	if not meta.hints_seen.has(hint_id):
		meta.hints_seen.append(hint_id)
