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


func test_every_site_fits_its_terrain_across_many_maps() -> void:
	var bad: Array[String] = []
	var missing: Array[String] = []
	for style: String in [WorldMap.STYLE_RANDOM, WorldMap.STYLE_NORTH_AMERICA]:
		for seed_value in range(1, 101 if style == WorldMap.STYLE_RANDOM else 21):
			var w := WorldMap.build(style, seed_value)
			var have := {}
			for i in w.sites.size():
				var s: Dictionary = w.sites[i]
				if i != w.capital_site and not w.site_fits(s, str(s["resource"])):
					bad.append("%s/%d site %d: %s on terrain %d" % [style, seed_value, i, s["resource"], int(s["terrain"])])
			for i in w.colony_order:
				have[str(w.sites[i]["resource"])] = true
			for id: String in Content.raw_resources():
				if not have.has(id):
					missing.append("%s/%d lacks %s" % [style, seed_value, id])
	assert_eq(bad.size(), 0, "sites on unsuitable terrain: %s" % str(bad.slice(0, 5)))
	assert_eq(missing.size(), 0, "maps missing goods: %s" % str(missing.slice(0, 5)))


func test_saved_world_reloads_identically() -> void:
	for style: String in [WorldMap.STYLE_RANDOM, WorldMap.STYLE_NORTH_AMERICA]:
		var w := WorldMap.build(style, 42)
		var d: Dictionary = JSON.parse_string(JSON.stringify(w.to_saved()))
		var back := WorldMap.from_saved(d)
		assert_not_null(back)
		assert_eq(back.terrain, w.terrain)
		assert_eq(back.colony_order, w.colony_order)
		assert_eq(back.sites.size(), w.sites.size())
		for i in w.colony_order:
			assert_eq(back.sites[i]["resource"], w.sites[i]["resource"])
			assert_almost_eq(float(back.route(i)["length"]), float(w.route(i)["length"]), 0.001)


func test_run_keeps_its_world_even_if_generation_changes() -> void:
	var run := RunState.create("english", WorldMap.STYLE_RANDOM, 9)
	run.found_next()
	var d: Dictionary = JSON.parse_string(JSON.stringify(run.to_dict()))
	# Pretend the generator now makes a different map for this seed.
	d["map_seed"] = 12345
	var back := RunState.from_dict(d)
	assert_eq(back.world.terrain, run.world.terrain)
	assert_eq(back.resource_of(back.colonies[1]), run.resource_of(run.colonies[1]))
	# A save from before worlds were stored still loads by regenerating.
	var legacy: Dictionary = JSON.parse_string(JSON.stringify(run.to_dict()))
	legacy.erase("world")
	assert_not_null(RunState.from_dict(legacy))
