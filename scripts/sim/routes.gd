## Child of Game. Owns the live Route instances (one per non-Capital colony,
## always shipping to the Capital) and fans out tick() to all of them -
## mirrors Colonies' register/tick pattern, but self-healing instead of
## requiring an explicit register() call: sync_with_colonies() (run at the
## start of every tick()) creates any missing route for a currently-active
## non-Capital colony and leaves existing ones untouched, so it doesn't
## matter what order colonies get registered/restored in - a route always
## catches up to reality on the very next tick.
##
## Does nothing until the Capital itself is registered (Game.colonies.capital())
## - there's nothing to ship to yet.
extends Node

var _by_colony_id: Dictionary = {}  # StringName (colony_id) -> Route


## Creates a Route for any active non-Capital colony that doesn't have one
## yet. Safe to call every tick - a no-op once every colony already has a
## route, and a no-op entirely until the Capital is registered.
func sync_with_colonies() -> void:
	var capital: Colony = Game.colonies.capital()
	if capital == null:
		return
	for colony: Colony in Game.colonies.all():
		if colony.is_capital:
			continue
		if not _by_colony_id.has(colony.colony_id):
			_by_colony_id[colony.colony_id] = Route.new(colony, capital)


func for_colony(colony_id: StringName) -> Route:
	return _by_colony_id.get(colony_id)


func all() -> Array[Route]:
	var out: Array[Route] = []
	for route: Route in _by_colony_id.values():
		out.append(route)
	return out


func tick(delta: float) -> void:
	sync_with_colonies()
	for route: Route in _by_colony_id.values():
		route.tick(delta)


func clear() -> void:
	_by_colony_id.clear()
