extends GutTest

var meta: MetaState
var _saved_balance: Dictionary


func before_each() -> void:
	# Market demand moves prices; these tests assume list prices.
	_saved_balance = Balance.k.duplicate()
	Balance.k["market_up_mult"] = 1.0
	Balance.k["market_down_mult"] = 1.0
	meta = MetaState.new()


func after_each() -> void:
	Balance.k = _saved_balance


func _fresh_run(seed_value: int = 3) -> RunState:
	return RunState.create("dutch", WorldMap.STYLE_RANDOM, seed_value)


func _developed_run() -> RunState:
	var run := _fresh_run()
	for i in 3:
		run.found_next()
	for c: RunState.ColonyState in run.colonies:
		c.prod_level = 5
		c.colonists = 1
	run.colonists_owned = 6
	var w := run.workshop("lumber")
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
	assert_eq(run.resource_of(run.capital()), "timber")
	_simulate(run, 10.0, 0.1)
	# Dutch: +15% production. Capital richness is 1, timber sells for 1.
	assert_almost_eq(run.gold, 11.5, 0.05)
	assert_eq(run.lifetime_gold, run.gold)


func test_colony_value_is_independent_of_its_good() -> void:
	var run := _fresh_run()
	var c := run.found_next()
	var gold_per_sec: float = Balance.base_units(run, c) * Content.price(run.resource_of(c)) / Balance.richness(run, c)
	assert_almost_eq(gold_per_sec, Balance.tier_value(1), 0.001)


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
	assert_almost_eq(float(c.crafted.get("lumber", 0)), float(a.crafted.get("lumber", 0)), float(a.crafted.get("lumber", 0)) * 0.02 + 2.0)


func test_one_big_step_matches_many_small_ones() -> void:
	var a := _developed_run()
	var b := _developed_run()
	_simulate(a, 600.0, 0.1)
	var ev := SimEvents.new()
	Sim.step(b, meta, 600.0, ev)
	assert_almost_eq(b.lifetime_gold, a.lifetime_gold, a.lifetime_gold * 0.02)


func test_transport_caps_delivery_rate() -> void:
	var run := _fresh_run()
	var c := run.found_next()
	c.prod_level = 400
	var ev := _simulate(run, 600.0, 0.5)
	var tp: float = Balance.route_throughput(run, meta, c)
	var delivered: float = float(ev.delivered.get(run.resource_of(c), 0.0))
	assert_lt(delivered, tp * 600.0 * 1.05)
	assert_gt(c.stock, 100.0, "surplus piles up at the colony")


func test_held_goods_go_to_warehouse() -> void:
	var run := _fresh_run()
	run.hold["timber"] = true
	_simulate(run, 5.0, 0.1)
	assert_almost_eq(run.stock_of("timber"), 5.75, 0.05)
	assert_almost_eq(run.gold, 0.0, 0.001)


func test_workshop_waits_for_inputs() -> void:
	var run := _fresh_run()
	var w := run.workshop("lumber")
	w.built = true
	w.colonists = 1
	run.hold["timber"] = true
	run.hold["lumber"] = true
	_simulate(run, 10.0, 0.1)
	# 1.15 timber/s in, 2 timber per board.
	assert_almost_eq(run.stock_of("lumber"), 5.75, 1.0)
	assert_lt(run.stock_of("timber"), 2.01)


func test_crafted_goods_can_chain() -> void:
	var run := _fresh_run()
	run.warehouse["pig_iron"] = 10.0
	run.warehouse["lumber"] = 10.0
	for id: String in ["pig_iron", "lumber", "tools"]:
		run.hold[id] = true
	var w := run.workshop("tools")
	w.built = true
	w.colonists = 1
	_simulate(run, 60.0, 0.1)
	assert_eq(int(run.crafted.get("tools", 0)), 10)
	assert_almost_eq(run.stock_of("pig_iron"), 0.0, 0.001)


func test_workshop_levels_scale_exponentially() -> void:
	var run := _fresh_run()
	var w := run.workshop("lumber")
	w.colonists = 1
	var s0: float = Balance.workshop_speed(run, meta, w)
	w.level = 10
	assert_almost_eq(Balance.workshop_speed(run, meta, w), s0 * pow(Balance.v("workshop_speed_growth"), 10), 0.001)


func test_discovery_records_first_arrival() -> void:
	var run := _fresh_run()
	var ev := SimEvents.new()
	Sim.step(run, meta, 1.0, ev)
	assert_true(run.discovered.has("timber"))
	assert_eq(ev.discovered, ["timber"] as Array[String])


func test_royal_favor_doubles_output_then_expires_mid_step() -> void:
	var a := _fresh_run()
	var b := _fresh_run()
	a.favor_seconds = 30.0
	b.favor_seconds = 30.0
	_simulate(a, 100.0, 0.1)
	var ev := SimEvents.new()
	Sim.step(b, meta, 100.0, ev)
	# 30s at 2.3/s + 70s at 1.15/s
	assert_almost_eq(a.lifetime_gold, 149.5, 0.5)
	assert_almost_eq(b.lifetime_gold, 149.5, 0.5)
	assert_eq(b.favor_seconds, 0.0)
