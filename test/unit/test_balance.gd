## Tests for Balance (docs/GAME_DESIGN.md §10's suggested architecture -
## "every constant and formula" in one place, adopted directly). Checks the
## formulas against the real data/balance.tres values, not synthetic numbers,
## so a retune that changes balance.tres and forgets to update these tests
## fails loudly rather than silently drifting.
extends GutTest


func test_colonist_cost_matches_the_documented_curve() -> void:
	assert_almost_eq(Balance.next_colonist_cost(0), 25.0, 0.0001)
	assert_almost_eq(Balance.next_colonist_cost(1), 28.75, 0.01)  # 25 * 1.15


func test_production_level_cost_grows_geometrically() -> void:
	assert_almost_eq(Balance.next_production_level_cost(0), 40.0, 0.0001)
	assert_almost_eq(Balance.next_production_level_cost(1), 45.2, 0.01)  # 40 * 1.13


func test_cargo_level_cost_grows_geometrically() -> void:
	assert_almost_eq(Balance.next_cargo_level_cost(0), 60.0, 0.0001)
	assert_almost_eq(Balance.next_cargo_level_cost(1), 69.6, 0.01)  # 60 * 1.16


func test_speed_level_cost_grows_geometrically() -> void:
	assert_almost_eq(Balance.next_speed_level_cost(0), 60.0, 0.0001)
	assert_almost_eq(Balance.next_speed_level_cost(1), 69.6, 0.01)


func test_production_rate_with_no_bonuses_is_just_the_base_rate() -> void:
	assert_almost_eq(Balance.colony_production_rate(1.0, 0, 0, 1.0), 1.0, 0.0001)


func test_production_rate_scales_with_level() -> void:
	# 1.0 * (1 + 0.25*2) = 1.5
	assert_almost_eq(Balance.colony_production_rate(1.0, 2, 0, 1.0), 1.5, 0.0001)


func test_production_rate_scales_with_colonists() -> void:
	# 1.0 * (1 + 0.1*3) = 1.3
	assert_almost_eq(Balance.colony_production_rate(1.0, 0, 3, 1.0), 1.3, 0.0001)


func test_production_rate_applies_the_prestige_multiplier() -> void:
	assert_almost_eq(Balance.colony_production_rate(1.0, 0, 0, 1.25), 1.25, 0.0001)


func test_cargo_capacity_with_no_bonuses_is_just_the_base_value() -> void:
	assert_almost_eq(Balance.colony_cargo_capacity(20.0, 0, 0), 20.0, 0.0001)


func test_cargo_capacity_scales_with_level_and_colonists() -> void:
	# 20 * (1 + 0.5*1) * (1 + 0.1*2) = 20 * 1.5 * 1.2 = 36
	assert_almost_eq(Balance.colony_cargo_capacity(20.0, 1, 2), 36.0, 0.0001)


func test_round_trip_seconds_land_vs_sea_at_the_same_distance() -> void:
	var land: float = Balance.route_round_trip_seconds(1, false, 1.0, 0, 0)
	var sea: float = Balance.route_round_trip_seconds(1, true, 1.0, 0, 0)
	assert_almost_eq(land, 12.0, 0.0001)
	assert_almost_eq(sea, 22.0, 0.0001)
	assert_gt(sea, land)


func test_round_trip_seconds_decreases_with_speed_level() -> void:
	# 12 / (1 + 0.5*2) = 6.0
	assert_almost_eq(Balance.route_round_trip_seconds(1, false, 1.0, 2, 0), 6.0, 0.0001)


func test_round_trip_seconds_decreases_with_colonists() -> void:
	# 12 / (1 + 0.1*2) = 10.0
	assert_almost_eq(Balance.route_round_trip_seconds(1, false, 1.0, 0, 2), 10.0, 0.0001)


func test_round_trip_seconds_at_zero_distance_is_zero() -> void:
	assert_almost_eq(Balance.route_round_trip_seconds(0, false, 1.0, 0, 0), 0.0, 0.0001)
