## Transport between a colony and the Capital (docs/GAME_DESIGN.md §5/§6).
##
## Simplified further than the document's own §6 wording by explicit
## direction in conversation: no "full or 30 seconds, whichever comes first"
## timer. A transport just cycles continuously - the moment it's back at its
## origin, it loads whatever's ready (up to capacity) and departs immediately,
## even if that's a partial load. There is no waiting, ever.
##
## Capacity and travel time both come from the origin Colony's own stats
## (Balance-driven: a per-colony base value, a gold-bought upgrade level, and
## the shared colonist bonus - see Colony.cargo_capacity()/round_trip_seconds()
## and docs/GODOT_PLAN.md's design realignment section). Land vs. sea
## (Colony.route_type, rolled once per colony) affects only travel time now.
##
## No sprite, no Node2D, no visual position - v1 ships with a plain list
## interface, not a map (§10, §12), so there's no geography left to animate a
## vehicle across. progress() (0-1 through the current leg) is kept
## regardless: it's still exactly what a shipping-status row in a list needs,
## and the one part worth reusing if a visual pass ever returns.
class_name Route
extends RefCounted

signal delivered(cargo: Dictionary)

enum State {
	AT_ORIGIN,
	TRAVELING_TO_HUB,
	TRAVELING_TO_ORIGIN,
}

var origin: Colony
var destination: Colony  # always the Capital in practice; Route itself stays generic

var state: State = State.AT_ORIGIN
var cargo: Dictionary = {}  # StringName -> float, only non-empty while traveling
var leg_elapsed: float = 0.0


func _init(p_origin: Colony, p_destination: Colony) -> void:
	origin = p_origin
	destination = p_destination


## Re-read live from the origin colony every call, never cached at
## construction - an upgrade purchased mid-run takes effect on the very next
## departure/leg, not the next Route object.
func capacity() -> float:
	return origin.cargo_capacity()


func leg_duration() -> float:
	return origin.round_trip_seconds() / 2.0


## 0.0 when idle at the origin (nothing in flight to show progress on); 0 -> 1
## across whichever leg is currently underway.
func progress() -> float:
	var duration: float = leg_duration()
	if state == State.AT_ORIGIN or duration <= 0.0:
		return 0.0
	return clampf(leg_elapsed / duration, 0.0, 1.0)


## Advances the route by `delta` seconds: at the origin, tries to load and
## depart every call (see the class doc - no waiting, ever); mid-journey,
## advances toward arrival.
func tick(delta: float) -> void:
	match state:
		State.AT_ORIGIN:
			_try_depart()
		State.TRAVELING_TO_HUB:
			_advance_leg(delta, _arrive_at_hub)
		State.TRAVELING_TO_ORIGIN:
			_advance_leg(delta, _arrive_at_origin)


func _try_depart() -> void:
	var loaded: Dictionary = _load_cargo()
	if loaded.is_empty():
		return
	cargo = loaded
	leg_elapsed = 0.0
	state = State.TRAVELING_TO_HUB


## Loads up to capacity() from origin.local_stock, highest ResourceDef.base_value
## first (the same cargo-prioritisation this project has used since task P3).
## Removes exactly what it loads from local_stock, so a partial load leaves
## the rest for next time - there is always a "next time," immediately.
func _load_cargo() -> Dictionary:
	var available: Dictionary = origin.local_stock
	if available.is_empty():
		return {}

	var ids: Array = available.keys()
	ids.sort_custom(_by_value_descending)

	var loaded: Dictionary = {}
	var remaining: float = capacity()
	for id: StringName in ids:
		if remaining <= 0.0:
			break
		var take: float = minf(float(available[id]), remaining)
		if take <= 0.0:
			continue
		loaded[id] = take
		remaining -= take

	for id: StringName in loaded.keys():
		var left: float = float(origin.local_stock.get(id, 0.0)) - float(loaded[id])
		if left <= 0.0:
			origin.local_stock.erase(id)
		else:
			origin.local_stock[id] = left

	return loaded


func _by_value_descending(a: StringName, b: StringName) -> bool:
	var def_a: ResourceDef = Db.resource(a)
	var def_b: ResourceDef = Db.resource(b)
	var value_a: float = def_a.base_value if def_a != null else 0.0
	var value_b: float = def_b.base_value if def_b != null else 0.0
	return value_a > value_b


func _advance_leg(delta: float, on_arrive: Callable) -> void:
	var duration: float = leg_duration()
	if duration <= 0.0:
		on_arrive.call()
		return
	leg_elapsed += delta
	if leg_elapsed >= duration:
		leg_elapsed = duration
		on_arrive.call()


func _arrive_at_hub() -> void:
	for id: StringName in cargo.keys():
		Game.inventory.add(id, cargo[id])
	delivered.emit(cargo)
	cargo = {}
	leg_elapsed = 0.0
	state = State.TRAVELING_TO_ORIGIN


func _arrive_at_origin() -> void:
	state = State.AT_ORIGIN
	leg_elapsed = 0.0
