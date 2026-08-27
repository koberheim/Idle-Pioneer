## Tests for Simulation (rework task: live simulation driver). Drives
## tick(delta) directly with an exact delta rather than waiting on real
## engine frames - _process() is just a thin wrapper proven separately by
## the start()/stop() tests below. Disabled by default (see Simulation's
## class doc for why) - none of these tests ever call start(), so _process()
## itself never fires during this suite.
extends GutTest


func before_each() -> void:
	Game.new_run(&"mvp_coast")


func after_each() -> void:
	Game.colonies.clear()
	Game.routes.clear()
	Game.crafting_stations.clear()
	Game.run = null


func test_tick_is_a_no_op_with_no_active_run() -> void:
	Game.run = null
	Game.simulation.tick(5.0)  # must not crash
	assert_null(Game.run, "no run should have been created as a side effect")


func test_tick_advances_colony_production() -> void:
	Game.routing.set_mode(&"timber", Game.routing.RESERVE)
	# Capital is bootstrapped automatically - base rate 1.0 timber/s.
	Game.simulation.tick(3.0)
	assert_almost_eq(Game.inventory.get_amount(&"timber"), 3.0, 0.0001)


func test_tick_advances_shipping() -> void:
	var outpost := Colony.new(&"cape_harbour")
	# Nonzero distance so the round trip takes measurable time instead of
	# completing instantly within one tick (distance defaults to 0.0 now -
	# rework task: randomized map).
	outpost.distance_cells = 1.0
	outpost.local_stock[&"cod"] = 5.0
	Game.colonies.register(outpost)

	Game.simulation.tick(0.001)  # syncs a route and departs immediately

	var route: Route = Game.routes.for_colony(&"cape_harbour")
	assert_not_null(route)
	assert_eq(route.state, Route.State.TRAVELING_TO_HUB)


func test_tick_advances_auto_craft() -> void:
	Game.routing.set_mode(&"salt_cod", Game.routing.RESERVE)
	Game.inventory.add(&"cod", 3.0)
	var station: CraftingStation = Game.crafting_stations.get_or_create(&"salt_cod_recipe")
	station.auto_craft = true

	Game.simulation.tick(2.5)  # exactly one craft cycle

	assert_almost_eq(Game.inventory.get_amount(&"salt_cod"), 1.0, 0.0001)


func test_tick_accumulates_elapsed_seconds() -> void:
	Game.simulation.tick(4.0)
	Game.simulation.tick(1.5)
	assert_almost_eq(Game.run.elapsed_seconds, 5.5, 0.0001)


func test_process_is_disabled_until_start_is_called() -> void:
	assert_false(Game.simulation.is_processing())
	Game.simulation.start()
	assert_true(Game.simulation.is_processing())
	Game.simulation.stop()
	assert_false(Game.simulation.is_processing())
