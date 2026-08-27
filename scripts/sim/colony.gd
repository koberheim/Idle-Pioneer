## A single colony's production and shipping stats (docs/GAME_DESIGN.md §5/§6,
## reworked per the design realignment: three independent, per-colony,
## gold-bought upgrade tracks - production, cargo, speed - plus a real base
## rate on all three that applies even with zero colonists assigned).
## Plain RefCounted - runtime simulation state with behaviour, like
## ProductionCycle and MapGrid, not a Node (nothing here needs the scene
## tree) and not a Resource (this is not authored content - ColonyDef is).
##
## All the actual formulas live in Balance (scripts/core/balance.gd) - this
## class just holds the state (which levels have been bought) and asks
## Balance to combine it with ColonyDef's base stats and whichever colonist
## Game.colonists has assigned to each of this colony's three type slots
## (rework task: typed colonist roster). Retuning any of this never means
## touching Colony.
##
## `colony_id` (this specific founded instance, e.g. "slot_3") and `tier_id`
## (which ColonyDef it draws its resource/base stats from, e.g. &"cape_harbour")
## are separate now (rework task: randomized map) - a tier can be reused by
## more than one colony once a run cycles past 7 non-Capital tiers. Where
## this colony actually sits (`distance_cells`, `is_coastal`) comes from its
## generated colony slot (RunState.colony_slots), not from the tier - two
## colonies sharing a tier can be at completely different distances.
class_name Colony
extends RefCounted

enum RouteType { LAND, SEA }

## Per-run instance id - what Routes/Colonists/save data key this colony by.
## Defaults to `tier_id` when not given, so a bare `Colony.new(&"cape_harbour")`
## (the shape nearly every existing test uses) still works exactly as before
## for anything that doesn't care about multi-instance distinctness.
var colony_id: StringName

## Which ColonyDef this colony draws its resource and base stats from.
var tier_id: StringName

var is_capital: bool
var slot_index: int = 0

## Independent gold-bought upgrade levels (docs/GODOT_PLAN.md's design
## realignment section - three separate tracks, not one generic level).
var production_level: int = 0
var cargo_level: int = 0
var speed_level: int = 0

## Whether this colony's generated map cell is coastal (rework task:
## randomized map) - real geography now, not a 50/50 roll. Public and
## mutable, same as before, so tests can pin a value directly instead of
## fighting randomness. The Capital is always coastal by construction
## (MapGenerator.place_capital only ever picks a coastal continent cell), so
## defaults to that for a Capital instance; false otherwise until real
## placement data is applied.
var is_coastal: bool = false

## Full round-trip travel time only cares whether THIS end is coastal -
## PlacementRules.route_kind's "both ends coastal -> sea" rule collapses to
## that once the Capital is guaranteed coastal (see is_coastal's doc).
var route_type: RouteType:
	get: return RouteType.SEA if is_coastal else RouteType.LAND

## Real distance from the Capital on the generated map, in grid cells - set
## once at placement (Colonies.found()) or restore (SaveSystem), read by
## distance(). Public and mutable for the same testing reason as is_coastal.
var distance_cells: float = 0.0

## StringName -> float. Only populated for a non-Capital colony - see tick().
var local_stock: Dictionary = {}


func _init(p_tier_id: StringName, p_colony_id: StringName = &"") -> void:
	tier_id = p_tier_id
	colony_id = p_colony_id if p_colony_id != &"" else p_tier_id

	var def: ColonyDef = Db.colony(tier_id)
	if def == null:
		push_error("Colony: unknown tier id '%s' - production will be a no-op" % tier_id)
		is_capital = false
		return

	is_capital = def.is_capital
	is_coastal = is_capital


func resource_id() -> StringName:
	var def: ColonyDef = Db.colony(tier_id)
	return def.resource_id if def != null else &""


## Real distance from the Capital, in grid cells (rework task: randomized
## map) - previously a 0-7 index doubling as ColonyDef.order; now a real
## generated number, independent of which tier this colony is.
func distance() -> float:
	return distance_cells


## The level of this colony's assigned colonist for `type` (0 if that slot
## is empty) - rework: typed colonist roster. Replaces the old headcount
## (colonists_assigned()) now that a colony has one specific slot per type
## rather than an arbitrary assigned count.
func _colonist_level(type: Colonist.Type) -> int:
	var c: Colonist = Game.colonists.colonist_at(colony_id, type)
	return c.level if c != null else 0


## Units per second this colony currently produces. Real even with zero
## colonists assigned - see the class doc.
func production_rate() -> float:
	var def: ColonyDef = Db.colony(tier_id)
	if def == null:
		return 0.0
	return Balance.colony_production_rate(
		def.base_production_rate,
		production_level,
		_colonist_level(Colonist.Type.RESOURCE),
		# Three independent multipliers, combined here rather than in Balance:
		# Progression's run-scoped upgrade (resets every run), Prestige's
		# Industry branch (permanent, §8), and the chosen nation's bonus, if
		# any (direct request - recovered from the Unity project's
		# NationalityData, see NationDef's class doc).
		# Balance.colony_production_rate() only ever takes one combined
		# "prestige_multiplier" - it doesn't need to know these are three
		# separate systems.
		Game.progression.production_multiplier() * Game.prestige.production_multiplier() * Game.nation_extraction_rate_multiplier()
	)


## Cargo capacity for a Route serving this colony.
func cargo_capacity() -> float:
	var def: ColonyDef = Db.colony(tier_id)
	if def == null:
		return 0.0
	return Balance.colony_cargo_capacity(
		def.base_cargo, cargo_level, _colonist_level(Colonist.Type.CARGO), Game.prestige.cargo_multiplier()
	)


## Full round-trip travel time in seconds for a Route serving this colony.
## The nation's speed bonus (direct request) picks ship or wagon by which
## kind of route this actually is - an English bonus does nothing for a
## land route, same as a Portuguese one does nothing for a sea route.
func round_trip_seconds() -> float:
	var def: ColonyDef = Db.colony(tier_id)
	if def == null:
		return 0.0
	var is_sea: bool = route_type == RouteType.SEA
	var nation_speed_multiplier: float = (
		Game.nation_ship_speed_multiplier() if is_sea else Game.nation_wagon_speed_multiplier()
	)
	return Balance.route_round_trip_seconds(
		distance(), is_sea, def.base_speed, speed_level, _colonist_level(Colonist.Type.SPEED),
		Game.prestige.speed_multiplier() * nation_speed_multiplier
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
## straight through Routing (sold for gold or added to central inventory,
## per that resource's Sell/Reserve setting) - docs/GAME_DESIGN.md §13 open
## question 1 answered "yes, the Capital produces," matching its
## distance-0/instant-delivery framing. Every other colony accumulates in
## local_stock until a Route collects it.
func tick(delta: float) -> void:
	var amount: float = production_rate() * delta
	if amount <= 0.0:
		return

	var res_id: StringName = resource_id()
	if res_id == &"":
		return

	if is_capital:
		Game.routing.deliver(res_id, amount)
	else:
		local_stock[res_id] = float(local_stock.get(res_id, 0.0)) + amount


## Empties local_stock and returns what was collected. A Capital colony never
## accumulates local_stock (see tick()), so this is always empty for one.
func collect() -> Dictionary:
	var collected: Dictionary = local_stock.duplicate()
	local_stock.clear()
	return collected
