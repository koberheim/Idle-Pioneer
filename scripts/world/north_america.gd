## A simplified North America (Labrador to Panama, the Rockies to the
## Atlantic), rasterised from coarse longitude/latitude outlines.
class_name NorthAmerica
extends RefCounted

const LON_MIN := -110.0
const LON_MAX := -48.0
const LAT_MAX := 62.0
const LAT_MIN := 7.0

const MAINLAND := [
	[-116, 64], [-78, 63], [-72, 62.4], [-64.5, 60.4], [-61.5, 56.5], [-57.5, 53.8], [-55.8, 52.1],
	[-59, 50.3], [-66, 50.2], [-68.5, 49.1], [-71.2, 46.9], [-70, 47.6], [-65.5, 49.1], [-64.3, 48.4],
	[-64.8, 47], [-64, 46.2], [-61.5, 45.9], [-60, 46.3], [-59.8, 45.9], [-63.5, 44.5], [-65.8, 43.5],
	[-66.3, 44.7], [-64.5, 45.3], [-67, 44.9], [-68.8, 44.3], [-70.2, 43.6], [-70.8, 42.6],
	[-69.9, 41.8], [-71.5, 41.4], [-73.8, 40.8], [-74.1, 40.4], [-74, 39.6], [-74.9, 38.9],
	[-75.2, 38.3], [-75.9, 37.2], [-76.2, 36.9], [-75.5, 35.3], [-76.5, 34.7], [-77.9, 33.9],
	[-79.8, 32.7], [-81, 31.6], [-81.4, 30.3], [-80.6, 28.4], [-80.1, 26.6], [-80.4, 25.3],
	[-81.2, 25.2], [-81.8, 26.3], [-82.7, 27.9], [-83.6, 29.8], [-85.1, 29.7], [-87.4, 30.3],
	[-89.4, 30.2], [-89.2, 29.1], [-90.5, 29.2], [-93.8, 29.7], [-95, 29.3], [-97.2, 27.7],
	[-97.4, 25.9], [-97.7, 22.3], [-96.1, 19.2], [-94.5, 18.2], [-91.5, 18.7], [-90.4, 20.9],
	[-87.1, 21.5], [-87.5, 19], [-88.3, 16.5], [-88.5, 15.8], [-86, 15.9], [-83.3, 15],
	[-83.6, 12], [-83.2, 10], [-81, 8.9], [-79.5, 9.5], [-77.6, 8.6], [-77.6, 7.6], [-80, 7.3],
	[-83, 8.3], [-85.8, 10.5], [-87.5, 13], [-91.5, 14], [-94, 16.1], [-96.5, 15.7], [-100, 17],
	[-105.4, 20], [-105.6, 22.5], [-109, 25.5], [-112, 29], [-116, 32],
]
const SOUTH_AMERICA := [
	[-77.6, 8.6], [-76, 9.6], [-75.5, 10.5], [-74, 11.2], [-72, 12.3], [-71.5, 11], [-70, 11.9],
	[-68, 10.6], [-65, 10.1], [-62, 10.7], [-60.5, 8.5], [-58, 6], [-78, 6],
]
const WATERS := [
	# Hudson Bay and James Bay
	[[-95, 64], [-95, 60], [-94.5, 58.8], [-92.5, 57], [-88, 56.5], [-82.5, 55.1], [-82.2, 53], [-80, 51.3], [-78.8, 54.5], [-77.3, 55.5], [-77, 58], [-78.1, 60.5], [-78, 63]],
	# Ungava Bay
	[[-70.5, 61.2], [-68.5, 58.3], [-66.2, 58.6], [-65.5, 60.2], [-66.5, 61.5]],
	# Great Lakes
	[[-92.2, 46.7], [-89.5, 48.1], [-86, 48.9], [-84.5, 46.9], [-87.2, 46.4], [-90, 46.6]],
	[[-87.9, 41.6], [-88, 44.1], [-85.4, 45.9], [-86.4, 43.4], [-86.6, 42.1]],
	[[-84.8, 46], [-81.4, 45.9], [-80, 44.6], [-81.8, 43], [-82.6, 43.3], [-83.6, 44.8]],
	[[-83.4, 41.6], [-80.8, 42.2], [-78.9, 42.9], [-79.6, 42.3], [-81.6, 41.4]],
	[[-79.9, 43.3], [-76.9, 43.9], [-76.1, 43.4], [-77.6, 43.2]],
	# St Lawrence estuary and the Gulf, cut into the coast polygon
	[[-71.2, 46.9], [-68.5, 49.1], [-66, 50.2], [-59, 50.3], [-60, 46.3], [-61.5, 45.9], [-64, 46.2], [-64.8, 47], [-64.3, 48.4], [-65.5, 49.1], [-70, 47.6]],
	# Chesapeake Bay
	[[-76.4, 37], [-76, 38.2], [-76.4, 39.5], [-76.8, 38.9], [-76.6, 37.6]],
]
const ISLANDS := [
	[[-59.3, 47.6], [-56, 49.6], [-55.4, 51.6], [-53, 49.3], [-52.6, 47.5], [-55, 46.8], [-58, 47.5]],
	[[-85, 21.9], [-82.5, 23.1], [-80, 23.2], [-77.5, 21.8], [-74.1, 20.2], [-77.5, 19.8], [-80, 21.7], [-83, 21.9], [-84.5, 21.4]],
	[[-74.5, 19.9], [-72.8, 19.95], [-70, 19.7], [-68.3, 18.6], [-70, 18.1], [-71.5, 17.6], [-74.4, 18.3]],
	[[-78.4, 18.5], [-76.2, 18.3], [-76.7, 17.8], [-78.3, 18.1]],
	[[-67.3, 18.6], [-65.5, 18.45], [-65.7, 17.9], [-67.2, 17.9]],
	[[-64.5, 32.4], [-64.8, 32.2], [-64.6, 32.1]],
]
## Small islands as [lon, lat, radius in degrees].
const DOTS := [
	[-78, 24.4, 0.6], [-77.3, 26.4, 0.5], [-78.6, 26.6, 0.4], [-76.2, 25, 0.45], [-75.5, 23.6, 0.4],
	[-73.6, 21.1, 0.4], [-61.5, 16.2, 0.4], [-61, 14.6, 0.35], [-59.5, 13.1, 0.3], [-61.3, 10.5, 0.55],
	[-63.2, 46.4, 0.5], [-70.6, 41.4, 0.3], [-72.8, 40.9, 0.5],
]
## Mountain chains as polylines with a half-width in degrees.
const APPALACHIANS := [[-85, 34.2], [-82.5, 35.8], [-80.2, 37.5], [-78, 39.5], [-75.8, 41.5], [-73.8, 43.2], [-71.5, 44.6], [-69.5, 45.8]]
const SIERRA_MADRE := [[-108, 28], [-105.5, 25], [-103, 21.5], [-99, 19.3], [-96.5, 17.2]]
const ROCKIES := [[-109.5, 62], [-108.5, 50], [-107, 44], [-106, 38], [-106.5, 33]]


static func to_tile(lon: float, lat: float) -> Vector2:
	var x: float = (lon - LON_MIN) / (LON_MAX - LON_MIN) * WorldMap.W
	var y: float = (LAT_MAX - lat) / (LAT_MAX - LAT_MIN) * WorldMap.H
	return Vector2(x, y)


static func to_lonlat(x: float, y: float) -> Vector2:
	return Vector2(LON_MIN + x / WorldMap.W * (LON_MAX - LON_MIN), LAT_MAX - y / WorldMap.H * (LAT_MAX - LAT_MIN))


static func fill(m: WorldMap) -> void:
	var wet := FastNoiseLite.new()
	wet.seed = m.seed_value + 5
	wet.frequency = 0.08
	var rough := FastNoiseLite.new()
	rough.seed = m.seed_value + 9
	rough.frequency = 0.12
	var polys: Array = [_poly(MAINLAND), _poly(SOUTH_AMERICA)]
	var isles: Array = []
	for p: Array in ISLANDS:
		isles.append(_poly(p))
	var waters: Array = []
	for p: Array in WATERS:
		waters.append(_poly(p))

	for y in WorldMap.H:
		for x in WorldMap.W:
			var ll: Vector2 = to_lonlat(x + 0.5, y + 0.5)
			var land: bool = false
			for poly: Dictionary in polys:
				if _inside(poly, ll):
					land = true
					break
			if land:
				for poly2: Dictionary in waters:
					if _inside(poly2, ll):
						land = false
						break
			if not land:
				for poly3: Dictionary in isles:
					if _inside(poly3, ll):
						land = true
						break
			if not land:
				for d: Array in DOTS:
					if Vector2(ll.x - float(d[0]), (ll.y - float(d[1])) * 1.4).length() < float(d[2]) + 0.35:
						land = true
						break
			var i: int = m.idx(x, y)
			if not land or x >= WorldMap.W - 2:
				m.terrain[i] = WorldMap.T.OCEAN
				m.height[i] = 0.0
				continue
			var moist: float = (wet.get_noise_2d(x, y) + 1.0) * 0.5
			var r: float = (rough.get_noise_2d(x, y) + 1.0) * 0.5
			var ridge_d: float = minf(_dist_to_line(APPALACHIANS, ll), minf(_dist_to_line(SIERRA_MADRE, ll), _dist_to_line(ROCKIES, ll)))
			var h: float = clampf(0.25 + (1.2 - ridge_d) * 0.35 + r * 0.25, 0.0, 1.0)
			m.height[i] = h
			var t: int
			if ll.x < -103.5 and ll.y > 30.0:
				t = WorldMap.T.MOUNTAINS if r > 0.45 else WorldMap.T.HILLS
			elif ridge_d < 0.55 and r > 0.4:
				t = WorldMap.T.MOUNTAINS if ll.x < -95.0 or r > 0.72 else WorldMap.T.HILLS
			elif ridge_d < 1.3 and r > 0.45:
				t = WorldMap.T.HILLS
			else:
				t = _biome(ll, moist, r)
			m.terrain[i] = t


static func _biome(ll: Vector2, moist: float, r: float) -> int:
	var lat: float = ll.y
	var lon: float = ll.x
	if lat > 57.0:
		return WorldMap.T.TUNDRA if moist < 0.6 else WorldMap.T.CONIFER
	if lat > 47.5:
		return WorldMap.T.CONIFER if moist > 0.35 else WorldMap.T.FOREST
	if lon < -97.0 and lat > 26.0:
		return WorldMap.T.GRASSLAND if moist > 0.45 else WorldMap.T.PLAINS
	if lat > 36.5:
		return WorldMap.T.FOREST if moist > 0.5 else (WorldMap.T.PLAINS if r > 0.5 else WorldMap.T.GRASSLAND)
	if lat > 28.5:
		if lon > -92.0 and moist > 0.7:
			return WorldMap.T.MARSH
		return WorldMap.T.FOREST if moist > 0.55 else (WorldMap.T.SAVANNAH if lon < -95.0 else WorldMap.T.PLAINS)
	if lat > 24.0 and lon > -82.5 and lon < -80.0:
		return WorldMap.T.MARSH
	if lon < -97.0 and lat > 18.0:
		return WorldMap.T.SAVANNAH
	return WorldMap.T.TROPICAL if moist > 0.35 else WorldMap.T.SAVANNAH


static func _poly(points: Array) -> Dictionary:
	var pts := PackedVector2Array()
	var mn := Vector2(INF, INF)
	var mx := Vector2(-INF, -INF)
	for p: Array in points:
		var v := Vector2(float(p[0]), float(p[1]))
		pts.append(v)
		mn = mn.min(v)
		mx = mx.max(v)
	return {"pts": pts, "min": mn, "max": mx}


static func _inside(poly: Dictionary, p: Vector2) -> bool:
	var mn: Vector2 = poly["min"]
	var mx: Vector2 = poly["max"]
	if p.x < mn.x or p.y < mn.y or p.x > mx.x or p.y > mx.y:
		return false
	return Geometry2D.is_point_in_polygon(p, poly["pts"])


static func _dist_to_line(line: Array, p: Vector2) -> float:
	var best: float = INF
	for i in line.size() - 1:
		var a := Vector2(float(line[i][0]), float(line[i][1]))
		var b := Vector2(float(line[i + 1][0]), float(line[i + 1][1]))
		best = minf(best, p.distance_to(Geometry2D.get_closest_point_to_segment(p, a, b)))
	return best
