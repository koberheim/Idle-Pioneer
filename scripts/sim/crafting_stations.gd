## Child of Game. Owns one CraftingStation per recipe the player has touched
## (auto-craft toggled, or otherwise created on demand) and fans out tick()
## to all of them - mirrors Colonies' register/tick pattern (scripts/sim/
## colonies.gd), keyed by recipe id instead of holding an explicit list.
extends Node

var _stations: Dictionary = {}  # StringName (recipe_id) -> CraftingStation


## Returns the station for `recipe_id`, creating one (auto_craft off by
## default) the first time it's asked for.
func get_or_create(recipe_id: StringName) -> CraftingStation:
	if not _stations.has(recipe_id):
		_stations[recipe_id] = CraftingStation.new(recipe_id)
	return _stations[recipe_id]


## Returns the existing station for `recipe_id`, or null if none has been
## created yet - does not create one (used by save/load and inspection code
## that shouldn't conjure a station just by looking).
func get_existing(recipe_id: StringName) -> CraftingStation:
	return _stations.get(recipe_id)


func all() -> Array[CraftingStation]:
	var out: Array[CraftingStation] = []
	for station: CraftingStation in _stations.values():
		out.append(station)
	return out


func tick(delta: float) -> void:
	for station: CraftingStation in _stations.values():
		station.tick(delta)


func clear() -> void:
	_stations.clear()
