## Content definition for a purchasable upgrade (replaces Unity's ResearchData
## ScriptableObject, drastically simplified for the MVP - see
## docs/GODOT_MIGRATION_ANALYSIS.md §B1, §7 for the full 63-node tree this will
## eventually grow towards; Phase 7 scopes MVP to exactly one upgrade).
##
## `effect` is a StringName, not an enum, and that is a deliberate departure from
## ResourceDef.category. docs/GODOT_MIGRATION_ANALYSIS.md §B4 is the reason: Unity
## stored ResearchData.effectType as a raw enum ordinal, and a single reorder
## silently repointed Research_TradingPosts from "unlock auto-sell" to `Custom`.
## An @export enum in Godot serializes to a .tres exactly the same way an int would
## in Unity - so effect keys, which are far more likely to be extended and
## reordered during MVP iteration than ResourceDef.category ever was, use a string
## key instead. See docs/CONVENTIONS.md "Content and cross-reference IDs."
class_name UpgradeDef
extends Resource

## Known effect keys. Not an enforced enum - documentation for what
## task P5 (Progression) knows how to interpret. Add to this list, don't renumber
## anything, when a new effect type is needed.
const EFFECT_GLOBAL_PRODUCTION_MULTIPLIER: StringName = &"global_production_multiplier"

## Stable identifier. Must match the .tres filename (enforced by Db). Never
## reference an upgrade by array index or file path - only this.
@export var id: StringName = &""

@export var display_name: String = ""
@export_multiline var description: String = ""

## Optional - same pattern as ResourceDef.icon/ColonyDef.icon. Not required
## by is_valid(): missing art is a content gap, not a broken upgrade.
@export var icon: Texture2D

@export var gold_cost: int = 0
@export var resource_costs: Array[RecipeIngredient] = []

## Other upgrades that must already be purchased before this one is available.
@export var prerequisite_ids: Array[StringName] = []

## One of the EFFECT_* constants above.
@export var effect: StringName = &""

## Meaning depends on `effect` - e.g. for EFFECT_GLOBAL_PRODUCTION_MULTIPLIER,
## the multiplier itself (1.25 = +25%).
@export var magnitude: float = 1.0


func is_valid() -> bool:
	if id == &"" or effect == &"":
		return false
	if gold_cost < 0:
		return false
	for cost: RecipeIngredient in resource_costs:
		if cost == null or not cost.is_valid():
			return false
	return true
