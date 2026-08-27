## Tests for Format.number() (docs/GAME_DESIGN.md §11 Phase 7: "£1.2M, not
## £1200000"). Pure static utility - no Game/autoload state involved.
extends GutTest


func test_small_value_shows_as_a_whole_number_by_default() -> void:
	assert_eq(Format.number(0.0), "0")
	assert_eq(Format.number(842.0), "842")
	assert_eq(Format.number(999.0), "999")


func test_small_value_with_decimals_keeps_fractional_precision() -> void:
	assert_eq(Format.number(12.3, 1), "12.3")
	assert_eq(Format.number(0.0, 1), "0.0")


func test_negative_value_keeps_its_sign() -> void:
	assert_eq(Format.number(-842.0), "-842")


func test_thousands_abbreviate_with_k_suffix() -> void:
	assert_eq(Format.number(1000.0), "1.0K")
	assert_eq(Format.number(12345.0), "12.3K")


func test_millions_abbreviate_with_m_suffix() -> void:
	assert_eq(Format.number(1250000.0), "1.3M")


func test_billions_and_trillions_abbreviate() -> void:
	assert_eq(Format.number(2_500_000_000.0), "2.5B")
	assert_eq(Format.number(7_800_000_000_000.0), "7.8T")


func test_decimals_argument_is_ignored_once_abbreviated() -> void:
	# Abbreviating already discards sub-unit precision - a caller passing
	# decimals=1 for the un-abbreviated small-number case shouldn't get two
	# decimal places once the value crosses into K/M/etc.
	assert_eq(Format.number(1500.0, 1), "1.5K")


func test_magnitude_past_the_last_named_suffix_keeps_stepping() -> void:
	# Past the largest named suffix (Qi, 10^18), the formatter keeps
	# dividing and appends the extra step count instead of freezing.
	var value: float = pow(1000.0, 8.0) * 3.0
	var result: String = Format.number(value)
	assert_true(result.begins_with("3.0Qi^2"), "expected a stepped Qi suffix, got: %s" % result)
