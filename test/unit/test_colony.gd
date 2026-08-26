## Tests for Colony (task P2). Uses real regions from the authored MVP data
## (task D5): harbor_point (coastal, deposit timber, 5s cycle) and clay_flats
## (inland, deposit clay, 5s cycle). Same Game.run/Game.meta reset discipline
## as test_inventory.gd/test_economy.gd (tasks R1/R2).
extends GutTest


func before_each() -> void:
	Game.new_run(&"mvp_coast")


func after_each() -> void:
	Game.run = null


func test_hub_colony_produces_into_central_inventory() -> void:
	var hub := Colony.new(&"harbor_point", true)
	hub.tick(5.0)  # exactly one cycle at harbor_point's 5s cycle
	assert_almost_eq(Game.inventory.get_amount(&"timber"), 1.0, 0.0001)


func test_hub_colony_does_not_accumulate_local_stock() -> void:
	var hub := Colony.new(&"harbor_point", true)
	hub.tick(5.0)
	assert_eq(hub.local_stock, {})


func test_non_hub_colony_produces_into_local_stock_not_central_inventory() -> void:
	var colony := Colony.new(&"clay_flats", false)
	colony.tick(5.0)
	assert_almost_eq(colony.local_stock.get(&"clay", 0.0), 1.0, 0.0001)
	assert_eq(Game.inventory.get_amount(&"clay"), 0.0, "non-hub production must not reach central inventory")


func test_collect_empties_and_returns_local_stock() -> void:
	var colony := Colony.new(&"clay_flats", false)
	colony.tick(10.0)  # two cycles
	var collected: Dictionary = colony.collect()
	assert_almost_eq(collected.get(&"clay", 0.0), 2.0, 0.0001)
	assert_eq(colony.local_stock, {}, "collect() must empty local_stock")


func test_collect_on_hub_is_always_empty() -> void:
	var hub := Colony.new(&"harbor_point", true)
	hub.tick(20.0)
	assert_eq(hub.collect(), {})


func test_partial_tick_produces_nothing() -> void:
	var colony := Colony.new(&"clay_flats", false)
	colony.tick(2.0)  # well under the 5s cycle
	assert_eq(colony.local_stock, {})


func test_multiple_cycles_in_one_tick_produce_proportional_amount() -> void:
	var colony := Colony.new(&"clay_flats", false)
	colony.tick(23.0)  # 4 full cycles (20s) + 3s leftover, at a 5s cycle
	assert_almost_eq(colony.local_stock.get(&"clay", 0.0), 4.0, 0.0001)


func test_ticks_across_multiple_calls_accumulate_correctly() -> void:
	var colony := Colony.new(&"clay_flats", false)
	colony.tick(3.0)
	colony.tick(3.0)  # 6s total - one cycle completes on this call
	assert_almost_eq(colony.local_stock.get(&"clay", 0.0), 1.0, 0.0001)


func test_colony_uses_its_region_base_cycle_seconds() -> void:
	var colony := Colony.new(&"clay_flats", false)
	assert_almost_eq(colony.cycle.cycle_seconds, 5.0, 0.0001)


func test_deposit_id_matches_the_region() -> void:
	var colony := Colony.new(&"harbor_point", false)
	assert_eq(colony.deposit_id(), &"timber")


## Uses the current Progression stub (always 1.0 with no upgrade purchased) -
## still meaningful once task P5 implements real multipliers, since no upgrade
## is purchased in this test's fresh run.
func test_production_amount_reflects_the_progression_multiplier() -> void:
	var colony := Colony.new(&"clay_flats", false)
	colony.tick(5.0)
	var expected: float = 1.0 * Game.progression.production_multiplier()
	assert_almost_eq(colony.local_stock.get(&"clay", 0.0), expected, 0.0001)


func test_unknown_region_id_is_a_safe_no_op() -> void:
	var colony := Colony.new(&"does_not_exist", false)
	colony.tick(100.0)
	assert_eq(colony.local_stock, {})
	assert_eq(colony.deposit_id(), &"")
