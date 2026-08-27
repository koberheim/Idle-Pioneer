## Tests for Route (docs/GAME_DESIGN.md §5/§6, reworked per the design
## realignment: capacity and travel time both come from the origin colony's
## own stats via Balance, not a simple land/sea lookup table). Uses the real
## colony table: tidewater_landing (Capital, destination for every route) and
## cape_harbour (distance 1, forced LAND) / chesapeake_fields (distance 2,
## forced SEA) as origins - distance_cells/is_coastal are set explicitly
## (rework task: randomized map - route_type is now derived from is_coastal,
## not a random roll) rather than left to real map generation, so these
## tests are deterministic.
extends GutTest

var _capital: Colony
var _land_origin: Colony  # cape_harbour, distance 1, LAND
var _sea_origin: Colony  # chesapeake_fields, distance 2, SEA


func before_each() -> void:
	Game.new_run(&"mvp_coast")
	# Routing now defaults to SELL (docs/GAME_DESIGN.md's own default,
	# reversed back to from an earlier RESERVE-by-default pass) - these tests
	# are about delivery/inventory mechanics, not Sell/Reserve itself, so
	# pin RESERVE here rather than touch every assertion.
	Game.routing.set_mode(&"cod", Game.routing.RESERVE)
	_capital = Colony.new(&"tidewater_landing")
	_land_origin = Colony.new(&"cape_harbour")
	_land_origin.distance_cells = 1.0
	_land_origin.is_coastal = false
	_sea_origin = Colony.new(&"chesapeake_fields")
	_sea_origin.distance_cells = 2.0
	_sea_origin.is_coastal = true


func after_each() -> void:
	Game.colonists.clear_assignments()
	Game.run = null


func test_capacity_matches_the_origin_colonys_base_cargo_with_no_upgrades() -> void:
	# base_cargo 20.0, no cargo_level, no colonists.
	var route := Route.new(_land_origin, _capital)
	assert_almost_eq(route.capacity(), 20.0, 0.0001)


func test_capacity_increases_with_cargo_level() -> void:
	_land_origin.cargo_level = 2  # 20 * (1 + 0.5*2) = 40
	var route := Route.new(_land_origin, _capital)
	assert_almost_eq(route.capacity(), 40.0, 0.0001)


func test_capacity_is_read_live_not_cached_at_construction() -> void:
	var route := Route.new(_land_origin, _capital)
	assert_almost_eq(route.capacity(), 20.0, 0.0001)
	_land_origin.cargo_level = 1
	assert_almost_eq(route.capacity(), 30.0, 0.0001, "a level bought after Route creation should still apply")


func test_leg_duration_matches_the_documented_formula() -> void:
	# distance 1 * 12s (land) round trip / base_speed 1.0 / 2 legs = 6s
	var route := Route.new(_land_origin, _capital)
	assert_almost_eq(route.leg_duration(), 6.0, 0.0001)


func test_sea_leg_duration_at_the_same_distance_is_longer_than_land() -> void:
	# Same distance (1), forced to each route type, isolates the type's
	# effect on duration from distance's effect.
	var sea_at_distance_one := Colony.new(&"cape_harbour")
	sea_at_distance_one.distance_cells = 1.0
	sea_at_distance_one.is_coastal = true
	var land_route := Route.new(_land_origin, _capital)
	var sea_route := Route.new(sea_at_distance_one, _capital)
	assert_gt(sea_route.leg_duration(), land_route.leg_duration())


func test_speed_level_reduces_leg_duration() -> void:
	_land_origin.speed_level = 2  # 12 / (1 + 0.5*2) / 2 = 3.0
	var route := Route.new(_land_origin, _capital)
	assert_almost_eq(route.leg_duration(), 3.0, 0.0001)


func test_route_starts_idle_at_origin_with_zero_progress() -> void:
	var route := Route.new(_land_origin, _capital)
	assert_eq(route.state, Route.State.AT_ORIGIN)
	assert_almost_eq(route.progress(), 0.0, 0.0001)


func test_route_does_not_depart_when_origin_has_no_cargo() -> void:
	var route := Route.new(_land_origin, _capital)
	route.tick(1.0)
	assert_eq(route.state, Route.State.AT_ORIGIN)


func test_route_departs_immediately_once_origin_has_any_cargo() -> void:
	# No waiting for a full hold and no timer - see the class doc.
	_land_origin.local_stock[&"cod"] = 1.0
	var route := Route.new(_land_origin, _capital)
	route.tick(0.001)
	assert_eq(route.state, Route.State.TRAVELING_TO_HUB)


func test_departing_removes_loaded_cargo_from_origin_local_stock() -> void:
	_land_origin.local_stock[&"cod"] = 10.0
	var route := Route.new(_land_origin, _capital)
	route.tick(0.001)
	assert_eq(_land_origin.local_stock.get(&"cod", 0.0), 0.0)


func test_cargo_prefers_higher_value_resource_first_when_capacity_bound() -> void:
	# muskets (base_value 38000) outranks cod (4). Capacity is 20, and
	# 100 muskets alone exceeds it, so cod should get nothing.
	_land_origin.local_stock[&"cod"] = 100.0
	_land_origin.local_stock[&"muskets"] = 100.0
	var route := Route.new(_land_origin, _capital)
	route.tick(0.001)
	assert_almost_eq(route.cargo.get(&"muskets", 0.0), 20.0, 0.0001)
	assert_eq(route.cargo.get(&"cod", 0.0), 0.0)


func test_cargo_load_is_capped_at_route_capacity() -> void:
	_land_origin.local_stock[&"cod"] = 300.0  # exceeds capacity (20)
	var route := Route.new(_land_origin, _capital)
	route.tick(0.001)
	assert_almost_eq(route.cargo.get(&"cod", 0.0), 20.0, 0.0001)
	assert_almost_eq(_land_origin.local_stock.get(&"cod", 0.0), 280.0, 0.0001, "the remainder stays behind")


func test_progress_climbs_monotonically_across_the_outbound_leg() -> void:
	_land_origin.local_stock[&"cod"] = 5.0
	var route := Route.new(_land_origin, _capital)
	route.tick(0.001)  # depart
	var duration: float = route.leg_duration()

	route.tick(duration * 0.25)
	var p1: float = route.progress()
	route.tick(duration * 0.25)
	var p2: float = route.progress()

	assert_gt(p2, p1)
	assert_lt(p2, 1.0)


## Proves hub arrival goes through Routing, not straight to inventory - a
## resource routed SELL should turn into gold instead of piling up in
## storage.
func test_arrival_at_hub_sells_instead_of_stocking_when_routed_sell() -> void:
	Game.routing.set_mode(&"cod", Game.routing.SELL)
	_land_origin.local_stock[&"cod"] = 7.0
	var route := Route.new(_land_origin, _capital)

	route.tick(0.001)  # depart
	route.tick(route.leg_duration() + 1.0)  # overshoot - arrive

	assert_almost_eq(Game.inventory.get_amount(&"cod"), 0.0, 0.0001)
	assert_almost_eq(Game.economy.gold, 28.0, 0.0001)  # 7 cod x base_value 4.0


func test_arrival_at_hub_adds_cargo_to_central_inventory_and_emits_delivered() -> void:
	_land_origin.local_stock[&"cod"] = 7.0
	var route := Route.new(_land_origin, _capital)
	watch_signals(route)

	route.tick(0.001)  # depart
	route.tick(route.leg_duration() + 1.0)  # overshoot - arrive

	assert_almost_eq(Game.inventory.get_amount(&"cod"), 7.0, 0.0001)
	assert_signal_emitted(route, "delivered")
	assert_eq(route.state, Route.State.TRAVELING_TO_ORIGIN, "should immediately start the return leg")


func test_progress_resets_at_the_start_of_the_return_leg() -> void:
	_land_origin.local_stock[&"cod"] = 7.0
	var route := Route.new(_land_origin, _capital)
	# A tiny departure tick, then exactly the remaining leg time - not an
	# overshoot. tick() now correctly spends any overshoot on the next leg
	# too (the large-delta fix), so an overshoot here would no longer land
	# exactly at the start of the return leg. Use
	# test_full_round_trip_returns_to_at_origin_ready_for_more_cargo and the
	# dedicated large-delta tests below for that behaviour.
	route.tick(0.000001)
	route.tick(route.leg_duration())
	assert_almost_eq(route.progress(), 0.0, 0.0001)


func test_full_round_trip_returns_to_at_origin_ready_for_more_cargo() -> void:
	_land_origin.local_stock[&"cod"] = 7.0
	var route := Route.new(_land_origin, _capital)
	route.tick(0.001)  # depart
	route.tick(route.leg_duration() + 1.0)  # arrive at hub, begin return
	route.tick(route.leg_duration() + 1.0)  # arrive back at origin

	assert_eq(route.state, Route.State.AT_ORIGIN)
	assert_almost_eq(route.progress(), 0.0, 0.0001)
	assert_eq(route.cargo, {})


## Proves the "continuous back and forth, no waiting" behavior end to end:
## once cargo is delivered and the vehicle is back, it should depart again
## immediately on the very next tick if there's more to carry.
func test_route_cycles_continuously_without_waiting_between_trips() -> void:
	_land_origin.local_stock[&"cod"] = 5.0
	var route := Route.new(_land_origin, _capital)

	route.tick(0.001)  # depart
	route.tick(route.leg_duration() + 1.0)  # arrive at hub
	route.tick(route.leg_duration() + 1.0)  # arrive back at origin

	_land_origin.local_stock[&"cod"] = 3.0
	route.tick(0.001)  # should depart again immediately, no idle gap
	assert_eq(route.state, Route.State.TRAVELING_TO_HUB)
	assert_almost_eq(route.cargo.get(&"cod", 0.0), 3.0, 0.0001)


## The offline-catch-up fix: a single huge tick() must complete every round
## trip the elapsed time and cargo actually cover, not just the first leg
## transition. Plenty of cod (300) so cargo is never the limiting factor -
## isolates the time-looping fix from the ingredient-halt behaviour that
## CraftingStation's equivalent tests cover separately.
func test_tick_completes_many_round_trips_in_one_large_delta() -> void:
	_land_origin.local_stock[&"cod"] = 200.0  # exactly 10 loads of capacity (20)
	var route := Route.new(_land_origin, _capital)
	var round_trip: float = route.leg_duration() * 2.0  # 12.0s

	route.tick(round_trip * 10.0)  # exactly 10 full round trips' worth of time

	assert_almost_eq(Game.inventory.get_amount(&"cod"), 200.0, 0.0001, "10 deliveries of 20 cod each")
	assert_eq(route.state, Route.State.AT_ORIGIN, "all 10 round trips should have completed and returned")
	assert_almost_eq(_land_origin.local_stock.get(&"cod", 0.0), 0.0, 0.0001)


func test_tick_with_a_large_delta_stops_cleanly_once_cargo_runs_out() -> void:
	_land_origin.local_stock[&"cod"] = 25.0  # one full 20-load, then a partial 5
	var route := Route.new(_land_origin, _capital)
	var round_trip: float = route.leg_duration() * 2.0

	route.tick(round_trip * 5.0)  # far more time than the remaining cargo needs

	assert_almost_eq(Game.inventory.get_amount(&"cod"), 25.0, 0.0001, "all cargo eventually delivered")
	assert_eq(route.state, Route.State.AT_ORIGIN, "nothing left to carry - back home and idle")
