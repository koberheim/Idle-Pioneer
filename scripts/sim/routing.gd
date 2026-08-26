## Child of Game. Per-resource Sell/Reserve routing at the Capital
## (docs/GAME_DESIGN.md §2/§9/§13's "Sell vs. Reserve" tension). This is the
## single place goods entering the Capital get resolved into either gold or
## central inventory - Colony's production tick (Capital only) and Route's
## hub arrival both call deliver() here instead of touching Game.inventory or
## Game.economy directly.
##
## A resource with no explicit entry defaults to RESERVE, not SELL, by
## direct instruction: goods pile up in storage exactly as they did before
## this system existed unless the player deliberately opts a resource into
## auto-selling. This is a real, considered choice (not the design doc's own
## stated default, which is SELL) - flagged in docs/GODOT_PLAN.md's design
## realignment section since a future balance pass may want to revisit it.
extends Node

signal routing_changed(resource_id: StringName, mode: StringName)

const SELL: StringName = &"sell"
const RESERVE: StringName = &"reserve"


func mode_for(resource_id: StringName) -> StringName:
	if Game.run == null:
		return RESERVE
	return Game.run.resource_routing.get(resource_id, RESERVE)


func set_mode(resource_id: StringName, mode: StringName) -> void:
	if Game.run == null:
		push_error("Routing.set_mode: no active run")
		return
	if mode != SELL and mode != RESERVE:
		push_error("Routing.set_mode: mode must be SELL or RESERVE, got '%s'" % mode)
		return

	Game.run.resource_routing[resource_id] = mode
	routing_changed.emit(resource_id, mode)


## Resolves `amount` of `resource_id` arriving at the Capital: sells it
## immediately for gold if routed SELL (it never touches central inventory at
## all), or adds it to central inventory if routed RESERVE. A no-op for a
## non-positive amount, same contract as Inventory.add()/Economy.add_gold().
func deliver(resource_id: StringName, amount: float) -> void:
	if amount <= 0.0:
		return
	if mode_for(resource_id) == SELL:
		Game.economy.add_gold(Game.economy.sell_value(resource_id, amount))
	else:
		Game.inventory.add(resource_id, amount)
