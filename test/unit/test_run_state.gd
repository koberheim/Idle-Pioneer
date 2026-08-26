## Tests for RunState (task G1).
extends GutTest


func _make_populated_run_state() -> RunState:
	var s := RunState.new()
	s.map_id = &"mvp_coast"
	s.map_seed = 0
	s.elapsed_seconds = 123.5
	s.gold = 87.0
	s.colonists_owned = 6
	s.inventory = {&"timber": 12.0, &"clay": 3.0}
	s.colonies = [
		{"region_id": &"harbor_point", "is_hub": true, "local_stock": {&"timber": 4.0}, "cycle_accumulated": 1.5},
		{"region_id": &"clay_flats", "is_hub": false, "local_stock": {}, "cycle_accumulated": 0.0},
	]
	s.upgrades_purchased = [&"primitive_tools"]
	s.colonies_founded = 2
	return s


func test_to_dict_from_dict_round_trip_preserves_all_fields() -> void:
	var original: RunState = _make_populated_run_state()
	var restored: RunState = RunState.from_dict(original.to_dict())

	assert_eq(restored.map_id, original.map_id)
	assert_eq(restored.map_seed, original.map_seed)
	assert_eq(restored.elapsed_seconds, original.elapsed_seconds)
	assert_eq(restored.gold, original.gold)
	assert_eq(restored.colonists_owned, original.colonists_owned)
	assert_eq(restored.inventory, original.inventory)
	assert_eq(restored.colonies, original.colonies)
	assert_eq(restored.upgrades_purchased, original.upgrades_purchased)
	assert_eq(restored.colonies_founded, original.colonies_founded)


## The real regression risk (docs/GODOT_PLAN.md Phase 8, task G1): JSON has no
## integer type, so a plain to_dict()/from_dict() round trip that never touches an
## actual JSON string can hide a bug that only shows up after real serialisation.
## Route through JSON.stringify/parse_string here to catch it for real.
func test_round_trip_through_actual_json_string_preserves_int_fields() -> void:
	var original: RunState = _make_populated_run_state()
	original.map_seed = 42
	original.colonies_founded = 3

	var json_text: String = JSON.stringify(original.to_dict())
	var parsed: Variant = JSON.parse_string(json_text)
	var restored: RunState = RunState.from_dict(parsed as Dictionary)

	assert_typeof(restored.map_seed, TYPE_INT)
	assert_eq(restored.map_seed, 42)
	assert_typeof(restored.colonies_founded, TYPE_INT)
	assert_eq(restored.colonies_founded, 3)


func test_inventory_keys_are_stringnames_after_round_trip() -> void:
	var restored: RunState = RunState.from_dict(_make_populated_run_state().to_dict())
	for key: Variant in restored.inventory.keys():
		assert_typeof(key, TYPE_STRING_NAME)


func test_fresh_run_state_has_sane_defaults() -> void:
	var s := RunState.new()
	assert_eq(s.map_id, &"")
	assert_eq(s.map_seed, 0)
	assert_eq(s.elapsed_seconds, 0.0)
	assert_eq(s.gold, 0.0)
	assert_eq(s.colonists_owned, 0)
	assert_eq(s.inventory, {})
	assert_eq(s.colonies, [] as Array[Dictionary])
	assert_eq(s.upgrades_purchased, [] as Array[StringName])
	assert_eq(s.colonies_founded, 0)


func test_from_dict_of_empty_dictionary_does_not_crash() -> void:
	var s: RunState = RunState.from_dict({})
	assert_eq(s.map_id, &"")
	assert_eq(s.gold, 0.0)
