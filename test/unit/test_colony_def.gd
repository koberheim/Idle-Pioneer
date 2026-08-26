## Tests for ColonyDef.is_valid() (rework task: real colony table).
extends GutTest


func _make_valid_colony() -> ColonyDef:
	var c := ColonyDef.new()
	c.id = &"cape_harbour"
	c.resource_id = &"cod"
	c.order = 1
	return c


func test_valid_colony_is_valid() -> void:
	assert_true(_make_valid_colony().is_valid())


func test_empty_id_is_invalid() -> void:
	var c: ColonyDef = _make_valid_colony()
	c.id = &""
	assert_false(c.is_valid())


func test_empty_resource_id_is_invalid() -> void:
	var c: ColonyDef = _make_valid_colony()
	c.resource_id = &""
	assert_false(c.is_valid())


func test_negative_order_is_invalid() -> void:
	var c: ColonyDef = _make_valid_colony()
	c.order = -1
	assert_false(c.is_valid())


func test_zero_base_production_rate_is_invalid() -> void:
	# A colony must produce something with zero colonists (design realignment) -
	# a zero base rate would silently defeat that.
	var c: ColonyDef = _make_valid_colony()
	c.base_production_rate = 0.0
	assert_false(c.is_valid())


func test_zero_base_cargo_is_invalid() -> void:
	var c: ColonyDef = _make_valid_colony()
	c.base_cargo = 0.0
	assert_false(c.is_valid())


func test_zero_base_speed_is_invalid() -> void:
	var c: ColonyDef = _make_valid_colony()
	c.base_speed = 0.0
	assert_false(c.is_valid())
