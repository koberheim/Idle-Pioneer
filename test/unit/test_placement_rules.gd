## Tests for PlacementRules (task M3), run against the real MVP map
## (data/maps/mvp_coast.txt) rather than synthetic toy grids - per
## docs/GODOT_PLAN.md task M3's stated regression risk, Unity's equivalent
## thresholds were calibrated against the wrong coordinate space and were
## silently broken as a result.
extends GutTest

var _grid: MapGrid


func before_all() -> void:
	_grid = MapLoader.from_file("res://data/maps/mvp_coast.txt")


func test_map_loaded_for_these_tests() -> void:
	assert_not_null(_grid, "test fixture problem, not a PlacementRules problem, if this fails")


func test_land_cell_is_a_valid_colony_site() -> void:
	assert_true(PlacementRules.is_valid_colony_site(_grid, Vector2i(0, 0)))


func test_coast_cell_is_a_valid_colony_site() -> void:
	assert_true(PlacementRules.is_valid_colony_site(_grid, Vector2i(9, 0)))


func test_shallow_water_is_not_a_valid_colony_site() -> void:
	assert_false(PlacementRules.is_valid_colony_site(_grid, Vector2i(10, 0)))


func test_deep_water_is_not_a_valid_colony_site() -> void:
	assert_false(PlacementRules.is_valid_colony_site(_grid, Vector2i(23, 0)))


func test_out_of_bounds_is_not_a_valid_colony_site() -> void:
	assert_false(PlacementRules.is_valid_colony_site(_grid, Vector2i(-1, 0)))
	assert_false(PlacementRules.is_valid_colony_site(_grid, Vector2i(999, 999)))


func test_coastal_sites_includes_known_coast_cells() -> void:
	var sites: Array[Vector2i] = PlacementRules.coastal_sites(_grid)
	assert_has(sites, Vector2i(9, 0), "mainland coast")
	assert_has(sites, Vector2i(16, 6), "island coast ring")


func test_coastal_sites_contains_only_actual_coast_cells() -> void:
	var sites: Array[Vector2i] = PlacementRules.coastal_sites(_grid)
	for c: Vector2i in sites:
		assert_true(_grid.is_coast(c), "%s in coastal_sites but is_coast() is false" % c)


func test_two_coastal_sites_route_by_sea() -> void:
	# Mainland coast at row 0 to the island's coast ring - both endpoints coastal.
	var kind: PlacementRules.RouteKind = PlacementRules.route_kind(
		_grid, Vector2i(9, 0), Vector2i(16, 6)
	)
	assert_eq(kind, PlacementRules.RouteKind.SEA)


func test_inland_to_coastal_routes_by_land() -> void:
	var kind: PlacementRules.RouteKind = PlacementRules.route_kind(
		_grid, Vector2i(0, 0), Vector2i(9, 0)
	)
	assert_eq(kind, PlacementRules.RouteKind.LAND)


func test_two_inland_sites_route_by_land() -> void:
	var kind: PlacementRules.RouteKind = PlacementRules.route_kind(
		_grid, Vector2i(0, 0), Vector2i(1, 1)
	)
	assert_eq(kind, PlacementRules.RouteKind.LAND)


func test_route_kind_is_symmetric() -> void:
	var a := Vector2i(9, 0)
	var b := Vector2i(16, 6)
	assert_eq(
		PlacementRules.route_kind(_grid, a, b),
		PlacementRules.route_kind(_grid, b, a)
	)


func test_route_distance_is_symmetric() -> void:
	var a := Vector2i(0, 0)
	var b := Vector2i(9, 6)
	assert_almost_eq(
		PlacementRules.route_distance(_grid, a, b),
		PlacementRules.route_distance(_grid, b, a),
		0.0001
	)


func test_route_distance_matches_known_euclidean_distance() -> void:
	# A 3-4-5 triangle for an exact expected value.
	var dist: float = PlacementRules.route_distance(_grid, Vector2i(0, 0), Vector2i(3, 4))
	assert_almost_eq(dist, 5.0, 0.0001)


func test_route_distance_of_a_cell_to_itself_is_zero() -> void:
	var dist: float = PlacementRules.route_distance(_grid, Vector2i(5, 5), Vector2i(5, 5))
	assert_almost_eq(dist, 0.0, 0.0001)
