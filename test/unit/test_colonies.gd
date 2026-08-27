## Tests for the Colonies subsystem - the register/tick fan-out registry,
## mirroring Unity's ColonyController. Game.colonies is a live autoload
## child, so before_each/after_each clear it explicitly to keep tests
## isolated from each other. Uses the real colony table (design realignment):
## tidewater_landing (Capital) and cape_harbour.
extends GutTest


func before_each() -> void:
	Game.new_run(&"mvp_coast")
	Game.colonies.clear()


func after_each() -> void:
	Game.colonies.clear()
	Game.run = null


func test_register_adds_to_all() -> void:
	var c := Colony.new(&"tidewater_landing")
	Game.colonies.register(c)
	assert_eq(Game.colonies.all(), [c] as Array[Colony])


func test_registering_the_same_colony_twice_does_not_duplicate() -> void:
	var c := Colony.new(&"tidewater_landing")
	Game.colonies.register(c)
	Game.colonies.register(c)
	assert_eq(Game.colonies.all().size(), 1)


func test_unregister_removes_from_all() -> void:
	var c := Colony.new(&"tidewater_landing")
	Game.colonies.register(c)
	Game.colonies.unregister(c)
	assert_eq(Game.colonies.all(), [] as Array[Colony])


func test_tick_fans_out_to_every_registered_colony() -> void:
	Game.routing.set_mode(&"timber", Game.routing.RESERVE)
	var capital := Colony.new(&"tidewater_landing")
	var outpost := Colony.new(&"cape_harbour")
	Game.colonies.register(capital)
	Game.colonies.register(outpost)

	Game.run.influence = 100.0
	var a: Colonist = Game.colonists.recruit(Colonist.Type.RESOURCE)
	var b: Colonist = Game.colonists.recruit(Colonist.Type.RESOURCE)
	Game.colonists.assign(a.id, &"tidewater_landing")
	Game.colonists.assign(b.id, &"cape_harbour")

	Game.colonies.tick(5.0)

	# rate = base 1.0 x colonist primary bonus (1 + 0.1*level 1) = 1.1/s x 5s = 5.5
	assert_almost_eq(Game.inventory.get_amount(&"timber"), 5.5, 0.0001, "capital should have produced")
	assert_almost_eq(outpost.local_stock.get(&"cod", 0.0), 5.5, 0.0001, "outpost should have produced")


func test_all_returns_a_copy_not_a_live_reference() -> void:
	var c := Colony.new(&"tidewater_landing")
	Game.colonies.register(c)
	var snapshot: Array[Colony] = Game.colonies.all()
	snapshot.clear()
	assert_eq(Game.colonies.all().size(), 1, "mutating the snapshot must not affect the real registry")


func test_clear_empties_the_registry() -> void:
	Game.colonies.register(Colony.new(&"tidewater_landing"))
	Game.colonies.register(Colony.new(&"cape_harbour"))
	Game.colonies.clear()
	assert_eq(Game.colonies.all(), [] as Array[Colony])


## Founding now walks Game.run.colony_slots (rework task: randomized map) -
## new_run() (already called in before_each) always generates a real slot
## list with slot 0 (the Capital) pre-founded, so there's no "before the
## Capital exists" state to test here any more; the real no-run-at-all case
## is a null Game.run instead.
func test_next_to_found_is_empty_with_no_active_run() -> void:
	Game.run = null
	assert_true(Game.colonies.next_to_found().is_empty())


func test_next_to_found_is_slot_one_right_after_a_new_run() -> void:
	# Slot 0 (the Capital) is founded automatically by new_run() - slot 1 is
	# next, always cape_harbour's tier (order 1) regardless of the map seed,
	# since tier cycling is independent of where slots physically land.
	var next: Dictionary = Game.colonies.next_to_found()
	assert_eq(int(next["slot_index"]), 1)
	assert_eq(int(next["tier_order"]), 1)


func test_found_spends_gold_and_registers_the_colony() -> void:
	Game.economy.add_gold(250.0)  # slot 1's real cost (Balance.next_colony_slot_cost(1))

	var ok: bool = Game.colonies.found(1)

	assert_true(ok)
	assert_true(Game.colonies.has(&"slot_1"))
	assert_almost_eq(Game.economy.gold, 0.0, 0.0001)
	assert_eq(Game.run.colonies_founded, 1)


func test_found_emits_founded_with_the_new_colony() -> void:
	Game.economy.add_gold(250.0)
	watch_signals(Game.colonies)

	Game.colonies.found(1)

	assert_signal_emitted(Game.colonies, "founded")


func test_found_fails_with_insufficient_gold_and_changes_nothing() -> void:
	Game.economy.add_gold(100.0)  # slot 1 costs 250

	var ok: bool = Game.colonies.found(1)

	assert_false(ok)
	assert_false(Game.colonies.has(&"slot_1"))
	assert_almost_eq(Game.economy.gold, 100.0, 0.0001, "a failed founding must not touch gold")


func test_found_rejects_founding_out_of_order() -> void:
	Game.economy.add_gold(1_000_000.0)

	# Slot 1 hasn't been founded yet - slot 2 must be rejected even with
	# plenty of gold.
	var ok: bool = Game.colonies.found(2)

	assert_false(ok)
	assert_false(Game.colonies.has(&"slot_2"))


func test_found_rejects_an_already_founded_slot() -> void:
	Game.economy.add_gold(1_000_000.0)
	Game.colonies.found(1)

	var ok: bool = Game.colonies.found(1)

	assert_false(ok)


func test_found_rejects_the_capital_slot() -> void:
	Game.economy.add_gold(1_000_000.0)
	var ok: bool = Game.colonies.found(0)
	assert_false(ok)


func test_found_rejects_an_out_of_range_slot() -> void:
	Game.economy.add_gold(1_000_000.0)
	var ok: bool = Game.colonies.found(999)
	assert_false(ok)


func test_tier_order_for_slot_cycles_through_the_seven_non_capital_tiers() -> void:
	assert_eq(Game.colonies.tier_order_for_slot(0), 0)
	assert_eq(Game.colonies.tier_order_for_slot(1), 1)
	assert_eq(Game.colonies.tier_order_for_slot(7), 7)
	assert_eq(Game.colonies.tier_order_for_slot(8), 1, "wraps back to tier 1 after a full cycle")
	assert_eq(Game.colonies.tier_order_for_slot(14), 7)
	assert_eq(Game.colonies.tier_order_for_slot(15), 1)


## Direct request: French nation bonus is -20% colony founding cost (see
## NationDef's class doc). Slot 1's base cost is 250.0 gold.
func test_french_nation_discounts_colony_founding_cost() -> void:
	Game.new_run(&"mvp_coast", -1, &"french")
	Game.economy.add_gold(250.0 * 0.8)

	assert_true(Game.colonies.found(1))
	assert_almost_eq(Game.economy.gold, 0.0, 0.0001)
