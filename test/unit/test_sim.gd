extends GutTest

var meta: MetaState


func before_each() -> void:
	meta = MetaState.new()


func _fresh_run(seed_value: int = 3) -> RunState:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	return RunState.create("english", rng)


func _developed_run() -> RunState:
	var run := _fresh_run()
	for i in 4:
		run.colonies[i].founded = true
		run.colonies[i].prod_level = 5
		run.colonies[i].colonists = 1
	run.colonists_owned = 6
	var w := run.workshop("planks")
	w.built = true
	w.colonists = 2
	run.hold["timber"] = true
	return run


func _simulate(run: RunState, total: float, step: float) -> SimEvents:
	var ev := SimEvents.new()
	var t: float = 0.0
	while t < total - 1e-6:
		Sim.step(run, meta, step, ev)
		t += step
	return ev


func test_capital_produces_and_sells_timber() -> void:
	var run := _fresh_run()
	_simulate(run, 10.0, 0.1)
	assert_almost_eq(run.gold, 10.0, 0.01)
	assert_eq(run.lifetime_gold, run.gold)


func test_result_is_independent_of_step_size() -> void:
	var a := _developed_run()
	var b := _developed_run()
	var c := _developed_run()
	_simulate(a, 3600.0, 0.1)
	_simulate(b, 3600.0, 1.0)
	_simulate(c, 3600.0, 5.0)
	assert_gt(a.lifetime_gold, 1000.0)
	assert_almost_eq(b.lifetime_gold, a.lifetime_gold, a.lifetime_gold * 0.01)
	assert_almost_eq(c.lifetime_gold, a.lifetime_gold, a.lifetime_gold * 0.01)
	assert_almost_eq(float(c.crafted.get("planks", 0)), float(a.crafted.get("planks", 0)), float(a.crafted.get("planks", 0)) * 0.02 + 2.0)


func test_one_big_step_matches_many_small_ones() -> void:
	var a := _developed_run()
	var b := _developed_run()
	_simulate(a, 600.0, 0.1)
	var ev := SimEvents.new()
	Sim.step(b, meta, 600.0, ev)
	assert_almost_eq(b.lifetime_gold, a.lifetime_gold, a.lifetime_gold * 0.02)


func test_transport_caps_delivery_rate() -> void:
	var run := _fresh_run()
	var c := run.colony("fishery")
	c.founded = true
	c.prod_level = 200
	_simulate(run, 600.0, 0.5)
	var tp: float = Balance.route_throughput(run, meta, c)
	var cod_sold: float = (run.lifetime_gold - 600.0) / Content.price("cod")
	assert_lt(cod_sold, tp * 600.0 * 1.05)
	assert_gt(c.stock, 100.0, "surplus piles up at the colony")


func test_held_goods_go_to_warehouse() -> void:
	var run := _fresh_run()
	run.hold["timber"] = true
	_simulate(run, 5.0, 0.1)
	assert_almost_eq(run.stock_of("timber"), 5.0, 0.01)
	assert_almost_eq(run.gold, 0.0, 0.001)


func test_workshop_waits_for_inputs() -> void:
	var run := _fresh_run()
	var w := run.workshop("planks")
	w.built = true
	w.colonists = 1
	run.hold["timber"] = true
	run.hold["planks"] = true
	_simulate(run, 10.0, 0.1)
	# 1 timber/s in, 2 timber per plank.
	assert_almost_eq(run.stock_of("planks"), 5.0, 1.0)
	assert_lt(run.stock_of("timber"), 2.01)


func test_crafted_goods_can_chain() -> void:
	var run := _fresh_run()
	run.warehouse["pig_iron"] = 30.0
	run.warehouse["planks"] = 10.0
	run.hold["pig_iron"] = true
	run.hold["planks"] = true
	run.hold["tools"] = true
	var w := run.workshop("tools")
	w.built = true
	w.colonists = 1
	run.hold["timber"] = false
	_simulate(run, 60.0, 0.1)
	assert_eq(int(run.crafted.get("tools", 0)), 10)
	assert_almost_eq(run.stock_of("pig_iron"), 0.0, 0.001)


func test_discovery_records_first_arrival() -> void:
	var run := _fresh_run()
	var ev := SimEvents.new()
	Sim.step(run, meta, 1.0, ev)
	assert_true(run.discovered.has("timber"))
	assert_eq(ev.discovered, ["timber"] as Array[String])
