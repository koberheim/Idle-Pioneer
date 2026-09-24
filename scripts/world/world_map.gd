## A run's world: terrain grid, candidate colony sites, and the routes between
## them and the capital. Rebuilt deterministically from (style, seed) whenever
## a run is started or loaded, so it never needs saving.
class_name WorldMap
extends RefCounted

const W := 64
const H := 96

enum T { OCEAN, LAKE, TUNDRA, CONIFER, FOREST, PLAINS, GRASSLAND, SAVANNAH, MARSH, TROPICAL, HILLS, MOUNTAINS }

const STYLE_RANDOM := "random"
const STYLE_NORTH_AMERICA := "north_america"

var style: String
var seed_value: int
var terrain := PackedByteArray()
var height := PackedFloat32Array()  # 0..1 land elevation (hillshading)
var ocean := PackedByteArray()      # 1 = water connected to the open sea
var water_depth := PackedFloat32Array()  # tiles from land, for water colour
## Candidate sites: {x, y, terrain, resource, route ("land"/"sea"), richness, port: Vector2i}
var sites: Array[Dictionary] = []
var capital_site: int = 0
## The order in which sites are settled this run (site indices, capital
## first). Random, but loosely outward from the capital.
var colony_order: Array[int] = []
var europe_port: Vector2i

var landmass := PackedInt32Array()  # connected land component id, -1 for water
var seas := PackedInt32Array()      # connected ocean component id, -1 elsewhere
var _main_landmass: int = -1
var _land_astar: AStarGrid2D
var _sea_astar: AStarGrid2D
var _route_cache: Dictionary = {}


static func build(p_style: String, p_seed: int) -> WorldMap:
	var m := WorldMap.new()
	m.style = p_style
	m.seed_value = p_seed
	m.terrain.resize(W * H)
	m.height.resize(W * H)
	if p_style == STYLE_NORTH_AMERICA:
		NorthAmerica.fill(m)
	else:
		m._generate_random()
	m._finish()
	return m


func idx(x: int, y: int) -> int:
	return y * W + x


func in_bounds(x: int, y: int) -> bool:
	return x >= 0 and y >= 0 and x < W and y < H


func t_at(x: int, y: int) -> int:
	return terrain[idx(x, y)] if in_bounds(x, y) else T.OCEAN


func is_land(x: int, y: int) -> bool:
	return in_bounds(x, y) and t_at(x, y) > T.LAKE


func is_ocean(x: int, y: int) -> bool:
	return in_bounds(x, y) and ocean[idx(x, y)] == 1


func is_coastal(x: int, y: int) -> bool:
	if not is_land(x, y):
		return false
	for d: Vector2i in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
		if is_ocean(x + d.x, y + d.y):
			return true
	return false


# --- Random continent ---------------------------------------------------------

func _generate_random() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	var shape := FastNoiseLite.new()
	shape.seed = seed_value
	shape.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	shape.frequency = 0.045
	shape.fractal_octaves = 4
	var ridge := FastNoiseLite.new()
	ridge.seed = seed_value + 11
	ridge.noise_type = FastNoiseLite.TYPE_SIMPLEX
	ridge.fractal_type = FastNoiseLite.FRACTAL_RIDGED
	ridge.frequency = 0.05
	ridge.fractal_octaves = 3
	var wet := FastNoiseLite.new()
	wet.seed = seed_value + 23
	wet.frequency = 0.06
	var warm := FastNoiseLite.new()
	warm.seed = seed_value + 37
	warm.frequency = 0.04

	# Continent sits in the west; the coast wanders; the east is open ocean
	# toward Europe, with islands scattered in it.
	var coast_bias: float = rng.randf_range(0.52, 0.62)
	var islands: Array[Vector3] = []
	for i in rng.randi_range(5, 9):
		islands.append(Vector3(rng.randf_range(W * 0.55, W - 8.0), rng.randf_range(6.0, H - 6.0), rng.randf_range(1.5, 4.0)))
	# Bays bite into the coast; capes push out into the sea.
	var bites: Array[Vector4] = []
	for i in rng.randi_range(3, 5):
		bites.append(Vector4(W * coast_bias + rng.randf_range(-6.0, 2.0), rng.randf_range(8.0, H - 8.0), rng.randf_range(3.5, 8.0), -0.9))
	for i in rng.randi_range(2, 4):
		bites.append(Vector4(W * coast_bias + rng.randf_range(2.0, 8.0), rng.randf_range(8.0, H - 8.0), rng.randf_range(3.0, 6.0), 0.8))
	var elev := PackedFloat32Array()
	elev.resize(W * H)
	for y in H:
		for x in W:
			var nx: float = float(x) / W
			var e: float = shape.get_noise_2d(x, y) * 0.8
			e += (coast_bias - nx) * 1.7
			for b: Vector4 in bites:
				var bd: float = Vector2(x - b.x, (y - b.y) * 0.7).length() / b.z
				if bd < 1.0:
					e += b.w * (1.0 - bd * bd)
			e += 0.08 * sin(float(y) / 9.0 + seed_value % 7)
			for isl: Vector3 in islands:
				var d: float = Vector2(x - isl.x, (y - isl.y) * 0.9).length() / isl.z
				if d < 1.6:
					e = maxf(e, 0.35 * (1.6 - d) + shape.get_noise_2d(x * 2, y * 2) * 0.25)
			if x >= W - 4:
				e = -1.0
			elev[idx(x, y)] = e

	for y in H:
		for x in W:
			var i: int = idx(x, y)
			var e: float = elev[i]
			if e < 0.0:
				terrain[i] = T.OCEAN
				height[i] = 0.0
				continue
			var r: float = (ridge.get_noise_2d(x, y) + 1.0) * 0.5
			var lat: float = float(y) / H + warm.get_noise_2d(x, y) * 0.12
			var moist: float = (wet.get_noise_2d(x, y) + 1.0) * 0.5
			var h: float = clampf(e * 0.6 + r * 0.5, 0.0, 1.0)
			height[i] = h
			if r > 0.86 and e > 0.25:
				terrain[i] = T.MOUNTAINS
			elif r > 0.74 and e > 0.12:
				terrain[i] = T.HILLS
			else:
				terrain[i] = _biome(lat, moist, e)


func _biome(lat: float, moist: float, e: float) -> int:
	if lat < 0.14:
		return T.TUNDRA if moist < 0.55 else T.CONIFER
	if lat < 0.32:
		return T.CONIFER if moist > 0.45 else (T.FOREST if moist > 0.3 else T.PLAINS)
	if lat < 0.62:
		if e < 0.12 and moist > 0.68:
			return T.MARSH
		return T.FOREST if moist > 0.55 else (T.GRASSLAND if moist > 0.38 else T.PLAINS)
	if e < 0.12 and moist > 0.6:
		return T.MARSH
	return T.TROPICAL if moist > 0.55 else T.SAVANNAH


# --- Shared finishing -----------------------------------------------------------

func _finish() -> void:
	_mark_ocean()
	_label_landmasses()
	_compute_depth()
	_build_astar()
	_place_sites()


## Water reaching the map edge is ocean; enclosed water becomes lakes.
func _mark_ocean() -> void:
	ocean.resize(W * H)
	ocean.fill(0)
	var stack: Array[Vector2i] = []
	for y in H:
		stack.append(Vector2i(W - 1, y))
		stack.append(Vector2i(0, y))
	for x in W:
		stack.append(Vector2i(x, 0))
		stack.append(Vector2i(x, H - 1))
	while not stack.is_empty():
		var p: Vector2i = stack.pop_back()
		if not in_bounds(p.x, p.y):
			continue
		var i: int = idx(p.x, p.y)
		if ocean[i] == 1 or terrain[i] > T.LAKE:
			continue
		ocean[i] = 1
		stack.append(p + Vector2i(1, 0))
		stack.append(p + Vector2i(-1, 0))
		stack.append(p + Vector2i(0, 1))
		stack.append(p + Vector2i(0, -1))
	for i in W * H:
		if terrain[i] <= T.LAKE and ocean[i] == 0:
			terrain[i] = T.LAKE


func _label_landmasses() -> void:
	landmass.resize(W * H)
	landmass.fill(-1)
	var sizes: Array[int] = []
	for y in H:
		for x in W:
			if not is_land(x, y) or landmass[idx(x, y)] >= 0:
				continue
			var id: int = sizes.size()
			var count: int = 0
			var stack: Array[Vector2i] = [Vector2i(x, y)]
			landmass[idx(x, y)] = id
			while not stack.is_empty():
				var p: Vector2i = stack.pop_back()
				count += 1
				for o: Vector2i in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
					var q: Vector2i = p + o
					if is_land(q.x, q.y) and landmass[idx(q.x, q.y)] < 0:
						landmass[idx(q.x, q.y)] = id
						stack.append(q)
			sizes.append(count)
	seas.resize(W * H)
	seas.fill(-1)
	var sea_id: int = 0
	for y in H:
		for x in W:
			if not is_ocean(x, y) or seas[idx(x, y)] >= 0:
				continue
			var st: Array[Vector2i] = [Vector2i(x, y)]
			seas[idx(x, y)] = sea_id
			while not st.is_empty():
				var p2: Vector2i = st.pop_back()
				for o: Vector2i in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
					var q2: Vector2i = p2 + o
					if is_ocean(q2.x, q2.y) and seas[idx(q2.x, q2.y)] < 0:
						seas[idx(q2.x, q2.y)] = sea_id
						st.append(q2)
			sea_id += 1
	var best: int = 0
	for i in sizes.size():
		if sizes[i] > sizes[best]:
			best = i
	_main_landmass = best


func _compute_depth() -> void:
	water_depth.resize(W * H)
	var dist := PackedInt32Array()
	dist.resize(W * H)
	dist.fill(99)
	var queue: Array[Vector2i] = []
	for y in H:
		for x in W:
			if is_land(x, y):
				dist[idx(x, y)] = 0
				queue.append(Vector2i(x, y))
	var head: int = 0
	while head < queue.size():
		var p: Vector2i = queue[head]
		head += 1
		var d: int = dist[idx(p.x, p.y)]
		for o: Vector2i in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
			var q: Vector2i = p + o
			if in_bounds(q.x, q.y) and dist[idx(q.x, q.y)] > d + 1:
				dist[idx(q.x, q.y)] = d + 1
				queue.append(q)
	for i in W * H:
		water_depth[i] = float(dist[i])


func _build_astar() -> void:
	_land_astar = AStarGrid2D.new()
	_land_astar.region = Rect2i(0, 0, W, H)
	_land_astar.diagonal_mode = AStarGrid2D.DIAGONAL_MODE_ONLY_IF_NO_OBSTACLES
	_land_astar.update()
	_sea_astar = AStarGrid2D.new()
	_sea_astar.region = Rect2i(0, 0, W, H)
	_sea_astar.diagonal_mode = AStarGrid2D.DIAGONAL_MODE_ONLY_IF_NO_OBSTACLES
	_sea_astar.update()
	for y in H:
		for x in W:
			var p := Vector2i(x, y)
			if is_land(x, y):
				_land_astar.set_point_weight_scale(p, move_cost(x, y))
			else:
				_land_astar.set_point_solid(p, true)
			if not is_ocean(x, y):
				_sea_astar.set_point_solid(p, true)


func move_cost(x: int, y: int) -> float:
	var t: Dictionary = Content.terrains[t_at(x, y)]
	return float(t.get("move", 1.0))


func _place_sites() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value * 7 + 3
	sites.clear()

	# Capital: a temperate coastal tile, preferably wooded, toward the north.
	var best := Vector2i(-1, -1)
	var best_score: float = -INF
	for y in range(8, H - 8):
		for x in range(2, W - 6):
			if not is_coastal(x, y) or landmass[idx(x, y)] != _main_landmass:
				continue
			var t: int = t_at(x, y)
			if t == T.MOUNTAINS or t == T.MARSH:
				continue
			var score: float = -absf(float(y) / H - 0.3) * 10.0 + rng.randf() * 1.5
			if t == T.FOREST or t == T.CONIFER:
				score += 2.0
			if score > best_score:
				best_score = score
				best = Vector2i(x, y)
	if best.x < 0:
		best = Vector2i(W / 3, H / 3)
		terrain[idx(best.x, best.y)] = T.FOREST
	sites.append(_make_site(best, "timber", "sea", 1.0))
	capital_site = 0
	var cap_port: Vector2i = sites[0]["port"]

	# Candidate sites everywhere else, spaced out.
	var cells: Array[Vector2i] = []
	for y in range(2, H - 2):
		for x in range(1, W - 4):
			if is_land(x, y) and t_at(x, y) != T.MOUNTAINS:
				cells.append(Vector2i(x, y))
	for i in range(cells.size() - 1, 0, -1):
		var j: int = rng.randi_range(0, i)
		var tmp: Vector2i = cells[i]
		cells[i] = cells[j]
		cells[j] = tmp
	var min_gap: float = 5.2
	for c: Vector2i in cells:
		if sites.size() >= 80:
			break
		var ok: bool = true
		for s: Dictionary in sites:
			if Vector2(c.x - int(s["x"]), c.y - int(s["y"])).length() < min_gap:
				ok = false
				break
		if not ok:
			continue
		var coastal: bool = is_coastal(c.x, c.y)
		var land_ok: bool = landmass[idx(c.x, c.y)] == landmass[idx(best.x, best.y)]
		var route: String
		if coastal and land_ok:
			route = "sea" if rng.randf() < 0.7 else "land"
		elif coastal:
			route = "sea"
		elif land_ok:
			route = "land"
		else:
			continue
		var res: String = _pick_resource(c, coastal, rng)
		if res == "":
			continue
		var site: Dictionary = _make_site(c, res, route, snappedf(rng.randf_range(0.8, 1.35), 0.05))
		if route == "sea":
			var port: Vector2i = site["port"]
			if port.x < 0 or seas[idx(port.x, port.y)] != seas[idx(cap_port.x, cap_port.y)]:
				if land_ok:
					site["route"] = "land"
				else:
					continue
		sites.append(site)
	_ensure_every_resource(rng)
	_roll_colony_order(rng)


func _roll_colony_order(rng: RandomNumberGenerator) -> void:
	var cap := Vector2(int(sites[0]["x"]), int(sites[0]["y"]))
	var keyed: Array = []
	for i in range(1, sites.size()):
		var d: float = Vector2(int(sites[i]["x"]), int(sites[i]["y"])).distance_to(cap)
		keyed.append([d * rng.randf_range(0.5, 1.6), i, d])
	keyed.sort_custom(func(a: Array, b: Array) -> bool: return a[0] < b[0])
	var limit: int = mini(int(Balance.v("max_colonies")), sites.size())
	var raws: Array[String] = Content.raw_resources()
	var counts: Dictionary = {"timber": 1}
	colony_order = [capital_site]
	for slot in range(1, limit):
		var missing: Array[String] = []
		for r: String in raws:
			if not counts.has(r):
				missing.append(r)
		var pick: int = -1
		var force_iron: bool = slot <= 3 and not counts.has("iron_ore") and slot == 3
		var force_missing: bool = not missing.is_empty() and (missing.size() >= limit - slot or (slot >= 5 and rng.randf() < 0.4))
		if force_iron:
			pick = _nearest_with(keyed, ["iron_ore"])
		elif force_missing:
			pick = _nearest_with(keyed, missing)
		if pick < 0:
			for j in keyed.size():
				var res: String = sites[int(keyed[j][1])]["resource"]
				if int(counts.get(res, 0)) < 2 or j >= 5:
					pick = j
					break
		if pick < 0:
			pick = 0
		var site_index: int = int(keyed[pick][1])
		keyed.remove_at(pick)
		colony_order.append(site_index)
		var rr: String = sites[site_index]["resource"]
		counts[rr] = int(counts.get(rr, 0)) + 1
		if keyed.is_empty():
			break


## Index in `keyed` of the closest remaining site producing one of `wanted`.
func _nearest_with(keyed: Array, wanted: Array) -> int:
	var best: int = -1
	var best_d: float = INF
	for j in keyed.size():
		if wanted.has(sites[int(keyed[j][1])]["resource"]) and float(keyed[j][2]) < best_d:
			best_d = float(keyed[j][2])
			best = j
	return best


func _make_site(c: Vector2i, res: String, route_kind: String, rich: float) -> Dictionary:
	var port := Vector2i(-1, -1)
	for d: Vector2i in [Vector2i(1, 0), Vector2i(0, 1), Vector2i(0, -1), Vector2i(-1, 0), Vector2i(1, 1), Vector2i(1, -1), Vector2i(-1, 1), Vector2i(-1, -1)]:
		if is_ocean(c.x + d.x, c.y + d.y):
			port = c + d
			break
	return {"x": c.x, "y": c.y, "terrain": t_at(c.x, c.y), "resource": res, "route": route_kind, "richness": rich, "port": port}


func _pick_resource(c: Vector2i, coastal: bool, rng: RandomNumberGenerator) -> String:
	var t: Dictionary = Content.terrains[t_at(c.x, c.y)]
	var weights: Dictionary = (t.get("resources", {}) as Dictionary).duplicate()
	if coastal:
		for key: String in (t.get("coastal", {}) as Dictionary).keys():
			weights[key] = float(weights.get(key, 0.0)) + float(t["coastal"][key])
	# Silver favours hills beside mountains.
	if t_at(c.x, c.y) == T.HILLS:
		for d: Vector2i in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
			if t_at(c.x + d.x, c.y + d.y) == T.MOUNTAINS:
				weights["silver"] = float(weights.get("silver", 0.0)) + 2.0
				break
	var total: float = 0.0
	for key: String in weights.keys():
		total += float(weights[key])
	if total <= 0.0:
		return ""
	var r: float = rng.randf() * total
	for key: String in weights.keys():
		r -= float(weights[key])
		if r <= 0.0:
			return key
	return str(weights.keys()[0])


## Every raw good must be obtainable somewhere, or some recipe chains would be
## impossible on this map.
func _ensure_every_resource(rng: RandomNumberGenerator) -> void:
	var counts: Dictionary = {}
	for s: Dictionary in sites:
		counts[s["resource"]] = int(counts.get(s["resource"], 0)) + 1
	for id: String in Content.raw_resources():
		var need: int = 2 - int(counts.get(id, 0))
		if need <= 0:
			continue
		var candidates: Array[int] = []
		for i in range(1, sites.size()):
			var s: Dictionary = sites[i]
			var t: Dictionary = Content.terrains[int(s["terrain"])]
			var fits: bool = (t.get("resources", {}) as Dictionary).has(id) or ((t.get("coastal", {}) as Dictionary).has(id) and s["port"] != Vector2i(-1, -1))
			if fits and int(counts.get(s["resource"], 0)) > 3:
				candidates.append(i)
		if candidates.is_empty():
			for i in range(1, sites.size()):
				if int(counts.get(sites[i]["resource"], 0)) > 3:
					candidates.append(i)
		for n in need:
			if candidates.is_empty():
				break
			var pick: int = candidates.pop_at(rng.randi_range(0, candidates.size() - 1))
			counts[sites[pick]["resource"]] = int(counts[sites[pick]["resource"]]) - 1
			sites[pick]["resource"] = id
			counts[id] = int(counts.get(id, 0)) + 1


# --- Routes -------------------------------------------------------------------

## The route from a site to the capital: {points: PackedVector2Array (tile
## coords, site -> capital), length: travel units}.
func route(site_index: int) -> Dictionary:
	if _route_cache.has(site_index):
		return _route_cache[site_index]
	var s: Dictionary = sites[site_index]
	var cap: Dictionary = sites[capital_site]
	var from := Vector2i(int(s["x"]), int(s["y"]))
	var to := Vector2i(int(cap["x"]), int(cap["y"]))
	var pts := PackedVector2Array()
	var length: float = 0.0
	if site_index == capital_site:
		pts.append(Vector2(from))
	elif s["route"] == "sea":
		var path: Array[Vector2i] = _sea_astar.get_id_path(s["port"], cap["port"])
		pts.append(Vector2(from))
		for p: Vector2i in path:
			pts.append(Vector2(p))
		pts.append(Vector2(to))
		for i in range(1, path.size()):
			length += Vector2(path[i] - path[i - 1]).length()
		length += 2.0
	else:
		var path2: Array[Vector2i] = _land_astar.get_id_path(from, to)
		for i in path2.size():
			pts.append(Vector2(path2[i]))
			if i > 0:
				length += Vector2(path2[i] - path2[i - 1]).length() * move_cost(path2[i].x, path2[i].y)
	var r: Dictionary = {"points": pts, "length": maxf(length, 1.0)}
	_route_cache[site_index] = r
	return r


## The lane from the capital's port east to Europe (off the map edge).
func europe_lane() -> PackedVector2Array:
	var cap: Dictionary = sites[capital_site]
	var port: Vector2i = cap["port"]
	var out := PackedVector2Array()
	out.append(Vector2(int(cap["x"]), int(cap["y"])))
	var path: Array[Vector2i] = _sea_astar.get_id_path(port, Vector2i(W - 1, port.y))
	for p: Vector2i in path:
		out.append(Vector2(p))
	out.append(Vector2(W + 3, port.y))
	return out


func site_index_at(tile: Vector2i) -> int:
	for i in sites.size():
		if int(sites[i]["x"]) == tile.x and int(sites[i]["y"]) == tile.y:
			return i
	return -1
