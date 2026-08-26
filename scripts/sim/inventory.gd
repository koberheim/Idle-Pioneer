## Child of Game. Central resource stock (task R1) - add/remove/query, with a
## change signal UI subscribes to instead of polling. Reads and writes
## Game.run.inventory directly (per Game's class doc: always the live RunState,
## never a cached copy - so this class deliberately holds no local dictionary
## of its own).
extends Node

signal changed(id: StringName, total: float, delta: float)


## Adds `amount` of `id` to the stock. `amount` must be positive - use
## try_remove for subtraction, never a negative add().
func add(id: StringName, amount: float) -> void:
	if not _check_known_resource("add", id):
		return
	if amount <= 0.0:
		push_error("Inventory.add: amount must be > 0, got %f" % amount)
		return

	var inv: Dictionary = Game.run.inventory
	var total: float = float(inv.get(id, 0.0)) + amount
	inv[id] = total
	changed.emit(id, total, amount)


## Removes `amount` of `id` if (and only if) that much is available. Returns
## false and mutates nothing on insufficient stock - never a partial removal.
func try_remove(id: StringName, amount: float) -> bool:
	if not _check_known_resource("try_remove", id):
		return false
	if amount <= 0.0:
		push_error("Inventory.try_remove: amount must be > 0, got %f" % amount)
		return false

	var inv: Dictionary = Game.run.inventory
	var current: float = float(inv.get(id, 0.0))
	if current < amount:
		return false

	# Clamp rather than let float subtraction drift to a tiny negative
	# (e.g. -0.0000001) that would then read as "has stock" to a naive `> 0`
	# check elsewhere.
	var total: float = maxf(0.0, current - amount)
	inv[id] = total
	changed.emit(id, total, -amount)
	return true


## 0.0 for a known resource that's simply never been held - that's a normal
## empty-stock state, not an error. An id that isn't a real ResourceDef at all
## is the error case (see _check_known_resource).
func get_amount(id: StringName) -> float:
	if not _check_known_resource("get_amount", id):
		return 0.0
	if Game.run == null:
		return 0.0
	return float(Game.run.inventory.get(id, 0.0))


func has(id: StringName, amount: float) -> bool:
	return get_amount(id) >= amount


func all() -> Dictionary:
	if Game.run == null:
		return {}
	return Game.run.inventory.duplicate()


## An id that isn't a real ResourceDef is a caller bug, not a legitimate "empty
## stock" state - loud error, never a silent zero (docs/GODOT_PLAN.md task R1's
## explicit acceptance criterion). Also catches "no run in progress," which is
## just as much a caller error for anything touching live inventory.
func _check_known_resource(caller: String, id: StringName) -> bool:
	if Game.run == null:
		push_error("Inventory.%s: no active run" % caller)
		return false
	if not Db.has_resource(id):
		push_error("Inventory.%s: unknown resource id '%s'" % [caller, id])
		return false
	return true
