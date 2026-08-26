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
