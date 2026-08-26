## One `{resource, amount}` line in a RecipeDef's input list. A small nested Resource
## instead of a bare Dictionary so the inspector gives a proper per-field editor
## (see docs/GODOT_PLAN.md task D2's implementation note).
class_name RecipeIngredient
extends Resource

@export var resource_id: StringName = &""
@export var amount: int = 1


func is_valid() -> bool:
	return resource_id != &"" and amount > 0
