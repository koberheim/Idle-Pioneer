## Tests for the CraftingStations registry - mirrors test_colonies.gd's
## register/tick fan-out coverage. Game.crafting_stations is a live autoload
## child, so before_each/after_each clear it explicitly.
extends GutTest


func before_each() -> void:
	Game.new_run(&"mvp_coast")
	Game.crafting_stations.clear()


func after_each() -> void:
	Game.crafting_stations.clear()
	Game.run = null


func test_get_or_create_returns_the_same_station_on_repeated_calls() -> void:
	var a: CraftingStation = Game.crafting_stations.get_or_create(&"salt_cod_recipe")
	var b: CraftingStation = Game.crafting_stations.get_or_create(&"salt_cod_recipe")
	assert_eq(a, b)


func test_get_existing_returns_null_before_creation() -> void:
	assert_null(Game.crafting_stations.get_existing(&"salt_cod_recipe"))


func test_all_lists_every_created_station() -> void:
	Game.crafting_stations.get_or_create(&"salt_cod_recipe")
	Game.crafting_stations.get_or_create(&"tools_recipe")
	assert_eq(Game.crafting_stations.all().size(), 2)


func test_tick_fans_out_to_every_created_station() -> void:
	Game.inventory.add(&"cod", 3.0)
	var station: CraftingStation = Game.crafting_stations.get_or_create(&"salt_cod_recipe")
	station.auto_craft = true

	Game.crafting_stations.tick(2.5)

	assert_almost_eq(Game.inventory.get_amount(&"salt_cod"), 1.0, 0.0001)


func test_clear_empties_the_registry() -> void:
	Game.crafting_stations.get_or_create(&"salt_cod_recipe")
	Game.crafting_stations.clear()
	assert_eq(Game.crafting_stations.all().size(), 0)


func test_new_run_clears_crafting_stations() -> void:
	Game.crafting_stations.get_or_create(&"salt_cod_recipe")
	Game.new_run(&"mvp_coast")
	assert_eq(Game.crafting_stations.all().size(), 0)
