## Tests for Route (task P3). Uses real MVP colonies (task D5): harbor_point
## (coastal, the Hub for these tests), island_outpost (coastal - a SEA route
## to the hub), clay_flats (inland - a LAND route to the hub). Same
## Game.run/Game.meta reset discipline as the other sim tests.
extends GutTest

var _hub: Colony
var _sea_origin: Colony
var _land_origin: Colony


func before_each() -> void:
	Game.new_run(&"mvp_coast")
	_hub = Colony.new(&"harbor_point", true)
	_sea_origin = Colony.new(&"island_outpost", false)
	_land_origin = Colony.new(&"clay_flats", false)


func after_each() -> void:
	Game.run = null


## The literal acceptance criterion from docs/GODOT_PLAN.md task P3: a sea
## route delivers strictly sooner than a land route of the SAME distance.
## Compared via the static speed table directly, since two real MVP colony
## pairs never share an exact distance by construction.
func test_sea_leg_duration_is_shorter_than_land_at_the_same_distance() -> void:
	var distance := 100.0
	var sea_duration: float = distance / Route.speed_for(PlacementRules.RouteKind.SEA)
	var land_duration: float = distance / Route.speed_for(PlacementRules.RouteKind.LAND)
	assert_lt(sea_duration, land_duration)


func test_sea_capacity_exceeds_land_capacity() -> void:
	assert_gt(Route.capacity_for(PlacementRules.RouteKind.SEA), Route.capacity_for(PlacementRules.RouteKind.LAND))


func test_route_between_two_coastal_colonies_is_sea_kind() -> void:
	var route := Route.new(_sea_origin, _hub)
	assert_eq(route.kind, PlacementRules.RouteKind.SEA)
	assert_almost_eq(route.capacity, Route.SEA_CAPACITY, 0.0001)


func test_route_from_an_inland_colony_is_land_kind() -> void:
	var route := Route.new(_land_origin, _hub)
	assert_eq(route.kind, PlacementRules.RouteKind.LAND)
	assert_almost_eq(route.capacity, Route.LAND_CAPACITY, 0.0001)


func test_route_starts_idle_at_origin_with_zero_progress() -> void:
	var route := Route.new(_land_origin, _hub)
	assert_eq(route.state, Route.State.AT_ORIGIN)
	assert_almost_eq(route.progress(), 0.0, 0.0001)


func test_route_does_not_depart_when_origin_has_no_cargo() -> void:
	var route := Route.new(_land_origin, _hub)
	route.tick(1.0)
	assert_eq(route.state, Route.State.AT_ORIGIN)


func test_route_departs_once_origin_has_cargo() -> void:
	_land_origin.local_stock[&"clay"] = 10.0
	var route := Route.new(_land_origin, _hub)
	route.tick(0.001)
	assert_eq(route.state, Route.State.TRAVELING_TO_HUB)


func test_departing_removes_loaded_cargo_from_origin_local_stock() -> void:
	_land_origin.local_stock[&"clay"] = 10.0
	var route := Route.new(_land_origin, _hub)
	route.tick(0.001)
	assert_eq(_land_origin.local_stock.get(&"clay", 0.0), 0.0)


func test_cargo_prefers_higher_value_resource_first_when_capacity_bound() -> void:
	# lumber (base_value 5.0) outranks timber (base_value 1.0). LAND capacity
	# is 50, and 100 lumber alone exceeds it, so timber should get nothing.
	_land_origin.local_stock[&"timber"] = 100.0
	_land_origin.local_stock[&"lumber"] = 100.0
	var route := Route.new(_land_origin, _hub)
	route.tick(0.001)
	assert_almost_eq(route.cargo.get(&"lumber", 0.0), 50.0, 0.0001)
	assert_eq(route.cargo.get(&"timber", 0.0), 0.0)


func test_cargo_load_is_capped_at_route_capacity() -> void:
	_sea_origin.local_stock[&"timber"] = 300.0  # exceeds SEA_CAPACITY (200)
	var route := Route.new(_sea_origin, _hub)
	route.tick(0.001)
	assert_almost_eq(route.cargo.get(&"timber", 0.0), 200.0, 0.0001)
	assert_almost_eq(_sea_origin.local_stock.get(&"timber", 0.0), 100.0, 0.0001, "the remainder stays behind")


func test_progress_climbs_monotonically_across_the_outbound_leg() -> void:
	_land_origin.local_stock[&"clay"] = 5.0
	var route := Route.new(_land_origin, _hub)
	route.tick(0.001)  # depart
	var duration: float = route.leg_duration

	route.tick(duration * 0.25)
	var p1: float = route.progress()
	route.tick(duration * 0.25)
	var p2: float = route.progress()

	assert_gt(p2, p1)
	assert_lt(p2, 1.0)


func test_arrival_at_hub_adds_cargo_to_central_inventory_and_emits_delivered() -> void:
	_land_origin.local_stock[&"clay"] = 7.0
	var route := Route.new(_land_origin, _hub)
	watch_signals(route)

	route.tick(0.001)  # depart
	route.tick(route.leg_duration + 1.0)  # overshoot - arrive

	assert_almost_eq(Game.inventory.get_amount(&"clay"), 7.0, 0.0001)
	assert_signal_emitted(route, "delivered")
	assert_eq(route.state, Route.State.TRAVELING_TO_ORIGIN, "should immediately start the return leg")


func test_progress_resets_at_the_start_of_the_return_leg() -> void:
	_land_origin.local_stock[&"clay"] = 7.0
	var route := Route.new(_land_origin, _hub)
	route.tick(0.001)
	route.tick(route.leg_duration + 1.0)  # arrive at hub, return leg begins
	assert_almost_eq(route.progress(), 0.0, 0.0001)


func test_full_round_trip_returns_to_at_origin_ready_for_more_cargo() -> void:
	_land_origin.local_stock[&"clay"] = 7.0
	var route := Route.new(_land_origin, _hub)
	route.tick(0.001)  # depart
	route.tick(route.leg_duration + 1.0)  # arrive at hub, begin return
	route.tick(route.leg_duration + 1.0)  # arrive back at origin

	assert_eq(route.state, Route.State.AT_ORIGIN)
	assert_almost_eq(route.progress(), 0.0, 0.0001)
	assert_eq(route.cargo, {})


func test_current_world_position_lies_on_the_line_at_the_expected_fraction() -> void:
	_land_origin.local_stock[&"clay"] = 5.0
	var route := Route.new(_land_origin, _hub)
	route.tick(0.001)  # depart
	var duration: float = route.leg_duration

	route.tick(duration * 0.5 - 0.001)  # land right at the midpoint

	var origin_cell: Vector2i = Db.region(&"clay_flats").cell
	var hub_cell: Vector2i = Db.region(&"harbor_point").cell
	var expected: Vector2 = Vector2(origin_cell).lerp(Vector2(hub_cell), route.progress())

	assert_almost_eq(route.current_world_position().x, expected.x, 0.01)
	assert_almost_eq(route.current_world_position().y, expected.y, 0.01)


func test_current_world_position_at_rest_is_the_origin_cell() -> void:
	var route := Route.new(_land_origin, _hub)
	var origin_cell: Vector2i = Db.region(&"clay_flats").cell
	assert_almost_eq(route.current_world_position().x, float(origin_cell.x), 0.0001)
	assert_almost_eq(route.current_world_position().y, float(origin_cell.y), 0.0001)
