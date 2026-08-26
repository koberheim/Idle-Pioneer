## Tests for Prestige (rework task: real prestige system, docs/GAME_DESIGN.md
## §8). Game.meta carries Liberty/branch levels and is NOT reset by
## Game.new_run() (that's the entire point - see Game's class doc), so every
## test here resets it explicitly, in both before_each and after_each, to
## keep leftover branch levels from leaking into any test file that runs
## afterward and doesn't expect Game.meta to be touched (test_colony.gd,
## test_route.gd, etc. never reset it themselves).
extends GutTest


func before_each() -> void:
	Game.new_run(&"mvp_coast")
	Game.meta = MetaState.new()


func after_each() -> void:
	Game.run = null
	Game.meta = MetaState.new()


func test_liberty_starts_at_zero() -> void:
	assert_eq(Game.prestige.liberty(), 0)


func test_lifetime_gold_earned_this_run_tracks_earnings_not_current_gold() -> void:
	Game.economy.add_gold(500.0)
	Game.economy.try_spend(300.0)
	assert_almost_eq(Game.prestige.lifetime_gold_earned_this_run(), 500.0, 0.0001, "spending must not reduce it")
	assert_almost_eq(Game.economy.gold, 200.0, 0.0001)


func test_cannot_declare_independence_below_the_gate() -> void:
	Game.economy.add_gold(1000.0)
	assert_false(Game.prestige.can_declare_independence())


func test_can_declare_independence_once_the_gate_is_met() -> void:
	Game.economy.add_gold(2_000_000_000.0)
	assert_true(Game.prestige.can_declare_independence())


func test_projected_liberty_payout_matches_the_documented_formula() -> void:
	Game.economy.add_gold(2_000_000_000.0)  # exactly the gate: floor(6 * sqrt(1)) = 6
	assert_eq(Game.prestige.projected_liberty_payout(), 6)


func test_declare_independence_below_the_gate_does_nothing() -> void:
	Game.economy.add_gold(1000.0)
	var awarded: int = Game.prestige.declare_independence()
	assert_eq(awarded, 0)
	assert_eq(Game.prestige.liberty(), 0)
	assert_true(Game.has_run(), "a failed declaration must not touch the run")


func test_declare_independence_awards_liberty_and_starts_a_fresh_run() -> void:
	Game.economy.add_gold(2_000_000_000.0)
	Game.inventory.add(&"timber", 50.0)

	var awarded: int = Game.prestige.declare_independence()

	assert_eq(awarded, 6)
	assert_eq(Game.prestige.liberty(), 6)
	assert_eq(Game.meta.lifetime_liberty_earned, 6)
	assert_eq(Game.meta.runs_completed, 1)
	assert_true(Game.has_run(), "should start a fresh run immediately, not leave the player without one")
	assert_almost_eq(Game.economy.gold, 0.0, 0.0001, "run state must be wiped")
	assert_almost_eq(Game.inventory.get_amount(&"timber"), 0.0, 0.0001, "run state must be wiped")


func test_declare_independence_emits_declared_independence() -> void:
	Game.economy.add_gold(2_000_000_000.0)
	watch_signals(Game.prestige)
	Game.prestige.declare_independence()
	assert_signal_emitted_with_parameters(Game.prestige, "declared_independence", [6])


func test_declare_independence_records_best_run_gold() -> void:
	Game.economy.add_gold(2_000_000_000.0)
	Game.prestige.declare_independence()
	assert_almost_eq(Game.meta.stats["best_run_gold"], 2_000_000_000.0, 0.0001)


func test_declare_independence_does_not_lower_an_existing_best_run_gold() -> void:
	Game.meta.stats["best_run_gold"] = 5_000_000_000.0
	Game.economy.add_gold(2_000_000_000.0)
	Game.prestige.declare_independence()
	assert_almost_eq(Game.meta.stats["best_run_gold"], 5_000_000_000.0, 0.0001, "a weaker run must not overwrite a better one")


func test_purchase_industry_deducts_liberty_and_increases_level() -> void:
	Game.meta.liberty = 10
	var ok: bool = Game.prestige.purchase_industry()
	assert_true(ok)
	assert_eq(Game.prestige.industry_level(), 1)
	assert_eq(Game.prestige.liberty(), 7)  # base cost 3


func test_purchase_navigation_deducts_liberty_and_increases_level() -> void:
	Game.meta.liberty = 10
	var ok: bool = Game.prestige.purchase_navigation()
	assert_true(ok)
	assert_eq(Game.prestige.navigation_level(), 1)
	assert_eq(Game.prestige.liberty(), 6)  # base cost 4


func test_purchase_settlement_deducts_liberty_and_increases_level() -> void:
	Game.meta.liberty = 10
	var ok: bool = Game.prestige.purchase_settlement()
	assert_true(ok)
	assert_eq(Game.prestige.settlement_level(), 1)
	assert_eq(Game.prestige.liberty(), 5)  # base cost 5


func test_purchase_fails_with_insufficient_liberty() -> void:
	Game.meta.liberty = 1
	var ok: bool = Game.prestige.purchase_industry()
	assert_false(ok)
	assert_eq(Game.prestige.industry_level(), 0)
	assert_eq(Game.prestige.liberty(), 1)


func test_purchase_is_rejected_once_a_branchs_max_level_is_reached() -> void:
	Game.meta.liberty = 1_000_000
	for i in range(Balance.settlement_max_level()):
		assert_true(Game.prestige.purchase_settlement())
	assert_eq(Game.prestige.settlement_level(), Balance.settlement_max_level())
	assert_false(Game.prestige.purchase_settlement(), "must not exceed the branch's max level")


func test_industry_boosts_a_colonys_production_rate() -> void:
	Game.meta.upgrades[&"industry"] = 1  # +15%
	var colony := Colony.new(&"cape_harbour")
	colony.tick(2.0)  # 1.0 x 1.15 x 2s = 2.3
	assert_almost_eq(colony.local_stock.get(&"cod", 0.0), 2.3, 0.0001)


func test_navigation_boosts_a_colonys_cargo_capacity() -> void:
	Game.meta.upgrades[&"navigation"] = 1  # +12%
	var colony := Colony.new(&"cape_harbour")
	assert_almost_eq(colony.cargo_capacity(), 22.4, 0.0001)  # 20 x 1.12


func test_navigation_reduces_a_colonys_round_trip_time() -> void:
	Game.meta.upgrades[&"navigation"] = 1  # +12% speed
	var colony := Colony.new(&"cape_harbour")
	colony.route_type = Colony.RouteType.LAND
	assert_almost_eq(colony.round_trip_seconds(), 12.0 / 1.12, 0.0001)


func test_settlement_discounts_the_next_colonist_cost() -> void:
	Game.meta.upgrades[&"settlement"] = 1  # 0.93x
	assert_almost_eq(Game.colonists.next_colonist_cost(), 25.0 * 0.93, 0.0001)


func test_settlement_discounts_the_next_colony_cost() -> void:
	Game.meta.upgrades[&"settlement"] = 1  # 0.93x
	assert_almost_eq(Game.economy.colony_cost(&"cape_harbour"), 250.0 * 0.93, 0.0001)
