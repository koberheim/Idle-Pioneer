## Tests for RunState (task G1).
extends GutTest


func _make_populated_run_state() -> RunState:
	var s := RunState.new()
	s.map_id = &"mvp_coast"
	s.map_seed = 0
	s.map = {"width": 4, "height": 4, "seed_value": 0, "terrain": "", "deposits": "", "deposit_palette": []}
	s.colony_slots = [
		{"slot_index": 0, "tier_order": 0, "cell": Vector2i(2, 3), "distance_cells": 0.0, "is_coastal": true, "founded": true},
		{"slot_index": 1, "tier_order": 1, "cell": Vector2i(5, 6), "distance_cells": 4.2, "is_coastal": false, "founded": true},
	]
	s.started_at_unix = 1700000000
	s.elapsed_seconds = 123.5
	s.gold = 87.0
	s.lifetime_gold_earned_this_run = 5400.0
	s.colonists_owned = 6
	s.inventory = {&"timber": 12.0, &"clay": 3.0}
	s.colonies = [
		{"colony_id": &"slot_0", "tier_id": &"tidewater_landing", "slot_index": 0, "production_level": 2, "cargo_level": 0, "speed_level": 1, "local_stock": {&"timber": 4.0}},
		{"colony_id": &"slot_1", "tier_id": &"cape_harbour", "slot_index": 1, "production_level": 0, "cargo_level": 3, "speed_level": 0, "local_stock": {}},
	]
	s.upgrades_purchased = [&"primitive_tools"]
	s.colonies_founded = 2
	s.workshops = [
		{"recipe_id": &"salt_cod_recipe", "auto_craft": true, "cycle_accumulated": 1.25},
	]
	s.resource_routing = {&"timber": &"sell", &"cod": &"reserve"}
	s.routes = [
		{"colony_id": &"cape_harbour", "state": 1, "cargo": {&"cod": 12.0}, "leg_elapsed": 2.5},
	]
	return s


func test_to_dict_from_dict_round_trip_preserves_all_fields() -> void:
	var original: RunState = _make_populated_run_state()
	var restored: RunState = RunState.from_dict(original.to_dict())

	assert_eq(restored.map_id, original.map_id)
	assert_eq(restored.map_seed, original.map_seed)
	assert_eq(restored.map, original.map)
	assert_eq(restored.colony_slots, original.colony_slots)
	assert_eq(restored.started_at_unix, original.started_at_unix)
	assert_eq(restored.elapsed_seconds, original.elapsed_seconds)
	assert_eq(restored.gold, original.gold)
	assert_eq(restored.lifetime_gold_earned_this_run, original.lifetime_gold_earned_this_run)
	assert_eq(restored.colonists_owned, original.colonists_owned)
	assert_eq(restored.inventory, original.inventory)
	assert_eq(restored.colonies, original.colonies)
	assert_eq(restored.upgrades_purchased, original.upgrades_purchased)
	assert_eq(restored.colonies_founded, original.colonies_founded)
	assert_eq(restored.workshops, original.workshops)
	assert_eq(restored.resource_routing, original.resource_routing)
	assert_eq(restored.routes, original.routes)


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
	assert_typeof(restored.started_at_unix, TYPE_INT)
	assert_eq(restored.started_at_unix, 1700000000)


func test_inventory_keys_are_stringnames_after_round_trip() -> void:
	var restored: RunState = RunState.from_dict(_make_populated_run_state().to_dict())
	for key: Variant in restored.inventory.keys():
		assert_typeof(key, TYPE_STRING_NAME)


func test_fresh_run_state_has_sane_defaults() -> void:
	var s := RunState.new()
	assert_eq(s.map_id, &"")
	assert_eq(s.map_seed, 0)
	assert_eq(s.map, {})
	assert_eq(s.colony_slots, [] as Array[Dictionary])
	assert_eq(s.started_at_unix, 0)
	assert_eq(s.elapsed_seconds, 0.0)
	assert_eq(s.gold, 0.0)
	assert_eq(s.lifetime_gold_earned_this_run, 0.0)
	assert_eq(s.colonists_owned, 0)
	assert_eq(s.inventory, {})
	assert_eq(s.colonies, [] as Array[Dictionary])
	assert_eq(s.upgrades_purchased, [] as Array[StringName])
	assert_eq(s.colonies_founded, 0)
	assert_eq(s.workshops, [] as Array[Dictionary])
	assert_eq(s.resource_routing, {})
	assert_eq(s.routes, [] as Array[Dictionary])


func test_route_state_round_trips_as_its_named_string_in_json() -> void:
	var original: RunState = _make_populated_run_state()
	var json_text: String = JSON.stringify(original.to_dict())
	assert_string_contains(json_text, "traveling_to_hub")

	var parsed: Variant = JSON.parse_string(json_text)
	var restored: RunState = RunState.from_dict(parsed as Dictionary)
	assert_eq(restored.routes[0]["state"], 1)


func test_from_dict_of_empty_dictionary_does_not_crash() -> void:
	var s: RunState = RunState.from_dict({})
	assert_eq(s.map_id, &"")
	assert_eq(s.gold, 0.0)
