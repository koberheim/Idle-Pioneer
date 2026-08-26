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
func new_run(map_id: StringName) -> void:
	if has_run():
		run_ended.emit()

	var fresh := RunState.new()
	fresh.map_id = map_id
	run = fresh

	# Not everything run-scoped lives inside the RunState object itself -
	# Colonies holds live Colony instances in memory, and Colonists holds
	# colonist-to-site assignments in memory, neither of which the `run = fresh`
	# swap above touches on its own. Both need clearing explicitly here, or a
	# new run would start with the previous run's colonies and colonist
	# assignments still active - exactly the "prestige didn't reset X" bug
	# this class's own doc comment warns about. Found and fixed while adding
	# the colonist pool, not something that had come up yet.
	colonies.clear()
	colonists.clear_assignments()
	crafting_stations.clear()

	run_started.emit()
