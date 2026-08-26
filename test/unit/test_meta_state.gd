## Tests for MetaState (task G2).
extends GutTest


func _make_populated_meta_state() -> MetaState:
	var s := MetaState.new()
	s.doubloons = 7
	s.meta_upgrades = [&"faster_start", &"cheaper_colonies"]
	s.lifetime_gold_earned = 45210.5
	s.runs_completed = 3
	return s


func test_to_dict_from_dict_round_trip_preserves_all_fields() -> void:
	var original: MetaState = _make_populated_meta_state()
	var restored: MetaState = MetaState.from_dict(original.to_dict())

	assert_eq(restored.doubloons, original.doubloons)
	assert_eq(restored.meta_upgrades, original.meta_upgrades)
	assert_eq(restored.lifetime_gold_earned, original.lifetime_gold_earned)
	assert_eq(restored.runs_completed, original.runs_completed)


## Same JSON int-vs-float gotcha as RunState (task G1) - route through a real
## JSON string, not just the in-memory dict, to actually exercise it.
func test_round_trip_through_actual_json_string_preserves_int_fields() -> void:
	var original: MetaState = _make_populated_meta_state()

	var json_text: String = JSON.stringify(original.to_dict())
	var parsed: Variant = JSON.parse_string(json_text)
	var restored: MetaState = MetaState.from_dict(parsed as Dictionary)

	assert_typeof(restored.doubloons, TYPE_INT)
	assert_eq(restored.doubloons, 7)
	assert_typeof(restored.runs_completed, TYPE_INT)
	assert_eq(restored.runs_completed, 3)


func test_meta_upgrade_ids_are_stringnames_after_round_trip() -> void:
	var restored: MetaState = MetaState.from_dict(_make_populated_meta_state().to_dict())
	for id: Variant in restored.meta_upgrades:
		assert_typeof(id, TYPE_STRING_NAME)


func test_fresh_meta_state_has_sane_defaults_for_a_first_launch() -> void:
	var s := MetaState.new()
	assert_eq(s.doubloons, 0)
	assert_eq(s.meta_upgrades, [] as Array[StringName])
	assert_eq(s.lifetime_gold_earned, 0.0)
	assert_eq(s.runs_completed, 0)


func test_from_dict_of_empty_dictionary_does_not_crash() -> void:
	var s: MetaState = MetaState.from_dict({})
	assert_eq(s.doubloons, 0)
	assert_eq(s.lifetime_gold_earned, 0.0)
