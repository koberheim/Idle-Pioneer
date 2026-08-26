## Tests for MapGrid (task M1) - entirely headless, no scene, no texture, no art.
## Proves the claim in docs/GODOT_PLAN.md Phase 5.4: the land/water layer is
## testable before any map art exists.
extends GutTest


func test_new_grid_defaults_to_all_deep_water() -> void:
	var g: MapGrid = MapGrid.create(3, 2)
	for y: int in range(2):
		for x: int in range(3):
			assert_eq(g.get_terrain(Vector2i(x, y)), MapGrid.Terrain.DEEP_WATER)


func test_set_and_get_terrain_round_trips() -> void:
	var g: MapGrid = MapGrid.create(4, 4)
	g.set_terrain(Vector2i(2, 1), MapGrid.Terrain.LAND)
	assert_eq(g.get_terrain(Vector2i(2, 1)), MapGrid.Terrain.LAND)
	# Untouched neighbour is unaffected.
	assert_eq(g.get_terrain(Vector2i(2, 0)), MapGrid.Terrain.DEEP_WATER)


func test_out_of_bounds_read_returns_deep_water_not_a_crash() -> void:
	var g: MapGrid = MapGrid.create(4, 4)
	assert_eq(g.get_terrain(Vector2i(-1, 0)), MapGrid.Terrain.DEEP_WATER)
	assert_eq(g.get_terrain(Vector2i(0, -1)), MapGrid.Terrain.DEEP_WATER)
	assert_eq(g.get_terrain(Vector2i(4, 0)), MapGrid.Terrain.DEEP_WATER)
	assert_eq(g.get_terrain(Vector2i(0, 4)), MapGrid.Terrain.DEEP_WATER)
	assert_eq(g.get_terrain(Vector2i(999, 999)), MapGrid.Terrain.DEEP_WATER)


func test_in_bounds_true_and_false_on_all_four_edges() -> void:
	var g: MapGrid = MapGrid.create(3, 2)
	# corners and edges that ARE in bounds
	assert_true(g.in_bounds(Vector2i(0, 0)))
	assert_true(g.in_bounds(Vector2i(2, 0)))
	assert_true(g.in_bounds(Vector2i(0, 1)))
	assert_true(g.in_bounds(Vector2i(2, 1)))
	# one step past each edge
	assert_false(g.in_bounds(Vector2i(-1, 0)), "left edge")
	assert_false(g.in_bounds(Vector2i(3, 0)), "right edge")
	assert_false(g.in_bounds(Vector2i(0, -1)), "top edge")
	assert_false(g.in_bounds(Vector2i(0, 2)), "bottom edge")


func test_is_land_true_for_land_and_coast() -> void:
	var g: MapGrid = MapGrid.create(2, 1)
	g.set_terrain(Vector2i(0, 0), MapGrid.Terrain.LAND)
	g.set_terrain(Vector2i(1, 0), MapGrid.Terrain.COAST)
	assert_true(g.is_land(Vector2i(0, 0)))
	assert_true(g.is_land(Vector2i(1, 0)))
	assert_false(g.is_water(Vector2i(0, 0)))
	assert_false(g.is_water(Vector2i(1, 0)))


func test_is_water_true_for_deep_and_shallow() -> void:
	var g: MapGrid = MapGrid.create(2, 1)
	g.set_terrain(Vector2i(0, 0), MapGrid.Terrain.DEEP_WATER)
	g.set_terrain(Vector2i(1, 0), MapGrid.Terrain.SHALLOW_WATER)
	assert_true(g.is_water(Vector2i(0, 0)))
	assert_true(g.is_water(Vector2i(1, 0)))
	assert_false(g.is_land(Vector2i(0, 0)))
	assert_false(g.is_land(Vector2i(1, 0)))


func test_is_coast_only_true_for_coast() -> void:
	var g: MapGrid = MapGrid.create(2, 1)
	g.set_terrain(Vector2i(0, 0), MapGrid.Terrain.COAST)
	g.set_terrain(Vector2i(1, 0), MapGrid.Terrain.LAND)
	assert_true(g.is_coast(Vector2i(0, 0)))
	assert_false(g.is_coast(Vector2i(1, 0)))


func test_neighbours4_corner_has_two_edge_has_three_interior_has_four() -> void:
	var g: MapGrid = MapGrid.create(3, 3)
	assert_eq(g.neighbours4(Vector2i(0, 0)).size(), 2, "top-left corner")
	assert_eq(g.neighbours4(Vector2i(1, 0)).size(), 3, "top edge, not corner")
	assert_eq(g.neighbours4(Vector2i(1, 1)).size(), 4, "interior")


func test_deposit_default_is_empty_string_name() -> void:
	var g: MapGrid = MapGrid.create(2, 2)
	assert_eq(g.deposit_at(Vector2i(0, 0)), &"")


func test_set_and_get_deposit_round_trips() -> void:
	var g: MapGrid = MapGrid.create(2, 2)
	g.set_deposit(Vector2i(0, 0), &"timber")
	g.set_deposit(Vector2i(1, 0), &"clay")
	assert_eq(g.deposit_at(Vector2i(0, 0)), &"timber")
	assert_eq(g.deposit_at(Vector2i(1, 0)), &"clay")
	assert_eq(g.deposit_at(Vector2i(0, 1)), &"", "untouched cell stays empty")


func test_repeated_deposit_id_does_not_grow_the_palette() -> void:
	var g: MapGrid = MapGrid.create(3, 1)
	g.set_deposit(Vector2i(0, 0), &"timber")
	g.set_deposit(Vector2i(1, 0), &"timber")
	g.set_deposit(Vector2i(2, 0), &"clay")
	# palette[0] is the reserved empty entry, so 3 distinct entries total.
	assert_eq(g.deposit_palette.size(), 3)


func test_out_of_bounds_deposit_read_returns_empty_not_a_crash() -> void:
	var g: MapGrid = MapGrid.create(2, 2)
	assert_eq(g.deposit_at(Vector2i(-1, -1)), &"")


func test_to_dict_from_dict_round_trip_preserves_both_layers() -> void:
	var original: MapGrid = MapGrid.create(4, 3, 12345)
	original.set_terrain(Vector2i(0, 0), MapGrid.Terrain.LAND)
	original.set_terrain(Vector2i(1, 0), MapGrid.Terrain.COAST)
	original.set_terrain(Vector2i(2, 0), MapGrid.Terrain.SHALLOW_WATER)
	original.set_deposit(Vector2i(0, 0), &"timber")
	original.set_deposit(Vector2i(3, 2), &"clay")

	var restored: MapGrid = MapGrid.from_dict(original.to_dict())

	assert_eq(restored.width, original.width)
	assert_eq(restored.height, original.height)
	assert_eq(restored.seed_value, original.seed_value)

	for y: int in range(original.height):
		for x: int in range(original.width):
			var c := Vector2i(x, y)
			assert_eq(restored.get_terrain(c), original.get_terrain(c), "terrain mismatch at %s" % c)
			assert_eq(restored.deposit_at(c), original.deposit_at(c), "deposit mismatch at %s" % c)


func test_to_ascii_reflects_terrain_and_deposit_layers() -> void:
	var g: MapGrid = MapGrid.create(3, 1)
	g.set_terrain(Vector2i(0, 0), MapGrid.Terrain.DEEP_WATER)
	g.set_terrain(Vector2i(1, 0), MapGrid.Terrain.COAST)
	g.set_terrain(Vector2i(2, 0), MapGrid.Terrain.LAND)
	g.set_deposit(Vector2i(2, 0), &"timber")

	# Deep water: plain glyph. Coast: plain glyph. Land-with-deposit: deposit
	# initial wins over the terrain glyph.
	assert_eq(g.to_ascii(), ".+T")
