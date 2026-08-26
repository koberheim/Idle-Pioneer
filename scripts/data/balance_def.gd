## Every tunable number this game's economy runs on, in one place -
## per docs/GAME_DESIGN.md §10: "Keep every one of these in a single Balance
## autoload so tuning never requires touching logic."
##
## This is a Resource (data/balance.tres), not hardcoded constants, so it can
## be opened and retuned directly in the Godot inspector - no code, no
## recompile, no touching a single script - and swapped for an alternate
## balance file for testing without changing anything else. The formulas that
## USE these numbers live in scripts/core/balance.gd (the Balance autoload);
## this class only holds the numbers themselves.
##
## Fields are grouped so a future pass (colonists' real bonus formula, a
## Navigation/Industry prestige multiplier, a fourth upgrade track) has an
## obvious place to land without reshaping what's already here.
class_name BalanceDef
extends Resource

@export_group("Colonists")
## §6: colonist_cost = base * growth^colonists_owned.
@export var colonist_base_cost: float = 25.0
@export var colonist_cost_growth: float = 1.15

## PLACEHOLDER - deliberately not designed yet ("we'll develop later," per
## conversation). A flat multiplier bonus applied per colonist assigned to a
## colony, identically across all three upgrade tracks below, until a real
## colonist-bonus design replaces this with something more considered.
@export var colonist_bonus_per_colonist: float = 0.1

@export_group("Colony Production Upgrade")
## Cost of the next production level: base * growth^current_level.
@export var production_level_base_cost: float = 40.0
@export var production_level_cost_growth: float = 1.13
## Multiplier bonus per level: rate *= (1 + bonus * level).
@export var production_level_bonus: float = 0.25

@export_group("Colony Cargo Upgrade")
@export var cargo_level_base_cost: float = 60.0
@export var cargo_level_cost_growth: float = 1.16
@export var cargo_level_bonus: float = 0.5

@export_group("Colony Speed Upgrade")
@export var speed_level_base_cost: float = 60.0
@export var speed_level_cost_growth: float = 1.16
@export var speed_level_bonus: float = 0.5

@export_group("Route Travel Time")
## Seconds of round-trip travel time per unit of distance. Land/sea is now
## the ONLY thing this affects - cargo capacity has its own per-colony track
## above instead (see docs/GODOT_PLAN.md's design realignment section for
## why - a judgment call, not something said outright).
@export var route_time_factor_land: float = 12.0
@export var route_time_factor_sea: float = 22.0
