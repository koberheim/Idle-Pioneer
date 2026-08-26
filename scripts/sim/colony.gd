## A single colony's production and shipping stats (docs/GAME_DESIGN.md §5/§6,
## reworked per the design realignment: three independent, per-colony,
## gold-bought upgrade tracks - production, cargo, speed - plus a real base
## rate on all three that applies even with zero colonists assigned).
## Plain RefCounted - runtime simulation state with behaviour, like
## ProductionCycle and MapGrid, not a Node (nothing here needs the scene
## tree) and not a Resource (this is not authored content - ColonyDef is).
##
## All the actual formulas live in Balance (scripts/core/balance.gd) - this
## class just holds the state (which levels have been bought, the rolled
## route type) and asks Balance to combine it with ColonyDef's base stats and
## Game.colonists' live count. Retuning any of this never means touching
## Colony.
class_name Colony
extends RefCounted

enum RouteType { LAND, SEA }

var colony_id: StringName
var is_capital: bool

## Independent gold-bought upgrade levels (docs/GODOT_PLAN.md's design
## realignment section - three separate tracks, not one generic level).
var production_level: int = 0
var cargo_level: int = 0
var speed_level: int = 0

## Rolled once per colony at creation - "each colony rolls land or sea,
## 50/50" (§5). Public and mutable (not just constructor-set) so tests can
## pin a specific value instead of fighting real randomness; a fresh Colony
## still rolls for itself by default. Now affects travel time only (Route
## reads this) - cargo capacity comes entirely from this colony's own base
## stat and cargo_level instead.
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


func colonists_assigned() -> int:
	return Game.colonists.assigned_to(colony_id)


## Units per second this colony currently produces. Real even with zero
## colonists assigned - see the class doc.
func production_rate() -> float:
	var def: ColonyDef = Db.colony(colony_id)
	if def == null:
		return 0.0
	return Balance.colony_production_rate(
		def.base_production_rate, production_level, colonists_assigned(), Game.progression.production_multiplier()
	)


## Cargo capacity for a Route serving this colony.
func cargo_capacity() -> float:
	var def: ColonyDef = Db.colony(colony_id)
	if def == null:
		return 0.0
	return Balance.colony_cargo_capacity(def.base_cargo, cargo_level, colonists_assigned())


## Full round-trip travel time in seconds for a Route serving this colony.
func round_trip_seconds() -> float:
	var def: ColonyDef = Db.colony(colony_id)
	if def == null:
		return 0.0
	return Balance.route_round_trip_seconds(
		distance(), route_type == RouteType.SEA, def.base_speed, speed_level, colonists_assigned()
	)


func next_production_level_cost() -> float:
	return Balance.next_production_level_cost(production_level)


func next_cargo_level_cost() -> float:
	return Balance.next_cargo_level_cost(cargo_level)


func next_speed_level_cost() -> float:
	return Balance.next_speed_level_cost(speed_level)


## Spends gold and raises production_level by one. Returns false and changes
## nothing on insufficient gold.
func purchase_production_level() -> bool:
	if not Game.economy.try_spend(next_production_level_cost()):
		return false
	production_level += 1
	return true


func purchase_cargo_level() -> bool:
	if not Game.economy.try_spend(next_cargo_level_cost()):
		return false
	cargo_level += 1
	return true


func purchase_speed_level() -> bool:
	if not Game.economy.try_spend(next_speed_level_cost()):
		return false
	speed_level += 1
	return true


## Advances production by `delta` seconds. The Capital (distance 0) delivers
## straight into central inventory - docs/GAME_DESIGN.md §13 open question 1
## answered "yes, the Capital produces," matching its distance-0/instant-
## delivery framing. Every other colony accumulates in local_stock until a
## Route collects it.
func tick(delta: float) -> void:
	var amount: float = production_rate() * delta
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
