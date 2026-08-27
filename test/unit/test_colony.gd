## Tests for Colony (docs/GAME_DESIGN.md §5/§6, reworked per the design
## realignment: three independent upgrade tracks, real base stats that apply
## even with zero colonists). Uses the real colony table: tidewater_landing
## (the Capital, produces timber) and cape_harbour (produces cod). Both start
## with base_production_rate 1.0, base_cargo 20.0, base_speed 1.0 (data/colonies/).
extends GutTest


func before_each() -> void:
	Game.new_run(&"mvp_coast")
	Game.economy.add_gold(1000.0)


func after_each() -> void:
	Game.run = null


## The design realignment's key correction: an unstaffed colony still
## produces, at its base rate - staffing is a bonus, not a requirement.
func test_unstaffed_colony_still_produces_at_its_base_rate() -> void:
	var colony := Colony.new(&"cape_harbour")
	colony.tick(2.0)  # base rate 1.0/s x 2s = 2.0, no colonists needed
	assert_almost_eq(colony.local_stock.get(&"cod", 0.0), 2.0, 0.0001)


func test_staffed_capital_produces_into_central_inventory() -> void:
	Game.routing.set_mode(&"timber", Game.routing.RESERVE)
	var capital := Colony.new(&"tidewater_landing")
	capital.tick(2.0)  # base rate alone: 1.0/s x 2s = 2.0 timber
	assert_almost_eq(Game.inventory.get_amount(&"timber"), 2.0, 0.0001)


func test_capital_never_accumulates_local_stock() -> void:
	var capital := Colony.new(&"tidewater_landing")
	capital.tick(5.0)
	assert_eq(capital.local_stock, {})


func test_non_capital_colony_produces_into_local_stock_not_central_inventory() -> void:
	var colony := Colony.new(&"cape_harbour")
	colony.tick(3.0)
	assert_almost_eq(colony.local_stock.get(&"cod", 0.0), 3.0, 0.0001)
	assert_eq(Game.inventory.get_amount(&"cod"), 0.0, "non-Capital production must not reach central inventory")


func test_collect_empties_and_returns_local_stock() -> void:
	var colony := Colony.new(&"cape_harbour")
	colony.tick(4.0)
	var collected: Dictionary = colony.collect()
	assert_almost_eq(collected.get(&"cod", 0.0), 4.0, 0.0001)
	assert_eq(colony.local_stock, {}, "collect() must empty local_stock")


func test_a_resource_colonist_boosts_production_on_top_of_the_base_rate() -> void:
	var colony := Colony.new(&"cape_harbour")
	Game.run.influence = 100.0
	var colonist: Colonist = Game.colonists.recruit(Colonist.Type.RESOURCE)
	Game.colonists.assign(colonist.id, &"cape_harbour")

	# Colonist primary bonus is +10%/level, starts at level 1: 1.0 x 1.1 = 1.1/s
	colony.tick(2.0)
	assert_almost_eq(colony.local_stock.get(&"cod", 0.0), 2.2, 0.0001)


func test_a_cargo_or_speed_colonist_does_not_affect_production() -> void:
	var colony := Colony.new(&"cape_harbour")
	Game.run.influence = 1000.0
	var cargo_colonist: Colonist = Game.colonists.recruit(Colonist.Type.CARGO)
	Game.colonists.assign(cargo_colonist.id, &"cape_harbour")

	colony.tick(2.0)  # still just the base rate - no Resource colonist assigned
	assert_almost_eq(colony.local_stock.get(&"cod", 0.0), 2.0, 0.0001)


func test_production_level_increases_output_by_the_documented_rate() -> void:
	# Balance: rate *= (1 + 0.25 * level).
	var colony := Colony.new(&"cape_harbour")
	colony.production_level = 2  # x(1 + 0.5) = x1.5

	colony.tick(2.0)  # 1.0 x 1.5 x 2s = 3.0
	assert_almost_eq(colony.local_stock.get(&"cod", 0.0), 3.0, 0.0001)


func test_ticks_accumulate_continuously_across_multiple_calls() -> void:
	var colony := Colony.new(&"cape_harbour")
	colony.tick(1.0)
	colony.tick(1.5)
	assert_almost_eq(colony.local_stock.get(&"cod", 0.0), 2.5, 0.0001)


## Distance is now real, generated map distance (rework task: randomized
## map), not a 0-7 index tied to which tier a colony is - two colonies of
## the same tier can be at completely different distances. Set once at
## founding/restore, read back verbatim by distance().
func test_distance_returns_the_colonys_set_distance_cells() -> void:
	var colony := Colony.new(&"cape_harbour")
	colony.distance_cells = 12.5
	assert_almost_eq(colony.distance(), 12.5, 0.0001)


func test_distance_defaults_to_zero() -> void:
	assert_almost_eq(Colony.new(&"cape_harbour").distance(), 0.0, 0.0001)


func test_cargo_capacity_matches_the_documented_formula() -> void:
	# base_cargo 20.0, no level, no colonists: 20 x 1 x 1 = 20
	var colony := Colony.new(&"cape_harbour")
	assert_almost_eq(colony.cargo_capacity(), 20.0, 0.0001)


func test_cargo_level_increases_capacity() -> void:
	# 20 * (1 + 0.5 * 2) = 40
	var colony := Colony.new(&"cape_harbour")
	colony.cargo_level = 2
	assert_almost_eq(colony.cargo_capacity(), 40.0, 0.0001)


func test_round_trip_seconds_matches_the_documented_formula() -> void:
	# distance 1 x 12s (land) / base_speed 1.0 = 12
	var colony := Colony.new(&"cape_harbour")
	colony.distance_cells = 1.0
	colony.is_coastal = false
	assert_almost_eq(colony.round_trip_seconds(), 12.0, 0.0001)


func test_speed_level_reduces_round_trip_time() -> void:
	# 12 / (1.0 * (1 + 0.5*2)) = 6.0
	var colony := Colony.new(&"cape_harbour")
	colony.distance_cells = 1.0
	colony.is_coastal = false
	colony.speed_level = 2
	assert_almost_eq(colony.round_trip_seconds(), 6.0, 0.0001)


func test_purchase_production_level_deducts_gold_and_increases_level() -> void:
	var colony := Colony.new(&"cape_harbour")
	var cost: float = colony.next_production_level_cost()
	var ok: bool = colony.purchase_production_level()
	assert_true(ok)
	assert_eq(colony.production_level, 1)
	assert_almost_eq(Game.economy.gold, 1000.0 - cost, 0.0001)


func test_purchase_cargo_level_deducts_gold_and_increases_level() -> void:
	var colony := Colony.new(&"cape_harbour")
	var ok: bool = colony.purchase_cargo_level()
	assert_true(ok)
	assert_eq(colony.cargo_level, 1)


func test_purchase_speed_level_deducts_gold_and_increases_level() -> void:
	var colony := Colony.new(&"cape_harbour")
	var ok: bool = colony.purchase_speed_level()
	assert_true(ok)
	assert_eq(colony.speed_level, 1)


func test_purchase_fails_and_changes_nothing_with_insufficient_gold() -> void:
	var colony := Colony.new(&"cape_harbour")
	Game.economy.try_spend(1000.0)  # drain the pool
	var ok: bool = colony.purchase_production_level()
	assert_false(ok)
	assert_eq(colony.production_level, 0)


func test_capital_is_always_coastal_and_route_type_is_irrelevant() -> void:
	# The Capital never ships anywhere (nothing routes to itself) - route_type
	# is meaningless for it, but is_coastal defaults true (real geography:
	# MapGenerator.place_capital only ever picks a coastal continent cell).
	var capital := Colony.new(&"tidewater_landing")
	assert_true(capital.is_coastal)
	assert_eq(capital.route_type, Colony.RouteType.SEA)


func test_route_type_is_derived_from_is_coastal() -> void:
	var colony := Colony.new(&"cape_harbour")
	assert_eq(colony.route_type, Colony.RouteType.LAND, "defaults false/LAND until real placement data is applied")
	colony.is_coastal = true
	assert_eq(colony.route_type, Colony.RouteType.SEA)


## Proves the Capital's production actually goes through Routing, not
## straight to inventory - a resource routed SELL should turn into gold
## instead of piling up in storage.
func test_capital_production_sells_instead_of_stocking_when_routed_sell() -> void:
	Game.routing.set_mode(&"timber", Game.routing.SELL)
	var gold_before: float = Game.economy.gold  # before_each already granted 1000
	var capital := Colony.new(&"tidewater_landing")
	capital.tick(2.0)  # 2.0 timber x base_value 1.0 = 2.0 gold
	assert_almost_eq(Game.inventory.get_amount(&"timber"), 0.0, 0.0001)
	assert_almost_eq(Game.economy.gold, gold_before + 2.0, 0.0001)


func test_unknown_colony_id_is_a_safe_no_op() -> void:
	var colony := Colony.new(&"does_not_exist")
	colony.tick(100.0)
	assert_eq(colony.local_stock, {})
	assert_eq(colony.resource_id(), &"")
	assert_almost_eq(colony.production_rate(), 0.0, 0.0001)
	assert_almost_eq(colony.cargo_capacity(), 0.0, 0.0001)
