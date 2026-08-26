## Child of Game. Owns the active Colony instances (task P2) and fans out
## tick() to all of them - mirrors Unity's ColonyController register/
## unregister/Tick pattern (docs/GODOT_MIGRATION_ANALYSIS.md §A2), reimplemented
## as a plain typed Array rather than a Node registry, since Colony (task P2)
## is a RefCounted, not a scene object.
extends Node

var _active: Array[Colony] = []


## Deduplicates by colony_id, not object identity - there is exactly one
## live Colony per id (get_colony()/capital() both assume this), so
## registering a second, different instance for an id that's already active
## is silently ignored rather than creating a desynced duplicate.
func register(colony: Colony) -> void:
	if colony != null and not has(colony.colony_id):
		_active.append(colony)


func unregister(colony: Colony) -> void:
	_active.erase(colony)


func tick(delta: float) -> void:
	for colony: Colony in _active:
		colony.tick(delta)


func all() -> Array[Colony]:
	return _active.duplicate()


func has(colony_id: StringName) -> bool:
	return get_colony(colony_id) != null


## Returns the live registered instance for `colony_id`, or null if it hasn't
## been founded/registered yet - the same instance Route/UI/save all read,
## never a fresh copy (Colony holds mutable purchased-level state, so a
## second instance would silently desync from the one everything else uses).
func get_colony(colony_id: StringName) -> Colony:
	for colony: Colony in _active:
		if colony.colony_id == colony_id:
			return colony
	return null


func capital() -> Colony:
	for colony: Colony in _active:
		if colony.is_capital:
			return colony
	return null


func clear() -> void:
	_active.clear()
