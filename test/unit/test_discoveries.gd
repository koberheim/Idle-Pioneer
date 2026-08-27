## Tests for Discoveries (direct request: Market/Crafting should only list
## what a run has actually encountered, in the order encountered - see the
## class doc). lumber_recipe (2 timber -> 1 lumber) is the real fixture used
## throughout: a recipe with exactly one input resource keeps the "all
## inputs discovered" check exercisable with a single discover_resource()
## call.
extends GutTest


func before_each() -> void:
	Game.new_run(&"mvp_coast")


func after_each() -> void:
	Game.run = null


func test_nothing_is_discovered_at_the_start_of_a_run() -> void:
	assert_eq(Game.discoveries.discovered_resources(), [] as Array[StringName])
	assert_eq(Game.discoveries.discovered_recipes(), [] as Array[StringName])


## Found via the nation-picker screen (direct request): MainScreen now
## calls refresh_all() - which reaches every panel's refresh(), including
## CraftingPanel/MarketPanel's calls into these two methods - before
## Game.new_run() has ever run, while the player is still choosing a
## nation. An untyped `[]` literal returned from a function declared
## `-> Array[StringName]` is a runtime type error in that case, not a
## silently-working empty array.
func test_discovered_resources_and_recipes_are_safe_with_no_active_run() -> void:
	Game.run = null
	assert_eq(Game.discoveries.discovered_resources(), [] as Array[StringName])
	assert_eq(Game.discoveries.discovered_recipes(), [] as Array[StringName])


func test_discover_resource_adds_it_once() -> void:
	Game.discoveries.discover_resource(&"timber")
	assert_true(Game.discoveries.is_resource_discovered(&"timber"))
	assert_eq(Game.discoveries.discovered_resources(), [&"timber"] as Array[StringName])


func test_discover_resource_is_idempotent() -> void:
	Game.discoveries.discover_resource(&"timber")
	Game.discoveries.discover_resource(&"timber")
	assert_eq(Game.discoveries.discovered_resources().size(), 1)


func test_discover_resource_emits_signal_only_on_first_discovery() -> void:
	watch_signals(Game.discoveries)
	Game.discoveries.discover_resource(&"timber")
	Game.discoveries.discover_resource(&"timber")
	assert_signal_emit_count(Game.discoveries, "resource_discovered", 1)


func test_discovery_order_is_preserved() -> void:
	Game.discoveries.discover_resource(&"timber")
	Game.discoveries.discover_resource(&"cod")
	assert_eq(Game.discoveries.discovered_resources(), [&"timber", &"cod"] as Array[StringName])


func test_recipe_becomes_discovered_once_all_its_inputs_are() -> void:
	assert_false(Game.discoveries.is_recipe_discovered(&"lumber_recipe"))
	Game.discoveries.discover_resource(&"timber")
	assert_true(Game.discoveries.is_recipe_discovered(&"lumber_recipe"), "lumber_recipe needs only timber")


func test_recipe_discovery_emits_signal() -> void:
	watch_signals(Game.discoveries)
	Game.discoveries.discover_resource(&"timber")
	assert_signal_emitted_with_parameters(Game.discoveries, "recipe_discovered", [&"lumber_recipe"])


func test_routing_deliver_discovers_the_resource() -> void:
	Game.routing.deliver(&"timber", 5.0)
	assert_true(Game.discoveries.is_resource_discovered(&"timber"))


func test_crafting_discovers_the_output_resource() -> void:
	Game.discoveries.discover_resource(&"timber")
	Game.inventory.add(&"timber", 2.0)
	Crafting.craft(&"lumber_recipe")
	assert_true(Game.discoveries.is_resource_discovered(&"lumber"))


func test_new_run_resets_discoveries() -> void:
	Game.discoveries.discover_resource(&"timber")
	Game.new_run(&"mvp_coast")
	assert_eq(Game.discoveries.discovered_resources(), [] as Array[StringName])
