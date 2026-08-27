## Child of Game. Owns the active Colony instances (task P2) and fans out
## tick() to all of them - mirrors Unity's ColonyController register/
## unregister/Tick pattern (docs/GODOT_MIGRATION_ANALYSIS.md §A2), reimplemented
## as a plain typed Array rather than a Node registry, since Colony (task P2)
## is a RefCounted, not a scene object.
##
## Founding (rework task: randomized map) now walks Game.run.colony_slots -
## the per-run generated list of where every colony will sit (see
## Game.new_run() and MapGenerator) - instead of a fixed Db-authored order
## list. Which ColonyDef a slot draws its resource/base stats from cycles
## through the 7 non-Capital tiers repeatedly (tier_order_for_slot()), since
## a run can found more colonies than there are tiers.
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


## Slot 0 is always the Capital's tier (order 0); every slot after that
## cycles through the 7 non-Capital tiers (order 1-7) in sequence, wrapping
## back to order 1 once a run founds more colonies than there are tiers -
## see ColonyDef's class doc.
func tier_order_for_slot(slot_index: int) -> int:
	if slot_index <= 0:
		return 0
	return ((slot_index - 1) % 7) + 1


## The colony_slots entry (see RunState's class doc for the shape) for the
## lowest-indexed unfounded slot - the one `found()` will actually place
## next. Empty (`{}`) if every slot is founded, or there's no active run.
func next_to_found() -> Dictionary:
	if Game.run == null:
		return {}
	for slot: Dictionary in Game.run.colony_slots:
		if not bool(slot.get("founded", false)):
			return slot
	return {}


## Spends gold and founds the colony at `slot_index`, if (and only if) it's
## the actual next slot in sequence and there's enough gold for it - see
## next_to_found(). Returns false and changes nothing otherwise (unknown
## slot, out of order, missing tier content, or insufficient funds).
func found(slot_index: int) -> bool:
	var next: Dictionary = next_to_found()
	if next.is_empty() or int(next["slot_index"]) != slot_index:
		return false

	var tier_def: ColonyDef = Db.colony_by_order(int(next["tier_order"]))
	if tier_def == null:
		return false

	# Nation's colony-cost bonus (direct request) combines with Settlement's
	# discount the same way - both are a straight multiplier on the base
	# cost, so Balance.next_colony_slot_cost() doesn't need to know there
	# are two separate sources for it.
	var cost: float = Balance.next_colony_slot_cost(
		slot_index, Game.prestige.cost_discount_multiplier() * Game.nation_colony_cost_multiplier()
	)
	if not Game.economy.try_spend(cost):
		return false

	var colony := Colony.new(tier_def.id, StringName("slot_%d" % slot_index))
	colony.slot_index = slot_index
	colony.distance_cells = float(next["distance_cells"])
	colony.is_coastal = bool(next["is_coastal"])
	register(colony)

	next["founded"] = true  # colony_slots entries are Dictionaries (reference types) - this mutates the real entry in Game.run.colony_slots, not a copy.

	if Game.run != null:
		Game.run.colonies_founded += 1

	founded.emit(colony)
	return true


func clear() -> void:
	_active.clear()
