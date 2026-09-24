## Every tunable number and formula in one place. Constants come from
## data/balance.json; multipliers are gathered from the nation, Founding
## Fathers, Liberty reforms, governors and charters so no other code needs to
## know where a bonus comes from.
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
	rate *= 1.0 + v("colonist_production_bonus") * c.colonists
	rate *= liberty_mult(meta, "industry")
	rate *= nation_bonus(run, "production")
	rate *= father_bonus(run, "production")
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
	cap *= liberty_mult(meta, "navigation")
	cap *= father_bonus(run, "cargo")
	cap *= charter_mult(c)
	cap *= governor_mult(run, meta, c, "cargo")
	return cap


func round_trip_seconds(run: RunState, meta: MetaState, c: RunState.ColonyState) -> float:
	var length: float = route_length(run, c)
	if length <= 0.0:
		return 0.0
	var sea: bool = is_sea(run, c)
	var t: float = 2.0 * length * (v("sea_seconds_per_step") if sea else v("land_seconds_per_step"))
	var speed: float = 1.0 + v("speed_per_level") * c.speed_level
	speed *= liberty_mult(meta, "navigation")
	speed *= governor_mult(run, meta, c, "speed")
	if sea:
		speed *= nation_bonus(run, "sea_speed") * father_bonus(run, "sea_speed")
	else:
		speed *= nation_bonus(run, "land_speed") * father_bonus(run, "land_speed")
	return t / speed


## Units per second a route can actually move; production beyond this piles up
## at the colony.
func route_throughput(run: RunState, meta: MetaState, c: RunState.ColonyState) -> float:
	var rt: float = round_trip_seconds(run, meta, c)
	if rt <= 0.0:
		return INF
	return cargo_capacity(run, meta, c) / rt


func charter_mult(c: RunState.ColonyState) -> float:
	return 1.0 + v("charter_bonus_per_level") * c.charter


## Goods needed to raise a colony to charter level `level` (1-based), or {}
## past the last charter. Later colonies need more.
func charter_cost(run: RunState, c: RunState.ColonyState, level: int) -> Dictionary:
	if level < 1 or level > Content.charters.size():
		return {}
	var scale: float = (1.0 + v("charter_scale_per_colony") * c.tier) * father_bonus(run, "charter_cost")
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
	return int(ceil(v("governor_commission_base") * pow(v("governor_commission_growth"), meta.governors.size())))


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
	return base * nation_bonus(run, "colony_cost") * father_bonus(run, "colony_cost") * liberty_mult(meta, "settlement")


func explore_mult(run: RunState) -> float:
	return father_bonus(run, "explore")


# --- Colonists --------------------------------------------------------------

func colonist_base(run: RunState, meta: MetaState) -> float:
	return v("colonist_cost_base") * father_bonus(run, "colonist_cost") * liberty_mult(meta, "settlement")


func colonist_cost(run: RunState, meta: MetaState, count: int = 1) -> float:
	return geometric_cost(colonist_base(run, meta), v("colonist_cost_growth"), run.colonists_owned, count)


# --- Workshops --------------------------------------------------------------

func craft_seconds(run: RunState, meta: MetaState, w: RunState.WorkshopState) -> float:
	if w.colonists <= 0:
		return INF
	return float(Content.recipe(w.id)["time"]) / workshop_speed(run, meta, w)


func workshop_speed(run: RunState, meta: MetaState, w: RunState.WorkshopState) -> float:
	var speed: float = w.colonists * pow(v("workshop_speed_growth"), w.level)
	speed *= father_bonus(run, "craft_speed") * liberty_mult(meta, "manufacture")
	return speed


func workshop_build_cost(recipe_id: String) -> float:
	return float(Content.recipe(recipe_id)["build_cost"])


func workshop_upgrade_base(run: RunState, w: RunState.WorkshopState) -> float:
	return v("workshop_cost_base") * Content.price(w.id) * father_bonus(run, "workshop_cost")


func workshop_upgrade_cost(run: RunState, w: RunState.WorkshopState, levels: int = 1) -> float:
	return geometric_cost(workshop_upgrade_base(run, w), v("workshop_cost_growth"), w.level, levels)


# --- Selling ----------------------------------------------------------------

func sell_price(run: RunState, meta: MetaState, resource_id: String) -> float:
	var p: float = Content.price(resource_id)
	p *= nation_bonus(run, "sell_price")
	p *= father_bonus(run, "sell_price")
	p *= liberty_mult(meta, "commerce")
	p *= father_bonus(run, "crafted_price") if Content.is_crafted(resource_id) else father_bonus(run, "raw_price")
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
		return v("market_up_mult") * father_bonus(run, "market")
	if (m["down"] as Array).has(resource_id):
		return v("market_down_mult")
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

func offline_cap_seconds(run: RunState) -> float:
	var hours: float = v("offline_cap_hours")
	for id: String in run.fathers:
		var f: Dictionary = Content.father(id)
		if f.get("effect", "") == "offline_hours":
			hours += float(f["value"])
	return hours * 3600.0


func independence_ready(run: RunState) -> bool:
	return run.lifetime_gold >= v("independence_gold") \
		and int(run.crafted.get("muskets", 0)) >= int(v("independence_muskets"))


func liberty_payout(run: RunState) -> int:
	if run.lifetime_gold < v("independence_gold"):
		return 0
	var raw: float = v("liberty_base") * sqrt(run.lifetime_gold / v("independence_gold"))
	raw *= nation_bonus(run, "liberty") * father_bonus(run, "liberty")
	return int(floor(raw))


func liberty_upgrade_cost(meta: MetaState, upgrade_id: String) -> int:
	var def: Dictionary = Content.liberty_upgrade(upgrade_id)
	if def.is_empty():
		return -1
	if upgrade_id == "settlement" and liberty_mult(meta, upgrade_id) <= v("settlement_floor") + 0.0001:
		return -1
	return int(ceil(float(def["base_cost"]) * pow(float(def["growth"]), meta.level(upgrade_id))))


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
	var n: int = int(floor(log(budget * (growth - 1.0) / first + 1.0) / log(growth)))
	n = clampi(n, 0, limit)
	while n > 0 and geometric_cost(base, growth, level, n) > budget:
		n -= 1
	return n
