## Abstract transport between a colony and the Hub (task P3). "Abstract" means
## duration only - no sprite, no Node, no visual anything in this file. But
## your answer to the plan's Q3 confirmed animated travel is a REQUIRED part of
## the final game, not a maybe, so this class is shaped for that from day one:
## progress() and current_world_position() are real, tested seams that a future
## VehicleView node subscribes to. Computing them costs nothing extra (the
## duration math already tracks elapsed/total) - retrofitting them after other
## code depends on this class's shape would cost a lot more. See
## docs/GODOT_PLAN.md Phase 7's table row on Transport and Phase 10 rule 5's
## third stated exception to "don't build ahead of need."
##
## Do NOT add a sprite, a Node2D, or anything that draws to this class. A
## VehicleView that reads progress()/current_world_position() is a separate,
## later, not-yet-scheduled task.
##
## route_kind (task M3) is what makes this load-bearing: SEA only when both
## endpoints are coastal (fast, high capacity), LAND otherwise (slow, low
## capacity) - see docs/GODOT_MIGRATION_ANALYSIS.md §5 for why Unity's
## equivalent thresholds were calibrated against the wrong coordinate space and
## effectively meant wagons could never reach anything.
class_name Route
extends RefCounted

signal delivered(cargo: Dictionary)

enum State {
	AT_ORIGIN,
	TRAVELING_TO_HUB,
	TRAVELING_TO_ORIGIN,
}

## Balance placeholders (Phase 7's task V3 is where these get tuned against
## real play, not here) - the only property that actually matters for MVP
## correctness is SEA being faster and higher-capacity than LAND.
const SEA_SPEED: float = 4.0  # cells/second
const LAND_SPEED: float = 2.0  # cells/second
const SEA_CAPACITY: float = 200.0
const LAND_CAPACITY: float = 50.0

var origin: Colony
var destination: Colony
var kind: PlacementRules.RouteKind
var capacity: float
var speed: float
var distance: float

var state: State = State.AT_ORIGIN
var cargo: Dictionary = {}  # StringName -> float, only non-empty while traveling
var leg_elapsed: float = 0.0
var leg_duration: float = 0.0


static func speed_for(route_kind: PlacementRules.RouteKind) -> float:
	return SEA_SPEED if route_kind == PlacementRules.RouteKind.SEA else LAND_SPEED


static func capacity_for(route_kind: PlacementRules.RouteKind) -> float:
	return SEA_CAPACITY if route_kind == PlacementRules.RouteKind.SEA else LAND_CAPACITY


func _init(p_origin: Colony, p_destination: Colony) -> void:
	origin = p_origin
	destination = p_destination

	var grid: MapGrid = Db.map_grid()
	var origin_cell: Vector2i = _cell_of(origin)
	var dest_cell: Vector2i = _cell_of(destination)

	kind = PlacementRules.route_kind(grid, origin_cell, dest_cell)
	distance = PlacementRules.route_distance(grid, origin_cell, dest_cell)
	speed = speed_for(kind)
	capacity = capacity_for(kind)


## Advances the route by `delta` seconds: waiting at the origin tries to load
## and depart every call (a "wait" isn't a separate timed phase - it's just
## nothing happening yet because there's no cargo), a traveling leg advances
## toward arrival. Time left over past an arrival within one tick() call is not
## carried into the next leg - an acceptable simplification for an abstract,
## every-frame-ticked system; unlike ProductionCycle (task P1), this is not
## meant to resolve multi-hour offline gaps.
func tick(delta: float) -> void:
	match state:
		State.AT_ORIGIN:
			_try_depart()
		State.TRAVELING_TO_HUB:
			_advance_leg(delta, _arrive_at_hub)
		State.TRAVELING_TO_ORIGIN:
			_advance_leg(delta, _arrive_at_origin)


## 0.0 when idle at the origin (nothing to show); 0 -> 1 across whichever leg
## is currently in flight. See the class doc for why this exists.
func progress() -> float:
	if leg_duration <= 0.0:
		return 0.0
	return clampf(leg_elapsed / leg_duration, 0.0, 1.0)


## Linear interpolation between the current leg's endpoints, in grid-cell
## space - no path-following yet (Phase 8+ is where a real Curve2D/PathFollow2D
## would replace this). At rest (AT_ORIGIN), this is just the origin's cell.
func current_world_position() -> Vector2:
	var from_cell: Vector2i
	var to_cell: Vector2i

	match state:
		State.TRAVELING_TO_HUB:
			from_cell = _cell_of(origin)
			to_cell = _cell_of(destination)
		State.TRAVELING_TO_ORIGIN:
			from_cell = _cell_of(destination)
			to_cell = _cell_of(origin)
		_:
			from_cell = _cell_of(origin)
			to_cell = _cell_of(origin)

	return Vector2(from_cell).lerp(Vector2(to_cell), progress())


func _cell_of(colony: Colony) -> Vector2i:
	var region: RegionDef = Db.region(colony.region_id)
	return region.cell if region != null else Vector2i.ZERO


func _try_depart() -> void:
	var loaded: Dictionary = _load_cargo()
	if loaded.is_empty():
		return
	cargo = loaded
	_start_leg()
	state = State.TRAVELING_TO_HUB


## Loads up to `capacity` from origin.local_stock, highest ResourceDef.base_value
## first - the cargo-prioritisation salvaged from Unity's TransportManager
## (docs/GODOT_MIGRATION_ANALYSIS.md §A2). Removes exactly what it loads from
## local_stock, so a partial load leaves the rest for next time.
func _load_cargo() -> Dictionary:
	var available: Dictionary = origin.local_stock
	if available.is_empty():
		return {}

	var ids: Array = available.keys()
	ids.sort_custom(_by_value_descending)

	var loaded: Dictionary = {}
	var remaining: float = capacity
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


func _start_leg() -> void:
	leg_elapsed = 0.0
	leg_duration = distance / speed if speed > 0.0 else 0.0


func _advance_leg(delta: float, on_arrive: Callable) -> void:
	if leg_duration <= 0.0:
		on_arrive.call()
		return
	leg_elapsed += delta
	if leg_elapsed >= leg_duration:
		leg_elapsed = leg_duration
		on_arrive.call()


func _arrive_at_hub() -> void:
	for id: StringName in cargo.keys():
		Game.inventory.add(id, cargo[id])
	delivered.emit(cargo)
	cargo = {}
	_start_leg()
	state = State.TRAVELING_TO_ORIGIN


func _arrive_at_origin() -> void:
	state = State.AT_ORIGIN
	leg_elapsed = 0.0
	leg_duration = 0.0
