## Autoload: the running game. Owns state (MetaState/RunState, task G3) and the
## four gameplay subsystem children below (task F4).
##
## `run` is null when no run is in progress (main menu / fresh install with no
## save). `meta` always exists - it's created empty on first launch and never
## replaced wholesale the way `run` is.
##
## IMPORTANT for every later task that reads state: always go through `Game.run`
## / `Game.meta` at the point of use. Never cache `Game.run` (or a field off it)
## in a local var that outlives a single function call. new_run() replaces the
## whole RunState object - a subsystem holding onto the old one would keep
## reading/writing stale state after a prestige, which is exactly the "prestige
## didn't reset X" bug docs/GODOT_PLAN.md Phase 6 designed this object-swap
## approach to avoid.
extends Node

signal run_started
signal run_ended

@onready var economy: Node = $Economy
@onready var inventory: Node = $Inventory
@onready var colonies: Node = $Colonies
@onready var progression: Node = $Progression
@onready var colonists: Node = $Colonists
@onready var crafting_stations: Node = $CraftingStations
@onready var prestige: Node = $Prestige
@onready var routing: Node = $Routing
@onready var routes: Node = $Routes
@onready var simulation: Node = $Simulation
@onready var discoveries: Node = $Discoveries

var meta: MetaState = MetaState.new()
var run: RunState = null


func _ready() -> void:
	pass


func has_run() -> bool:
	return run != null


## Starts a fresh run on the given map, replacing whatever `run` was previously.
## This IS prestige (once something calls it after a run is already in progress) -
## see the class doc above for why the reset boundary is this wholesale swap
## rather than a loop over "which fields count as run-scoped."
##
## Generates a brand-new random map every time (rework task: randomized
## map) - a fresh continent-and-islands layout and a fresh set of colony
## sites, seeded and then fixed for this run's whole lifetime (confirmed
## directly: reload must never reshuffle it, only a prestige reset
## generates a new one - see RunState.map's class doc). `seed_value` is an
## explicit override for reproducibility/testing; -1 (the default) picks a
## real random seed.
##
## `nation_id` defaults to empty - "no nation chosen," which every
## nation_*_multiplier() below treats as neutral (1.0, no bonus). That
## keeps every existing caller that predates the nation-picker screen (and
## every test that calls new_run() without one) exactly as they were -
## picking a nation is something a caller opts into, never an implicit
## default bonus.
func new_run(map_id: StringName, seed_value: int = -1, nation_id: StringName = &"") -> void:
	if has_run():
		run_ended.emit()

	var fresh := RunState.new()
	fresh.map_id = map_id
	fresh.nation_id = nation_id
	fresh.started_at_unix = Time.get_unix_time_from_system()
	fresh.map_seed = seed_value if seed_value >= 0 else randi()

	var grid: MapGrid = MapGenerator.generate_terrain(
		Balance.map_width(), Balance.map_height(), fresh.map_seed,
		Balance.continent_threshold(), Balance.island_count(), Balance.island_min_radius(), Balance.island_max_radius()
	)
	var rng := RandomNumberGenerator.new()
	rng.seed = fresh.map_seed
	var capital_cell: Vector2i = MapGenerator.place_capital(grid, rng)
	var placed: Array[Dictionary] = MapGenerator.place_colony_slots(
		grid, capital_cell, Balance.max_colonies(), Balance.colony_distance_step(), Balance.min_colony_spacing(), rng
	)

	fresh.map = grid.to_dict()
	var slots: Array[Dictionary] = [{
		"slot_index": 0, "tier_order": 0, "cell": capital_cell,
		"distance_cells": 0.0, "is_coastal": true, "founded": true,
	}]
	for i: int in range(placed.size()):
		slots.append({
			"slot_index": i + 1,
			"tier_order": colonies.tier_order_for_slot(i + 1),
			"cell": placed[i]["cell"],
			"distance_cells": placed[i]["distance_cells"],
			"is_coastal": placed[i]["is_coastal"],
			"founded": false,
		})
	fresh.colony_slots = slots

	run = fresh

	# Not everything run-scoped lives inside the RunState object itself -
	# Colonies holds live Colony instances in memory, which the `run = fresh`
	# swap above doesn't touch on its own. Needs clearing explicitly here, or
	# a new run would start with the previous run's colonies still active -
	# exactly the "prestige didn't reset X" bug this class's own doc comment
	# warns about. (Colonists no longer needs this - the typed roster lives
	# directly on RunState now, rework: typed colonist roster, so the
	# `run = fresh` swap above already resets it for free.)
	colonies.clear()
	crafting_stations.clear()
	routes.clear()

	# The Capital always exists from the moment a run starts - free, per
	# docs/GAME_DESIGN.md §5's colony table. Every other colony has to be
	# founded (Colonies.found()); the Capital is the one exception, so it's
	# bootstrapped here directly from slot 0 rather than requiring a player
	# action for something that was never actually optional.
	var capital_def: ColonyDef = Db.capital()
	if capital_def != null:
		var capital := Colony.new(capital_def.id, &"slot_0")
		capital.slot_index = 0
		capital.is_coastal = true
		colonies.register(capital)

	run_started.emit()


## The chosen nation's data, or null if none was chosen (see new_run()'s
## doc) or the id doesn't resolve to real content. Every nation_*_multiplier()
## below goes through this rather than reading Db.nation() itself, so
## "no nation" only has to be handled once.
func current_nation() -> NationDef:
	if run == null or run.nation_id == &"":
		return null
	return Db.nation(run.nation_id)


func nation_extraction_rate_multiplier() -> float:
	var n: NationDef = current_nation()
	return n.extraction_rate_multiplier if n != null else 1.0


func nation_ship_speed_multiplier() -> float:
	var n: NationDef = current_nation()
	return n.ship_speed_multiplier if n != null else 1.0


func nation_wagon_speed_multiplier() -> float:
	var n: NationDef = current_nation()
	return n.wagon_speed_multiplier if n != null else 1.0


func nation_colony_cost_multiplier() -> float:
	var n: NationDef = current_nation()
	return n.colony_cost_multiplier if n != null else 1.0


func nation_gold_sell_multiplier() -> float:
	var n: NationDef = current_nation()
	return n.gold_sell_multiplier if n != null else 1.0


func nation_liberty_generation_multiplier() -> float:
	var n: NationDef = current_nation()
	return n.liberty_generation_multiplier if n != null else 1.0
