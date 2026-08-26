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
	Game.colonists.clear_assignments()
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
	var capital := Colony.new(&"tidewater_landing")
	var outpost := Colony.new(&"cape_harbour")
	Game.colonies.register(capital)
	Game.colonies.register(outpost)

	Game.economy.add_gold(1000.0)
	Game.colonists.buy_colonist()
	Game.colonists.buy_colonist()
	Game.colonists.assign(&"tidewater_landing", 1)
	Game.colonists.assign(&"cape_harbour", 1)

	Game.colonies.tick(5.0)

	# rate = base 1.0 x colonist bonus (1 + 0.1*1) = 1.1/s x 5s = 5.5
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


func test_next_to_found_is_null_before_the_capital_exists() -> void:
	assert_null(Game.colonies.next_to_found())


func test_next_to_found_is_the_first_non_capital_colony_in_order() -> void:
	Game.colonies.register(Colony.new(&"tidewater_landing"))
	assert_eq(Game.colonies.next_to_found().id, &"cape_harbour")


func test_found_spends_gold_and_registers_the_colony() -> void:
	Game.colonies.register(Colony.new(&"tidewater_landing"))
	Game.economy.add_gold(250.0)  # cape_harbour's real unlock_cost

	var ok: bool = Game.colonies.found(&"cape_harbour")

	assert_true(ok)
	assert_true(Game.colonies.has(&"cape_harbour"))
	assert_almost_eq(Game.economy.gold, 0.0, 0.0001)
	assert_eq(Game.run.colonies_founded, 1)


func test_found_emits_founded_with_the_new_colony() -> void:
	Game.colonies.register(Colony.new(&"tidewater_landing"))
	Game.economy.add_gold(250.0)
	watch_signals(Game.colonies)

	Game.colonies.found(&"cape_harbour")

	assert_signal_emitted(Game.colonies, "founded")


func test_found_fails_with_insufficient_gold_and_changes_nothing() -> void:
	Game.colonies.register(Colony.new(&"tidewater_landing"))
	Game.economy.add_gold(100.0)  # cape_harbour costs 250

	var ok: bool = Game.colonies.found(&"cape_harbour")

	assert_false(ok)
	assert_false(Game.colonies.has(&"cape_harbour"))
	assert_almost_eq(Game.economy.gold, 100.0, 0.0001, "a failed founding must not touch gold")


func test_found_rejects_founding_out_of_order() -> void:
	Game.colonies.register(Colony.new(&"tidewater_landing"))
	Game.economy.add_gold(1_000_000.0)

	# chesapeake_fields is order 2 - cape_harbour (order 1) hasn't been
	# founded yet, so this must be rejected even with plenty of gold.
	var ok: bool = Game.colonies.found(&"chesapeake_fields")

	assert_false(ok)
	assert_false(Game.colonies.has(&"chesapeake_fields"))


func test_found_rejects_an_already_founded_colony() -> void:
	Game.colonies.register(Colony.new(&"tidewater_landing"))
	Game.economy.add_gold(1_000_000.0)
	Game.colonies.found(&"cape_harbour")

	var ok: bool = Game.colonies.found(&"cape_harbour")

	assert_false(ok)


func test_found_rejects_the_capital() -> void:
	Game.colonies.register(Colony.new(&"tidewater_landing"))
	Game.economy.add_gold(1_000_000.0)
	var ok: bool = Game.colonies.found(&"tidewater_landing")
	assert_false(ok)


func test_found_rejects_an_unknown_colony_id() -> void:
	Game.colonies.register(Colony.new(&"tidewater_landing"))
	Game.economy.add_gold(1_000_000.0)
	var ok: bool = Game.colonies.found(&"does_not_exist")
	assert_false(ok)
