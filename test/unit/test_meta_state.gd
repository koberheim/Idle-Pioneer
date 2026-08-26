## Tests for MetaState (task G2).
extends GutTest


func _make_populated_meta_state() -> MetaState:
	var s := MetaState.new()
	s.liberty = 7
	s.lifetime_liberty_earned = 20
	s.upgrades = {&"industry": 2, &"navigation": 1}
	s.lifetime_gold_earned = 45210.5
	s.runs_completed = 3
	s.recipes_ever_unlocked = [&"planks_recipe", &"salt_cod_recipe"]
	s.stats = {"best_run_gold": 9000.5, "fastest_run_seconds": 1234}
	return s


func test_to_dict_from_dict_round_trip_preserves_all_fields() -> void:
	var original: MetaState = _make_populated_meta_state()
	var restored: MetaState = MetaState.from_dict(original.to_dict())

	assert_eq(restored.liberty, original.liberty)
	assert_eq(restored.lifetime_liberty_earned, original.lifetime_liberty_earned)
	assert_eq(restored.upgrades, original.upgrades)
	assert_eq(restored.lifetime_gold_earned, original.lifetime_gold_earned)
	assert_eq(restored.runs_completed, original.runs_completed)
	assert_eq(restored.recipes_ever_unlocked, original.recipes_ever_unlocked)
	assert_eq(restored.stats, original.stats)


## Same JSON int-vs-float gotcha as RunState (task G1) - route through a real
## JSON string, not just the in-memory dict, to actually exercise it.
func test_round_trip_through_actual_json_string_preserves_int_fields() -> void:
	var original: MetaState = _make_populated_meta_state()

	var json_text: String = JSON.stringify(original.to_dict())
	var parsed: Variant = JSON.parse_string(json_text)
	var restored: MetaState = MetaState.from_dict(parsed as Dictionary)

	assert_typeof(restored.liberty, TYPE_INT)
	assert_eq(restored.liberty, 7)
	assert_typeof(restored.lifetime_liberty_earned, TYPE_INT)
	assert_eq(restored.lifetime_liberty_earned, 20)
	assert_typeof(restored.runs_completed, TYPE_INT)
	assert_eq(restored.runs_completed, 3)
	assert_typeof(restored.stats["fastest_run_seconds"], TYPE_INT)
	assert_eq(restored.stats["fastest_run_seconds"], 1234)


func test_upgrade_levels_are_stringname_keyed_ints_after_round_trip() -> void:
	var restored: MetaState = MetaState.from_dict(_make_populated_meta_state().to_dict())
	for key: Variant in restored.upgrades.keys():
		assert_typeof(key, TYPE_STRING_NAME)
	assert_typeof(restored.upgrades[&"industry"], TYPE_INT)
	assert_eq(restored.upgrades[&"industry"], 2)


func test_fresh_meta_state_has_sane_defaults_for_a_first_launch() -> void:
	var s := MetaState.new()
	assert_eq(s.liberty, 0)
	assert_eq(s.lifetime_liberty_earned, 0)
	assert_eq(s.upgrades, {})
	assert_eq(s.lifetime_gold_earned, 0.0)
	assert_eq(s.runs_completed, 0)
	assert_eq(s.recipes_ever_unlocked, [] as Array[StringName])
	assert_eq(s.stats, {"best_run_gold": 0.0, "fastest_run_seconds": 0})


func test_from_dict_of_empty_dictionary_does_not_crash() -> void:
	var s: MetaState = MetaState.from_dict({})
	assert_eq(s.liberty, 0)
	assert_eq(s.lifetime_gold_earned, 0.0)
