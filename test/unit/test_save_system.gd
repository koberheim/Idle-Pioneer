## Tests for SaveSystem (task S1). These tests write to the real user://
## save file location (there's no practical way around that for a file-system
## test), so before_each/after_each always delete it - both to keep tests from
## leaking into each other and so this test run never leaves a stray save file
## behind on the machine it runs on.
extends GutTest


func before_each() -> void:
	SaveSystem.delete_save()
	Game.new_run(&"mvp_coast")
	Game.meta = MetaState.new()
	Game.colonies.clear()


func after_each() -> void:
	SaveSystem.delete_save()
	Game.run = null
	Game.meta = MetaState.new()
	Game.colonies.clear()


func test_has_save_is_false_with_no_file() -> void:
	assert_false(SaveSystem.has_save())


func test_save_fails_with_no_active_run() -> void:
	Game.run = null
	assert_false(SaveSystem.save())
	assert_false(SaveSystem.has_save(), "a failed save must not create a file")


func test_save_creates_a_file_and_has_save_reflects_it() -> void:
	var ok: bool = SaveSystem.save()
	assert_true(ok)
	assert_true(SaveSystem.has_save())


func test_save_leaves_no_leftover_temp_file() -> void:
	SaveSystem.save()
	assert_false(FileAccess.file_exists(SaveSystem.TMP_PATH))


func test_delete_save_removes_the_file() -> void:
	SaveSystem.save()
	SaveSystem.delete_save()
	assert_false(SaveSystem.has_save())


func test_load_of_missing_file_returns_false() -> void:
	assert_false(SaveSystem.load())


## "Missing file -> clean first-launch" from docs/GODOT_PLAN.md task S1: a
## missing save is not an error and must not disturb whatever state already
## exists in memory - it's the caller's job (task V1, later) to start a fresh
## run when load() reports false.
func test_load_of_missing_file_does_not_touch_existing_game_state() -> void:
	Game.economy.add_gold(42.0)
	SaveSystem.load()
	assert_almost_eq(Game.economy.gold, 42.0, 0.0001)


func test_load_of_corrupt_file_returns_false_without_crashing() -> void:
	var file: FileAccess = FileAccess.open(SaveSystem.SAVE_PATH, FileAccess.WRITE)
	file.store_string("{ this is not valid json ]]]")
	file.close()

	assert_false(SaveSystem.load())


func test_load_of_corrupt_file_does_not_touch_existing_game_state() -> void:
	Game.economy.add_gold(42.0)
	var file: FileAccess = FileAccess.open(SaveSystem.SAVE_PATH, FileAccess.WRITE)
	file.store_string("{ this is not valid json ]]]")
	file.close()

	SaveSystem.load()
	assert_almost_eq(Game.economy.gold, 42.0, 0.0001, "a failed load must not corrupt in-memory state")


func test_save_file_is_readable_text_not_a_binary_blob() -> void:
	Game.economy.add_gold(10.0)
	SaveSystem.save()

	var file: FileAccess = FileAccess.open(SaveSystem.SAVE_PATH, FileAccess.READ)
	var text: String = file.get_as_text()
	file.close()

	assert_string_contains(text, "save_version")
	assert_string_contains(text, "\"gold\": 10")


func test_save_then_load_restores_gold() -> void:
	Game.economy.add_gold(123.0)
	SaveSystem.save()
	Game.run = null

	SaveSystem.load()
	assert_almost_eq(Game.economy.gold, 123.0, 0.0001)


func test_save_then_load_restores_inventory() -> void:
	Game.inventory.add(&"timber", 8.0)
	Game.inventory.add(&"clay", 3.0)
	SaveSystem.save()
	Game.run = null

	SaveSystem.load()
	assert_almost_eq(Game.inventory.get_amount(&"timber"), 8.0, 0.0001)
	assert_almost_eq(Game.inventory.get_amount(&"clay"), 3.0, 0.0001)


func test_save_then_load_restores_purchased_upgrades() -> void:
	Game.economy.add_gold(50.0)
	Game.progression.purchase(&"primitive_tools")
	SaveSystem.save()
	Game.run = null

	SaveSystem.load()
	assert_true(Game.progression.is_purchased(&"primitive_tools"))
	assert_almost_eq(Game.progression.production_multiplier(), 1.25, 0.0001)


func test_save_then_load_restores_meta_across_a_run_reset() -> void:
	Game.meta.doubloons = 4
	Game.meta.lifetime_gold_earned = 900.0
	SaveSystem.save()
	Game.run = null
	Game.meta = MetaState.new()

	SaveSystem.load()
	assert_eq(Game.meta.doubloons, 4)
	assert_almost_eq(Game.meta.lifetime_gold_earned, 900.0, 0.0001)


func test_save_then_load_restores_colonies_with_correct_ids_and_capital_flag() -> void:
	var capital := Colony.new(&"tidewater_landing")
	var outpost := Colony.new(&"cape_harbour")
	Game.colonies.register(capital)
	Game.colonies.register(outpost)

	SaveSystem.save()
	Game.run = null
	Game.colonies.clear()

	SaveSystem.load()
	var restored: Array[Colony] = Game.colonies.all()
	assert_eq(restored.size(), 2)

	var by_id: Dictionary = {}
	for c: Colony in restored:
		by_id[c.colony_id] = c
	# is_capital isn't stored directly - it's re-derived from colony_id via
	# ColonyDef on restore (see RunState's class doc), so this also proves
	# that derivation actually happens on load, not just that the id survived.
	assert_true((by_id[&"tidewater_landing"] as Colony).is_capital)
	assert_false((by_id[&"cape_harbour"] as Colony).is_capital)


func test_save_then_load_restores_colony_local_stock() -> void:
	var outpost := Colony.new(&"cape_harbour")
	outpost.local_stock[&"cod"] = 6.0
	Game.colonies.register(outpost)

	SaveSystem.save()
	Game.run = null
	Game.colonies.clear()

	SaveSystem.load()
	var restored: Colony = Game.colonies.all()[0]
	assert_almost_eq(restored.local_stock.get(&"cod", 0.0), 6.0, 0.0001)


## Proves a save/load doesn't quietly discard any of the three purchased
## upgrade levels or the colony's rolled land/sea route type.
func test_save_then_load_restores_all_three_upgrade_levels_and_route_type() -> void:
	var outpost := Colony.new(&"cape_harbour")
	outpost.production_level = 3
	outpost.cargo_level = 2
	outpost.speed_level = 4
	outpost.route_type = Colony.RouteType.SEA
	Game.colonies.register(outpost)

	SaveSystem.save()
	Game.run = null
	Game.colonies.clear()

	SaveSystem.load()
	var restored: Colony = Game.colonies.all()[0]
	assert_eq(restored.production_level, 3)
	assert_eq(restored.cargo_level, 2)
	assert_eq(restored.speed_level, 4)
	assert_eq(restored.route_type, Colony.RouteType.SEA)


func test_save_then_load_with_no_colonies_restores_an_empty_list() -> void:
	SaveSystem.save()
	Game.run = null

	SaveSystem.load()
	assert_eq(Game.colonies.all(), [] as Array[Colony])
