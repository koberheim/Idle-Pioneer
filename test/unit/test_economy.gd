## Tests for Economy (task R2). Same discipline as test_inventory.gd (task R1),
## plus one more: Economy also mutates Game.meta.lifetime_gold_earned, and meta
## deliberately survives new_run() (that's the whole point of the prestige
## split - see task G3) - so resetting only Game.run here would leak earned-gold
## totals across tests within this file. Both get reset, matching
## test_game.gd's pattern (task G3).
extends GutTest


func before_each() -> void:
	Game.new_run(&"mvp_coast")
	Game.meta = MetaState.new()


func after_each() -> void:
	Game.run = null
	Game.meta = MetaState.new()


func test_gold_starts_at_zero_for_a_fresh_run() -> void:
	assert_eq(Game.economy.gold, 0.0)


func test_add_gold_increases_gold() -> void:
	Game.economy.add_gold(50.0)
	assert_eq(Game.economy.gold, 50.0)


func test_add_gold_accumulates_across_calls() -> void:
	Game.economy.add_gold(50.0)
	Game.economy.add_gold(25.0)
	assert_almost_eq(Game.economy.gold, 75.0, 0.0001)


func test_add_gold_emits_gold_changed_with_the_new_total() -> void:
	watch_signals(Game.economy)
	Game.economy.add_gold(50.0)
	assert_signal_emitted_with_parameters(Game.economy, "gold_changed", [50.0])


func test_add_gold_of_zero_or_negative_is_a_no_op() -> void:
	Game.economy.add_gold(0.0)
	assert_eq(Game.economy.gold, 0.0)
	Game.economy.add_gold(-10.0)
	assert_eq(Game.economy.gold, 0.0)


func test_add_gold_accumulates_lifetime_gold_earned() -> void:
	Game.economy.add_gold(50.0)
	Game.economy.add_gold(25.0)
	assert_almost_eq(Game.meta.lifetime_gold_earned, 75.0, 0.0001)


func test_try_spend_succeeds_and_deducts_when_enough_gold() -> void:
	Game.economy.add_gold(100.0)
	var ok: bool = Game.economy.try_spend(40.0)
	assert_true(ok)
	assert_almost_eq(Game.economy.gold, 60.0, 0.0001)


func test_try_spend_fails_and_mutates_nothing_when_short() -> void:
	Game.economy.add_gold(10.0)
	var ok: bool = Game.economy.try_spend(50.0)
	assert_false(ok)
	assert_eq(Game.economy.gold, 10.0, "failed spend must not touch gold")


func test_try_spend_does_not_affect_lifetime_gold_earned() -> void:
	Game.economy.add_gold(100.0)
	Game.economy.try_spend(40.0)
	# Spending is not earning - lifetime_gold_earned tracks income only, per
	# task G2's stated purpose (a future prestige payout formula).
	assert_almost_eq(Game.meta.lifetime_gold_earned, 100.0, 0.0001)


func test_sell_value_matches_base_value_times_amount() -> void:
	# timber base_value is 1.0 (data/resources/timber.tres).
	assert_almost_eq(Game.economy.sell_value(&"timber", 10.0), 10.0, 0.0001)
	# lumber base_value is 5.0 (data/resources/lumber.tres).
	assert_almost_eq(Game.economy.sell_value(&"lumber", 3.0), 15.0, 0.0001)


func test_sell_value_of_unknown_resource_is_zero() -> void:
	assert_eq(Game.economy.sell_value(&"does_not_exist", 10.0), 0.0)


func test_sell_removes_stock_and_adds_correct_gold() -> void:
	Game.inventory.add(&"timber", 10.0)
	var ok: bool = Game.economy.sell(&"timber", 4.0)
	assert_true(ok)
	assert_almost_eq(Game.inventory.get_amount(&"timber"), 6.0, 0.0001)
	assert_almost_eq(Game.economy.gold, 4.0, 0.0001)  # 4 timber x 1.0 gold


func test_sell_fails_and_adds_no_gold_when_insufficient_stock() -> void:
	Game.inventory.add(&"timber", 2.0)
	var ok: bool = Game.economy.sell(&"timber", 10.0)
	assert_false(ok)
	assert_eq(Game.economy.gold, 0.0)
	assert_almost_eq(Game.inventory.get_amount(&"timber"), 2.0, 0.0001, "failed sale must not touch stock")


func test_sell_of_unknown_resource_fails_cleanly() -> void:
	var ok: bool = Game.economy.sell(&"does_not_exist", 1.0)
	assert_false(ok)
	assert_eq(Game.economy.gold, 0.0)


func test_next_colony_cost_at_zero_founded_is_the_base_cost() -> void:
	Game.run.colonies_founded = 0
	assert_almost_eq(Game.economy.next_colony_cost(), 100.0, 0.0001)


func test_next_colony_cost_follows_the_exponential_curve() -> void:
	Game.run.colonies_founded = 2
	# 100 * 2.5^2 = 625
	assert_almost_eq(Game.economy.next_colony_cost(), 625.0, 0.01)


func test_operations_without_an_active_run_are_safe_no_ops() -> void:
	Game.run = null
	assert_eq(Game.economy.gold, 0.0)
	assert_false(Game.economy.try_spend(10.0))
	assert_eq(Game.economy.next_colony_cost(), 100.0)
	# add_gold() should not crash even with no run to write into.
	Game.economy.add_gold(10.0)
