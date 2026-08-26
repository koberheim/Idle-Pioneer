## Tests for ProductionCycle (task P1).
extends GutTest


func test_partial_advance_completes_no_cycles_and_retains_remainder() -> void:
	var c := ProductionCycle.new(1.0)
	var cycles: int = c.advance(0.5)
	assert_eq(cycles, 0)
	assert_almost_eq(c.accumulated, 0.5, 0.0001)


func test_advance_past_two_cycles_completes_two_and_retains_remainder() -> void:
	var c := ProductionCycle.new(1.0)
	var cycles: int = c.advance(2.5)
	assert_eq(cycles, 2)
	assert_almost_eq(c.accumulated, 0.5, 0.0001)


func test_exact_multiple_advance_leaves_zero_remainder() -> void:
	var c := ProductionCycle.new(1.0)
	var cycles: int = c.advance(3.0)
	assert_eq(cycles, 3)
	assert_almost_eq(c.accumulated, 0.0, 0.0001)


func test_consecutive_small_advances_accumulate_correctly() -> void:
	var c := ProductionCycle.new(1.0)
	assert_eq(c.advance(0.4), 0)
	assert_eq(c.advance(0.4), 0)
	assert_eq(c.advance(0.4), 1)  # 1.2 total - one cycle, 0.2 left
	assert_almost_eq(c.accumulated, 0.2, 0.0001)


func test_zero_delta_is_a_safe_no_op() -> void:
	var c := ProductionCycle.new(1.0)
	c.advance(0.5)
	var cycles: int = c.advance(0.0)
	assert_eq(cycles, 0)
	assert_almost_eq(c.accumulated, 0.5, 0.0001, "zero delta must not touch state")


func test_negative_delta_is_a_safe_no_op() -> void:
	var c := ProductionCycle.new(1.0)
	c.advance(0.5)
	var cycles: int = c.advance(-3.0)
	assert_eq(cycles, 0)
	assert_almost_eq(c.accumulated, 0.5, 0.0001, "negative delta must not touch state")


func test_zero_cycle_seconds_is_a_safe_no_op_not_a_divide_by_zero_crash() -> void:
	var c := ProductionCycle.new(0.0)
	var cycles: int = c.advance(10.0)
	assert_eq(cycles, 0)


func test_negative_cycle_seconds_is_a_safe_no_op() -> void:
	var c := ProductionCycle.new(-1.0)
	var cycles: int = c.advance(10.0)
	assert_eq(cycles, 0)


func test_changing_cycle_length_mid_flight_does_not_corrupt_the_accumulator() -> void:
	var c := ProductionCycle.new(1.0)
	c.advance(0.5)  # 0.5s banked at a 1s cycle
	c.cycle_seconds = 2.0  # now a 2s cycle
	var cycles: int = c.advance(2.0)  # 2.5s total accumulated against a 2s cycle
	assert_eq(cycles, 1)
	assert_almost_eq(c.accumulated, 0.5, 0.0001)


## The whole point of this class: an 8-hour absence must resolve in one division,
## not a loop of 28,800 iterations. This is precisely the calculation Unity
## disabled offline progress to avoid (docs/GODOT_MIGRATION_ANALYSIS.md §E3).
func test_eight_hour_offline_gap_resolves_instantly_via_arithmetic() -> void:
	var c := ProductionCycle.new(1.0)
	var start_usec: int = Time.get_ticks_usec()
	var cycles: int = c.advance(8.0 * 3600.0)
	var elapsed_usec: int = Time.get_ticks_usec() - start_usec

	assert_eq(cycles, 28800)
	assert_almost_eq(c.accumulated, 0.0, 0.0001)
	assert_lt(elapsed_usec, 50000, "should resolve in well under 50ms - a loop would be far slower")


func test_eight_hour_gap_at_a_five_second_cycle_matches_the_mvp_production_rate() -> void:
	# The MVP's actual cycle length (docs/GODOT_PLAN.md Phase 7's lumber recipe
	# and the timber/clay regions both use ~5s cycles).
	var c := ProductionCycle.new(5.0)
	var cycles: int = c.advance(8.0 * 3600.0)
	assert_eq(cycles, 5760)  # 28800s / 5s
