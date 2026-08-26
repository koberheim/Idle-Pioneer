## Autoload: every economic formula this game runs on (docs/GAME_DESIGN.md
## §10's suggested architecture, adopted directly - "every constant and
## formula" in one place). Colony/Route/Colonists call into here rather than
## computing their own numbers, so retuning a cost curve or a bonus-per-level
## rate is always a one-file change - never a hunt across every system that
## happens to use it.
##
## The raw tunable numbers live in data/balance.tres (a BalanceDef Resource,
## editable directly in the Godot inspector - no code, no recompile). This
## script is the formulas that combine those numbers; swapping in a different
## balance.tres (for a test, or a wholesale rebalance) changes every number at
## once without touching a single line here.
extends Node

var _def: BalanceDef


func _ready() -> void:
	_def = load("res://data/balance.tres")
	if _def == null:
		push_error("Balance: failed to load res://data/balance.tres")


## Shared shape for every "cost grows geometrically per level/purchase already
## made" curve in the game (§6: colonist_cost, building_cost, transport_cost,
## workshop_cost are all `base * growth^count`) - one function instead of four
## near-identical ones.
func _geometric_cost(base: float, growth: float, count: int) -> float:
	return base * pow(growth, count)


## Cost of recruiting the next colonist (any type) - "no cap owned, but
## expensive" (rework: typed colonist roster). `prestige_discount_multiplier`
## is Settlement's effect (Prestige.cost_discount_multiplier()) - defaults to
## 1.0 (no discount) so every existing caller/test that hasn't bought
## Settlement yet is unaffected.
func next_colonist_recruit_cost(colonists_owned: int, prestige_discount_multiplier: float = 1.0) -> float:
	return _geometric_cost(_def.colonist_recruit_base_cost, _def.colonist_recruit_cost_growth, colonists_owned) * prestige_discount_multiplier


## Cost of raising one specific colonist from `current_level` to the next -
## scales with that colonist's own level, independent of how many colonists
## are owned overall. Same Settlement-discount convention as recruiting.
func next_colonist_upgrade_cost(current_level: int, prestige_discount_multiplier: float = 1.0) -> float:
	return _geometric_cost(_def.colonist_upgrade_base_cost, _def.colonist_upgrade_cost_growth, current_level) * prestige_discount_multiplier


func next_production_level_cost(current_level: int) -> float:
	return _geometric_cost(_def.production_level_base_cost, _def.production_level_cost_growth, current_level)


func next_cargo_level_cost(current_level: int) -> float:
	return _geometric_cost(_def.cargo_level_base_cost, _def.cargo_level_cost_growth, current_level)


func next_speed_level_cost(current_level: int) -> float:
	return _geometric_cost(_def.speed_level_base_cost, _def.speed_level_cost_growth, current_level)


## A colonist's primary effect, scaled by its own level (rework: typed
## colonist roster - replaces the old flat per-headcount bonus). `level` is
## 0 when no colonist of the relevant type is assigned to a colony, which
## correctly yields a neutral 1.0 multiplier - a colony still works fine
## unstaffed, staffing is a bonus on top (docs/GODOT_PLAN.md's design
## realignment section).
func colonist_primary_multiplier(level: int) -> float:
	return 1.0 + _def.colonist_primary_bonus_per_level * float(level)


## PLACEHOLDER FRAMEWORK ONLY - see BalanceDef.colonist_secondary_unlock_level's
## doc comment. Nothing calls this yet; it exists so the data model has room
## for a real secondary-effect design later without a restructure.
func colonist_secondary_modifier(level: int) -> float:
	if level < _def.colonist_secondary_unlock_level:
		return 0.0
	return _def.colonist_secondary_bonus_per_level * float(level - _def.colonist_secondary_unlock_level + 1)


## Units/second a colony produces. Colonies have a real base rate with zero
## colonists assigned - staffing is a bonus on top, not a requirement to
## produce anything at all (docs/GODOT_PLAN.md's design realignment section -
## this is a deliberate correction to §4's "every colonist is either
## producing or converting" read literally). `resource_colonist_level` is 0
## if no Resource-type colonist is assigned to this colony.
func colony_production_rate(
	base_rate: float, production_level: int, resource_colonist_level: int, prestige_multiplier: float
) -> float:
	var level_multiplier: float = 1.0 + _def.production_level_bonus * float(production_level)
	return base_rate * level_multiplier * colonist_primary_multiplier(resource_colonist_level) * prestige_multiplier


## Cargo capacity - a colony's own base_cargo, its cargo upgrade level, and
## its assigned Cargo-type colonist's level (0 if none). Land vs. sea no
## longer affects this (see route_round_trip_seconds for where it does
## apply). `prestige_cargo_multiplier` is Navigation's cargo effect
## (Prestige.cargo_multiplier()) - defaults to 1.0 so every existing
## caller/test is unaffected until Navigation is bought.
func colony_cargo_capacity(
	base_cargo: float, cargo_level: int, cargo_colonist_level: int, prestige_cargo_multiplier: float = 1.0
) -> float:
	var level_multiplier: float = 1.0 + _def.cargo_level_bonus * float(cargo_level)
	return base_cargo * level_multiplier * colonist_primary_multiplier(cargo_colonist_level) * prestige_cargo_multiplier


## Full round-trip travel time in seconds. `is_sea` picks the per-distance
## time factor (land vs. sea, docs/GAME_DESIGN.md §5's per-colony roll); the
## colony's own base_speed, speed upgrade level, and its assigned Speed-type
## colonist's level (0 if none) all reduce it further.
## `prestige_speed_multiplier` is Navigation's speed effect
## (Prestige.speed_multiplier()) - defaults to 1.0 so every existing
## caller/test is unaffected until Navigation is bought.
func route_round_trip_seconds(
	distance: float, is_sea: bool, base_speed: float, speed_level: int, speed_colonist_level: int,
	prestige_speed_multiplier: float = 1.0
) -> float:
	var time_factor: float = _def.route_time_factor_sea if is_sea else _def.route_time_factor_land
	var speed_multiplier: float = (
		base_speed
		* (1.0 + _def.speed_level_bonus * float(speed_level))
		* colonist_primary_multiplier(speed_colonist_level)
		* prestige_speed_multiplier
	)
	if speed_multiplier <= 0.0:
		return 0.0
	return distance * time_factor / speed_multiplier


## §8: reset unlocks once this run's lifetime earnings (not current on-hand
## gold, which can be spent down) cross the threshold.
func prestige_gate_met(lifetime_gold_earned_this_run: float) -> bool:
	return lifetime_gold_earned_this_run >= _def.prestige_gate_threshold


## §6: liberty = floor(6 x sqrt(lifetime_coin_this_run / 2e9)).
func prestige_liberty_payout(lifetime_gold_earned_this_run: float) -> int:
	if lifetime_gold_earned_this_run <= 0.0:
		return 0
	return int(floor(_def.prestige_payout_multiplier * sqrt(lifetime_gold_earned_this_run / _def.prestige_payout_divisor)))


func offline_catch_up_cap_seconds() -> float:
	return _def.offline_catch_up_cap_seconds


## PLACEHOLDER - see BalanceDef.influence_earn_rate_per_gold's doc comment.
func influence_earn_rate_per_gold() -> float:
	return _def.influence_earn_rate_per_gold


func map_width() -> int:
	return _def.map_width


func map_height() -> int:
	return _def.map_height


func continent_threshold() -> float:
	return _def.continent_threshold


func island_count() -> int:
	return _def.island_count


func island_min_radius() -> float:
	return _def.island_min_radius


func island_max_radius() -> float:
	return _def.island_max_radius


func colony_distance_step() -> float:
	return _def.colony_distance_step


func min_colony_spacing() -> float:
	return _def.min_colony_spacing


func max_colonies() -> int:
	return _def.max_colonies


## Cost of founding colony slot `slot_index` (1-indexed - slot 0 is the free
## Capital). Replaces the old per-colony ColonyDef.unlock_cost table (task
## #26), which doesn't extend past 8 hand-authored entries - see
## BalanceDef.colony_slot_base_cost's doc for how these constants were fit.
## `prestige_discount_multiplier` is Settlement's effect, same convention as
## next_colonist_cost().
func next_colony_slot_cost(slot_index: int, prestige_discount_multiplier: float = 1.0) -> float:
	return _geometric_cost(_def.colony_slot_base_cost, _def.colony_slot_cost_growth, slot_index - 1) * prestige_discount_multiplier


func industry_max_level() -> int:
	return _def.industry_max_level


func navigation_max_level() -> int:
	return _def.navigation_max_level


func settlement_max_level() -> int:
	return _def.settlement_max_level


func next_industry_cost(level: int) -> float:
	return _geometric_cost(_def.industry_base_cost, _def.industry_cost_growth, level)


func next_navigation_cost(level: int) -> float:
	return _geometric_cost(_def.navigation_base_cost, _def.navigation_cost_growth, level)


func next_settlement_cost(level: int) -> float:
	return _geometric_cost(_def.settlement_base_cost, _def.settlement_cost_growth, level)


## +15% production per level, additive (docs/GAME_DESIGN.md §8's Industry
## branch). Combines with Progression's run-scoped multiplier at the call
## site (Colony.production_rate()) - Balance.colony_production_rate() only
## ever takes one combined multiplier, not two separate ones.
func industry_production_multiplier(level: int) -> float:
	return 1.0 + _def.industry_bonus_per_level * float(level)


## +12% transport speed per level, additive (docs/GAME_DESIGN.md §8's
## Navigation branch).
func navigation_speed_multiplier(level: int) -> float:
	return 1.0 + _def.navigation_bonus_per_level * float(level)


## +12% cargo per level, additive - same rate as speed, per §8 ("and +12%
## cargo per level"), kept as its own function since the two effects are
## independently retunable fields in BalanceDef even though they start equal.
func navigation_cargo_multiplier(level: int) -> float:
	return 1.0 + _def.navigation_bonus_per_level * float(level)


## -7% colonist/colony cost per level, multiplicative (0.93^level), floored
## at -60% total discount (docs/GAME_DESIGN.md §8's Settlement branch).
func settlement_cost_multiplier(level: int) -> float:
	var multiplier: float = pow(1.0 - _def.settlement_discount_per_level, float(level))
	return maxf(multiplier, 1.0 - _def.settlement_max_discount)
