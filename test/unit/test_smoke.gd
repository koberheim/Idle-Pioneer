## Smoke test: proves the GUT harness itself is wired up correctly.
## If this fails, the problem is the test runner, not the game.
extends GutTest


func test_gut_runs() -> void:
	assert_eq(1 + 1, 2, "basic arithmetic should hold")


func test_gut_can_fail() -> void:
	# Sanity check that assertions actually fail when they should.
	# Flip to assert_ne to see it go red, then flip back.
	assert_eq(2 + 2, 4, "basic arithmetic should hold")
