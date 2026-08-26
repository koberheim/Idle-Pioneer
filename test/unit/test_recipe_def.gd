## Tests for RecipeDef.is_valid() (task D2).
extends GutTest


func _make_ingredient(resource_id: StringName, amount: int) -> RecipeIngredient:
	var ing := RecipeIngredient.new()
	ing.resource_id = resource_id
	ing.amount = amount
	return ing


func _make_valid_recipe() -> RecipeDef:
	var r := RecipeDef.new()
	r.id = &"lumber_recipe"
	r.output_id = &"lumber"
	r.output_amount = 1
	r.inputs = [_make_ingredient(&"timber", 2)]
	return r


func test_valid_recipe_is_valid() -> void:
	assert_true(_make_valid_recipe().is_valid())


func test_empty_inputs_is_invalid() -> void:
	# This is the exact Unity bug (GODOT_MIGRATION_ANALYSIS.md §B2): 7 of 10
	# shipped recipes had `inputs: []`, making crafting free.
	var r: RecipeDef = _make_valid_recipe()
	r.inputs = []
	assert_false(r.is_valid())


func test_empty_output_id_is_invalid() -> void:
	var r: RecipeDef = _make_valid_recipe()
	r.output_id = &""
	assert_false(r.is_valid())


func test_zero_output_amount_is_invalid() -> void:
	var r: RecipeDef = _make_valid_recipe()
	r.output_amount = 0
	assert_false(r.is_valid())


func test_negative_output_amount_is_invalid() -> void:
	var r: RecipeDef = _make_valid_recipe()
	r.output_amount = -1
	assert_false(r.is_valid())


func test_ingredient_with_empty_resource_id_is_invalid() -> void:
	var r: RecipeDef = _make_valid_recipe()
	r.inputs = [_make_ingredient(&"", 2)]
	assert_false(r.is_valid())


func test_ingredient_with_zero_amount_is_invalid() -> void:
	var r: RecipeDef = _make_valid_recipe()
	r.inputs = [_make_ingredient(&"timber", 0)]
	assert_false(r.is_valid())


func test_one_bad_ingredient_among_good_ones_invalidates_the_whole_recipe() -> void:
	var r: RecipeDef = _make_valid_recipe()
	r.inputs = [_make_ingredient(&"timber", 2), _make_ingredient(&"clay", 0)]
	assert_false(r.is_valid())


func test_multiple_valid_ingredients_is_valid() -> void:
	var r: RecipeDef = _make_valid_recipe()
	r.inputs = [_make_ingredient(&"timber", 2), _make_ingredient(&"clay", 1)]
	assert_true(r.is_valid())
