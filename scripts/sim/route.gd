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

## Safety cap on how many state-steps a single tick() call will take (see
## tick()'s doc below) - not a realistic limit, just a guard against an
## unforeseen bug turning a large delta into a true infinite loop.
const MAX_STEPS_PER_TICK: int = 200000


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


## Advances the route by `delta` seconds. Loops through as many departures,
## arrivals, and legs as `delta` and the available cargo allow - not just
## one - so a large delta (e.g. catching up several hours or days of offline
## time in one call) correctly completes every round trip that time and
## cargo actually cover, rather than completing at most one leg transition
## and silently dropping the rest. Each step reports how much of the budget
## it actually spent; the loop stops the moment a step spends nothing (e.g.
## idle at the origin with nothing left to load).
func tick(delta: float) -> void:
	var remaining: float = delta
	var steps: int = 0
	while remaining > 0.0 and steps < MAX_STEPS_PER_TICK:
		steps += 1
		var state_before: State = state
		var consumed: float = _step(remaining)
		remaining -= consumed
		if state == state_before and consumed <= 0.0:
			break  # genuinely stuck - AT_ORIGIN with nothing to load


## Advances at most one state transition, capped at `budget` seconds. Returns
## how much of `budget` was actually spent - 0.0 for a departure (departing
## itself takes no simulated time; the loop above keeps going with the same
## budget so the newly-started leg gets to use it) and 0.0 when no progress
## was possible at all.
func _step(budget: float) -> float:
	match state:
		State.AT_ORIGIN:
			_try_depart()
			return 0.0
		State.TRAVELING_TO_HUB:
			return _advance_leg(budget, _arrive_at_hub)
		State.TRAVELING_TO_ORIGIN:
			return _advance_leg(budget, _arrive_at_origin)
	return 0.0


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


## Advances the current leg by at most `budget` seconds, stopping exactly at
## arrival rather than overshooting into the next leg - overshoot is the
## caller's (tick()'s) job to redistribute on its next loop iteration, since
## on_arrive() can change state (and therefore what "the current leg" even
## means) out from under a single call here. Returns how much time was spent.
func _advance_leg(budget: float, on_arrive: Callable) -> float:
	var duration: float = leg_duration()
	if duration <= 0.0:
		on_arrive.call()
		return 0.0
	var remaining_on_leg: float = duration - leg_elapsed
	var spent: float = minf(budget, remaining_on_leg)
	leg_elapsed += spent
	if leg_elapsed >= duration:
		leg_elapsed = duration
		on_arrive.call()
	return spent


func _arrive_at_hub() -> void:
	for id: StringName in cargo.keys():
		Game.routing.deliver(id, cargo[id])
	delivered.emit(cargo)
	cargo = {}
	leg_elapsed = 0.0
	state = State.TRAVELING_TO_ORIGIN


func _arrive_at_origin() -> void:
	state = State.AT_ORIGIN
	leg_elapsed = 0.0
