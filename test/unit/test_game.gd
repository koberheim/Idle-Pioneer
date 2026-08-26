## Tests for Game's RunState/MetaState wiring (task G3).
##
## Game is an autoload - a live singleton shared across the whole test process,
## not a fresh instance per test. before_each/after_each reset it explicitly so
## these tests can't leak state into each other or into later test files that
## also touch Game (e.g. task R1's Inventory tests).
extends GutTest


func before_each() -> void:
	Game.run = null
	Game.meta = MetaState.new()


func after_each() -> void:
	Game.run = null
	Game.meta = MetaState.new()


func test_fresh_game_has_no_run() -> void:
	assert_false(Game.has_run())
	assert_null(Game.run)


func test_new_run_creates_a_run_with_the_given_map_id() -> void:
	Game.new_run(&"mvp_coast")
	assert_true(Game.has_run())
	assert_eq(Game.run.map_id, &"mvp_coast")


func test_two_new_run_calls_produce_independent_state() -> void:
	Game.new_run(&"mvp_coast")
	Game.run.gold = 500.0
	Game.run.colonies_founded = 3

	Game.new_run(&"mvp_coast")

	# The second run must not carry over the first's mutations - if it did,
	# something cached the old RunState instead of reading Game.run fresh.
	assert_eq(Game.run.gold, 0.0)
	assert_eq(Game.run.colonies_founded, 0)


func test_new_run_does_not_touch_meta() -> void:
	Game.meta.doubloons = 5
	Game.meta.lifetime_gold_earned = 1000.0

	Game.new_run(&"mvp_coast")
	Game.new_run(&"mvp_coast")

	assert_eq(Game.meta.doubloons, 5)
	assert_eq(Game.meta.lifetime_gold_earned, 1000.0)


func test_new_run_emits_run_started() -> void:
	watch_signals(Game)
	Game.new_run(&"mvp_coast")
	assert_signal_emitted(Game, "run_started")


func test_new_run_does_not_emit_run_ended_when_no_prior_run_existed() -> void:
	watch_signals(Game)
	Game.new_run(&"mvp_coast")
	assert_signal_not_emitted(Game, "run_ended")


func test_starting_a_second_run_emits_run_ended_for_the_first() -> void:
	Game.new_run(&"mvp_coast")
	watch_signals(Game)
	Game.new_run(&"mvp_coast")
	assert_signal_emitted(Game, "run_ended")
	assert_signal_emitted(Game, "run_started")
