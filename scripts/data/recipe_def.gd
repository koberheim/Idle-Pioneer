## Content definition for a crafting recipe (replaces Unity's RecipeData
## ScriptableObject - see docs/GODOT_MIGRATION_ANALYSIS.md §B1).
##
## docs/GODOT_MIGRATION_ANALYSIS.md §B2: 7 of the 10 Unity recipes shipped with
## `inputs: []` - i.e. free output for nothing. is_valid() exists specifically so
## that mistake is a validation failure here (see Db.validate() / task D4) rather
## than a silent gameplay bug.
class_name RecipeDef
extends Resource

## Stable identifier. Must match the .tres filename (enforced by Db). Never
## reference a recipe by array index or file path - only this.
@export var id: StringName = &""

@export var display_name: String = ""
@export var inputs: Array[RecipeIngredient] = []
@export var output_id: StringName = &""
@export var output_amount: int = 1

## Seconds to craft one batch.
@export var craft_seconds: float = 5.0


## A recipe with no inputs, no output, or a malformed ingredient is not
## craftable - see the class doc above for why this exists.
func is_valid() -> bool:
	if inputs.is_empty():
		return false
	if output_id == &"":
		return false
	if output_amount <= 0:
		return false
	for ingredient: RecipeIngredient in inputs:
		if ingredient == null or not ingredient.is_valid():
			return false
	return true
