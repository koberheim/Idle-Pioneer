## Tests for Routing (rework task: save file structure / Sell vs. Reserve,
## docs/GAME_DESIGN.md §2/§9). Default is RESERVE, not the doc's own stated
## SELL default - a deliberate choice made in conversation so goods keep
## piling up in storage exactly as before this system existed unless the
## player explicitly opts a resource into auto-selling. See Routing's class
## doc.
extends GutTest


func before_each() -> void:
	Game.new_run(&"mvp_coast")


func after_each() -> void:
	Game.run = null


func test_default_mode_is_reserve() -> void:
	assert_eq(Game.routing.mode_for(&"timber"), Game.routing.RESERVE)


func test_set_mode_changes_the_mode() -> void:
	Game.routing.set_mode(&"timber", Game.routing.SELL)
	assert_eq(Game.routing.mode_for(&"timber"), Game.routing.SELL)


func test_set_mode_emits_routing_changed() -> void:
	watch_signals(Game.routing)
	Game.routing.set_mode(&"timber", Game.routing.SELL)
	assert_signal_emitted_with_parameters(Game.routing, "routing_changed", [&"timber", Game.routing.SELL])


func test_set_mode_rejects_an_unknown_mode_and_changes_nothing() -> void:
	Game.routing.set_mode(&"timber", &"bogus")
	assert_eq(Game.routing.mode_for(&"timber"), Game.routing.RESERVE)


func test_deliver_adds_to_inventory_when_reserved() -> void:
	Game.routing.deliver(&"timber", 5.0)
	assert_almost_eq(Game.inventory.get_amount(&"timber"), 5.0, 0.0001)
	assert_almost_eq(Game.economy.gold, 0.0, 0.0001)


func test_deliver_sells_for_gold_when_routed_sell_and_never_touches_inventory() -> void:
	Game.routing.set_mode(&"timber", Game.routing.SELL)
	Game.routing.deliver(&"timber", 5.0)  # timber base_value 1.0
	assert_almost_eq(Game.economy.gold, 5.0, 0.0001)
	assert_almost_eq(Game.inventory.get_amount(&"timber"), 0.0, 0.0001)


func test_deliver_of_a_non_positive_amount_is_a_no_op() -> void:
	Game.routing.deliver(&"timber", 0.0)
	Game.routing.deliver(&"timber", -1.0)
	assert_almost_eq(Game.inventory.get_amount(&"timber"), 0.0, 0.0001)


func test_routing_choice_is_per_resource() -> void:
	Game.routing.set_mode(&"timber", Game.routing.SELL)
	assert_eq(Game.routing.mode_for(&"cod"), Game.routing.RESERVE, "setting one resource must not affect another")
