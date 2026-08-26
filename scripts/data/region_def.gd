## Content definition for a hand-authored placement site (task D3 - see
## docs/GODOT_PLAN.md Phase 7: MVP regions are hand-authored, not procedural).
##
## Deliberately has NO `is_coastal` field. The plan calls this out explicitly: a
## region's coastal-ness must be derived from the MapGrid it sits on (task M5,
## via PlacementRules), never authored a second time by hand - two independent
## sources of truth for the same fact is exactly how they drift apart. Ask
## `PlacementRules` (task M3) at load time instead of trusting a stored bool here.
class_name RegionDef
extends Resource

## Stable identifier. Must match the .tres filename (enforced by Db). Never
## reference a region by array index or file path - only this.
@export var id: StringName = &""

@export var display_name: String = ""

## Grid position on the map this region belongs to (task M2's MapGrid).
@export var cell: Vector2i = Vector2i.ZERO

## Which deposit this site produces. Empty means no deposit - a region with no
## deposit is not a valid colony site (see PlacementRules.is_valid_colony_site,
## task M3).
@export var deposit_id: StringName = &""

## Seconds per production cycle before any multiplier is applied.
@export var base_cycle_seconds: float = 5.0


func is_valid() -> bool:
	return id != &"" and deposit_id != &"" and base_cycle_seconds > 0.0
