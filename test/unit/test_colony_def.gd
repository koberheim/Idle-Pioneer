## Tests for ColonyDef.is_valid() (rework task: real colony table).
extends GutTest


func _make_valid_colony() -> ColonyDef:
	var c := ColonyDef.new()
	c.id = &"cape_harbour"
	c.resource_id = &"cod"
	c.order = 1
	c.unlock_cost = 250.0
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


func test_negative_unlock_cost_is_invalid() -> void:
	var c: ColonyDef = _make_valid_colony()
	c.unlock_cost = -1.0
	assert_false(c.is_valid())


func test_zero_unlock_cost_is_valid() -> void:
	# The Capital starts founded for free (docs/GAME_DESIGN.md §5).
	var c: ColonyDef = _make_valid_colony()
	c.unlock_cost = 0.0
	assert_true(c.is_valid())
