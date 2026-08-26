## Pure queries over a MapGrid that make terrain matter to gameplay (task M3 -
## see docs/GODOT_PLAN.md Phase 5.3). Static functions, no state of its own -
## everything it needs comes from the MapGrid passed in.
##
## route_kind is the rule that makes the land/water layer load-bearing rather
## than decorative (docs/GODOT_MIGRATION_ANALYSIS.md §5): a coastal colony can be
## served by a fast, high-capacity ship; an inland one needs a slower wagon.
## Unity's equivalent logic (`useShip = isWaterAccess && gridDistance >= 250f`,
## `TransportVehicle.CanReachColony`'s hardcoded `distance < 20f`) was calibrated
## against the wrong coordinate space and effectively meant wagons could never
## reach anything - see docs/GODOT_PLAN.md task P3's regression-risk note. This
## rule is deliberately simpler and is tested against the real MVP map, not
## invented distances.
class_name PlacementRules

enum RouteKind {
	LAND,
	SEA,
}


## A colony can only be founded on land or coast - never on open or shallow
## water. Whether a *specific* site is available (unoccupied, has a deposit) is
## RegionDef/task M5's concern, not this grid-level check.
static func is_valid_colony_site(g: MapGrid, c: Vector2i) -> bool:
	if g == null or not g.in_bounds(c):
		return false
	return g.is_land(c)


## Every coast cell on the grid - the pool of sites eligible for fast sea
## transport (see route_kind).
static func coastal_sites(g: MapGrid) -> Array[Vector2i]:
	var out: Array[Vector2i] = []
	if g == null:
		return out
	for y: int in range(g.height):
		for x: int in range(g.width):
			var c := Vector2i(x, y)
			if g.is_coast(c):
				out.append(c)
	return out


## SEA only when BOTH endpoints are coastal - a ship needs water access at
## departure and arrival, not just at one end. Everything else is LAND (a wagon
## route), including a coast-to-inland pairing.
static func route_kind(g: MapGrid, from: Vector2i, to: Vector2i) -> RouteKind:
	if g != null and g.is_coast(from) and g.is_coast(to):
		return RouteKind.SEA
	return RouteKind.LAND


## Straight-line grid distance between two cells. Both a sea and a land route
## use this the same way for now (task P3 turns it into a travel duration via a
## kind-specific speed) - there's no pathfinding yet (Phase 8+), so this is
## deliberately just Euclidean distance, not a walked/sailed path length.
static func route_distance(g: MapGrid, from: Vector2i, to: Vector2i) -> float:
	return Vector2(from).distance_to(Vector2(to))
