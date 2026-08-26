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


func next_colonist_cost(colonists_owned: int) -> float:
	return _geometric_cost(_def.colonist_base_cost, _def.colonist_cost_growth, colonists_owned)


func next_production_level_cost(current_level: int) -> float:
	return _geometric_cost(_def.production_level_base_cost, _def.production_level_cost_growth, current_level)


func next_cargo_level_cost(current_level: int) -> float:
	return _geometric_cost(_def.cargo_level_base_cost, _def.cargo_level_cost_growth, current_level)


func next_speed_level_cost(current_level: int) -> float:
	return _geometric_cost(_def.speed_level_base_cost, _def.speed_level_cost_growth, current_level)


## A colonist's bonus applies identically to all three colony tracks right
## now - see BalanceDef.colonist_bonus_per_colonist's doc comment for why
## that's a placeholder, not a real design decision.
func _colonist_multiplier(colonists_assigned: int) -> float:
	return 1.0 + _def.colonist_bonus_per_colonist * float(colonists_assigned)


## Units/second a colony produces. Colonies have a real base rate with zero
## colonists assigned - staffing is a bonus on top, not a requirement to
## produce anything at all (docs/GODOT_PLAN.md's design realignment section -
## this is a deliberate correction to §4's "every colonist is either
## producing or converting" read literally).
func colony_production_rate(
	base_rate: float, production_level: int, colonists_assigned: int, prestige_multiplier: float
) -> float:
	var level_multiplier: float = 1.0 + _def.production_level_bonus * float(production_level)
	return base_rate * level_multiplier * _colonist_multiplier(colonists_assigned) * prestige_multiplier


## Cargo capacity - a colony's own base_cargo, its cargo upgrade level, and
## its assigned colonists. Land vs. sea no longer affects this (see
## route_round_trip_seconds for where it does apply).
func colony_cargo_capacity(base_cargo: float, cargo_level: int, colonists_assigned: int) -> float:
	var level_multiplier: float = 1.0 + _def.cargo_level_bonus * float(cargo_level)
	return base_cargo * level_multiplier * _colonist_multiplier(colonists_assigned)


## Full round-trip travel time in seconds. `is_sea` picks the per-distance
## time factor (land vs. sea, docs/GAME_DESIGN.md §5's per-colony roll); the
## colony's own base_speed, speed upgrade level, and assigned colonists all
## reduce it further.
func route_round_trip_seconds(
	distance: int, is_sea: bool, base_speed: float, speed_level: int, colonists_assigned: int
) -> float:
	var time_factor: float = _def.route_time_factor_sea if is_sea else _def.route_time_factor_land
	var speed_multiplier: float = base_speed * (1.0 + _def.speed_level_bonus * float(speed_level)) * _colonist_multiplier(colonists_assigned)
	if speed_multiplier <= 0.0:
		return 0.0
	return float(distance) * time_factor / speed_multiplier
