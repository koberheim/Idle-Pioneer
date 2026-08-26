## Child of Game. Owns the active Colony instances (task P2) and fans out
## tick() to all of them - mirrors Unity's ColonyController register/
## unregister/Tick pattern (docs/GODOT_MIGRATION_ANALYSIS.md §A2), reimplemented
## as a plain typed Array rather than a Node registry, since Colony (task P2)
## is a RefCounted, not a scene object.
extends Node

var _active: Array[Colony] = []


func register(colony: Colony) -> void:
	if colony != null and not _active.has(colony):
		_active.append(colony)


func unregister(colony: Colony) -> void:
	_active.erase(colony)


func tick(delta: float) -> void:
	for colony: Colony in _active:
		colony.tick(delta)


func all() -> Array[Colony]:
	return _active.duplicate()


func clear() -> void:
	_active.clear()
