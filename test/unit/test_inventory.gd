## Tests for Inventory (task R1). Inventory reads/writes Game.run directly, so
## before_each/after_each start and clear a real run - same discipline as
## test_game.gd (task G3), since Game is a live autoload shared across the
## whole test process.
extends GutTest


func before_each() -> void:
	Game.new_run(&"mvp_coast")


func after_each() -> void:
	Game.run = null


func test_get_amount_of_never_added_known_resource_is_zero_not_an_error() -> void:
	# A known ResourceDef with no stock yet is a completely normal state.
	assert_eq(Game.inventory.get_amount(&"timber"), 0.0)


func test_add_increases_stock_from_zero() -> void:
	Game.inventory.add(&"timber", 5.0)
	assert_eq(Game.inventory.get_amount(&"timber"), 5.0)


func test_add_accumulates_across_multiple_calls() -> void:
	Game.inventory.add(&"timber", 5.0)
	Game.inventory.add(&"timber", 2.5)
	assert_almost_eq(Game.inventory.get_amount(&"timber"), 7.5, 0.0001)


func test_add_does_not_affect_other_resources() -> void:
	Game.inventory.add(&"timber", 5.0)
	assert_eq(Game.inventory.get_amount(&"clay"), 0.0)


func test_add_emits_changed_with_correct_total_and_positive_delta() -> void:
	watch_signals(Game.inventory)
	Game.inventory.add(&"timber", 5.0)
	assert_signal_emitted_with_parameters(Game.inventory, "changed", [&"timber", 5.0, 5.0])


func test_add_of_zero_or_negative_amount_is_a_no_op() -> void:
	Game.inventory.add(&"timber", 0.0)
	assert_eq(Game.inventory.get_amount(&"timber"), 0.0)
	Game.inventory.add(&"timber", -3.0)
	assert_eq(Game.inventory.get_amount(&"timber"), 0.0)


func test_add_of_unknown_resource_id_is_a_no_op() -> void:
	Game.inventory.add(&"does_not_exist", 5.0)
	assert_eq(Game.inventory.get_amount(&"does_not_exist"), 0.0)


func test_try_remove_succeeds_and_subtracts_when_enough_stock() -> void:
	Game.inventory.add(&"timber", 10.0)
	var ok: bool = Game.inventory.try_remove(&"timber", 4.0)
	assert_true(ok)
	assert_almost_eq(Game.inventory.get_amount(&"timber"), 6.0, 0.0001)


func test_try_remove_fails_and_mutates_nothing_when_short() -> void:
	Game.inventory.add(&"timber", 3.0)
	var ok: bool = Game.inventory.try_remove(&"timber", 10.0)
	assert_false(ok)
	assert_eq(Game.inventory.get_amount(&"timber"), 3.0, "failed removal must not touch stock")


func test_try_remove_of_exact_stock_leaves_exactly_zero() -> void:
	Game.inventory.add(&"timber", 5.0)
	var ok: bool = Game.inventory.try_remove(&"timber", 5.0)
	assert_true(ok)
	assert_eq(Game.inventory.get_amount(&"timber"), 0.0)


func test_try_remove_emits_changed_with_correct_total_and_negative_delta() -> void:
	Game.inventory.add(&"timber", 10.0)
	watch_signals(Game.inventory)
	Game.inventory.try_remove(&"timber", 4.0)
	assert_signal_emitted_with_parameters(Game.inventory, "changed", [&"timber", 6.0, -4.0])


func test_try_remove_of_unknown_resource_id_returns_false() -> void:
	assert_false(Game.inventory.try_remove(&"does_not_exist", 1.0))


func test_try_remove_repeated_small_amounts_never_drifts_below_zero() -> void:
	# Regression risk called out in docs/GODOT_PLAN.md task R1: float
	## subtraction must not leave a tiny negative like -0.0000001 that a naive
	## `> 0` check elsewhere would misread as "has stock."
	Game.inventory.add(&"timber", 0.3)
	Game.inventory.try_remove(&"timber", 0.1)
	Game.inventory.try_remove(&"timber", 0.1)
	Game.inventory.try_remove(&"timber", 0.1)
	assert_true(Game.inventory.get_amount(&"timber") >= 0.0)


func test_has_true_when_enough_stock() -> void:
	Game.inventory.add(&"timber", 5.0)
	assert_true(Game.inventory.has(&"timber", 5.0))
	assert_true(Game.inventory.has(&"timber", 3.0))


func test_has_false_when_not_enough_stock() -> void:
	Game.inventory.add(&"timber", 2.0)
	assert_false(Game.inventory.has(&"timber", 5.0))


func test_all_reflects_current_stock_across_resources() -> void:
	Game.inventory.add(&"timber", 4.0)
	Game.inventory.add(&"clay", 2.0)
	var snapshot: Dictionary = Game.inventory.all()
	assert_eq(snapshot[&"timber"], 4.0)
	assert_eq(snapshot[&"clay"], 2.0)


func test_all_returns_a_copy_not_a_live_reference() -> void:
	Game.inventory.add(&"timber", 4.0)
	var snapshot: Dictionary = Game.inventory.all()
	snapshot[&"timber"] = 999.0
	assert_eq(Game.inventory.get_amount(&"timber"), 4.0, "mutating the snapshot must not affect real stock")


func test_operations_without_an_active_run_are_safe_no_ops() -> void:
	Game.run = null
	assert_eq(Game.inventory.get_amount(&"timber"), 0.0)
	assert_false(Game.inventory.try_remove(&"timber", 1.0))
	assert_eq(Game.inventory.all(), {})
	# add() should not crash even with no run to write into.
	Game.inventory.add(&"timber", 5.0)
