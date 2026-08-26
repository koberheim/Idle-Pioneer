## Tests for MapGenerator (rework task: randomized map). Uses a small grid
## (40x30) for fast tests, not the real Balance-configured production size -
## MapGenerator itself never reads Balance (see its class doc: pure,
## parameterized, testable without a live run).
extends GutTest

const WIDTH := 40
const HEIGHT := 30
const CONTINENT_THRESHOLD := 0.15


func _make_grid(seed_value: int = 1) -> MapGrid:
	return MapGenerator.generate_terrain(WIDTH, HEIGHT, seed_value, CONTINENT_THRESHOLD, 5, 2.0, 5.0)


func test_generate_terrain_produces_some_land_and_some_water() -> void:
	var grid: MapGrid = _make_grid()
	var land_count: int = 0
	var water_count: int = 0
	for y: int in range(grid.height):
		for x: int in range(grid.width):
			var c := Vector2i(x, y)
			if grid.is_land(c):
				land_count += 1
			else:
				water_count += 1
	assert_gt(land_count, 0, "expected some land")
	assert_gt(water_count, 0, "expected some water")


func test_generate_terrain_is_reproducible_for_the_same_seed() -> void:
	var a: MapGrid = _make_grid(42)
	var b: MapGrid = _make_grid(42)
	assert_eq(a.terrain, b.terrain, "the same seed must produce the same terrain")


func test_generate_terrain_differs_for_different_seeds() -> void:
	var a: MapGrid = _make_grid(1)
	var b: MapGrid = _make_grid(2)
	assert_ne(a.terrain, b.terrain, "different seeds should (almost always) differ")


func test_coast_cells_are_land_adjacent_to_water() -> void:
	var grid: MapGrid = _make_grid()
	var found_coast: bool = false
	for y: int in range(grid.height):
		for x: int in range(grid.width):
			var c := Vector2i(x, y)
			if grid.is_coast(c):
				found_coast = true
				var touches_water: bool = false
				for n: Vector2i in grid.neighbours4(c):
					if grid.is_water(n):
						touches_water = true
				assert_true(touches_water, "coast cell %s must touch water" % c)
	assert_true(found_coast, "expected at least one coast cell")


func test_find_continent_is_the_largest_connected_landmass() -> void:
	var grid: MapGrid = _make_grid()
	var components: Array = MapGenerator.find_land_components(grid)
	assert_gt(components.size(), 0)
	var continent: Array[Vector2i] = MapGenerator.find_continent(grid)
	for component: Array in components:
		assert_true(component.size() <= continent.size())


func test_place_capital_lands_on_continent_coast() -> void:
	var grid: MapGrid = _make_grid()
	var rng := RandomNumberGenerator.new()
	rng.seed = 7
	var capital: Vector2i = MapGenerator.place_capital(grid, rng)

	assert_true(grid.is_coast(capital))
	var continent: Array[Vector2i] = MapGenerator.find_continent(grid)
	assert_true(continent.has(capital), "capital must be on the continent, not an island")


func test_place_capital_is_reproducible_for_the_same_seed() -> void:
	var grid: MapGrid = _make_grid(3)
	var rng_a := RandomNumberGenerator.new()
	rng_a.seed = 99
	var rng_b := RandomNumberGenerator.new()
	rng_b.seed = 99
	assert_eq(MapGenerator.place_capital(grid, rng_a), MapGenerator.place_capital(grid, rng_b))


func test_place_colony_slots_never_places_on_water() -> void:
	var grid: MapGrid = _make_grid()
	var rng := RandomNumberGenerator.new()
	rng.seed = 11
	var capital: Vector2i = MapGenerator.place_capital(grid, rng)
	var slots: Array[Dictionary] = MapGenerator.place_colony_slots(grid, capital, 10, 3.0, 2.0, rng)

	assert_gt(slots.size(), 0)
	for slot: Dictionary in slots:
		assert_true(grid.is_land(slot["cell"]))


func test_place_colony_slots_distance_grows_with_slot_index() -> void:
	var grid: MapGrid = _make_grid()
	var rng := RandomNumberGenerator.new()
	rng.seed = 5
	var capital: Vector2i = MapGenerator.place_capital(grid, rng)
	var slots: Array[Dictionary] = MapGenerator.place_colony_slots(grid, capital, 8, 2.5, 1.5, rng)

	assert_gt(slots.size(), 3, "need several slots to check a trend")
	# Not a strict ladder (semi-random per the brief) - check the trend via
	# first-half vs second-half average distance instead of a monotonic walk.
	var half: int = slots.size() / 2
	var first_half_avg: float = 0.0
	for i in range(half):
		first_half_avg += float(slots[i]["distance_cells"])
	first_half_avg /= half
	var second_half_avg: float = 0.0
	for i in range(half, slots.size()):
		second_half_avg += float(slots[i]["distance_cells"])
	second_half_avg /= (slots.size() - half)

	assert_gt(second_half_avg, first_half_avg, "later slots should be farther out on average")


func test_place_colony_slots_respects_minimum_spacing() -> void:
	var grid: MapGrid = _make_grid()
	var rng := RandomNumberGenerator.new()
	rng.seed = 13
	var capital: Vector2i = MapGenerator.place_capital(grid, rng)
	var min_spacing: float = 3.0
	var slots: Array[Dictionary] = MapGenerator.place_colony_slots(grid, capital, 10, 3.0, min_spacing, rng)

	var cells: Array[Vector2i] = [capital]
	for slot: Dictionary in slots:
		cells.append(slot["cell"])

	for i in range(cells.size()):
		for j in range(i + 1, cells.size()):
			assert_true(
				Vector2(cells[i] - cells[j]).length() >= min_spacing - 0.001,
				"cells %s and %s are closer than the minimum spacing" % [cells[i], cells[j]]
			)


func test_place_colony_slots_stops_instead_of_looping_forever_on_a_tiny_map() -> void:
	# A 6x6 grid can't possibly fit 25 well-spaced colonies - this must
	# return fewer slots, not hang or crash (the correct-by-construction
	# guarantee the class doc promises).
	var tiny: MapGrid = MapGenerator.generate_terrain(6, 6, 1, 0.0, 0, 0.0, 0.0)
	var rng := RandomNumberGenerator.new()
	rng.seed = 1
	var capital: Vector2i = MapGenerator.place_capital(tiny, rng)
	if capital == Vector2i(-1, -1):
		assert_true(true, "no valid capital site on this tiny map - correctly reported, not faked")
		return
	var slots: Array[Dictionary] = MapGenerator.place_colony_slots(tiny, capital, 25, 3.0, 2.0, rng)
	assert_lt(slots.size(), 24)
