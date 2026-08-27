## Tests for the Db content registry (task D4; D5 extends the assertions below
## once the real MVP content - resources, a recipe, regions, an upgrade - exists
## to check against).
##
## Db is an autoload, so it has already scanned res://data/ by the time any test
## runs - the "real data" assertions below check the live res://data/ content.
## The bad-data assertions point Db's internal directory-evaluation logic at
## throwaway fixtures under test/helpers/fixtures/ instead, so a deliberately
## broken file never has to live in res://data/ itself.
extends GutTest

const FIXTURES: String = "res://test/helpers/fixtures/"


func test_real_data_has_no_problems_across_every_collection() -> void:
	assert_eq(Db.validate(), [] as Array[String], "res://data/ should be clean")


func test_resource_lookup_returns_a_resource_def() -> void:
	var timber: ResourceDef = Db.resource(&"timber")
	assert_not_null(timber)
	assert_eq(timber.id, &"timber")
	assert_eq(timber.display_name, "Timber")


func test_resource_lookup_of_missing_id_returns_null() -> void:
	assert_null(Db.resource(&"does_not_exist"))


func test_all_resources_includes_known_ids() -> void:
	var ids: Array[StringName] = []
	for def: ResourceDef in Db.all_resources():
		ids.append(def.id)
	assert_has(ids, &"timber")
	assert_has(ids, &"clay")


func test_all_upgrades_includes_known_ids() -> void:
	var ids: Array[StringName] = []
	for def: UpgradeDef in Db.all_upgrades():
		ids.append(def.id)
	assert_has(ids, &"primitive_tools")


func test_all_recipes_includes_known_ids_sorted_by_craft_seconds() -> void:
	var recipes: Array[RecipeDef] = Db.all_recipes()
	var ids: Array[StringName] = []
	for def: RecipeDef in recipes:
		ids.append(def.id)
	assert_has(ids, &"planks_recipe")
	assert_has(ids, &"muskets_recipe")

	for i in range(1, recipes.size()):
		assert_true(
			recipes[i - 1].craft_seconds <= recipes[i].craft_seconds,
			"expected ascending craft_seconds order"
		)


## The rest of this block is task D5: proving the authored MVP content is
## actually reachable through Db, not just that validate() finds no problems
## with it (a file with no id can't be "invalid" if it was never scanned at all).
func test_recipe_lookup_returns_the_lumber_recipe() -> void:
	var recipe: RecipeDef = Db.recipe(&"lumber_recipe")
	assert_not_null(recipe)
	assert_eq(recipe.output_id, &"lumber")
	assert_eq(recipe.inputs.size(), 1)
	assert_eq(recipe.inputs[0].resource_id, &"timber")
	assert_eq(recipe.inputs[0].amount, 2)


func test_region_lookup_returns_a_region_def() -> void:
	var region: RegionDef = Db.region(&"harbor_point")
	assert_not_null(region)
	assert_eq(region.cell, Vector2i(9, 0))
	assert_eq(region.deposit_id, &"timber")


func test_all_six_mvp_regions_are_loaded() -> void:
	for id: StringName in [
		&"harbor_point", &"clay_flats", &"pine_ridge",
		&"coastal_clay", &"island_outpost", &"riverside",
	]:
		assert_not_null(Db.region(id), "missing region: %s" % id)


func test_upgrade_lookup_returns_primitive_tools() -> void:
	var upgrade: UpgradeDef = Db.upgrade(&"primitive_tools")
	assert_not_null(upgrade)
	assert_eq(upgrade.gold_cost, 50)
	assert_eq(upgrade.effect, UpgradeDef.EFFECT_GLOBAL_PRODUCTION_MULTIPLIER)
	assert_almost_eq(upgrade.magnitude, 1.25, 0.0001)


## Every authored region must sit on a legal site on the map it's meant for -
## this is what task M5 will make Db enforce automatically; for now (before M5
## wires that check into Db itself) this test catches the same class of mistake
## by construction, using the actual map file rather than trusting the
## coordinates typed into each .tres by eye.
func test_every_mvp_region_sits_on_a_valid_colony_site() -> void:
	var grid: MapGrid = MapLoader.from_file("res://data/maps/mvp_coast.txt")
	assert_not_null(grid)
	for def: RegionDef in [
		Db.region(&"harbor_point"), Db.region(&"clay_flats"), Db.region(&"pine_ridge"),
		Db.region(&"coastal_clay"), Db.region(&"island_outpost"), Db.region(&"riverside"),
	]:
		assert_true(
			PlacementRules.is_valid_colony_site(grid, def.cell),
			"%s at %s is not on land or coast" % [def.id, def.cell]
		)


func test_mvp_regions_include_both_coastal_and_inland_sites() -> void:
	# Phase 7 explicitly calls for both, since that contrast is what makes the
	# land/water layer a real placement decision rather than decoration.
	var grid: MapGrid = MapLoader.from_file("res://data/maps/mvp_coast.txt")
	var coastal_count := 0
	var inland_count := 0
	for def: RegionDef in [
		Db.region(&"harbor_point"), Db.region(&"clay_flats"), Db.region(&"pine_ridge"),
		Db.region(&"coastal_clay"), Db.region(&"island_outpost"), Db.region(&"riverside"),
	]:
		if grid.is_coast(def.cell):
			coastal_count += 1
		else:
			inland_count += 1
	assert_gt(coastal_count, 0, "expected at least one coastal region")
	assert_gt(inland_count, 0, "expected at least one inland region")


## Task M5's own guard rail, tested directly: a region placed on water must be
## rejected, with a message naming both the region and the cell. Uses a fixture
## whose cell (23, 0) was ground-truthed as deep water on the real
## data/maps/mvp_coast.txt map (Db validates region placement against that one
## map - see Db.MAP_PATH - so a fixture-only map can't be substituted here).
func test_region_on_water_is_rejected_with_a_message_naming_region_and_cell() -> void:
	var result: Dictionary = Db._evaluate_directory(FIXTURES + "db_region_on_water/")
	assert_eq((result.problems as Array).size(), 0, "the fixture itself should pass id/is_valid checks")

	var placement_problems: Array[String] = Db._placement_problems(result.valid)
	assert_eq(placement_problems.size(), 1)
	assert_string_contains(placement_problems[0], "sunken_outpost")
	assert_string_contains(placement_problems[0], "(23, 0)")


func test_region_is_coastal_reflects_the_map() -> void:
	assert_true(Db.region_is_coastal(&"harbor_point"))
	assert_false(Db.region_is_coastal(&"clay_flats"))


func test_map_grid_returns_the_real_mvp_map() -> void:
	var grid: MapGrid = Db.map_grid()
	assert_not_null(grid)
	assert_eq(grid.width, 24)
	assert_eq(grid.height, 16)


func test_valid_fixture_loads_with_no_problems() -> void:
	var result: Dictionary = Db._evaluate_directory(FIXTURES + "db_valid/")
	assert_eq((result.problems as Array).size(), 0)
	assert_true((result.valid as Dictionary).has(&"widget"))


func test_duplicate_id_is_reported_and_excluded() -> void:
	var result: Dictionary = Db._evaluate_directory(FIXTURES + "db_duplicate/")
	var problems: Array = result.problems
	var valid: Dictionary = result.valid

	var has_duplicate_problem := false
	for p: String in problems:
		if p.contains("duplicate id"):
			has_duplicate_problem = true
	assert_true(has_duplicate_problem, "expected a duplicate-id problem, got: %s" % [problems])

	# The second entry to claim the id loses - only one "a" survives, and it's
	# never both: a colliding entry is excluded from `valid` entirely.
	assert_true(valid.has(&"a"))
	assert_eq(valid.size(), 1)


func test_empty_id_is_reported_and_excluded() -> void:
	var result: Dictionary = Db._evaluate_directory(FIXTURES + "db_empty_id/")
	var problems: Array = result.problems
	assert_eq((result.valid as Dictionary).size(), 0)

	var has_empty_problem := false
	for p: String in problems:
		if p.contains("empty id"):
			has_empty_problem = true
	assert_true(has_empty_problem, "expected an empty-id problem, got: %s" % [problems])


func test_mismatched_id_is_reported_and_excluded() -> void:
	var result: Dictionary = Db._evaluate_directory(FIXTURES + "db_mismatched_id/")
	var problems: Array = result.problems
	assert_eq((result.valid as Dictionary).size(), 0)

	var has_mismatch_problem := false
	for p: String in problems:
		if p.contains("does not match filename"):
			has_mismatch_problem = true
	assert_true(has_mismatch_problem, "expected a filename-mismatch problem, got: %s" % [problems])


func test_missing_directory_yields_empty_result_not_a_crash() -> void:
	var result: Dictionary = Db._evaluate_directory(FIXTURES + "does_not_exist/")
	assert_eq((result.valid as Dictionary).size(), 0)
	assert_eq((result.problems as Array).size(), 0)


## Proves Db actually catches the Unity §B2 bug (a recipe with no inputs) rather
## than RecipeDef.is_valid() existing as dead code nobody calls - see
## docs/CONVENTIONS.md "No system without a caller."
func test_recipe_with_empty_inputs_is_rejected_by_db() -> void:
	var result: Dictionary = Db._evaluate_directory(FIXTURES + "db_invalid_recipe/")
	assert_eq((result.valid as Dictionary).size(), 0, "an invalid recipe must not be loaded")

	var problems: Array = result.problems
	var has_validation_problem := false
	for p: String in problems:
		if p.contains("failed content validation"):
			has_validation_problem = true
	assert_true(has_validation_problem, "expected a content-validation problem, got: %s" % [problems])


## Rework: real colony table (docs/GAME_DESIGN.md §5). Checks against the
## live res://data/colonies/ content, same as the resource lookups above.
func test_colony_lookup_returns_a_colony_def() -> void:
	var capital: ColonyDef = Db.colony(&"tidewater_landing")
	assert_not_null(capital)
	assert_eq(capital.resource_id, &"timber")
	assert_true(capital.is_capital)


func test_all_eight_colonies_are_loaded() -> void:
	for id: StringName in [
		&"tidewater_landing", &"cape_harbour", &"chesapeake_fields", &"carolina_flats",
		&"ironworks_hollow", &"indigo_reach", &"sugar_isle", &"northern_traces",
	]:
		assert_not_null(Db.colony(id), "missing colony: %s" % id)


func test_all_colonies_returns_them_in_fixed_play_order() -> void:
	var colonies: Array[ColonyDef] = Db.all_colonies()
	assert_eq(colonies.size(), 8)
	for i: int in range(colonies.size()):
		assert_eq(colonies[i].order, i, "colony at index %d should have order %d" % [i, i])
	assert_eq(colonies[0].id, &"tidewater_landing")
	assert_eq(colonies[7].id, &"northern_traces")


func test_capital_returns_tidewater_landing() -> void:
	var cap: ColonyDef = Db.capital()
	assert_not_null(cap)
	assert_eq(cap.id, &"tidewater_landing")


func test_each_colony_resource_id_resolves_to_a_real_resource() -> void:
	for def: ColonyDef in Db.all_colonies():
		assert_not_null(Db.resource(def.resource_id), "%s references unknown resource '%s'" % [def.id, def.resource_id])


func test_colony_prices_match_the_design_doc_table() -> void:
	var expected: Dictionary = {
		&"tidewater_landing": 1.0,
		&"cape_harbour": 4.0,
		&"chesapeake_fields": 14.0,
		&"carolina_flats": 45.0,
		&"ironworks_hollow": 150.0,
		&"indigo_reach": 480.0,
		&"sugar_isle": 1600.0,
		&"northern_traces": 5200.0,
	}
	for id: StringName in expected.keys():
		var def: ColonyDef = Db.colony(id)
		var res: ResourceDef = Db.resource(def.resource_id)
		assert_almost_eq(res.base_value, expected[id], 0.0001, "%s's resource price mismatch" % id)


## unlock_cost was removed from ColonyDef (rework task: randomized map) -
## founding cost is now a single per-slot formula (Balance.next_colony_slot_cost),
## checked directly against the design doc's real table in test_balance.gd's
## test_next_colony_slot_cost_matches_the_fitted_curve.


func test_duplicate_colony_order_is_reported() -> void:
	var result: Dictionary = Db._evaluate_directory(FIXTURES + "db_colony_duplicate_order/")
	var problems: Array[String] = Db._colony_table_problems(result.valid)
	var has_it := false
	for p: String in problems:
		if p.contains("already used by"):
			has_it = true
	assert_true(has_it, "expected a duplicate-order problem, got: %s" % [problems])


func test_missing_capital_is_reported() -> void:
	var result: Dictionary = Db._evaluate_directory(FIXTURES + "db_colony_no_capital/")
	var problems: Array[String] = Db._colony_table_problems(result.valid)
	var has_it := false
	for p: String in problems:
		if p.contains("no colony has is_capital"):
			has_it = true
	assert_true(has_it, "expected a missing-capital problem, got: %s" % [problems])


func test_multiple_capitals_is_reported() -> void:
	var result: Dictionary = Db._evaluate_directory(FIXTURES + "db_colony_two_capitals/")
	var problems: Array[String] = Db._colony_table_problems(result.valid)
	var has_it := false
	for p: String in problems:
		if p.contains("more than one colony"):
			has_it = true
	assert_true(has_it, "expected a multiple-capitals problem, got: %s" % [problems])


## Rework: real 10 recipes (docs/GAME_DESIGN.md §7).
func test_all_ten_new_recipes_are_loaded() -> void:
	for id: StringName in [
		&"planks_recipe", &"salt_cod_recipe", &"cigars_recipe", &"cloth_recipe",
		&"pig_iron_recipe", &"barrels_recipe", &"dyed_cloth_recipe", &"tools_recipe",
		&"rum_recipe", &"muskets_recipe",
	]:
		assert_not_null(Db.recipe(id), "missing recipe: %s" % id)


func test_recipe_sale_prices_match_the_design_doc_table() -> void:
	var expected: Dictionary = {
		&"planks": 4.0, &"salt_cod": 18.0, &"cigars": 70.0, &"cloth": 230.0,
		&"pig_iron": 520.0, &"barrels": 1400.0, &"dyed_cloth": 2700.0,
		&"tools": 4800.0, &"rum": 14000.0, &"muskets": 38000.0,
	}
	for id: StringName in expected.keys():
		var def: ResourceDef = Db.resource(id)
		assert_not_null(def, "missing crafted good: %s" % id)
		assert_almost_eq(def.base_value, expected[id], 0.01, "%s sale price mismatch" % id)


func test_barrels_recipe_consumes_crafted_goods_not_just_raw_ones() -> void:
	# Recipes 6-10 chain from other recipes' outputs (docs/GAME_DESIGN.md §7's
	# "the first genuinely interesting economic decision in the game").
	var recipe: RecipeDef = Db.recipe(&"barrels_recipe")
	var input_ids: Array[StringName] = []
	for ing: RecipeIngredient in recipe.inputs:
		input_ids.append(ing.resource_id)
	assert_has(input_ids, &"planks")
	assert_has(input_ids, &"pig_iron")
	assert_true(Db.resource(&"planks").is_processed)
	assert_true(Db.resource(&"pig_iron").is_processed)


## Proves the full raw-ore-to-Muskets chain actually works end to end through
## the crafting system as it exists today (on-demand, task P4) - Muskets is
## four crafting steps deep (Iron Ore -> Pig Iron -> Tools -> Muskets, plus
## Timber -> Planks feeding both Tools and Muskets), and this is the real
## content, not a synthetic fixture.
##
## Requirements worked out from the recipes themselves: 1 Muskets needs
## 2 Tools + 2 Planks. Each Tools needs 3 Pig Iron + 1 Planks, so 2 Tools need
## 6 Pig Iron + 2 Planks - plus the 2 Planks Muskets consumes directly, that's
## 4 Planks (= 8 Timber) and 6 Pig Iron (= 12 Iron Ore) in total.
func test_full_musket_chain_crafts_end_to_end() -> void:
	Game.new_run(&"mvp_coast")
	# Routing defaults to SELL and crafted output is routed through it too
	# (see test_crafting.gd's before_each) - every intermediate good in this
	# chain has to stay in inventory to feed the next step, not get sold.
	for id: StringName in [&"planks", &"pig_iron", &"tools", &"muskets"]:
		Game.routing.set_mode(id, Game.routing.RESERVE)

	Game.inventory.add(&"timber", 8.0)
	Game.inventory.add(&"iron_ore", 12.0)

	for i: int in range(4):
		assert_true(Crafting.craft(&"planks_recipe"), "planks batch %d" % i)
	assert_almost_eq(Game.inventory.get_amount(&"planks"), 4.0, 0.0001)

	for i: int in range(6):
		assert_true(Crafting.craft(&"pig_iron_recipe"), "pig iron batch %d" % i)
	assert_almost_eq(Game.inventory.get_amount(&"pig_iron"), 6.0, 0.0001)

	assert_true(Crafting.craft(&"tools_recipe"))
	assert_true(Crafting.craft(&"tools_recipe"))
	assert_almost_eq(Game.inventory.get_amount(&"tools"), 2.0, 0.0001)
	assert_almost_eq(Game.inventory.get_amount(&"pig_iron"), 0.0, 0.0001)
	assert_almost_eq(Game.inventory.get_amount(&"planks"), 2.0, 0.0001, "2 planks left over for muskets")

	assert_true(Crafting.craft(&"muskets_recipe"))
	assert_almost_eq(Game.inventory.get_amount(&"muskets"), 1.0, 0.0001)
	assert_almost_eq(Game.inventory.get_amount(&"tools"), 0.0, 0.0001)
	assert_almost_eq(Game.inventory.get_amount(&"planks"), 0.0, 0.0001)

	Game.run = null


## Direct request: 6 nations recovered from the Unity project's
## NationalityData assets (Assets/03_Data/Nationalities/*.asset) - see
## NationDef's class doc for the archaeology.
func test_all_six_nations_are_loaded() -> void:
	for id: StringName in [&"dutch", &"english", &"french", &"swedish", &"portuguese", &"spanish"]:
		assert_not_null(Db.nation(id), "missing nation: %s" % id)


func test_all_nations_returns_six_sorted_by_display_name() -> void:
	var nations: Array[NationDef] = Db.all_nations()
	assert_eq(nations.size(), 6)
	for i in range(1, nations.size()):
		assert_true(
			nations[i - 1].display_name <= nations[i].display_name, "expected ascending display_name order"
		)


func test_each_nation_carries_exactly_its_own_original_bonus() -> void:
	var expected: Dictionary = {
		&"dutch": {"field": "extraction_rate_multiplier", "value": 1.15},
		&"english": {"field": "ship_speed_multiplier", "value": 1.1},
		&"french": {"field": "colony_cost_multiplier", "value": 0.8},
		&"swedish": {"field": "liberty_generation_multiplier", "value": 1.15},
		&"portuguese": {"field": "wagon_speed_multiplier", "value": 1.3},
		&"spanish": {"field": "gold_sell_multiplier", "value": 1.25},
	}
	var all_fields: Array[String] = [
		"ship_speed_multiplier", "wagon_speed_multiplier", "colony_cost_multiplier",
		"gold_sell_multiplier", "extraction_rate_multiplier", "liberty_generation_multiplier",
	]
	for id: StringName in expected.keys():
		var def: NationDef = Db.nation(id)
		var bonus_field: String = expected[id]["field"]
		for field: String in all_fields:
			var value: float = def.get(field)
			if field == bonus_field:
				assert_almost_eq(value, expected[id]["value"], 0.0001, "%s.%s" % [id, field])
			else:
				assert_almost_eq(value, 1.0, 0.0001, "%s.%s should be neutral" % [id, field])
