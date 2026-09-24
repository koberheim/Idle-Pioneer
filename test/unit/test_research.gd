extends GutTest
## The Philosophical Society: gating, costs and effects of studies.

var meta: MetaState


func before_each() -> void:
	meta = MetaState.new()
	meta.runs_completed = 3


func _run(colonies: int) -> RunState:
	var run := RunState.create("english", WorldMap.STYLE_RANDOM, 3)
	for i in colonies - 1:
		run.found_next()
	return run


func test_every_study_has_valid_data() -> void:
	assert_gt(Content.research.size(), 80)
	for def: Dictionary in Content.research:
		assert_false(Content.study(str(def["id"])).is_empty())
		for r: Variant in def.get("requires", []):
			assert_false(Content.study(str(r)).is_empty(), "%s requires %s" % [def["id"], r])


func test_locked_before_third_independence() -> void:
	var run := _run(1)
	meta.runs_completed = 2
	var first: String = str(Content.research[0]["id"])
	assert_eq(Balance.study_block(run, meta, first), "Locked")


func test_tier_needs_colonies_and_prerequisites() -> void:
	var run := _run(1)
	for def: Dictionary in Content.research:
		var block: String = Balance.study_block(run, meta, str(def["id"]))
		if int(def["tier"]) >= 2:
			assert_ne(block, "", "%s should be blocked with one colony" % def["id"])


func test_study_applies_its_effect_and_resets_with_the_run() -> void:
	var run := _run(8)
	var target: Dictionary = {}
	for def: Dictionary in Content.research:
		if def["effect"]["type"] == "production" and (def.get("requires", []) as Array).is_empty() and int(def["tier"]) == 1:
			target = def
			break
	if target.is_empty():
		pass_test("no tier-1 production study")
		return
	var c: RunState.ColonyState = run.colonies[0]
	var before: float = Balance.production_rate(run, meta, c)
	run.research[target["id"]] = 1
	run.research_version += 1
	var after: float = Balance.production_rate(run, meta, c)
	var t: Array = target["effect"]["targets"]
	if t.has("all") or t.has(run.resource_of(c)) or t.has("land"):
		assert_gt(after, before)
	var fresh := RunState.create("english", WorldMap.STYLE_RANDOM, 3)
	assert_true(fresh.research.is_empty())


func test_repeatable_costs_triple() -> void:
	var run := _run(4)
	for def: Dictionary in Content.research:
		if bool(def.get("repeatable", false)) and int(def["tier"]) == 1:
			var id: String = str(def["id"])
			var c0: float = float(Balance.study_cost(run, id)["gold"])
			run.research[id] = 1
			var c1: float = float(Balance.study_cost(run, id)["gold"])
			assert_almost_eq(c1 / c0, Balance.v("research_repeat_cost_growth"), 0.01)
			return
	fail_test("no tier-1 repeatable")


func test_recipe_input_study_trims_inputs() -> void:
	var run := _run(1)
	for def: Dictionary in Content.research:
		if def["effect"]["type"] == "recipe_input":
			var t: Array = def["effect"]["targets"]
			run.research[def["id"]] = 1
			run.research_version += 1
			assert_eq(int(Balance.recipe_inputs(run, str(t[0]))[str(t[1])]), int(def["effect"]["value"]))
			return
	pass_test("no recipe_input study")


func test_research_saves_and_loads() -> void:
	var run := _run(2)
	var id: String = str(Content.research[0]["id"])
	run.research[id] = 2
	var back := RunState.from_dict(JSON.parse_string(JSON.stringify(run.to_dict())))
	assert_eq(back.study_level(id), 2)
