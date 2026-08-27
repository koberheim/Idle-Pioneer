## Tests for the Routes registry (rework task: live simulation driver).
## Self-healing by design (sync_with_colonies(), run at the start of every
## tick()) rather than requiring an explicit register() call - these tests
## exercise that directly rather than constructing Route objects by hand.
extends GutTest


func before_each() -> void:
	Game.new_run(&"mvp_coast")  # bootstraps the Capital automatically
	Game.routes.clear()


func after_each() -> void:
	Game.routes.clear()
	Game.colonies.clear()
	Game.run = null


func test_sync_creates_nothing_before_any_non_capital_colony_exists() -> void:
	Game.routes.sync_with_colonies()
	assert_eq(Game.routes.all().size(), 0)


func test_sync_creates_a_route_for_a_registered_non_capital_colony() -> void:
	Game.colonies.register(Colony.new(&"cape_harbour"))
	Game.routes.sync_with_colonies()
	assert_not_null(Game.routes.for_colony(&"cape_harbour"))


func test_sync_does_not_create_a_route_for_the_capital() -> void:
	Game.routes.sync_with_colonies()
	assert_null(Game.routes.for_colony(&"tidewater_landing"))


func test_sync_is_idempotent() -> void:
	Game.colonies.register(Colony.new(&"cape_harbour"))
	Game.routes.sync_with_colonies()
	var first: Route = Game.routes.for_colony(&"cape_harbour")
	Game.routes.sync_with_colonies()
	assert_eq(Game.routes.for_colony(&"cape_harbour"), first, "an existing route must not be replaced")


func test_a_created_routes_origin_and_destination_are_the_live_colony_instances() -> void:
	var outpost := Colony.new(&"cape_harbour")
	Game.colonies.register(outpost)
	Game.routes.sync_with_colonies()
	var route: Route = Game.routes.for_colony(&"cape_harbour")
	assert_eq(route.origin, outpost)
	assert_eq(route.destination, Game.colonies.capital())


func test_tick_syncs_and_advances_every_route() -> void:
	var outpost := Colony.new(&"cape_harbour")
	# A nonzero distance so the round trip actually takes measurable time -
	# distance defaults to 0.0 now (real, generated per-slot data - rework
	# task: randomized map), which would otherwise complete the whole round
	# trip instantly within a single tick() call.
	outpost.distance_cells = 1.0
	outpost.local_stock[&"cod"] = 5.0
	Game.colonies.register(outpost)

	Game.routes.tick(0.001)  # sync creates the route, then departs immediately

	var route: Route = Game.routes.for_colony(&"cape_harbour")
	assert_eq(route.state, Route.State.TRAVELING_TO_HUB)


func test_clear_empties_the_registry() -> void:
	Game.colonies.register(Colony.new(&"cape_harbour"))
	Game.routes.sync_with_colonies()
	Game.routes.clear()
	assert_eq(Game.routes.all().size(), 0)


## docs/GAME_DESIGN.md §11 Phase 7: "notifications when shipments land" -
## Routes forwards each Route's own `delivered` signal with the colony
## attached, since a bare Route doesn't know its own display context.
func test_a_route_arriving_at_the_hub_emits_shipment_delivered_with_its_colony() -> void:
	var outpost := Colony.new(&"cape_harbour")
	outpost.distance_cells = 0.0  # zero distance -> the leg completes within one tick()
	outpost.local_stock[&"cod"] = 5.0
	Game.colonies.register(outpost)

	watch_signals(Game.routes)
	Game.routes.tick(0.001)

	assert_signal_emitted_with_parameters(Game.routes, "shipment_delivered", [outpost, {&"cod": 5.0}])
