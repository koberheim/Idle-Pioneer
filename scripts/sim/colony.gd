## A single colony's production (task P2). Plain RefCounted - runtime
## simulation state with behaviour, like ProductionCycle and MapGrid, not a
## Node (nothing here needs the scene tree) and not a Resource (this is not
## authored content).
##
## Sits on a RegionDef (task D3) and produces exactly that region's one
## deposit resource on a ProductionCycle (task P1). This single-resource-per-
## colony shape is deliberate, not incidental: docs/GODOT_MIGRATION_ANALYSIS.md
## §4 found Unity gave every resource in a colony's producedResources list the
## *same full amount* per cycle, so a 3-resource colony produced 3x the
## throughput of a 1-resource colony for free. A RegionDef has exactly one
## `deposit_id` (task D3), so Colony structurally can't repeat that mistake -
## there is nowhere to put a second resource. If multi-resource colonies are
## ever wanted, that has to be a deliberate cost (e.g. a slower shared cycle,
## or an explicit split of `amount`), not "one more list entry."
class_name Colony
extends RefCounted

var region_id: StringName
var is_hub: bool
var cycle: ProductionCycle

## StringName -> float. Only populated for a non-hub colony - see tick().
var local_stock: Dictionary = {}


func _init(p_region_id: StringName, p_is_hub: bool = false) -> void:
	region_id = p_region_id
	is_hub = p_is_hub

	var region: RegionDef = Db.region(region_id)
	if region == null:
		push_error("Colony: unknown region id '%s' - production will be a no-op" % region_id)
		cycle = ProductionCycle.new(1.0)
		return

	cycle = ProductionCycle.new(region.base_cycle_seconds)


func deposit_id() -> StringName:
	var region: RegionDef = Db.region(region_id)
	return region.deposit_id if region != null else &""


## Advances this colony's production clock by `delta` seconds. The Hub
## deposits straight into central inventory (Game.inventory), matching
## ColonySpawner.SpawnColony's `useLocalStorage = !isStarter` in the original
## Unity project; every other colony accumulates in local_stock until a Route
## (task P3) collects it.
func tick(delta: float) -> void:
	var cycles: int = cycle.advance(delta)
	if cycles <= 0:
		return

	var dep_id: StringName = deposit_id()
	if dep_id == &"":
		return

	var amount: float = float(cycles) * Game.progression.production_multiplier()

	if is_hub:
		Game.inventory.add(dep_id, amount)
	else:
		local_stock[dep_id] = float(local_stock.get(dep_id, 0.0)) + amount


## Empties local_stock and returns what was collected. A hub colony never
## accumulates local_stock (see tick()), so this is always empty for one.
func collect() -> Dictionary:
	var collected: Dictionary = local_stock.duplicate()
	local_stock.clear()
	return collected
