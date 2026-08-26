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
## why - a judgment call, not something said outright). "Distance" is now
## real grid cells from the generated map (rework task: randomized map),
## not the old 0-7 order index - these two numbers were tuned against that
## smaller range and are a first-pass fit for the new one, not a claim of
## precision; retune freely once a real run's pacing has been played.
@export var route_time_factor_land: float = 12.0
@export var route_time_factor_sea: float = 22.0

@export_group("Map Generation")
## Simulation-lattice size (rework task: randomized map). Coarse on purpose -
## this grid is never rendered pixel-for-pixel (see
## docs/GODOT_MIGRATION_ANALYSIS.md §C5's warning about the old 2000x1500
## Unity grid being a 3-million-cell texture) - it only has to be fine enough
## for placement and distance to feel meaningful.
@export var map_width: int = 60
@export var map_height: int = 60
## Land forms where (noise * 0.5 + west-edge bias) exceeds this - see
## MapGenerator.generate_terrain(). Higher = less land/more open ocean.
## 0.6 was tuned by eye (docs/GODOT_PLAN's verification step) to read as
## "mostly a continent," not a coin-flip blob covering half the map.
@export var continent_threshold: float = 0.6
@export var island_count: int = 5
@export var island_min_radius: float = 3.0
@export var island_max_radius: float = 7.0
## Target distance (grid cells) between consecutive colony slots - see
## MapGenerator.place_colony_slots(). Each slot's actual band is a spread
## around `distance_step * slot_index`, not a fixed multiple - "semi-random,"
## per the brief, not a rigid ladder.
@export var colony_distance_step: float = 2.5
## Minimum distance (grid cells) a new colony slot must keep from the
## Capital and every other placed slot.
@export var min_colony_spacing: float = 2.0

@export_group("Colony Founding")
## How many colony slots a run generates in total (Capital included) -
## explicitly a number you expect to retune, not a locked design constant.
@export var max_colonies: int = 25
## Cost of founding colony slot N (1-indexed - slot 0 is the free Capital):
## base * growth^N. Replaces the old hand-authored 8-entry unlock_cost table
## (task #26), which doesn't extend to 25+ slots - fit against that table's
## own real values (250 -> 3,000 -> 40,000 -> ... -> 1.1B, a strikingly
## consistent ~13x step per tier) rather than invented from scratch.
@export var colony_slot_base_cost: float = 250.0
@export var colony_slot_cost_growth: float = 13.0

@export_group("Offline Catch-Up")
## Maximum real-world time (seconds) a single load() will fast-forward
## through, regardless of how long the save file says the player was away.
## Prevents an absurdly long gap (or a corrupted/tampered timestamp) from
## producing an equally absurd result - 24 hours by default, easily retuned.
@export var offline_catch_up_cap_seconds: float = 86400.0

@export_group("Prestige Gate and Payout")
## §8/§6: reset unlocks once this run has earned this much gold, lifetime
## (not current on-hand gold, which can be spent down).
@export var prestige_gate_threshold: float = 2_000_000_000.0
## Same 2e9 baseline the doc's payout formula divides by - kept as its own
## field rather than reusing prestige_gate_threshold so gate and payout can
## be retuned independently later without one accidentally moving the other.
@export var prestige_payout_divisor: float = 2_000_000_000.0
@export var prestige_payout_multiplier: float = 6.0

@export_group("Prestige - Industry")
## Cost of the next Industry level, in Liberty: base * growth^current_level -
## the same shape as every other cost curve in this file, applied to the
## doc's stated rule ("costs escalate base x 1.8^level") rather than its
## rendered example table, which isn't a clean power series.
@export var industry_base_cost: float = 3.0
@export var industry_cost_growth: float = 1.8
@export var industry_max_level: int = 10
## +15% production per level, additive (docs/GAME_DESIGN.md §8).
@export var industry_bonus_per_level: float = 0.15

@export_group("Prestige - Navigation")
@export var navigation_base_cost: float = 4.0
@export var navigation_cost_growth: float = 1.8
@export var navigation_max_level: int = 8
## +12% transport speed AND +12% cargo per level, additive, same rate for
## both (docs/GAME_DESIGN.md §8).
@export var navigation_bonus_per_level: float = 0.12

@export_group("Prestige - Settlement")
@export var settlement_base_cost: float = 5.0
@export var settlement_cost_growth: float = 1.8
@export var settlement_max_level: int = 8
## -7% colonist and colony cost per level, multiplicative (0.93^level), never
## discounting past -60% total (docs/GAME_DESIGN.md §8).
@export var settlement_discount_per_level: float = 0.07
@export var settlement_max_discount: float = 0.6
