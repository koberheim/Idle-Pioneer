## Content definition for a raw or processed resource (replaces Unity's ResourceData
## ScriptableObject - see docs/GODOT_MIGRATION_ANALYSIS.md §B1).
##
## Every instance lives as a .tres under res://data/resources/ and is loaded by Db.
## `id` is the only thing anything else should ever reference - see
## docs/CONVENTIONS.md "Content and cross-reference IDs" for why.
class_name ResourceDef
extends Resource

enum Category {
	BASIC,
	CROP,
	WOOD,
	ORE,
	TEXTILE,
	CASH_CROP,
	PRECIOUS_METAL,
	GEMSTONE,
	OCEAN,
	EXOTIC,
	ANCIENT,
	HERB,
	STONE,
	FUEL,
}

## Stable identifier. Must match the .tres filename (enforced by Db). Never
## reference a resource by array index, enum ordinal, or file path - only this.
@export var id: StringName = &""

@export var display_name: String = ""
@export var icon: Texture2D
@export var category: Category = Category.BASIC

## Gold value when sold, before any multiplier.
@export var base_value: float = 1.0

## True for a crafted/refined good (Unity's `isTradeGood`); false for a raw material.
@export var is_processed: bool = false

@export_multiline var description: String = ""
