## Tests for the Colonists subsystem (rework: typed colonist roster -
## docs/GAME_DESIGN.md §4's "central tension," now Resource/Cargo/Speed
## colonists, one per colony per type). Same Game.run reset discipline as
## the other sim tests.
extends GutTest


func before_each() -> void:
	Game.new_run(&"mvp_coast")


func after_each() -> void:
	Game.run = null


func test_fresh_run_has_no_colonists() -> void:
	assert_eq(Game.colonists.colonists_owned(), 0)
	assert_eq(Game.colonists.idle_colonists().size(), 0)


func test_first_colonist_costs_the_base_recruit_price() -> void:
	assert_almost_eq(Game.colonists.next_recruit_cost(), 25.0, 0.0001)


func test_recruit_cost_grows_by_the_documented_rate_per_colonist_owned() -> void:
	# 25 * 1.15^1 = 28.75
	Game.run.influence = 1000.0
	Game.colonists.recruit(Colonist.Type.RESOURCE)
	assert_almost_eq(Game.colonists.next_recruit_cost(), 28.75, 0.01)


func test_recruit_deducts_influence_and_increases_owned() -> void:
	Game.run.influence = 100.0
	var c: Colonist = Game.colonists.recruit(Colonist.Type.RESOURCE)
	assert_not_null(c)
	assert_eq(Game.colonists.colonists_owned(), 1)
	assert_almost_eq(Game.colonists.influence(), 75.0, 0.0001)


func test_recruit_fails_and_deducts_nothing_with_insufficient_influence() -> void:
	Game.run.influence = 10.0  # costs 25
	var c: Colonist = Game.colonists.recruit(Colonist.Type.RESOURCE)
	assert_null(c)
	assert_eq(Game.colonists.colonists_owned(), 0)
	assert_almost_eq(Game.colonists.influence(), 10.0, 0.0001)


func test_recruit_emits_colonist_recruited() -> void:
	Game.run.influence = 100.0
	watch_signals(Game.colonists)
	Game.colonists.recruit(Colonist.Type.CARGO)
	assert_signal_emitted(Game.colonists, "colonist_recruited")


func test_newly_recruited_colonist_is_idle_at_level_one_with_the_right_type() -> void:
	Game.run.influence = 100.0
	var c: Colonist = Game.colonists.recruit(Colonist.Type.SPEED)
	assert_eq(c.level, 1)
	assert_eq(c.type, Colonist.Type.SPEED)
	assert_eq(c.assigned_colony_id, &"")
	assert_eq(Game.colonists.idle_colonists().size(), 1)


func test_assign_moves_a_colonist_from_idle_to_a_colony() -> void:
	Game.run.influence = 100.0
	var c: Colonist = Game.colonists.recruit(Colonist.Type.RESOURCE)

	var ok: bool = Game.colonists.assign(c.id, &"cape_harbour")

	assert_true(ok)
	assert_eq(Game.colonists.colonist_at(&"cape_harbour", Colonist.Type.RESOURCE).id, c.id)
	assert_eq(Game.colonists.idle_colonists().size(), 0)


func test_assign_fails_if_the_colony_already_has_a_colonist_of_that_type() -> void:
	Game.run.influence = 1000.0
	var a: Colonist = Game.colonists.recruit(Colonist.Type.RESOURCE)
	var b: Colonist = Game.colonists.recruit(Colonist.Type.RESOURCE)
	Game.colonists.assign(a.id, &"cape_harbour")

	var ok: bool = Game.colonists.assign(b.id, &"cape_harbour")

	assert_false(ok)
	assert_eq(Game.colonists.colonist_at(&"cape_harbour", Colonist.Type.RESOURCE).id, a.id)
	assert_eq(b.assigned_colony_id, &"", "the rejected colonist must still be idle")


func test_assign_fails_if_the_colonist_is_already_assigned_elsewhere() -> void:
	Game.run.influence = 100.0
	var c: Colonist = Game.colonists.recruit(Colonist.Type.RESOURCE)
	Game.colonists.assign(c.id, &"cape_harbour")

	var ok: bool = Game.colonists.assign(c.id, &"chesapeake_fields")

	assert_false(ok)
	assert_eq(Game.colonists.colonist_at(&"cape_harbour", Colonist.Type.RESOURCE).id, c.id)


func test_assign_fails_for_an_unknown_colonist_id() -> void:
	assert_false(Game.colonists.assign(&"does_not_exist", &"cape_harbour"))


## docs/GAME_DESIGN.md §4's whole point, now with real shape: a colony can
## hold at most one of each type at once - two colonists of the same type
## can never both work the same colony.
func test_a_colony_can_hold_one_of_each_type_at_once() -> void:
	Game.run.influence = 1000.0
	var resource_colonist: Colonist = Game.colonists.recruit(Colonist.Type.RESOURCE)
	var cargo_colonist: Colonist = Game.colonists.recruit(Colonist.Type.CARGO)
	var speed_colonist: Colonist = Game.colonists.recruit(Colonist.Type.SPEED)

	assert_true(Game.colonists.assign(resource_colonist.id, &"cape_harbour"))
	assert_true(Game.colonists.assign(cargo_colonist.id, &"cape_harbour"))
	assert_true(Game.colonists.assign(speed_colonist.id, &"cape_harbour"))

	assert_eq(Game.colonists.colonist_at(&"cape_harbour", Colonist.Type.RESOURCE).id, resource_colonist.id)
	assert_eq(Game.colonists.colonist_at(&"cape_harbour", Colonist.Type.CARGO).id, cargo_colonist.id)
	assert_eq(Game.colonists.colonist_at(&"cape_harbour", Colonist.Type.SPEED).id, speed_colonist.id)


func test_unassign_returns_a_colonist_to_the_idle_pool() -> void:
	Game.run.influence = 100.0
	var c: Colonist = Game.colonists.recruit(Colonist.Type.RESOURCE)
	Game.colonists.assign(c.id, &"cape_harbour")

	var ok: bool = Game.colonists.unassign(c.id)

	assert_true(ok)
	assert_null(Game.colonists.colonist_at(&"cape_harbour", Colonist.Type.RESOURCE))
	assert_eq(Game.colonists.idle_colonists().size(), 1)


func test_unassign_fails_for_an_already_idle_colonist() -> void:
	Game.run.influence = 100.0
	var c: Colonist = Game.colonists.recruit(Colonist.Type.RESOURCE)
	assert_false(Game.colonists.unassign(c.id))


func test_assign_best_picks_the_highest_level_idle_colonist_of_the_matching_type() -> void:
	Game.run.influence = 10000.0
	var low: Colonist = Game.colonists.recruit(Colonist.Type.RESOURCE)
	var high: Colonist = Game.colonists.recruit(Colonist.Type.RESOURCE)
	Game.colonists.upgrade(high.id)
	Game.colonists.upgrade(high.id)

	var ok: bool = Game.colonists.assign_best(&"cape_harbour", Colonist.Type.RESOURCE)

	assert_true(ok)
	assert_eq(Game.colonists.colonist_at(&"cape_harbour", Colonist.Type.RESOURCE).id, high.id)
	assert_eq(low.assigned_colony_id, &"")


func test_assign_best_fails_with_no_matching_idle_colonist() -> void:
	assert_false(Game.colonists.assign_best(&"cape_harbour", Colonist.Type.RESOURCE))


func test_upgrade_raises_level_and_deducts_influence() -> void:
	Game.run.influence = 100.0
	var c: Colonist = Game.colonists.recruit(Colonist.Type.RESOURCE)  # costs 25, 75 left
	var cost: float = Game.colonists.next_upgrade_cost(c.id)  # 20 * 1.2^1 = 24

	var ok: bool = Game.colonists.upgrade(c.id)

	assert_true(ok)
	assert_eq(Game.colonists.get_colonist(c.id).level, 2)
	assert_almost_eq(Game.colonists.influence(), 75.0 - cost, 0.0001)


func test_upgrade_fails_with_insufficient_influence() -> void:
	Game.run.influence = 25.0
	var c: Colonist = Game.colonists.recruit(Colonist.Type.RESOURCE)  # 0 left
	assert_false(Game.colonists.upgrade(c.id))
	assert_eq(Game.colonists.get_colonist(c.id).level, 1)


func test_upgrade_cost_scales_with_the_colonists_own_level_not_total_owned() -> void:
	Game.run.influence = 100000.0
	var a: Colonist = Game.colonists.recruit(Colonist.Type.RESOURCE)
	Game.colonists.recruit(Colonist.Type.CARGO)  # a second colonist owned, unrelated to `a`'s upgrade cost

	var cost_at_level_one: float = Game.colonists.next_upgrade_cost(a.id)
	Game.colonists.upgrade(a.id)
	var cost_at_level_two: float = Game.colonists.next_upgrade_cost(a.id)

	assert_gt(cost_at_level_two, cost_at_level_one, "upgrading should get more expensive as the colonist levels up")


func test_operations_without_an_active_run_are_safe() -> void:
	Game.run = null
	assert_eq(Game.colonists.colonists_owned(), 0)
	assert_almost_eq(Game.colonists.influence(), 0.0, 0.0001)
	assert_null(Game.colonists.recruit(Colonist.Type.RESOURCE))
