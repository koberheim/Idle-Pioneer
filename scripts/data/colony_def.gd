## Content definition for one of the game's eight fixed colonies (see
## docs/GAME_DESIGN.md §5 - "Colonies"). This replaces RegionDef for content
## going forward: the design is a fixed, named, ordered table (eight specific
## places, each with one specific resource, at a fixed one-time cost), not a
## flexible placement system. RegionDef and the land/water map it depended on
## are left in place unused rather than deleted - see docs/GODOT_PLAN.md's
## design realignment section for why.
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

## Which raw good this colony produces - a ResourceDef id.
@export var resource_id: StringName = &""

## Fixed play order, 0-7. Tidewater Landing (the Capital) is always 0.
## Doubles as the "distance" figure in docs/GAME_DESIGN.md §5/§6 - the design
## table gives every colony a distance equal to its position in the list, so
## there is no separate distance field to drift out of sync with order.
@export var order: int = 0

## One-time coin cost to found this colony - a fixed number from the table
## (§5), not a computed curve. Zero for the Capital, which starts founded.
@export var unlock_cost: float = 0.0

## True only for Tidewater Landing. The Capital is where every other
## colony's goods arrive, where selling and crafting happen, and it starts
## already founded.
@export var is_capital: bool = false


func is_valid() -> bool:
	if id == &"" or resource_id == &"":
		return false
	if order < 0 or unlock_cost < 0.0:
		return false
	return true
