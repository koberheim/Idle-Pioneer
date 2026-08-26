## Tests for MapLoader (task M2).
extends GutTest


func test_parses_a_simple_spaced_map() -> void:
	var g: MapGrid = MapLoader.from_ascii(". ~ + #\n. ~ + #")
	assert_not_null(g)
	assert_eq(g.width, 4)
	assert_eq(g.height, 2)
	assert_eq(g.get_terrain(Vector2i(0, 0)), MapGrid.Terrain.DEEP_WATER)
	assert_eq(g.get_terrain(Vector2i(1, 0)), MapGrid.Terrain.SHALLOW_WATER)
	assert_eq(g.get_terrain(Vector2i(2, 0)), MapGrid.Terrain.COAST)
	assert_eq(g.get_terrain(Vector2i(3, 0)), MapGrid.Terrain.LAND)


func test_parses_a_compact_no_space_map() -> void:
	var g: MapGrid = MapLoader.from_ascii(".~+#\n.~+#")
	assert_not_null(g)
	assert_eq(g.width, 4)
	assert_eq(g.height, 2)
	assert_eq(g.get_terrain(Vector2i(3, 1)), MapGrid.Terrain.LAND)


func test_tolerates_leading_and_trailing_blank_lines() -> void:
	var g: MapGrid = MapLoader.from_ascii("\n\n. ~\n+ #\n\n")
	assert_not_null(g)
	assert_eq(g.width, 2)
	assert_eq(g.height, 2)


func test_ragged_row_returns_null() -> void:
	var g: MapGrid = MapLoader.from_ascii(". ~ +\n. ~")
	assert_null(g)


func test_unknown_glyph_returns_null() -> void:
	var g: MapGrid = MapLoader.from_ascii(". ~ X\n. ~ +")
	assert_null(g)


func test_empty_input_returns_null() -> void:
	assert_null(MapLoader.from_ascii(""))
	assert_null(MapLoader.from_ascii("\n\n\n"))


## The round trip MapGrid's own doc promises: MapLoader.from_ascii(g.to_ascii())
## reproduces g, because to_ascii()'s compact (no-space) output is exactly the
## second input style from_ascii accepts. Deliberately terrain-only (no
## deposits set) - see the SCOPE NOTE on MapLoader for why deposits and this
## round trip don't mix.
func test_round_trips_through_map_grid_to_ascii() -> void:
	var original: MapGrid = MapGrid.create(5, 3)
	original.set_terrain(Vector2i(0, 0), MapGrid.Terrain.LAND)
	original.set_terrain(Vector2i(1, 0), MapGrid.Terrain.COAST)
	original.set_terrain(Vector2i(2, 0), MapGrid.Terrain.SHALLOW_WATER)
	original.set_terrain(Vector2i(3, 0), MapGrid.Terrain.DEEP_WATER)
	original.set_terrain(Vector2i(0, 2), MapGrid.Terrain.COAST)

	var restored: MapGrid = MapLoader.from_ascii(original.to_ascii())

	assert_not_null(restored)
	assert_eq(restored.width, original.width)
	assert_eq(restored.height, original.height)
	for y: int in range(original.height):
		for x: int in range(original.width):
			var c := Vector2i(x, y)
			assert_eq(restored.get_terrain(c), original.get_terrain(c), "mismatch at %s" % c)


func test_from_file_loads_the_mvp_coast_map() -> void:
	var g: MapGrid = MapLoader.from_file("res://data/maps/mvp_coast.txt")
	assert_not_null(g)
	assert_eq(g.width, 24)
	assert_eq(g.height, 16)


func test_from_file_of_missing_path_returns_null() -> void:
	assert_null(MapLoader.from_file("res://data/maps/does_not_exist.txt"))


func test_mvp_coast_map_has_a_valid_mainland_coastline() -> void:
	var g: MapGrid = MapLoader.from_file("res://data/maps/mvp_coast.txt")
	assert_not_null(g)
	# West edge is all land, east edge is all deep water - the coastline runs
	# between them somewhere on every row.
	for y: int in range(g.height):
		assert_true(g.is_land(Vector2i(0, y)), "west edge should be land at row %d" % y)
		assert_true(g.is_water(Vector2i(g.width - 1, y)), "east edge should be water at row %d" % y)


func test_mvp_coast_map_has_its_small_island() -> void:
	var g: MapGrid = MapLoader.from_file("res://data/maps/mvp_coast.txt")
	assert_not_null(g)
	assert_eq(g.get_terrain(Vector2i(17, 6)), MapGrid.Terrain.LAND, "the offshore island")
	assert_true(g.is_water(Vector2i(17, 3)), "well clear of the mainland and the island")
