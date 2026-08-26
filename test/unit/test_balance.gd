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


func test_prestige_gate_is_not_met_below_the_threshold() -> void:
	assert_false(Balance.prestige_gate_met(1_999_999_999.0))


func test_prestige_gate_is_met_at_the_threshold() -> void:
	assert_true(Balance.prestige_gate_met(2_000_000_000.0))


func test_prestige_liberty_payout_matches_the_documented_formula() -> void:
	# floor(6 * sqrt(1)) = 6 at exactly the gate.
	assert_eq(Balance.prestige_liberty_payout(2_000_000_000.0), 6)
	# Doubling earnings gives ~8.5 per the doc's own worked example.
	assert_eq(Balance.prestige_liberty_payout(4_000_000_000.0), 8)


func test_prestige_liberty_payout_is_zero_with_no_earnings() -> void:
	assert_eq(Balance.prestige_liberty_payout(0.0), 0)


func test_industry_cost_and_bonus_match_level_one() -> void:
	assert_almost_eq(Balance.next_industry_cost(0), 3.0, 0.0001)
	assert_almost_eq(Balance.industry_production_multiplier(1), 1.15, 0.0001)


func test_navigation_cost_and_bonuses_match_level_one() -> void:
	assert_almost_eq(Balance.next_navigation_cost(0), 4.0, 0.0001)
	assert_almost_eq(Balance.navigation_speed_multiplier(1), 1.12, 0.0001)
	assert_almost_eq(Balance.navigation_cargo_multiplier(1), 1.12, 0.0001)


func test_settlement_cost_and_discount_match_level_one() -> void:
	assert_almost_eq(Balance.next_settlement_cost(0), 5.0, 0.0001)
	assert_almost_eq(Balance.settlement_cost_multiplier(1), 0.93, 0.0001)


func test_settlement_discount_compounds_multiplicatively_with_level() -> void:
	# 0.93^2 = 0.8649
	assert_almost_eq(Balance.settlement_cost_multiplier(2), 0.8649, 0.0001)


func test_settlement_discount_floors_at_the_configured_maximum() -> void:
	# Even a hypothetical very high level must never discount past -60%.
	assert_almost_eq(Balance.settlement_cost_multiplier(100), 0.4, 0.0001)


func test_prestige_multipliers_at_level_zero_are_neutral() -> void:
	assert_almost_eq(Balance.industry_production_multiplier(0), 1.0, 0.0001)
	assert_almost_eq(Balance.navigation_speed_multiplier(0), 1.0, 0.0001)
	assert_almost_eq(Balance.navigation_cargo_multiplier(0), 1.0, 0.0001)
	assert_almost_eq(Balance.settlement_cost_multiplier(0), 1.0, 0.0001)


func test_round_trip_seconds_accepts_a_real_grid_distance() -> void:
	# distance is now a float (real grid cells, rework task: randomized map),
	# not the old small int - a fractional value must work the same way.
	assert_almost_eq(Balance.route_round_trip_seconds(4.5, false, 1.0, 0, 0), 54.0, 0.0001)


func test_map_generation_settings_match_balance_tres() -> void:
	assert_eq(Balance.map_width(), 60)
	assert_eq(Balance.map_height(), 60)
	assert_almost_eq(Balance.continent_threshold(), 0.6, 0.0001)
	assert_eq(Balance.island_count(), 5)
	assert_almost_eq(Balance.island_min_radius(), 3.0, 0.0001)
	assert_almost_eq(Balance.island_max_radius(), 7.0, 0.0001)
	assert_almost_eq(Balance.colony_distance_step(), 2.5, 0.0001)
	assert_almost_eq(Balance.min_colony_spacing(), 2.0, 0.0001)
	assert_eq(Balance.max_colonies(), 25)


func test_next_colony_slot_cost_matches_the_fitted_curve() -> void:
	# base 250, growth 13 - fit against the old hand-authored table.
	assert_almost_eq(Balance.next_colony_slot_cost(1), 250.0, 0.0001)
	assert_almost_eq(Balance.next_colony_slot_cost(2), 3250.0, 0.01)
	assert_almost_eq(Balance.next_colony_slot_cost(3), 42250.0, 0.01)


func test_next_colony_slot_cost_applies_the_prestige_discount() -> void:
	assert_almost_eq(Balance.next_colony_slot_cost(1, 0.93), 250.0 * 0.93, 0.0001)
