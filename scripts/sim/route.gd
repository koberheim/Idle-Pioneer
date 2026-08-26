## Transport between a colony and the Capital (docs/GAME_DESIGN.md §5/§6).
##
## Simplified further than the document's own §6 wording by explicit
## direction in conversation: no "full or 30 seconds, whichever comes first"
## timer. A transport just cycles continuously - the moment it's back at its
## origin, it loads whatever's ready (up to capacity) and departs immediately,
## even if that's a partial load. There is no waiting, ever.
##
## Land vs. sea is rolled once per colony (Colony.route_type, §5's "each
## colony rolls land or sea, 50/50") rather than derived from a real map -
## this project's old map/land-water system is left in place, unused; see
## docs/GODOT_PLAN.md's design realignment section for the full reasoning.
## Sea routes get more cargo capacity and cover distance faster (§6).
##
## No sprite, no Node2D, no visual position anymore - v1 ships with a plain
## list interface, not a map (§10, §12), so there's no geography left to
## animate a vehicle across. progress() (0-1 through the current leg) is kept
## regardless: it's still exactly what a shipping-status row in a list needs,
## and it's the one piece worth reusing if a visual pass ever returns.
class_name Route
extends RefCounted

signal delivered(cargo: Dictionary)

enum State {
	AT_ORIGIN,
	TRAVELING_TO_HUB,
	TRAVELING_TO_ORIGIN,
}

## §6's formulas. Where §5's summary table and §6's precise formula disagree
## on how cargo scales with transport level (the table reads as a flat
## `20 x level`; §6 gives `base x (1 + 0.5 x level)`), §6 is treated as
## authoritative - it's the section explicitly meant to be "the single
## Balance autoload" every other number is drawn from.
const CARGO_BASE_LAND: float = 20.0
const CARGO_BASE_SEA: float = 50.0
const CARGO_LEVEL_BONUS: float = 0.5  # +50% capacity per transport level

const TIME_FACTOR_LAND: float = 12.0  # seconds of round-trip time per distance, land
const TIME_FACTOR_SEA: float = 22.0  # seconds of round-trip time per distance, sea

var origin: Colony
var destination: Colony  # always the Capital in practice; Route itself stays generic

var state: State = State.AT_ORIGIN
var cargo: Dictionary = {}  # StringName -> float, only non-empty while traveling
var leg_elapsed: float = 0.0


static func base_cargo_for(route_type: Colony.RouteType) -> float:
	return CARGO_BASE_SEA if route_type == Colony.RouteType.SEA else CARGO_BASE_LAND


static func time_factor_for(route_type: Colony.RouteType) -> float:
	return TIME_FACTOR_SEA if route_type == Colony.RouteType.SEA else TIME_FACTOR_LAND


func _init(p_origin: Colony, p_destination: Colony) -> void:
	origin = p_origin
	destination = p_destination


## Re-read live from origin.transport_level every call, never cached at
## construction - a transport upgrade purchased mid-run takes effect on the
## very next departure, not the next Route object.
func capacity() -> float:
	return base_cargo_for(origin.route_type) * (1.0 + CARGO_LEVEL_BONUS * float(origin.transport_level))


## One-way leg duration. §6 gives a single round_trip_time for the whole out-
## and-back cycle; the document never distinguishes an outbound speed from a
## return speed, so it's split evenly across both legs here.
func leg_duration() -> float:
	var round_trip: float = float(origin.distance()) * time_factor_for(origin.route_type)
	return round_trip / 2.0


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
