## Procedural map + colony-slot placement (rework task: randomized map per
## run). Static, no state of its own - mirrors MapLoader's style. Builds on
## MapGrid/PlacementRules exactly as authored for the hand-made MVP map;
## this is the piece that was never built for either project (see
## docs/GODOT_MIGRATION_ANALYSIS.md §E2 - the Unity map generator was
## hardcoded/unseeded, and colony placement was brute-force rejection
## sampling that could silently fail).
##
## Every placement function here enumerates the actual set of valid
## candidate cells and picks uniformly at random among them - never
## "try a random cell, retry on failure, give up after N attempts." That
## rejection-sampling pattern is exactly what produced Unity's silent
## fallback-to-a-default-position bug. Enumerate first; there is nothing
## left to fail once a candidate list is in hand (empty list is handled
## explicitly, not by looping forever).
class_name MapGenerator


## Builds the terrain grid: a single directionally-biased landmass (the
## continent, denser toward x=0 and tapering east) plus `island_count`
## small, separately-seeded blob islands scattered in the open water.
## Coast is computed afterward exactly as MapGrid already models it - any
## land cell 4-adjacent to a water cell.
static func generate_terrain(
	width: int, height: int, seed_value: int,
	continent_threshold: float, island_count: int, island_min_radius: float, island_max_radius: float
) -> MapGrid:
	var grid: MapGrid = MapGrid.create(width, height, seed_value)

	var continent_noise := FastNoiseLite.new()
	continent_noise.seed = seed_value
	continent_noise.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	continent_noise.frequency = 0.035

	for y: int in range(height):
		for x: int in range(width):
			# 1.0 at the west edge, 0.0 at the east edge - "mostly a
			# continent" anchored to one side, not a shape centered on the
			# map (which would just be a blob, not a continent silhouette).
			var west_bias: float = 1.0 - float(x) / float(width)
			var value: float = continent_noise.get_noise_2d(x, y) * 0.5 + west_bias
			if value > continent_threshold:
				grid.set_terrain(Vector2i(x, y), MapGrid.Terrain.LAND)

	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value

	for i: int in range(island_count):
		_stamp_island(grid, rng, seed_value + 1000 + i, island_min_radius, island_max_radius)

	_compute_coast(grid)
	return grid


static func _stamp_island(
	grid: MapGrid, rng: RandomNumberGenerator, island_seed: int, min_radius: float, max_radius: float
) -> void:
	# Islands live in the open water east of the continent's densest band -
	# roughly the map's eastern half - so they read as separate landmasses,
	# not an extension of the coastline.
	var center := Vector2i(
		rng.randi_range(int(grid.width * 0.5), grid.width - 1),
		rng.randi_range(0, grid.height - 1)
	)
	var radius: float = rng.randf_range(min_radius, max_radius)

	var island_noise := FastNoiseLite.new()
	island_noise.seed = island_seed
	island_noise.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	island_noise.frequency = 0.2

	var margin: int = int(ceil(radius)) + 2
	for y: int in range(max(0, center.y - margin), min(grid.height, center.y + margin)):
		for x: int in range(max(0, center.x - margin), min(grid.width, center.x + margin)):
			var c := Vector2i(x, y)
			var distance: float = Vector2(c - center).length()
			# Perturbed edge radius, not a perfect circle - an organic-ish
			# blob rather than a disc.
			var edge: float = radius * (0.7 + 0.3 * island_noise.get_noise_2d(x, y))
			if distance < edge:
				grid.set_terrain(c, MapGrid.Terrain.LAND)


static func _compute_coast(grid: MapGrid) -> void:
	# Two passes: the first pass's LAND->COAST conversions must not feed
	# into the second cell's neighbour check (a cell converted to COAST is
	# still land for this purpose) - collect first, apply after, so
	# iteration order can never matter.
	var coast_cells: Array[Vector2i] = []
	for y: int in range(grid.height):
		for x: int in range(grid.width):
			var c := Vector2i(x, y)
			if grid.get_terrain(c) != MapGrid.Terrain.LAND:
				continue
			for n: Vector2i in grid.neighbours4(c):
				if grid.is_water(n):
					coast_cells.append(c)
					break
	for c: Vector2i in coast_cells:
		grid.set_terrain(c, MapGrid.Terrain.COAST)


## Every land+coast cell, grouped into 4-connected components. The largest
## component is "the continent" by definition - everything else is an
## island, however large - matching the class doc's "determined after
## generation, not tracked during it" approach.
static func find_land_components(grid: MapGrid) -> Array:
	var visited: Dictionary = {}
	var components: Array = []

	for y: int in range(grid.height):
		for x: int in range(grid.width):
			var start := Vector2i(x, y)
			if not grid.is_land(start) or visited.has(start):
				continue

			var component: Array[Vector2i] = []
			var stack: Array[Vector2i] = [start]
			visited[start] = true
			while not stack.is_empty():
				var current: Vector2i = stack.pop_back()
				component.append(current)
				for n: Vector2i in grid.neighbours4(current):
					if grid.is_land(n) and not visited.has(n):
						visited[n] = true
						stack.append(n)
			components.append(component)

	return components


static func find_continent(grid: MapGrid) -> Array[Vector2i]:
	var largest: Array[Vector2i] = []
	for component: Array in find_land_components(grid):
		if component.size() > largest.size():
			largest = component
	return largest


## The starting colony always sits on the continent's coast (never an
## island) - a uniform-random pick among every coastal continent cell.
## Returns Vector2i(-1, -1) (with a push_error) only if the continent
## somehow has no coast at all, which would mean generation parameters
## produced a landmass touching every edge of the map - a configuration
## error, not something a retry would fix.
static func place_capital(grid: MapGrid, rng: RandomNumberGenerator) -> Vector2i:
	var candidates: Array[Vector2i] = []
	for c: Vector2i in find_continent(grid):
		if grid.is_coast(c):
			candidates.append(c)

	if candidates.is_empty():
		push_error("MapGenerator.place_capital: continent has no coastal cell")
		return Vector2i(-1, -1)

	return candidates[rng.randi_range(0, candidates.size() - 1)]


## Places up to `max_colonies` - 1 colony slots (slot 0 is the capital,
## already placed), each farther from the capital than the last on average,
## with real randomness in both distance and direction ("semi-random" per
## the brief, not a rigid ladder). Returns one Dictionary per slot actually
## placed: {"cell": Vector2i, "distance_cells": float, "is_coastal": bool} -
## fewer than max_colonies - 1 entries if the map runs out of room; this
## stops placing rather than forcing a slot into an invalid or overlapping
## position.
static func place_colony_slots(
	grid: MapGrid, capital_cell: Vector2i, max_colonies: int, distance_step: float, min_spacing: float,
	rng: RandomNumberGenerator
) -> Array[Dictionary]:
	var placed_cells: Array[Vector2i] = [capital_cell]
	var slots: Array[Dictionary] = []

	# Precomputed once, sorted by distance from the Capital - lets every
	# slot's candidate search binary-search straight to its target band
	# instead of rescanning the whole grid (a full O(width x height) rescan
	# per slot, worsened by up to 6 widen-retries each, was slow enough to
	# noticeably drag down every test that calls new_run()).
	var land_by_distance: Array[Dictionary] = _land_cells_by_distance(grid, capital_cell)

	for i: int in range(1, max_colonies):
		var min_dist: float = distance_step * i * 0.6
		var max_dist: float = distance_step * i * 1.4 + distance_step

		var candidates: Array[Vector2i] = _candidates_in_band(land_by_distance, placed_cells, min_dist, max_dist, min_spacing)
		var widen_attempts: int = 0
		while candidates.is_empty() and widen_attempts < 6:
			min_dist *= 0.7
			max_dist *= 1.5
			candidates = _candidates_in_band(land_by_distance, placed_cells, min_dist, max_dist, min_spacing)
			widen_attempts += 1

		if candidates.is_empty():
			break  # map is full - stop here rather than faking a position

		var chosen: Vector2i = candidates[rng.randi_range(0, candidates.size() - 1)]
		placed_cells.append(chosen)
		slots.append({
			"cell": chosen,
			"distance_cells": PlacementRules.route_distance(grid, capital_cell, chosen),
			"is_coastal": grid.is_coast(chosen),
		})

	return slots


static func _land_cells_by_distance(grid: MapGrid, capital_cell: Vector2i) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for y: int in range(grid.height):
		for x: int in range(grid.width):
			var c := Vector2i(x, y)
			if grid.is_land(c):
				out.append({"cell": c, "distance": PlacementRules.route_distance(grid, capital_cell, c)})
	out.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return float(a["distance"]) < float(b["distance"]))
	return out


static func _candidates_in_band(
	land_by_distance: Array[Dictionary], placed_cells: Array[Vector2i], min_dist: float, max_dist: float, min_spacing: float
) -> Array[Vector2i]:
	var out: Array[Vector2i] = []
	# Sorted ascending by distance - jump straight to the first cell that
	# could be in range, then stop the moment we walk past max_dist rather
	# than scanning every remaining (guaranteed out-of-range) entry too.
	var start: int = _lower_bound_by_distance(land_by_distance, min_dist)
	for idx: int in range(start, land_by_distance.size()):
		var entry: Dictionary = land_by_distance[idx]
		var distance: float = entry["distance"]
		if distance > max_dist:
			break
		var c: Vector2i = entry["cell"]
		if _too_close_to_any(c, placed_cells, min_spacing):
			continue
		out.append(c)
	return out


## First index whose distance is >= min_dist, in a list already sorted
## ascending by distance - standard binary search lower bound.
static func _lower_bound_by_distance(land_by_distance: Array[Dictionary], min_dist: float) -> int:
	var low: int = 0
	var high: int = land_by_distance.size()
	while low < high:
		var mid: int = (low + high) / 2
		if float(land_by_distance[mid]["distance"]) < min_dist:
			low = mid + 1
		else:
			high = mid
	return low


static func _too_close_to_any(c: Vector2i, placed_cells: Array[Vector2i], min_spacing: float) -> bool:
	for p: Vector2i in placed_cells:
		if Vector2(c - p).length() < min_spacing:
			return true
	return false
