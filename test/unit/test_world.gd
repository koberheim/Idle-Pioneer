extends GutTest


func test_random_maps_are_deterministic_per_seed() -> void:
	var a := WorldMap.build(WorldMap.STYLE_RANDOM, 42)
	var b := WorldMap.build(WorldMap.STYLE_RANDOM, 42)
	var c := WorldMap.build(WorldMap.STYLE_RANDOM, 43)
	assert_eq(a.terrain, b.terrain)
	assert_eq(a.colony_order, b.colony_order)
	assert_ne(a.terrain, c.terrain, "different seeds give different maps")


func test_every_map_can_hold_25_colonies_covering_every_raw_good() -> void:
	for s in [1, 2, 3, 4, 5, 6, 7, 8]:
		var m := WorldMap.build(WorldMap.STYLE_RANDOM, s)
		assert_eq(m.colony_order.size(), int(Balance.v("max_colonies")), "seed %d" % s)
		var seen: Dictionary = {}
		for i: int in m.colony_order:
			seen[m.sites[i]["resource"]] = true
		for r: String in Content.raw_resources():
			assert_true(seen.has(r), "seed %d is missing %s" % [s, r])


func test_iron_is_found_early() -> void:
	for s in [1, 2, 3, 4, 5]:
		var m := WorldMap.build(WorldMap.STYLE_RANDOM, s)
		var found: bool = false
		for n in 4:
			if m.sites[m.colony_order[n]]["resource"] == "iron_ore":
				found = true
		assert_true(found, "seed %d" % s)


func test_every_route_reaches_the_capital() -> void:
	for style: String in [WorldMap.STYLE_RANDOM, WorldMap.STYLE_NORTH_AMERICA]:
		var m := WorldMap.build(style, 9)
		var cap: Dictionary = m.sites[m.capital_site]
		for i: int in m.colony_order:
			var r: Dictionary = m.route(i)
			var pts: PackedVector2Array = r["points"]
			assert_false(pts.is_empty())
			if i != m.capital_site:
				assert_gt(float(r["length"]), 0.0)
				assert_eq(pts[pts.size() - 1], Vector2(int(cap["x"]), int(cap["y"])), "%s site %d" % [style, i])


func test_sea_sites_are_coastal_and_capital_is_on_the_mainland_coast() -> void:
	var m := WorldMap.build(WorldMap.STYLE_RANDOM, 3)
	var cap: Dictionary = m.sites[m.capital_site]
	assert_true(m.is_coastal(int(cap["x"]), int(cap["y"])))
	for s: Dictionary in m.sites:
		if s["route"] == "sea":
			assert_ne(s["port"], Vector2i(-1, -1))


func test_north_america_has_its_landmarks() -> void:
	var m := WorldMap.build(WorldMap.STYLE_NORTH_AMERICA, 1)
	var florida: Vector2 = NorthAmerica.to_tile(-81.4, 28.0)
	var gulf: Vector2 = NorthAmerica.to_tile(-90.0, 25.0)
	var superior: Vector2 = NorthAmerica.to_tile(-87.5, 47.6)
	var cuba: Vector2 = NorthAmerica.to_tile(-79.5, 22.0)
	assert_true(m.is_land(int(florida.x), int(florida.y)), "Florida")
	assert_true(m.is_ocean(int(gulf.x), int(gulf.y)), "Gulf of Mexico")
	assert_eq(m.t_at(int(superior.x), int(superior.y)), WorldMap.T.LAKE, "Lake Superior")
	assert_true(m.is_land(int(cuba.x), int(cuba.y)), "Cuba")
