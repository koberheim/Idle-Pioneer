## Tests for Crafting (task P4). Uses the real lumber_recipe (task D5: 2
## timber -> 1 lumber) for the id-based public API, and hand-built RecipeDef
## objects for the atomicity edge case that no real fixture needs to exist for.
extends GutTest


func before_each() -> void:
	Game.new_run(&"mvp_coast")


func after_each() -> void:
	Game.run = null


func _make_ingredient(resource_id: StringName, amount: int) -> RecipeIngredient:
	var ing := RecipeIngredient.new()
	ing.resource_id = resource_id
	ing.amount = amount
	return ing


func test_can_craft_true_with_enough_ingredients() -> void:
	Game.inventory.add(&"timber", 2.0)
	assert_true(Crafting.can_craft(&"lumber_recipe"))


func test_can_craft_false_with_insufficient_ingredients() -> void:
	Game.inventory.add(&"timber", 1.0)
	assert_false(Crafting.can_craft(&"lumber_recipe"))


func test_can_craft_false_with_no_ingredients() -> void:
	assert_false(Crafting.can_craft(&"lumber_recipe"))


func test_can_craft_false_for_unknown_recipe_id() -> void:
	assert_false(Crafting.can_craft(&"does_not_exist"))


func test_craft_consumes_inputs_and_produces_output() -> void:
	Game.inventory.add(&"timber", 2.0)
	var ok: bool = Crafting.craft(&"lumber_recipe")
	assert_true(ok)
	assert_almost_eq(Game.inventory.get_amount(&"timber"), 0.0, 0.0001)
	assert_almost_eq(Game.inventory.get_amount(&"lumber"), 1.0, 0.0001)


func test_craft_only_consumes_exactly_what_the_recipe_needs() -> void:
	Game.inventory.add(&"timber", 5.0)
	Crafting.craft(&"lumber_recipe")
	assert_almost_eq(Game.inventory.get_amount(&"timber"), 3.0, 0.0001, "should consume 2, leaving 3")


func test_craft_fails_cleanly_with_insufficient_ingredients_and_consumes_nothing() -> void:
	Game.inventory.add(&"timber", 1.0)  # recipe needs 2
	var ok: bool = Crafting.craft(&"lumber_recipe")
	assert_false(ok)
	assert_almost_eq(Game.inventory.get_amount(&"timber"), 1.0, 0.0001, "a failed craft must not touch stock")
	assert_almost_eq(Game.inventory.get_amount(&"lumber"), 0.0, 0.0001)


func test_craft_of_unknown_recipe_id_returns_false() -> void:
	assert_false(Crafting.craft(&"does_not_exist"))


## The exact Unity bug this whole system exists to prevent (docs/GODOT_MIGRATION_ANALYSIS.md
## §B2): a recipe with no inputs must never be craftable. Db already refuses to
## load such a recipe at all (task D2's Db integration), so it can never even
## be looked up by id here - this exercises can_craft_recipe/craft_recipe
## directly against a hand-built RecipeDef to prove Crafting's own defense
## doesn't depend on Db having already filtered it out.
func test_recipe_with_empty_inputs_is_never_craftable() -> void:
	var free_lunch := RecipeDef.new()
	free_lunch.id = &"free_lunch"
	free_lunch.inputs = []
	free_lunch.output_id = &"gold_bars"
	free_lunch.output_amount = 999

	assert_false(Crafting.can_craft_recipe(free_lunch))
	assert_false(Crafting.craft_recipe(free_lunch))
	# "gold_bars" isn't a real ResourceDef, so checking it via get_amount would
	# just trip Inventory's own unknown-id error for an unrelated reason - the
	# actual claim here is nothing was produced at all.
	assert_true(Game.inventory.all().is_empty())


## The atomicity edge case documented on Crafting._required_totals(): a recipe
## that lists the same resource_id across two separate ingredient rows must
## still be checked and consumed as one aggregated total, not per-row (which
## could pass two independent checks against the same stock and then fail
## partway through consuming).
func test_duplicate_ingredient_rows_are_aggregated_not_double_counted() -> void:
	var recipe := RecipeDef.new()
	recipe.id = &"double_timber"
	recipe.inputs = [_make_ingredient(&"timber", 2), _make_ingredient(&"timber", 2)]  # needs 4 total
	recipe.output_id = &"lumber"
	recipe.output_amount = 1

	Game.inventory.add(&"timber", 3.0)  # enough for one row alone, not both
	assert_false(Crafting.can_craft_recipe(recipe), "3 timber is not enough for a 4-timber requirement")

	Game.inventory.add(&"timber", 1.0)  # now 4 total
	assert_true(Crafting.can_craft_recipe(recipe))

	var ok: bool = Crafting.craft_recipe(recipe)
	assert_true(ok)
	assert_almost_eq(Game.inventory.get_amount(&"timber"), 0.0, 0.0001, "all 4 should be consumed, not left over")
	assert_almost_eq(Game.inventory.get_amount(&"lumber"), 1.0, 0.0001)
