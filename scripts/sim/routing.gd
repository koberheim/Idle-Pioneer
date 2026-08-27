## Child of Game. Per-resource Sell/Reserve routing at the Capital
## (docs/GAME_DESIGN.md §2/§9/§13's "Sell vs. Reserve" tension). This is the
## single place goods entering the Capital get resolved into either gold or
## central inventory - Colony's production tick (Capital only) and Route's
## hub arrival both call deliver() here instead of touching Game.inventory or
## Game.economy directly.
##
## A resource with no explicit entry defaults to SELL, matching
## docs/GAME_DESIGN.md's own stated default. An earlier pass this session
## deliberately flipped this to RESERVE (goods pile up in storage unless
## explicitly opted into auto-selling); reversed back per direct feedback
## after playtesting - a fresh colony producing and never selling anything
## reads as "gold isn't ticking up," not as an intentional design choice, so
## SELL is the default that actually needs an opt-out, not an opt-in.
extends Node

signal routing_changed(resource_id: StringName, mode: StringName)

const SELL: StringName = &"sell"
const RESERVE: StringName = &"reserve"


func mode_for(resource_id: StringName) -> StringName:
	if Game.run == null:
		return SELL
	return Game.run.resource_routing.get(resource_id, SELL)


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
	Game.discoveries.discover_resource(resource_id)
	if mode_for(resource_id) == SELL:
		Game.economy.add_gold(Game.economy.sell_value(resource_id, amount))
	else:
		Game.inventory.add(resource_id, amount)
