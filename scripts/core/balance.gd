## Every tunable number and formula in one place. Constants come from
## data/balance.json; multipliers are gathered from the nation, Founding
## Fathers, and Liberty upgrades so no other code needs to know where a bonus
## comes from.
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
	return 1.0 + float(def.get("per_level", 0.0)) * lvl


# --- Colonies ---------------------------------------------------------------

func is_sea(c: RunState.ColonyState) -> bool:
	var sites: Array = Content.colony_sites(c.id)
	if sites.is_empty():
		return false
	return str((sites[clampi(c.site, 0, sites.size() - 1)] as Dictionary).get("route", "land")) == "sea"


func production_rate(run: RunState, meta: MetaState, c: RunState.ColonyState) -> float:
	var def: Dictionary = Content.colony(c.id)
	var rate: float = v("base_rate")
	rate *= 1.0 + v("prod_per_level") * c.prod_level
	rate *= 1.0 + v("colonist_production_bonus") * c.colonists
	rate *= liberty_mult(meta, "industry")
	rate *= nation_bonus(run, "production")
	rate *= father_bonus(run, "production")
	rate *= charter_mult(c)
	rate *= governor_mult(run, meta, c, "prod")
	if run.favor_seconds > 0.0:
		rate *= v("favor_multiplier")
	if def.get("resource", "") == "furs":
		rate *= father_bonus(run, "fur_production")
	return rate


func cargo_capacity(run: RunState, meta: MetaState, c: RunState.ColonyState) -> float:
	# Cargo grows with distance as fast as travel time does, so a route's
	# throughput doesn't depend on distance - far colonies are just lumpier.
	var dist: float = maxf(float(Content.colony(c.id)["distance"]), 1.0)
	var cap: float = dist * (v("sea_cargo_per_distance") if is_sea(c) else v("land_cargo_per_distance"))
	cap *= 1.0 + v("cargo_per_level") * c.cargo_level
	cap *= liberty_mult(meta, "navigation")
	cap *= father_bonus(run, "cargo")
	cap *= charter_mult(c)
	cap *= governor_mult(run, meta, c, "cargo")
	return cap


func round_trip_seconds(run: RunState, meta: MetaState, c: RunState.ColonyState) -> float:
	var def: Dictionary = Content.colony(c.id)
	var sea: bool = is_sea(c)
	var t: float = float(def["distance"]) * (v("sea_time_factor") if sea else v("land_time_factor"))
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
## past the last charter. Farther colonies need proportionally more.
func charter_cost(colony_id: String, level: int) -> Dictionary:
	if level < 1 or level > Content.charters.size():
		return {}
	var scale: float = 1.0 + v("charter_scale_per_colony") * Content.colony_index(colony_id)
	var out: Dictionary = {}
	var goods: Dictionary = Content.charters[level - 1]["goods"]
	for k: String in goods.keys():
		out[k] = ceilf(float(goods[k]) * scale)
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


func colony_scale(colony_id: String) -> float:
	return Content.price(str(Content.colony(colony_id)["resource"]))


func colony_upgrade_cost(track: String, c: RunState.ColonyState, levels: int = 1) -> float:
	var lvl: int = c.prod_level
	if track == "cargo":
		lvl = c.cargo_level
	elif track == "speed":
		lvl = c.speed_level
	return geometric_cost(v(track + "_cost_base") * colony_scale(c.id), v(track + "_cost_growth"), lvl, levels)


func found_cost(run: RunState, meta: MetaState, colony_id: String) -> float:
	var base: float = float(Content.colony(colony_id)["found_cost"])
	return base * nation_bonus(run, "colony_cost") * father_bonus(run, "colony_cost") * liberty_mult(meta, "settlement")


# --- Colonists --------------------------------------------------------------

func colonist_cost(run: RunState, meta: MetaState, count: int = 1) -> float:
	var base: float = v("colonist_cost_base") * father_bonus(run, "colonist_cost") * liberty_mult(meta, "settlement")
	return geometric_cost(base, v("colonist_cost_growth"), run.colonists_owned, count)


# --- Workshops --------------------------------------------------------------

func craft_seconds(run: RunState, w: RunState.WorkshopState) -> float:
	if w.colonists <= 0:
		return INF
	var base: float = float(Content.recipe(w.id)["time"])
	var speed: float = w.colonists * (1.0 + v("craft_per_level") * w.level) * father_bonus(run, "craft_speed")
	return base / speed


func workshop_build_cost(recipe_id: String) -> float:
	return float(Content.recipe(recipe_id)["build_cost"])


func workshop_upgrade_cost(w: RunState.WorkshopState, levels: int = 1) -> float:
	return geometric_cost(v("workshop_cost_base") * Content.price(w.id), v("workshop_cost_growth"), w.level, levels)


# --- Selling ----------------------------------------------------------------

func sell_price(run: RunState, meta: MetaState, resource_id: String) -> float:
	var p: float = Content.price(resource_id)
	p *= nation_bonus(run, "sell_price")
	p *= liberty_mult(meta, "commerce")
	p *= father_bonus(run, "crafted_price") if Content.is_crafted(resource_id) else father_bonus(run, "raw_price")
	p *= market_mult(run, resource_id)
	return p


# --- The European market --------------------------------------------------------

## Demand in Europe shifts every market period: a few goods are wanted (sell
## high), a couple are in glut (sell low). Derived from the run's start time
## and simulated time, so it's deterministic and offline catch-up agrees with
## live play.
func market_state(run: RunState) -> Dictionary:
	var period_len: float = v("market_period_seconds")
	var period: int = int(floor(run.play_seconds / period_len))
	var key: Array = [int(run.started_unix), period]
	if key == _market_cache_key:
		_market_cache["remaining"] = period_len * (period + 1) - run.play_seconds
		return _market_cache
	var rng := RandomNumberGenerator.new()
	rng.seed = hash([int(run.started_unix), period])
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
		return v("market_up_mult")
	if (m["down"] as Array).has(resource_id):
		return v("market_down_mult")
	return 1.0


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
	var costs: Array = Content.liberty_upgrade(upgrade_id).get("costs", [])
	var lvl: int = meta.level(upgrade_id)
	if lvl >= costs.size():
		return -1
	return int(costs[lvl])


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
