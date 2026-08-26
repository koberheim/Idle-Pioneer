## Tests for RegionDef.is_valid() (task D3).
extends GutTest


func _make_valid_region() -> RegionDef:
	var r := RegionDef.new()
	r.id = &"harbor_point"
	r.cell = Vector2i(4, 2)
	r.deposit_id = &"timber"
	r.base_cycle_seconds = 5.0
	return r


func test_valid_region_is_valid() -> void:
	assert_true(_make_valid_region().is_valid())


func test_empty_id_is_invalid() -> void:
	var r: RegionDef = _make_valid_region()
	r.id = &""
	assert_false(r.is_valid())


func test_empty_deposit_id_is_invalid() -> void:
	var r: RegionDef = _make_valid_region()
	r.deposit_id = &""
	assert_false(r.is_valid())


func test_zero_cycle_seconds_is_invalid() -> void:
	var r: RegionDef = _make_valid_region()
	r.base_cycle_seconds = 0.0
	assert_false(r.is_valid())


func test_negative_cycle_seconds_is_invalid() -> void:
	var r: RegionDef = _make_valid_region()
	r.base_cycle_seconds = -1.0
	assert_false(r.is_valid())


func test_has_no_is_coastal_field() -> void:
	# Deliberate - see the class doc on RegionDef. Coastal-ness is derived from
	# the map (task M5), never authored a second time on the region itself.
	var r: RegionDef = _make_valid_region()
	var property_names: Array[String] = []
	for prop: Dictionary in r.get_property_list():
		property_names.append(prop["name"])
	assert_does_not_have(property_names, "is_coastal")
