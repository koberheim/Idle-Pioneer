## Child of Game. Owns the active Colony instances (task P2) and fans out
## tick() to all of them - mirrors Unity's ColonyController register/
## unregister/Tick pattern (docs/GODOT_MIGRATION_ANALYSIS.md §A2), reimplemented
## as a plain typed Array rather than a Node registry, since Colony (task P2)
## is a RefCounted, not a scene object.
extends Node

signal founded(colony: Colony)

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


## The next colony available to found, in the fixed order defined by
## docs/GAME_DESIGN.md §5's colony table (ColonyDef.order) - colonies must be
## founded in sequence, one at a time, matching that table's own framing of
## "distance." Null once every colony is founded, or before the Capital
## itself has been bootstrapped (see game.gd's new_run()).
func next_to_found() -> ColonyDef:
	if capital() == null:
		return null
	for def: ColonyDef in Db.all_colonies():
		if not def.is_capital and not has(def.id):
			return def
	return null


## Spends gold and founds `colony_id`, if (and only if) it's the actual next
## colony in sequence and there's enough gold for it - see next_to_found().
## Returns false and changes nothing otherwise (unknown id, Capital, out of
## order, or insufficient funds).
func found(colony_id: StringName) -> bool:
	var next: ColonyDef = next_to_found()
	if next == null or next.id != colony_id:
		return false
	if not Game.economy.try_spend(Game.economy.colony_cost(colony_id)):
		return false

	var colony := Colony.new(colony_id)
	register(colony)
	if Game.run != null:
		Game.run.colonies_founded += 1
	founded.emit(colony)
	return true


func clear() -> void:
	_active.clear()
