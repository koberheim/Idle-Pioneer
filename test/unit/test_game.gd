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
	Game.colonies.clear()
	Game.colonists.clear_assignments()
	Game.routes.clear()


func after_each() -> void:
	Game.run = null
	Game.meta = MetaState.new()
	Game.colonies.clear()
	Game.colonists.clear_assignments()
	Game.routes.clear()


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


## Found while building the colonist pool: new_run() replaced `Game.run`
## wholesale, but Colonies (live Colony instances) and Colonists (colonist-to-
## site assignments) both live in memory outside RunState, and neither was
## being cleared - a second run would start with the first run's colonies
## and colonist assignments still active. Fixed in game.gd's new_run(); this
## test covers the fix.
##
## A fresh run always has exactly the Capital (bootstrapped automatically -
## see game.gd's new_run(), rework task: live simulation), so "cleared"
## means "only the fresh Capital remains," not "empty" - founding a second
## colony is what proves anything beyond the Capital actually got wiped.
func test_new_run_clears_leftover_colonies_and_colonist_assignments() -> void:
	Game.new_run(&"mvp_coast")
	Game.colonies.register(Colony.new(&"cape_harbour"))
	Game.economy.add_gold(100.0)
	Game.colonists.buy_colonist()
	Game.colonists.assign(&"tidewater_landing", 1)

	Game.new_run(&"mvp_coast")

	var remaining: Array[Colony] = Game.colonies.all()
	assert_eq(remaining.size(), 1, "only the freshly-bootstrapped Capital should remain")
	assert_true(remaining[0].is_capital)
	assert_eq(Game.colonists.total_assigned(), 0, "leftover assignments should be cleared")


## The Capital is free and always founded from the start (docs/GAME_DESIGN.md
## §5) - every other colony has to be bought via Colonies.found().
func test_new_run_bootstraps_the_capital() -> void:
	Game.new_run(&"mvp_coast")
	var capital: Colony = Game.colonies.capital()
	assert_not_null(capital)
	assert_eq(capital.colony_id, &"tidewater_landing")
	assert_true(capital.is_capital)


func test_new_run_does_not_touch_meta() -> void:
	Game.meta.liberty = 5
	Game.meta.lifetime_gold_earned = 1000.0

	Game.new_run(&"mvp_coast")
	Game.new_run(&"mvp_coast")

	assert_eq(Game.meta.liberty, 5)
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
