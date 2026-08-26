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
	assert_has(ids, &"lumber")


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
