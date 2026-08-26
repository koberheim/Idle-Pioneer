## Tests for CraftingStation (rework task: continuous crafting). Uses the
## real salt_cod_recipe (3 cod -> 1 salt_cod, craft_seconds 2.5) throughout.
extends GutTest


func before_each() -> void:
	Game.new_run(&"mvp_coast")


func after_each() -> void:
	Game.run = null


func test_craft_now_is_instant_and_ignores_auto_craft() -> void:
	Game.inventory.add(&"cod", 3.0)
	var station := CraftingStation.new(&"salt_cod_recipe")
	assert_true(station.craft_now())
	assert_almost_eq(Game.inventory.get_amount(&"salt_cod"), 1.0, 0.0001)
	assert_almost_eq(Game.inventory.get_amount(&"cod"), 0.0, 0.0001)


func test_craft_now_fails_without_enough_ingredients() -> void:
	var station := CraftingStation.new(&"salt_cod_recipe")
	assert_false(station.craft_now())


func test_tick_does_nothing_while_auto_craft_is_off() -> void:
	Game.inventory.add(&"cod", 300.0)
	var station := CraftingStation.new(&"salt_cod_recipe")
	station.tick(100.0)
	assert_almost_eq(Game.inventory.get_amount(&"salt_cod"), 0.0, 0.0001)


func test_tick_crafts_one_batch_per_completed_cycle() -> void:
	Game.inventory.add(&"cod", 9.0)
	var station := CraftingStation.new(&"salt_cod_recipe")
	station.auto_craft = true

	station.tick(2.5)  # exactly one cycle
	assert_almost_eq(Game.inventory.get_amount(&"salt_cod"), 1.0, 0.0001)

	station.tick(5.0)  # two more cycles
	assert_almost_eq(Game.inventory.get_amount(&"salt_cod"), 3.0, 0.0001)
	assert_almost_eq(Game.inventory.get_amount(&"cod"), 0.0, 0.0001)


## The core "hours or days" requirement: a single huge tick() must resolve
## instantly and correctly to as many crafts as ingredients allow, not loop
## second by second.
func test_tick_catches_up_a_long_offline_gap_in_one_call() -> void:
	Game.inventory.add(&"cod", 30.0)  # enough for 10 crafts
	var station := CraftingStation.new(&"salt_cod_recipe")
	station.auto_craft = true

	station.tick(3600.0)  # one hour >> far more than 10 cycles' worth of time

	assert_almost_eq(Game.inventory.get_amount(&"salt_cod"), 10.0, 0.0001)
	assert_almost_eq(Game.inventory.get_amount(&"cod"), 0.0, 0.0001)


func test_tick_halts_cleanly_when_ingredients_run_out_mid_catchup() -> void:
	Game.inventory.add(&"cod", 10.0)  # enough for 3 crafts (9 cod), 1 left over
	var station := CraftingStation.new(&"salt_cod_recipe")
	station.auto_craft = true

	station.tick(100.0)  # implies far more than 3 cycles

	assert_almost_eq(Game.inventory.get_amount(&"salt_cod"), 3.0, 0.0001)
	assert_almost_eq(Game.inventory.get_amount(&"cod"), 1.0, 0.0001)


## Once ingredients return, auto-craft should resume on its own - proving the
## halt above isn't a permanent stop.
func test_auto_craft_resumes_once_ingredients_are_available_again() -> void:
	Game.inventory.add(&"cod", 2.0)  # not enough for even one craft
	var station := CraftingStation.new(&"salt_cod_recipe")
	station.auto_craft = true

	station.tick(2.5)
	assert_almost_eq(Game.inventory.get_amount(&"salt_cod"), 0.0, 0.0001)

	Game.inventory.add(&"cod", 1.0)  # now enough
	station.tick(0.001)
	assert_almost_eq(Game.inventory.get_amount(&"salt_cod"), 1.0, 0.0001)


func test_manual_craft_now_works_independently_while_auto_craft_is_on() -> void:
	Game.inventory.add(&"cod", 6.0)
	var station := CraftingStation.new(&"salt_cod_recipe")
	station.auto_craft = true

	assert_true(station.craft_now())
	assert_almost_eq(Game.inventory.get_amount(&"salt_cod"), 1.0, 0.0001)
	assert_almost_eq(Game.inventory.get_amount(&"cod"), 3.0, 0.0001)
