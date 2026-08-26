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
	Game.crafting_stations.clear()
	Game.routes.clear()


func after_each() -> void:
	SaveSystem.delete_save()
	Game.run = null
	Game.meta = MetaState.new()
	Game.colonies.clear()
	Game.crafting_stations.clear()
	Game.routes.clear()


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
	Game.meta.liberty = 4
	Game.meta.lifetime_gold_earned = 900.0
	SaveSystem.save()
	Game.run = null
	Game.meta = MetaState.new()

	SaveSystem.load()
	assert_eq(Game.meta.liberty, 4)
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
	# is_capital isn't stored directly - it's re-derived from tier_id via
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
## upgrade levels or the colony's real (map-derived) coastal-ness.
func test_save_then_load_restores_all_three_upgrade_levels_and_route_type() -> void:
	# Force slot 1 coastal so this is deterministic regardless of the real
	# generated map's seed (rework task: randomized map).
	Game.run.colony_slots[1]["is_coastal"] = true
	var outpost := Colony.new(&"cape_harbour", &"slot_1")
	outpost.slot_index = 1
	outpost.is_coastal = true
	outpost.production_level = 3
	outpost.cargo_level = 2
	outpost.speed_level = 4
	Game.colonies.register(outpost)

	SaveSystem.save()
	Game.run = null
	Game.colonies.clear()

	SaveSystem.load()
	var restored: Colony = Game.colonies.get_colony(&"slot_1")
	assert_eq(restored.production_level, 3)
	assert_eq(restored.cargo_level, 2)
	assert_eq(restored.speed_level, 4)
	assert_eq(restored.route_type, Colony.RouteType.SEA)


func test_save_then_load_with_no_colonies_restores_an_empty_list() -> void:
	SaveSystem.save()
	Game.run = null

	SaveSystem.load()
	assert_eq(Game.colonies.all(), [] as Array[Colony])


## Proves an auto-craft toggle and a long-running craft's in-progress timer
## both survive a save/load - the exact scenario the "runs while offline,
## potentially hours/days" requirement depends on: the game must remember
## where a slow craft was, not just whether auto-craft was on.
func test_save_then_load_restores_auto_craft_toggle_and_cycle_progress() -> void:
	var station: CraftingStation = Game.crafting_stations.get_or_create(&"salt_cod_recipe")
	station.auto_craft = true
	station.cycle.accumulated = 1.75

	SaveSystem.save()
	Game.run = null
	Game.crafting_stations.clear()

	SaveSystem.load()
	var restored: CraftingStation = Game.crafting_stations.get_existing(&"salt_cod_recipe")
	assert_not_null(restored)
	assert_true(restored.auto_craft)
	assert_almost_eq(restored.cycle.accumulated, 1.75, 0.0001)


func test_save_then_load_restores_lifetime_gold_earned_this_run() -> void:
	Game.economy.add_gold(500.0)
	Game.economy.try_spend(200.0)  # spending must not undo this on reload either
	SaveSystem.save()
	Game.run = null

	SaveSystem.load()
	assert_almost_eq(Game.prestige.lifetime_gold_earned_this_run(), 500.0, 0.0001)


func test_save_then_load_restores_liberty_and_prestige_upgrade_levels() -> void:
	Game.meta.liberty = 12
	Game.meta.lifetime_liberty_earned = 20
	Game.meta.upgrades[&"industry"] = 2
	SaveSystem.save()
	Game.run = null
	Game.meta = MetaState.new()

	SaveSystem.load()
	assert_eq(Game.meta.liberty, 12)
	assert_eq(Game.meta.lifetime_liberty_earned, 20)
	assert_eq(Game.prestige.industry_level(), 2)


## Rework: typed colonist roster. Proves Influence, every colonist's type
## and level, and its assignment all survive a save/load intact.
func test_save_then_load_restores_the_colonist_roster_and_influence() -> void:
	Game.run.influence = 500.0
	var c: Colonist = Game.colonists.recruit(Colonist.Type.CARGO)
	Game.colonists.upgrade(c.id)
	Game.colonists.assign(c.id, &"slot_0")

	SaveSystem.save()
	Game.run = null

	SaveSystem.load()
	var restored: Colonist = Game.colonists.get_colonist(c.id)
	assert_not_null(restored)
	assert_eq(restored.type, Colonist.Type.CARGO)
	assert_eq(restored.level, 2)
	assert_eq(restored.assigned_colony_id, &"slot_0")
	assert_gt(Game.colonists.influence(), 0.0, "leftover Influence after recruiting/upgrading should survive too")


func test_save_then_load_restores_resource_routing() -> void:
	Game.routing.set_mode(&"timber", Game.routing.SELL)
	SaveSystem.save()
	Game.run = null

	SaveSystem.load()
	assert_eq(Game.routing.mode_for(&"timber"), Game.routing.SELL)
	assert_eq(Game.routing.mode_for(&"cod"), Game.routing.RESERVE, "an unset resource should still default correctly")


func test_save_then_load_restores_started_at_unix() -> void:
	var stamped: int = Game.run.started_at_unix
	SaveSystem.save()
	Game.run = null

	SaveSystem.load()
	assert_eq(Game.run.started_at_unix, stamped)


func test_save_then_load_restores_recipes_ever_unlocked_and_stats() -> void:
	Game.inventory.add(&"timber", 2.0)
	Crafting.craft(&"lumber_recipe")
	Game.meta.stats["best_run_gold"] = 4200.0
	SaveSystem.save()
	Game.run = null
	Game.meta = MetaState.new()

	SaveSystem.load()
	assert_has(Game.meta.recipes_ever_unlocked, &"lumber_recipe")
	assert_almost_eq(Game.meta.stats["best_run_gold"], 4200.0, 0.0001)


func test_save_then_load_with_no_workshops_restores_an_empty_list() -> void:
	SaveSystem.save()
	Game.run = null

	SaveSystem.load()
	assert_eq(Game.crafting_stations.all(), [] as Array[CraftingStation])


func test_save_then_load_restores_a_routes_in_flight_state() -> void:
	var capital := Colony.new(&"tidewater_landing")
	var outpost := Colony.new(&"cape_harbour")
	# Nonzero distance so the round trip takes measurable time instead of
	# completing instantly within one tick (distance defaults to 0.0 now -
	# rework task: randomized map).
	outpost.distance_cells = 1.0
	outpost.local_stock[&"cod"] = 5.0
	Game.colonies.register(capital)
	Game.colonies.register(outpost)
	Game.routes.tick(0.001)  # syncs the route into existence and departs

	var before: Route = Game.routes.for_colony(&"cape_harbour")
	var leg_before: float = before.leg_elapsed
	var cargo_before: float = before.cargo.get(&"cod", 0.0)

	SaveSystem.save()
	Game.run = null
	Game.colonies.clear()
	Game.routes.clear()

	SaveSystem.load()
	var restored: Route = Game.routes.for_colony(&"cape_harbour")
	assert_not_null(restored)
	assert_eq(restored.state, Route.State.TRAVELING_TO_HUB)
	assert_almost_eq(restored.leg_elapsed, leg_before, 0.01)
	assert_almost_eq(restored.cargo.get(&"cod", 0.0), cargo_before, 0.0001)


## The offline-catch-up requirement: reloading after real time has passed
## should fast-forward production by that much, in one load() call, not
## require the game to have been open the whole time.
func test_load_applies_offline_catch_up_to_colony_production() -> void:
	Game.colonies.register(Colony.new(&"tidewater_landing"))
	SaveSystem.save()
	_rewrite_saved_at_unix(Time.get_unix_time_from_system() - 10)
	Game.run = null
	Game.colonies.clear()

	SaveSystem.load()
	assert_almost_eq(Game.inventory.get_amount(&"timber"), 10.0, 0.5, "10s offline at base rate 1.0/s")


func test_load_offline_catch_up_is_capped_at_the_configured_maximum() -> void:
	Game.colonies.register(Colony.new(&"tidewater_landing"))
	SaveSystem.save()
	_rewrite_saved_at_unix(Time.get_unix_time_from_system() - 999_999_999)
	Game.run = null
	Game.colonies.clear()

	SaveSystem.load()
	assert_almost_eq(Game.inventory.get_amount(&"timber"), Balance.offline_catch_up_cap_seconds(), 1.0)


func test_load_with_a_fresh_save_applies_negligible_catch_up() -> void:
	Game.colonies.register(Colony.new(&"tidewater_landing"))
	SaveSystem.save()
	Game.run = null
	Game.colonies.clear()

	SaveSystem.load()
	assert_lt(Game.inventory.get_amount(&"timber"), 1.0, "essentially no real time passed between save and load")


func _rewrite_saved_at_unix(new_value: int) -> void:
	var file: FileAccess = FileAccess.open(SaveSystem.SAVE_PATH, FileAccess.READ)
	var data: Dictionary = JSON.parse_string(file.get_as_text())
	file.close()
	data["saved_at_unix"] = new_value
	var out_file: FileAccess = FileAccess.open(SaveSystem.SAVE_PATH, FileAccess.WRITE)
	out_file.store_string(JSON.stringify(data))
	out_file.close()
