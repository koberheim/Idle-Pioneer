## Tests for Route (docs/GAME_DESIGN.md §5/§6, simplified further per
## conversation: no full-or-30-seconds timer, just continuous cycling).
## Uses the real colony table: tidewater_landing (Capital, destination for
## every route) and cape_harbour (distance 1, forced LAND) / chesapeake_fields
## (distance 2, forced SEA) as origins - route_type is forced explicitly
## rather than left to the real random roll, so these tests are deterministic.
extends GutTest

var _capital: Colony
var _land_origin: Colony  # cape_harbour, distance 1, LAND
var _sea_origin: Colony  # chesapeake_fields, distance 2, SEA


func before_each() -> void:
	Game.new_run(&"mvp_coast")
	_capital = Colony.new(&"tidewater_landing")
	_land_origin = Colony.new(&"cape_harbour")
	_land_origin.route_type = Colony.RouteType.LAND
	_sea_origin = Colony.new(&"chesapeake_fields")
	_sea_origin.route_type = Colony.RouteType.SEA


func after_each() -> void:
	Game.run = null


func test_land_capacity_matches_the_documented_formula() -> void:
	# 20 * (1 + 0.5 * 0) = 20
	var route := Route.new(_land_origin, _capital)
	assert_almost_eq(route.capacity(), 20.0, 0.0001)


func test_sea_capacity_exceeds_land_capacity_at_the_same_transport_level() -> void:
	var land_route := Route.new(_land_origin, _capital)
	var sea_route := Route.new(_sea_origin, _capital)
	assert_gt(sea_route.capacity(), land_route.capacity())


func test_capacity_increases_with_transport_level() -> void:
	_land_origin.transport_level = 2  # 20 * (1 + 0.5*2) = 40
	var route := Route.new(_land_origin, _capital)
	assert_almost_eq(route.capacity(), 40.0, 0.0001)


func test_capacity_is_read_live_not_cached_at_construction() -> void:
	var route := Route.new(_land_origin, _capital)
	assert_almost_eq(route.capacity(), 20.0, 0.0001)
	_land_origin.transport_level = 1
	assert_almost_eq(route.capacity(), 30.0, 0.0001, "a level bought after Route creation should still apply")


func test_leg_duration_matches_the_documented_formula() -> void:
	# distance 1 * 12s round trip / 2 = 6s per leg
	var route := Route.new(_land_origin, _capital)
	assert_almost_eq(route.leg_duration(), 6.0, 0.0001)


func test_sea_leg_duration_at_the_same_distance_is_longer_than_land() -> void:
	# Same distance (1), forced to each route type, isolates the type's
	# effect on duration from distance's effect.
	var sea_at_distance_one := Colony.new(&"cape_harbour")
	sea_at_distance_one.route_type = Colony.RouteType.SEA
	var land_route := Route.new(_land_origin, _capital)
	var sea_route := Route.new(sea_at_distance_one, _capital)
	assert_gt(sea_route.leg_duration(), land_route.leg_duration())


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
	# muskets (base_value 38000) outranks cod (4). LAND capacity is 20, and
	# 100 muskets alone exceeds it, so cod should get nothing.
	_land_origin.local_stock[&"cod"] = 100.0
	_land_origin.local_stock[&"muskets"] = 100.0
	var route := Route.new(_land_origin, _capital)
	route.tick(0.001)
	assert_almost_eq(route.cargo.get(&"muskets", 0.0), 20.0, 0.0001)
	assert_eq(route.cargo.get(&"cod", 0.0), 0.0)


func test_cargo_load_is_capped_at_route_capacity() -> void:
	_sea_origin.local_stock[&"tobacco"] = 300.0  # exceeds SEA capacity (50)
	var route := Route.new(_sea_origin, _capital)
	route.tick(0.001)
	assert_almost_eq(route.cargo.get(&"tobacco", 0.0), 50.0, 0.0001)
	assert_almost_eq(_sea_origin.local_stock.get(&"tobacco", 0.0), 250.0, 0.0001, "the remainder stays behind")


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
	route.tick(0.001)
	route.tick(route.leg_duration() + 1.0)
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
