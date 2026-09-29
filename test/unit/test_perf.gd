extends GutTest
## Late-game offline catch-up must stay fast: many short voyages are settled
## in bulk rather than one at a time.

var meta: MetaState


func before_each() -> void:
	meta = MetaState.new()


func _late_run() -> RunState:
	var run := RunState.create("english", WorldMap.STYLE_RANDOM, 7)
	run.started_unix = 1000.0  # same market rolls for every copy
	while run.found_next() != null:
		pass
	for c: RunState.ColonyState in run.colonies:
		c.prod_level = 300
		c.cargo_level = 100
		c.speed_level = 300
	return run


func test_four_hours_catch_up_is_fast() -> void:
	var run := _late_run()
	var ev := SimEvents.new()
	var t0: int = Time.get_ticks_msec()
	var remaining: float = 4.0 * 3600.0
	while remaining > 0.0:
		var s: float = minf(Balance.v("offline_step_seconds"), remaining)
		Sim.step(run, meta, s, ev)
		remaining -= s
	var ms: int = Time.get_ticks_msec() - t0
	gut.p("4h catch-up: %d ms" % ms)
	assert_lt(ms, 2500, "4h catch-up took %d ms" % ms)
	assert_gt(ev.trips, 1000)
	assert_lte(ev.shipments.size(), run.colonies.size())


func test_batched_trips_match_step_by_step() -> void:
	var a := _late_run()
	var b := _late_run()
	var ea := SimEvents.new()
	var eb := SimEvents.new()
	# One big step (batched) against many tiny ones (mostly trip by trip).
	Sim.step(a, meta, 60.0, ea)
	for i in 6000:
		Sim.step(b, meta, 0.01, eb)
	assert_almost_eq(a.lifetime_gold / b.lifetime_gold, 1.0, 0.02)


func test_heaviest_realistic_catch_up() -> void:
	var run := _late_run()
	meta.runs_completed = 3
	for r: Dictionary in Content.relics:
		meta.relics.append(str(r["id"]))
	for def: Dictionary in Content.recipes:
		var w := run.workshop(str(def["id"]))
		w.built = true
		w.colonists = 3
		w.level = 60
		for input_id: String in (def["inputs"] as Dictionary).keys():
			run.hold[input_id] = true
	run.colonists_owned = 500
	var n: int = 0
	for s: Dictionary in Content.research:
		if n < 60 and (s.get("requires", []) as Array).size() <= 1:
			run.research[str(s["id"])] = 2 if bool(s.get("repeatable", false)) else 1
			n += 1
	run.research_version += 1
	for id: String in ["timber", "iron_ore", "cotton", "hides", "grain", "cod"]:
		run.warehouse[id] = 1.0e6
	var ev := SimEvents.new()
	var t0: int = Time.get_ticks_msec()
	var remaining: float = 8.0 * 3600.0
	run.sim_rate = Balance.v("offline_efficiency")
	while remaining > 0.0:
		var s: float = minf(Balance.v("offline_step_seconds"), remaining)
		Sim.step(run, meta, s, ev)
		remaining -= s
	run.sim_rate = 1.0
	var ms: int = Time.get_ticks_msec() - t0
	gut.p("heaviest 8h catch-up: %d ms" % ms)
	assert_lt(ms, 4000, "heaviest catch-up took %d ms" % ms)
	assert_gt(ev.gold_earned, 0.0)
	assert_false(is_nan(run.gold) or is_inf(run.gold))
