## Every tunable number and formula in one place. Constants come from
## data/balance.json; multipliers are gathered from the nation, Founding
## Fathers, relics, Liberty reforms, governors, charters, specializations and
## milestones so no other code needs to know where a bonus comes from.
extends Node

const BALANCE_PATH := "res://data/balance.json"

var k: Dictionary = {}
var _market_cache_key: Array = []
var _market_cache: Dictionary = {}


func _init() -> void:
	var f := FileAccess.open(BALANCE_PATH, FileAccess.READ)
	var parsed: Variant = JSON.parse_string(f.get_as_text()) if f != null else null
	if parsed is Dictionary:
		k = parsed
	else:
		push_error("Balance: cannot read %s" % BALANCE_PATH)


func v(key: String) -> float:
	return float(k.get(key, 0.0))


# --- Bonus sources ----------------------------------------------------------

func nation_bonus(run: RunState, bonus: String) -> float:
	var n: Dictionary = Content.nation(run.nation_id)
	if n.get("bonus", "") == bonus:
		return float(n["value"])
	return 1.0


func father_bonus(run: RunState, effect: String) -> float:
	var m: float = 1.0
	for id: String in run.fathers:
		var f: Dictionary = Content.father(id)
		if f.get("effect", "") == effect:
			m *= float(f["value"])
	return m


## Relics are permanent: each owned relic with this effect multiplies it, and
## a completed set adds its own bonus. offline_hours adds instead.
func relic_bonus(meta: MetaState, effect: String) -> float:
	if meta == null:
		return 1.0
	var additive: bool = effect == "offline_hours"
	var m: float = 0.0 if additive else 1.0
	for id: String in meta.relics:
		var r: Dictionary = Content.relic(id)
		if r.get("effect", "") == effect:
			if additive:
				m += float(r["value"])
			else:
				m *= float(r["value"])
	if not additive:
		for s: Dictionary in Content.relic_sets:
			if s.get("effect", "") == effect and meta.set_complete(str(s["id"])):
				m *= float(s["value"])
	return m


## Founding Fathers (this run) and relics (forever) share effect names.
func bonus(run: RunState, meta: MetaState, effect: String) -> float:
	return father_bonus(run, effect) * relic_bonus(meta, effect)


func _meta_or_game(meta: MetaState) -> MetaState:
	return meta if meta != null else Game.meta


func liberty_mult(meta: MetaState, upgrade_id: String) -> float:
	var def: Dictionary = Content.liberty_upgrade(upgrade_id)
	var lvl: int = meta.level(upgrade_id)
	if upgrade_id == "settlement":
		return maxf(pow(1.0 - float(def["per_level"]), lvl), v("settlement_floor"))
	# Reforms compound: each level multiplies the last.
	return pow(1.0 + float(def.get("per_level", 0.0)), lvl)


# --- Colonies ---------------------------------------------------------------

## Gold per second a colony of this settlement tier yields at base. Later
## colonies are worth exponentially more, whatever good they produce.
func tier_value(tier: int) -> float:
	return pow(v("colony_value_growth"), tier)


func is_sea(run: RunState, c: RunState.ColonyState) -> bool:
	return run.site_of(c)["route"] == "sea"


func richness(run: RunState, c: RunState.ColonyState) -> float:
	return float(run.site_of(c).get("richness", 1.0))


## Units per second at base: the tier's value expressed in this colony's good.
func base_units(run: RunState, c: RunState.ColonyState) -> float:
	return tier_value(c.tier) * richness(run, c) / Content.price(run.resource_of(c))


func production_rate(run: RunState, meta: MetaState, c: RunState.ColonyState) -> float:
	var rate: float = base_units(run, c)
	rate *= 1.0 + v("prod_per_level") * c.prod_level
	rate *= milestone_mult(c.prod_level, v("milestone_prod_mult"))
	var res: String = run.resource_of(c)
	var rk: String = route_key(run, c) if c.tier > 0 else "land"
	rate *= 1.0 + v("colonist_production_bonus") * c.colonists * spec_mult(c, "colonist") * research_mult(run, "colonist_bonus", [res])
	rate *= research_mult(run, "production", [res, rk])
	rate *= liberty_mult(meta, "industry")
	rate *= nation_bonus(run, "production")
	rate *= bonus(run, meta, "production")
	rate *= spec_mult(c, "prod")
	rate *= run.sim_rate
	rate *= charter_mult(c)
	rate *= governor_mult(run, meta, c, "prod")
	if run.favor_seconds > 0.0:
		rate *= v("favor_multiplier")
	return rate


func route_length(run: RunState, c: RunState.ColonyState) -> float:
	if c.tier == 0:
		return 0.0
	return float(run.world.route(c.site)["length"])


func cargo_capacity(run: RunState, meta: MetaState, c: RunState.ColonyState) -> float:
	# Cargo grows almost as fast as travel time, so a far colony is lumpier but
	# only slightly slower on average than a near one.
	var length: float = maxf(route_length(run, c), 1.0)
	var factor: float = v("sea_cargo_factor") if is_sea(run, c) else v("land_cargo_factor")
	var cap: float = factor * pow(length, v("cargo_distance_exponent")) * base_units(run, c)
	cap *= 1.0 + v("cargo_per_level") * c.cargo_level
	cap *= milestone_mult(c.cargo_level, v("milestone_cargo_mult"))
	cap *= research_mult(run, "cargo", [route_key(run, c)])
	cap *= liberty_mult(meta, "navigation")
	cap *= bonus(run, meta, "cargo")
	cap *= spec_mult(c, "cargo")
	cap *= charter_mult(c)
	cap *= governor_mult(run, meta, c, "cargo")
	return cap


func round_trip_seconds(run: RunState, meta: MetaState, c: RunState.ColonyState) -> float:
	var length: float = route_length(run, c)
	if length <= 0.0:
		return 0.0
	var sea: bool = is_sea(run, c)
	length *= research_mult(run, "route_length", ["sea" if sea else "land"])
	var t: float = 2.0 * length * (v("sea_seconds_per_step") if sea else v("land_seconds_per_step"))
	var speed: float = 1.0 + v("speed_per_level") * c.speed_level
	speed *= milestone_mult(c.speed_level, v("milestone_speed_mult"))
	speed *= research_mult(run, "speed", ["sea" if sea else "land"])
	# Away from the game the wagons and ships keep half pace too.
	speed *= run.sim_rate
	speed *= liberty_mult(meta, "navigation")
	speed *= governor_mult(run, meta, c, "speed")
	speed *= spec_mult(c, "speed")
	if sea:
		speed *= nation_bonus(run, "sea_speed") * bonus(run, meta, "sea_speed")
	else:
		speed *= nation_bonus(run, "land_speed") * bonus(run, meta, "land_speed")
	return t / speed


## Units per second a route can actually move; production beyond this piles up
## at the colony.
func route_throughput(run: RunState, meta: MetaState, c: RunState.ColonyState) -> float:
	var rt: float = round_trip_seconds(run, meta, c)
	if rt <= 0.0:
		return INF
	return cargo_capacity(run, meta, c) / rt


# --- Research -----------------------------------------------------------------

## Product of studied multipliers of `type` whose targets include "all" or
## any of `keys` (resource ids, recipe ids, "land"/"sea", "crafted"/"raw").
func research_mult(run: RunState, type: String, keys: Array = []) -> float:
	var fx: Array = run.research_effects().get(type, [])
	var m: float = 1.0
	for e: Array in fx:
		var targets: Array = e[0]
		if targets.is_empty() or targets.has("all"):
			m *= float(e[1])
			continue
		for key: Variant in keys:
			if targets.has(key):
				m *= float(e[1])
				break
	return m


## Sum of an additive research effect (offline hours, workshop labour...).
func research_add(run: RunState, type: String) -> float:
	var t: float = 0.0
	for e: Array in run.research_effects().get(type, []):
		t += float(e[1])
	return t


## A recipe's inputs after any study that trims them.
func recipe_inputs(run: RunState, recipe_id: String) -> Dictionary:
	var base: Dictionary = Content.recipe(recipe_id)["inputs"]
	var fx: Array = run.research_effects().get("recipe_input", []) if run != null else []
	if fx.is_empty():
		return base
	var out: Dictionary = base.duplicate()
	for e: Array in fx:
		var t: Array = e[0]
		if t.size() == 2 and str(t[0]) == recipe_id and out.has(str(t[1])):
			out[str(t[1])] = mini(int(out[str(t[1])]), maxi(1, int(e[1])))
	return out


## A Founding Father's price this run (studies can cheapen the gold part).
func father_cost(run: RunState, father_id: String) -> Dictionary:
	var cost: Dictionary = (Content.father(father_id)["cost"] as Dictionary).duplicate()
	if cost.has("gold"):
		cost["gold"] = float(cost["gold"]) * research_mult(run, "father_cost")
	return cost


func route_key(run: RunState, c: RunState.ColonyState) -> String:
	return "sea" if is_sea(run, c) else "land"


const STUDY_TIER_COLONIES := [0, 1, 4, 8, 12, 16, 20]


func study_colonies_needed(def: Dictionary) -> int:
	return int(STUDY_TIER_COLONIES[clampi(int(def.get("tier", 1)), 1, 6)])


## Goods and gold to study `id` at its next level. Goods scale with how many
## colonies the run has; gold is about ten minutes of that tier's colony at
## base. Repeatable studies cost x3 per level already taken.
func study_cost(run: RunState, id: String) -> Dictionary:
	var def: Dictionary = Content.study(id)
	var lvl: int = run.study_level(id)
	var repeat: float = pow(v("research_repeat_cost_growth"), lvl)
	var scale: float = (1.0 + v("research_scale_per_colony") * run.colonies.size()) * repeat
	var out: Dictionary = {}
	for key: String in (def.get("cost", {}) as Dictionary).keys():
		out[key] = ceilf(float(def["cost"][key]) * scale)
	var tier_colony: int = study_colonies_needed(def)
	out["gold"] = ceilf(tier_value(maxi(tier_colony - 1, 0)) * v("research_gold_seconds") * repeat)
	return out


## Why `id` can't be studied now, or "" if it can (cost aside).
func study_block(run: RunState, meta: MetaState, id: String) -> String:
	var def: Dictionary = Content.study(id)
	if def.is_empty():
		return "Unknown"
	if not unlocked(meta, "research"):
		return "Locked"
	if run.study_level(id) > 0 and not bool(def.get("repeatable", false)):
		return "Studied"
	var ex: String = str(def.get("excludes", ""))
	if ex != "" and run.study_level(ex) > 0:
		return "Chose " + str(Content.study(ex).get("name", ex))
	var need: int = study_colonies_needed(def)
	if run.colonies.size() < need:
		return "Needs %d colonies" % need
	for r: Variant in def.get("requires", []):
		if run.study_level(str(r)) <= 0:
			return "Needs " + str(Content.study(str(r)).get("name", r))
	var any: Array = def.get("requires_any", [])
	if not any.is_empty():
		var ok: bool = false
		for r: Variant in any:
			if run.study_level(str(r)) > 0:
				ok = true
		if not ok:
			return "Needs a path's final study"
	return ""


# --- Unlocks ------------------------------------------------------------------

## Newer systems open up over successive expeditions so a first run stays
## simple: the number of independences declared before `feature` appears.
func unlock_runs(feature: String) -> int:
	return int((k.get("unlock_after_runs", {}) as Dictionary).get(feature, 0))


func unlocked(meta: MetaState, feature: String) -> bool:
	return meta != null and meta.runs_completed >= unlock_runs(feature)


# --- Milestones ---------------------------------------------------------------

## Upgrade levels that double a track's output: the listed thresholds, then
## every milestone_step_after levels past the last one.
func milestone_count(level: int) -> int:
	var list: Array = k.get("milestones", [])
	var n: int = 0
	for t: Variant in list:
		if level >= int(t):
			n += 1
	if not list.is_empty() and level > int(list[-1]):
		n += (level - int(list[-1])) / int(v("milestone_step_after"))
	return n


## The next milestone level above `level`.
func next_milestone(level: int) -> int:
	var list: Array = k.get("milestones", [])
	for t: Variant in list:
		if int(t) > level:
			return int(t)
	var last: int = int(list[-1]) if not list.is_empty() else 0
	var step: int = int(v("milestone_step_after"))
	return last + ((level - last) / step + 1) * step


## The milestone at or below `level` (0 before the first).
func prev_milestone(level: int) -> int:
	var prev: int = 0
	var m: int = next_milestone(-1)
	while m <= level:
		prev = m
		m = next_milestone(m)
	return prev


func milestone_mult(level: int, per: float) -> float:
	return pow(per, milestone_count(level))


# --- Specializations -----------------------------------------------------------

func spec_mult(c: RunState.ColonyState, effect: String) -> float:
	if c.spec == "":
		return 1.0
	var s: Dictionary = Content.specialization(c.spec)
	return float(s["value"]) if s.get("effect", "") == effect else 1.0


## The two specializations offered to a colony, fixed per colony and run.
func specs_offered(run: RunState, c: RunState.ColonyState) -> Array[Dictionary]:
	var route: String = "none" if c.tier == 0 else str(run.site_of(c)["route"])
	var pool: Array[Dictionary] = []
	for s: Dictionary in Content.specializations:
		if s["route"] == "any" or s["route"] == route:
			pool.append(s)
	var rng := RandomNumberGenerator.new()
	rng.seed = hash([run.map_seed, c.id, "spec"])
	for i in range(pool.size() - 1, 0, -1):
		var j: int = rng.randi_range(0, i)
		var tmp: Dictionary = pool[i]
		pool[i] = pool[j]
		pool[j] = tmp
	return pool.slice(0, 2)


## A Market Town makes its good sell higher everywhere.
func market_town_mult(run: RunState, resource_id: String) -> float:
	var m: float = 1.0
	for c: RunState.ColonyState in run.colonies:
		if c.spec == "market_town" and run.resource_of(c) == resource_id:
			m = maxf(m, spec_mult(c, "price"))
	return m


func charter_mult(c: RunState.ColonyState) -> float:
	return 1.0 + v("charter_bonus_per_level") * c.charter


## Goods needed to raise a colony to charter level `level` (1-based), or {}
## past the last charter. Later colonies need more.
func charter_cost(run: RunState, c: RunState.ColonyState, level: int) -> Dictionary:
	if level < 1 or level > Content.charters.size():
		return {}
	var scale: float = (1.0 + v("charter_scale_per_colony") * c.tier) * father_bonus(run, "charter_cost") * research_mult(run, "charter_cost")
	var out: Dictionary = {}
	var goods: Dictionary = Content.charters[level - 1]["goods"]
	for key: String in goods.keys():
		out[key] = ceilf(float(goods[key]) * scale)
	return out


## A governor posted at this colony multiplies the stat matching their type.
func governor_mult(run: RunState, meta: MetaState, c: RunState.ColonyState, type_id: String) -> float:
	var gid: int = run.governor_at(c.id)
	if gid < 0:
		return 1.0
	var g: Dictionary = meta.governor(gid)
	if g.is_empty() or g["type"] != type_id:
		return 1.0
	return governor_multiplier_for_rank(int(g["rank"]))


func governor_multiplier_for_rank(rank: int) -> float:
	return 1.0 + v("governor_bonus_base") + v("governor_bonus_per_rank") * (rank - 1)


func governor_commission_cost(meta: MetaState) -> int:
	return int(ceil(minf(v("governor_commission_base") * pow(v("governor_commission_growth"), meta.governors.size()), 9.0e18)))


## Liberty to promote a governor from `rank` to rank + 1, or -1 at max rank.
func governor_rank_cost(rank: int) -> int:
	if rank >= int(v("governor_max_rank")):
		return -1
	return int(ceil(v("governor_rank_cost_base") * pow(v("governor_rank_cost_growth"), rank - 1)))


func colony_upgrade_cost(run: RunState, track: String, c: RunState.ColonyState, levels: int = 1) -> float:
	return geometric_cost(upgrade_base(run, track, c), v(track + "_cost_growth"), track_level(c, track), levels)


func upgrade_base(run: RunState, track: String, c: RunState.ColonyState) -> float:
	return v(track + "_cost_base") * tier_value(c.tier) * father_bonus(run, "upgrade_cost")


func track_level(c: RunState.ColonyState, track: String) -> int:
	match track:
		"cargo": return c.cargo_level
		"speed": return c.speed_level
	return c.prod_level


## Gold to found colony number `tier` (1 = the first after the capital).
func found_cost_for_tier(tier: int) -> float:
	var cost: float = v("found_cost_first")
	for n in range(2, tier + 1):
		cost *= v("found_cost_growth_base") + v("found_cost_growth_step") * n
	return cost


func found_cost(run: RunState, meta: MetaState) -> float:
	var base: float = found_cost_for_tier(run.colonies.size())
	return base * nation_bonus(run, "colony_cost") * bonus(run, meta, "colony_cost") * liberty_mult(meta, "settlement") * research_mult(run, "colony_cost")


func explore_mult(run: RunState, meta: MetaState = null) -> float:
	return bonus(run, _meta_or_game(meta), "explore") * research_mult(run, "explore")


# --- Colonists --------------------------------------------------------------

func colonist_base(run: RunState, meta: MetaState) -> float:
	return v("colonist_cost_base") * bonus(run, meta, "colonist_cost") * liberty_mult(meta, "settlement") * research_mult(run, "colonist_cost")


func colonist_cost(run: RunState, meta: MetaState, count: int = 1) -> float:
	return geometric_cost(colonist_base(run, meta), v("colonist_cost_growth"), run.colonists_owned, count)


# --- Workshops --------------------------------------------------------------

func craft_seconds(run: RunState, meta: MetaState, w: RunState.WorkshopState) -> float:
	if w.colonists <= 0:
		return INF
	return float(Content.recipe(w.id)["time"]) / workshop_speed(run, meta, w)


func workshop_speed(run: RunState, meta: MetaState, w: RunState.WorkshopState) -> float:
	var labour: float = float(w.colonists) + (research_add(run, "workshop_labour") if w.colonists > 0 else 0.0)
	var speed: float = labour * pow(v("workshop_speed_growth"), w.level)
	speed *= research_mult(run, "workshop_speed", [w.id])
	speed *= milestone_mult(w.level, v("milestone_workshop_mult"))
	speed *= run.sim_rate
	speed *= bonus(run, meta, "craft_speed") * liberty_mult(meta, "manufacture")
	return speed


func workshop_build_cost(recipe_id: String) -> float:
	return float(Content.recipe(recipe_id)["build_cost"])


func workshop_upgrade_base(run: RunState, w: RunState.WorkshopState) -> float:
	return v("workshop_cost_base") * Content.price(w.id) * father_bonus(run, "workshop_cost") * research_mult(run, "workshop_cost")


func workshop_upgrade_cost(run: RunState, w: RunState.WorkshopState, levels: int = 1) -> float:
	return geometric_cost(workshop_upgrade_base(run, w), v("workshop_cost_growth"), w.level, levels)


# --- Selling ----------------------------------------------------------------

func sell_price(run: RunState, meta: MetaState, resource_id: String) -> float:
	var p: float = Content.price(resource_id)
	p *= nation_bonus(run, "sell_price")
	p *= bonus(run, meta, "sell_price")
	p *= liberty_mult(meta, "commerce")
	p *= bonus(run, meta, "crafted_price") if Content.is_crafted(resource_id) else bonus(run, meta, "raw_price")
	p *= market_town_mult(run, resource_id)
	p *= research_mult(run, "sell", [resource_id, "crafted" if Content.is_crafted(resource_id) else "raw"])
	p *= market_mult(run, resource_id)
	return p


# --- The European market --------------------------------------------------------

## Demand in Europe shifts every market period: a few goods are wanted (sell
## high), a few are in glut (sell low). Derived from the run's start time and
## simulated time, so it's deterministic and offline catch-up agrees with
## live play.
func market_state(run: RunState) -> Dictionary:
	var period_len: float = v("market_period_seconds")
	var period: int = int(floor(run.play_seconds / period_len))
	var key: Array = [int(run.started_unix), period]
	if key == _market_cache_key:
		_market_cache["remaining"] = period_len * (period + 1) - run.play_seconds
		return _market_cache
	var rng := RandomNumberGenerator.new()
	rng.seed = hash(key)
	var ids: Array[String] = []
	for r: Dictionary in Content.resources:
		ids.append(str(r["id"]))
	for i in range(ids.size() - 1, 0, -1):
		var j: int = rng.randi_range(0, i)
		var tmp: String = ids[i]
		ids[i] = ids[j]
		ids[j] = tmp
	var up_n: int = int(v("market_up_count"))
	var down_n: int = int(v("market_down_count"))
	_market_cache_key = key
	_market_cache = {
		"period": period,
		"up": ids.slice(0, up_n),
		"down": ids.slice(up_n, up_n + down_n),
		"remaining": period_len * (period + 1) - run.play_seconds,
	}
	return _market_cache


func market_mult(run: RunState, resource_id: String) -> float:
	var m: Dictionary = market_state(run)
	if (m["up"] as Array).has(resource_id):
		var up: float = v("market_up_mult")
		for e: Array in run.research_effects().get("market_wanted", []):
			up = maxf(up, float(e[1]))
		return up * father_bonus(run, "market")
	if (m["down"] as Array).has(resource_id):
		var down: float = v("market_down_mult")
		for e: Array in run.research_effects().get("market_glut", []):
			down = maxf(down, float(e[1]))
		return down
	return 1.0


# --- Founding Fathers -------------------------------------------------------------

## The Founding Fathers who can be invited this run: a random handful from
## each tier, fixed for the run.
func fathers_offered(run: RunState) -> Array[Dictionary]:
	var rng := RandomNumberGenerator.new()
	rng.seed = hash([run.map_seed, "fathers"])
	var per_tier: int = int(v("fathers_offered_per_tier"))
	var out: Array[Dictionary] = []
	for tier in range(1, 5):
		var pool: Array[Dictionary] = []
		for f: Dictionary in Content.fathers:
			if int(f.get("tier", 1)) == tier:
				pool.append(f)
		for i in range(pool.size() - 1, 0, -1):
			var j: int = rng.randi_range(0, i)
			var tmp: Dictionary = pool[i]
			pool[i] = pool[j]
			pool[j] = tmp
		for i in mini(per_tier, pool.size()):
			out.append(pool[i])
	for id: String in run.fathers:
		var f: Dictionary = Content.father(id)
		if not f.is_empty() and not out.has(f):
			out.append(f)
	return out


# --- Independence -----------------------------------------------------------

func offline_cap_seconds(run: RunState, meta: MetaState = null) -> float:
	var hours: float = v("offline_cap_hours") + relic_bonus(_meta_or_game(meta), "offline_hours") + research_add(run, "offline_hours")
	for id: String in run.fathers:
		var f: Dictionary = Content.father(id)
		if f.get("effect", "") == "offline_hours":
			hours += float(f["value"])
	return hours * 3600.0


func independence_ready(run: RunState) -> bool:
	return run.lifetime_gold >= v("independence_gold") \
		and run.stock_of("muskets") + 0.0001 >= v("independence_muskets")


## What may be spent of a good: everything except the militia's muskets.
func spendable(run: RunState, resource_id: String) -> float:
	return run.stock_of(resource_id) - militia_reserve(run, resource_id)


## Muskets set aside for the militia: never sold, needed to declare.
func militia_reserve(run: RunState, resource_id: String) -> float:
	if resource_id != "muskets":
		return 0.0
	return minf(run.stock_of("muskets"), v("independence_muskets"))


func liberty_payout(run: RunState, meta: MetaState = null) -> int:
	if run.lifetime_gold < v("independence_gold"):
		return 0
	var raw: float = v("liberty_base") * pow(run.lifetime_gold / v("independence_gold"), v("liberty_exponent"))
	raw *= nation_bonus(run, "liberty") * bonus(run, _meta_or_game(meta), "liberty") * research_mult(run, "liberty")
	return int(floor(minf(raw, 9.0e18)))


func liberty_upgrade_cost(meta: MetaState, upgrade_id: String) -> int:
	var def: Dictionary = Content.liberty_upgrade(upgrade_id)
	if def.is_empty():
		return -1
	if upgrade_id == "settlement" and liberty_mult(meta, upgrade_id) <= v("settlement_floor") + 0.0001:
		return -1
	return int(ceil(minf(float(def["base_cost"]) * pow(float(def["growth"]), meta.level(upgrade_id)), 9.0e18)))


# --- Helpers ----------------------------------------------------------------

## Total cost of buying `count` successive levels starting at `level`, where
## level n costs base * growth^n.
func geometric_cost(base: float, growth: float, level: int, count: int) -> float:
	if count <= 0:
		return 0.0
	var first: float = base * pow(growth, level)
	if is_equal_approx(growth, 1.0):
		return first * count
	return first * (pow(growth, count) - 1.0) / (growth - 1.0)


## How many successive levels `budget` can buy, capped at `limit`.
func affordable_levels(base: float, growth: float, level: int, budget: float, limit: int = 1000) -> int:
	var first: float = base * pow(growth, level)
	if budget < first:
		return 0
	# In logs, so huge budget-to-cost ratios can't overflow to INF.
	var lr: float = log(budget) - log(first) + log(growth - 1.0)
	var n_f: float = (lr if lr > 30.0 else log(exp(lr) + 1.0)) / log(growth)
	var n: int = int(clampf(floor(n_f), 0.0, float(limit)))
	while n > 0 and geometric_cost(base, growth, level, n) > budget:
		n -= 1
	return n
