## Tests for the Colonists subsystem (the shared workforce pool -
## docs/GAME_DESIGN.md §4). Same Game.run reset discipline as the other sim
## tests.
extends GutTest


func before_each() -> void:
	Game.new_run(&"mvp_coast")


func after_each() -> void:
	Game.colonists.clear_assignments()
	Game.run = null


func test_fresh_run_has_no_colonists() -> void:
	assert_eq(Game.colonists.colonists_owned(), 0)
	assert_eq(Game.colonists.colonists_idle(), 0)


func test_first_colonist_costs_the_base_price() -> void:
	assert_almost_eq(Game.colonists.next_colonist_cost(), 25.0, 0.0001)


func test_cost_grows_by_the_documented_rate_per_colonist_owned() -> void:
	# 25 * 1.15^1 = 28.75
	Game.economy.add_gold(1000.0)
	Game.colonists.buy_colonist()
	assert_almost_eq(Game.colonists.next_colonist_cost(), 28.75, 0.01)


func test_buy_colonist_deducts_gold_and_increases_owned() -> void:
	Game.economy.add_gold(100.0)
	var ok: bool = Game.colonists.buy_colonist()
	assert_true(ok)
	assert_eq(Game.colonists.colonists_owned(), 1)
	assert_almost_eq(Game.economy.gold, 75.0, 0.0001)


func test_buy_colonist_fails_and_deducts_nothing_with_insufficient_gold() -> void:
	Game.economy.add_gold(10.0)  # costs 25
	var ok: bool = Game.colonists.buy_colonist()
	assert_false(ok)
	assert_eq(Game.colonists.colonists_owned(), 0)
	assert_almost_eq(Game.economy.gold, 10.0, 0.0001)


func test_buy_colonist_emits_colonist_purchased_with_new_total() -> void:
	Game.economy.add_gold(100.0)
	watch_signals(Game.colonists)
	Game.colonists.buy_colonist()
	assert_signal_emitted_with_parameters(Game.colonists, "colonist_purchased", [1])


func test_newly_bought_colonist_is_idle() -> void:
	Game.economy.add_gold(100.0)
	Game.colonists.buy_colonist()
	assert_eq(Game.colonists.colonists_idle(), 1)


func test_assign_moves_a_colonist_from_idle_to_a_site() -> void:
	Game.economy.add_gold(100.0)
	Game.colonists.buy_colonist()
	Game.colonists.buy_colonist()

	var ok: bool = Game.colonists.assign(&"cape_harbour", 2)
	assert_true(ok)
	assert_eq(Game.colonists.assigned_to(&"cape_harbour"), 2)
	assert_eq(Game.colonists.colonists_idle(), 0)


func test_assign_fails_and_changes_nothing_without_enough_idle_colonists() -> void:
	Game.economy.add_gold(100.0)
	Game.colonists.buy_colonist()  # only 1 idle

	var ok: bool = Game.colonists.assign(&"cape_harbour", 2)
	assert_false(ok)
	assert_eq(Game.colonists.assigned_to(&"cape_harbour"), 0)
	assert_eq(Game.colonists.colonists_idle(), 1, "a failed assignment must not touch the pool")


func test_the_central_tension_total_assigned_can_never_exceed_owned() -> void:
	# docs/GAME_DESIGN.md §4's whole point: every colonist is either
	# gathering or crafting, and you can't have more assigned than you own.
	Game.economy.add_gold(1000.0)
	for i: int in range(3):
		Game.colonists.buy_colonist()

	assert_true(Game.colonists.assign(&"cape_harbour", 2))
	assert_true(Game.colonists.assign(&"planks_recipe", 1))
	assert_false(Game.colonists.assign(&"chesapeake_fields", 1), "all 3 are already spoken for")
	assert_eq(Game.colonists.total_assigned(), 3)
	assert_eq(Game.colonists.colonists_idle(), 0)


func test_unassign_returns_a_colonist_to_the_idle_pool() -> void:
	Game.economy.add_gold(100.0)
	Game.colonists.buy_colonist()
	Game.colonists.assign(&"cape_harbour", 1)

	var ok: bool = Game.colonists.unassign(&"cape_harbour", 1)
	assert_true(ok)
	assert_eq(Game.colonists.assigned_to(&"cape_harbour"), 0)
	assert_eq(Game.colonists.colonists_idle(), 1)


func test_unassign_fails_and_changes_nothing_if_site_does_not_have_that_many() -> void:
	Game.economy.add_gold(100.0)
	Game.colonists.buy_colonist()
	Game.colonists.assign(&"cape_harbour", 1)

	var ok: bool = Game.colonists.unassign(&"cape_harbour", 5)
	assert_false(ok)
	assert_eq(Game.colonists.assigned_to(&"cape_harbour"), 1)


func test_clear_assignments_frees_every_colonist_back_to_idle() -> void:
	Game.economy.add_gold(1000.0)
	Game.colonists.buy_colonist()
	Game.colonists.buy_colonist()
	Game.colonists.assign(&"cape_harbour", 1)
	Game.colonists.assign(&"chesapeake_fields", 1)

	Game.colonists.clear_assignments()

	assert_eq(Game.colonists.total_assigned(), 0)
	assert_eq(Game.colonists.colonists_idle(), 2)


func test_operations_without_an_active_run_are_safe() -> void:
	Game.run = null
	assert_eq(Game.colonists.colonists_owned(), 0)
	assert_false(Game.colonists.buy_colonist())
