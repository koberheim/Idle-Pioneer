## Content definition for one of the game's eight colony *tiers* (see
## docs/GAME_DESIGN.md §5 - "Colonies"). Originally one .tres per specific
## named place; rework task "randomized map" repurposed these as templates
## instead - "what a colony producing this resource looks like" - reused
## once per resource on the value curve, then cycled again (a second, a
## third time...) as a run founds more colonies than there are tiers. Every
## per-INSTANCE fact (where a founded colony actually sits, how far that is,
## whether it's coastal) now lives on the generated colony slot
## (RunState.colony_slots) and the runtime Colony object instead - see
## Colony's class doc.
##
## Selling price lives on ResourceDef, not here - a colony has one resource,
## so duplicating a price field on both would just be two sources of truth for
## the same fact (the exact mistake RegionDef's class doc already called out
## once, for is_coastal vs. the map).
class_name ColonyDef
extends Resource

## Stable identifier. Must match the .tres filename (enforced by Db).
@export var id: StringName = &""

@export var display_name: String = ""

## Optional - a colony card with no icon set just shows text (see
## docs/CONVENTIONS.md-style pattern already used by ResourceDef.icon).
## Not required by is_valid(): missing art is a content gap, not a broken
## colony.
@export var icon: Texture2D

## Which raw good this colony produces - a ResourceDef id.
@export var resource_id: StringName = &""

## This tier's position on the value curve, 0-7 (Tidewater Landing/timber is
## always 0). Used only to pick which tier a colony slot cycles to next
## (Colonies.found()) - no longer doubles as physical distance (rework task
## "randomized map": that's real, generated, and lives on the colony slot
## instead - see Colony's class doc).
@export var order: int = 0

## True only for Tidewater Landing. The Capital is where every other
## colony's goods arrive, where selling and crafting happen, and it starts
## already founded.
@export var is_capital: bool = false

## This colony's own base production/cargo/speed, before any upgrade level or
## colonist is applied (Balance.gd's formulas combine these with a Colony's
## purchased levels). Given the same starting value across all eight colonies
## for now - they're per-colony fields specifically so each can be tuned
## individually later without a code change, not because they need to differ
## on day one. See docs/GODOT_PLAN.md's design realignment section: a colony
## produces and ships at this base rate with zero colonists assigned, staffing
## is a bonus on top, not a requirement.
@export_group("Base Stats")
@export var base_production_rate: float = 1.0
@export var base_cargo: float = 20.0
@export var base_speed: float = 1.0


func is_valid() -> bool:
	if id == &"" or resource_id == &"":
		return false
	if order < 0:
		return false
	if base_production_rate <= 0.0 or base_cargo <= 0.0 or base_speed <= 0.0:
		return false
	return true
