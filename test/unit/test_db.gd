## Tests for the Db content registry (task D4).
##
## Db is an autoload, so it has already scanned res://data/ by the time any test
## runs - the "real data" assertions below check the live res://data/resources/
## content. The bad-data assertions point Db's internal directory-evaluation logic
## at throwaway fixtures under test/helpers/fixtures/ instead, so a deliberately
## broken file never has to live in res://data/ itself.
extends GutTest

const FIXTURES: String = "res://test/helpers/fixtures/"


func test_real_resource_data_has_no_problems() -> void:
	assert_eq(Db.validate(), [] as Array[String], "res://data/resources/ should be clean")


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
