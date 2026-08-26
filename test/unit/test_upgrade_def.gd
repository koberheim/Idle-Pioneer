## Tests for UpgradeDef.is_valid() (task D3).
extends GutTest


func _make_cost(resource_id: StringName, amount: int) -> RecipeIngredient:
	var c := RecipeIngredient.new()
	c.resource_id = resource_id
	c.amount = amount
	return c


func _make_valid_upgrade() -> UpgradeDef:
	var u := UpgradeDef.new()
	u.id = &"primitive_tools"
	u.gold_cost = 50
	u.effect = UpgradeDef.EFFECT_GLOBAL_PRODUCTION_MULTIPLIER
	u.magnitude = 1.25
	return u


func test_valid_upgrade_is_valid() -> void:
	assert_true(_make_valid_upgrade().is_valid())


func test_empty_id_is_invalid() -> void:
	var u: UpgradeDef = _make_valid_upgrade()
	u.id = &""
	assert_false(u.is_valid())


func test_empty_effect_is_invalid() -> void:
	var u: UpgradeDef = _make_valid_upgrade()
	u.effect = &""
	assert_false(u.is_valid())


func test_negative_gold_cost_is_invalid() -> void:
	var u: UpgradeDef = _make_valid_upgrade()
	u.gold_cost = -1
	assert_false(u.is_valid())


func test_zero_gold_cost_is_valid() -> void:
	# Free upgrades are a legitimate design choice (Unity's cheapest research was
	# 25 gold, not 0, but nothing rules out a free unlock).
	var u: UpgradeDef = _make_valid_upgrade()
	u.gold_cost = 0
	assert_true(u.is_valid())


func test_valid_resource_costs_is_valid() -> void:
	var u: UpgradeDef = _make_valid_upgrade()
	u.resource_costs = [_make_cost(&"timber", 10)]
	assert_true(u.is_valid())


func test_malformed_resource_cost_is_invalid() -> void:
	var u: UpgradeDef = _make_valid_upgrade()
	u.resource_costs = [_make_cost(&"timber", 0)]
	assert_false(u.is_valid())


func test_effect_is_a_string_name_not_an_enum() -> void:
	# Deliberate - see the class doc on UpgradeDef. This is the fix for the exact
	# Unity bug in GODOT_MIGRATION_ANALYSIS.md §B4 (effectType: 17 silently
	# repointing after an enum reorder).
	var u: UpgradeDef = _make_valid_upgrade()
	assert_typeof(u.effect, TYPE_STRING_NAME)
