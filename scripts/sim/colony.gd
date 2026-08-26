## A single colony's production (docs/GAME_DESIGN.md §5/§6). Plain RefCounted -
## runtime simulation state with behaviour, like ProductionCycle and MapGrid,
## not a Node (nothing here needs the scene tree) and not a Resource (this is
## not authored content).
##
## Sits on a ColonyDef (the fixed eight-colony table) and produces exactly
## that colony's one resource. Production is a continuous rate now, not a
## discrete cycle - §6's formula is already a smooth units/second figure, so
## task P1's ProductionCycle (division-based exact catch-up for a "wait N
## seconds, get 1 unit" cycle) isn't used here anymore; amount = rate x delta
## is exact by construction, with nothing left to catch up on. ProductionCycle
## itself is untouched and still tested, in case a future system needs a real
## discrete cycle again.
##
## Output depends on how many colonists are assigned (Game.colonists,
## read live, never cached - see docs/GAME_DESIGN.md §4's central tension:
## an unstaffed colony produces nothing) and this colony's building level, a
## coin-bought upgrade tracked here as plain mutable state.
class_name Colony
extends RefCounted

## §6: base_rate is 1.0 units/sec for every colony - value differentiation
## comes from price, not speed.
const BASE_RATE: float = 1.0

enum RouteType { LAND, SEA }

var colony_id: StringName
var is_capital: bool

## Coin-bought, per docs/GAME_DESIGN.md §6's building_cost curve (a later
## rework wires up the actual purchase). +25% production per level.
var building_level: int = 0

## Coin-bought, per §6's transport_cost curve (read by Route). Meaningless
## for the Capital, which has distance 0 and never ships anywhere.
var transport_level: int = 0

## Rolled once per colony at creation - "each colony rolls land or sea,
## 50/50" (§5). Public and mutable (not just constructor-set) so tests can
## pin a specific value instead of fighting real randomness; a fresh Colony
## still rolls for itself by default.
var route_type: RouteType = RouteType.LAND

## StringName -> float. Only populated for a non-Capital colony - see tick().
var local_stock: Dictionary = {}


func _init(p_colony_id: StringName) -> void:
	colony_id = p_colony_id

	var def: ColonyDef = Db.colony(colony_id)
	if def == null:
		push_error("Colony: unknown colony id '%s' - production will be a no-op" % colony_id)
		is_capital = false
		return

	is_capital = def.is_capital
	route_type = RouteType.LAND if is_capital or randf() < 0.5 else RouteType.SEA


func resource_id() -> StringName:
	var def: ColonyDef = Db.colony(colony_id)
	return def.resource_id if def != null else &""


## This colony's position in the fixed play order, 0-7 - doubles as
## "distance" in every §6 formula that needs it (ColonyDef's class doc
## explains why there's no separate field).
func distance() -> int:
	var def: ColonyDef = Db.colony(colony_id)
	return def.order if def != null else 0


## Units per second this colony currently produces:
## base_rate x colonists_assigned x (1 + 0.25 x building_level) x prestige
## multiplier (§6). Colonists are read live from Game.colonists every call,
## never cached - the same "always read live state" discipline as Game.run.
func rate() -> float:
	var colonists: int = Game.colonists.assigned_to(colony_id)
	if colonists <= 0:
		return 0.0
	var building_multiplier: float = 1.0 + 0.25 * float(building_level)
	return BASE_RATE * float(colonists) * building_multiplier * Game.progression.production_multiplier()


## Advances production by `delta` seconds. The Capital (distance 0) delivers
## straight into central inventory - docs/GAME_DESIGN.md §13 open question 1
## answered "yes, the Capital produces," matching its distance-0/instant-
## delivery framing. Every other colony accumulates in local_stock until a
## Route collects it.
func tick(delta: float) -> void:
	var amount: float = rate() * delta
	if amount <= 0.0:
		return

	var res_id: StringName = resource_id()
	if res_id == &"":
		return

	if is_capital:
		Game.inventory.add(res_id, amount)
	else:
		local_stock[res_id] = float(local_stock.get(res_id, 0.0)) + amount


## Empties local_stock and returns what was collected. A Capital colony never
## accumulates local_stock (see tick()), so this is always empty for one.
func collect() -> Dictionary:
	var collected: Dictionary = local_stock.duplicate()
	local_stock.clear()
	return collected
