## Tests for Colony (docs/GAME_DESIGN.md §5/§6). Uses the real colony table
## (design realignment): tidewater_landing (the Capital, produces timber) and
## cape_harbour (produces cod). Same Game.run reset discipline as the other
## sim tests - and, since production now depends on assigned colonists
## (§4's central tension), most tests need to buy and assign at least one
## colonist before a colony will produce anything at all.
extends GutTest


func before_each() -> void:
	Game.new_run(&"mvp_coast")
	Game.economy.add_gold(1000.0)


func after_each() -> void:
	Game.colonists.clear_assignments()
	Game.run = null


func test_unstaffed_colony_produces_nothing() -> void:
	# The whole point of docs/GAME_DESIGN.md §4: no colonists, no output.
	var colony := Colony.new(&"cape_harbour")
	colony.tick(10.0)
	assert_eq(colony.local_stock, {})


func test_staffed_capital_produces_into_central_inventory() -> void:
	var capital := Colony.new(&"tidewater_landing")
	Game.colonists.buy_colonist()
	Game.colonists.assign(&"tidewater_landing", 1)

	capital.tick(2.0)  # rate 1.0/s x 1 colonist x 2s = 2.0 timber
	assert_almost_eq(Game.inventory.get_amount(&"timber"), 2.0, 0.0001)


func test_capital_never_accumulates_local_stock() -> void:
	var capital := Colony.new(&"tidewater_landing")
	Game.colonists.buy_colonist()
	Game.colonists.assign(&"tidewater_landing", 1)
	capital.tick(5.0)
	assert_eq(capital.local_stock, {})


func test_non_capital_colony_produces_into_local_stock_not_central_inventory() -> void:
	var colony := Colony.new(&"cape_harbour")
	Game.colonists.buy_colonist()
	Game.colonists.assign(&"cape_harbour", 1)

	colony.tick(3.0)  # rate 1.0/s x 1 x 3s = 3.0 cod
	assert_almost_eq(colony.local_stock.get(&"cod", 0.0), 3.0, 0.0001)
	assert_eq(Game.inventory.get_amount(&"cod"), 0.0, "non-Capital production must not reach central inventory")


func test_collect_empties_and_returns_local_stock() -> void:
	var colony := Colony.new(&"cape_harbour")
	Game.colonists.buy_colonist()
	Game.colonists.assign(&"cape_harbour", 1)
	colony.tick(4.0)

	var collected: Dictionary = colony.collect()
	assert_almost_eq(collected.get(&"cod", 0.0), 4.0, 0.0001)
	assert_eq(colony.local_stock, {}, "collect() must empty local_stock")


func test_more_colonists_produce_proportionally_more() -> void:
	var colony := Colony.new(&"cape_harbour")
	for i: int in range(3):
		Game.colonists.buy_colonist()
	Game.colonists.assign(&"cape_harbour", 3)

	colony.tick(2.0)  # rate 1.0/s x 3 x 2s = 6.0
	assert_almost_eq(colony.local_stock.get(&"cod", 0.0), 6.0, 0.0001)


func test_building_level_increases_output_by_the_documented_rate() -> void:
	# §6: x(1 + 0.25 x building_level).
	var colony := Colony.new(&"cape_harbour")
	Game.colonists.buy_colonist()
	Game.colonists.assign(&"cape_harbour", 1)
	colony.building_level = 2  # x(1 + 0.5) = x1.5

	colony.tick(2.0)  # 1.0 x 1 x 1.5 x 2s = 3.0
	assert_almost_eq(colony.local_stock.get(&"cod", 0.0), 3.0, 0.0001)


func test_ticks_accumulate_continuously_across_multiple_calls() -> void:
	var colony := Colony.new(&"cape_harbour")
	Game.colonists.buy_colonist()
	Game.colonists.assign(&"cape_harbour", 1)

	colony.tick(1.0)
	colony.tick(1.5)
	assert_almost_eq(colony.local_stock.get(&"cod", 0.0), 2.5, 0.0001)


func test_distance_matches_the_colonys_fixed_play_order() -> void:
	assert_eq(Colony.new(&"tidewater_landing").distance(), 0)
	assert_eq(Colony.new(&"cape_harbour").distance(), 1)
	assert_eq(Colony.new(&"northern_traces").distance(), 7)


func test_capital_route_type_is_always_land_and_irrelevant() -> void:
	# The Capital has distance 0 and never ships anywhere - route_type is
	# meaningless for it, but pinned to a stable value rather than left random.
	assert_eq(Colony.new(&"tidewater_landing").route_type, Colony.RouteType.LAND)


func test_non_capital_route_type_is_settable_for_deterministic_tests() -> void:
	var colony := Colony.new(&"cape_harbour")
	colony.route_type = Colony.RouteType.SEA
	assert_eq(colony.route_type, Colony.RouteType.SEA)


func test_unknown_colony_id_is_a_safe_no_op() -> void:
	var colony := Colony.new(&"does_not_exist")
	Game.colonists.buy_colonist()
	Game.colonists.assign(&"does_not_exist", 1)
	colony.tick(100.0)
	assert_eq(colony.local_stock, {})
	assert_eq(colony.resource_id(), &"")
