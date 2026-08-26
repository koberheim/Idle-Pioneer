## Autoload: writes the player's progress to a file and reads it back
## (task S1). This is the only place that touches disk - nothing else in the
## project should read or write save data directly.
##
## The file has two parts, matching the split established in tasks G1/G2/G3:
## `meta` (permanent - doubloons, lifetime totals, survives everything) and
## `run` (the current playthrough - gold, resources, colonies, upgrades; can be
## null if no playthrough is in progress). See docs/GODOT_PLAN.md Phase 6 for
## why that split exists.
##
## Writes are atomic: the new save is written to a temporary file first, and
## only swapped into place once that write finished successfully. A crash or
## power loss mid-write can never leave a half-written, corrupted save behind -
## the player either keeps their last good save or gets the new one, never
## something in between.
extends Node

const SAVE_PATH: String = "user://save.json"
const TMP_PATH: String = "user://save.json.tmp"

## Bump this whenever the save file's shape changes, and add a migration step
## below (see _migrate) so an older save file still loads correctly - task S2
## is what actually builds and proves out that migration chain; this is just
## where it will live.
const CURRENT_SAVE_VERSION: int = 1


func has_save() -> bool:
	return FileAccess.file_exists(SAVE_PATH)


func delete_save() -> void:
	if not FileAccess.file_exists(SAVE_PATH):
		return
	var err: Error = DirAccess.remove_absolute(SAVE_PATH)
	if err != OK:
		push_error("SaveSystem.delete_save: failed to remove save file (%s)" % error_string(err))


## Writes the current game state to disk. Returns false (and leaves any
## existing save file untouched) if anything goes wrong.
func save() -> bool:
	if Game.run == null:
		push_error("SaveSystem.save: no active run to save")
		return false

	# The live colonies (task P2) aren't part of RunState day-to-day - only
	# captured into it right before writing, so RunState never needs to know
	# about the Colony class the rest of the time.
	Game.run.colonies = _capture_colonies()
	Game.run.workshops = _capture_workshops()

	var payload: Dictionary = {
		"save_version": CURRENT_SAVE_VERSION,
		# Not used yet - task S3 (offline progress) will read this to work out
		# how long the player was away. Captured now so that feature doesn't
		# need a save-format change later.
		"saved_at_unix": Time.get_unix_time_from_system(),
		"meta": Game.meta.to_dict(),
		"run": Game.run.to_dict(),
	}

	var json_text: String = JSON.stringify(payload, "\t")

	var tmp_file: FileAccess = FileAccess.open(TMP_PATH, FileAccess.WRITE)
	if tmp_file == null:
		push_error("SaveSystem.save: could not open temp file (%s)" % error_string(FileAccess.get_open_error()))
		return false
	tmp_file.store_string(json_text)
	tmp_file.close()

	var err: Error = DirAccess.rename_absolute(TMP_PATH, SAVE_PATH)
	if err != OK:
		push_error("SaveSystem.save: could not finalize save file (%s)" % error_string(err))
		return false

	return true


## Loads game state from disk into Game.meta/Game.run/Game.colonies. Returns
## false on anything short of a clean, valid save - a missing file (first
## launch) is not an error and is reported the same way as a corrupt one: both
## just mean "nothing to load," and it's up to the caller (see task V1) to
## start a fresh run when this returns false. Never crashes on bad input.
func load() -> bool:
	if not FileAccess.file_exists(SAVE_PATH):
		return false

	var file: FileAccess = FileAccess.open(SAVE_PATH, FileAccess.READ)
	if file == null:
		push_error("SaveSystem.load: could not open save file (%s)" % error_string(FileAccess.get_open_error()))
		return false
	var text: String = file.get_as_text()
	file.close()

	var parsed: Variant = JSON.parse_string(text)
	if not (parsed is Dictionary):
		push_error("SaveSystem.load: save file is not valid JSON")
		return false

	var data: Dictionary = parsed
	var version: int = int(data.get("save_version", 0))
	if version <= 0:
		push_error("SaveSystem.load: save file is missing a valid save_version")
		return false
	if version > CURRENT_SAVE_VERSION:
		push_error(
			"SaveSystem.load: save file is version %d, newer than this build understands (%d)" % [
				version, CURRENT_SAVE_VERSION
			]
		)
		return false

	data = _migrate(data, version)

	Game.meta = MetaState.from_dict(data.get("meta", {}))

	var run_data: Variant = data.get("run")
	if run_data is Dictionary:
		Game.run = RunState.from_dict(run_data)
		_restore_colonies(Game.run.colonies)
		_restore_workshops(Game.run.workshops)
	else:
		Game.run = null
		Game.colonies.clear()
		Game.crafting_stations.clear()

	return true


## Snapshots every live colony into the plain-dictionary shape RunState.colonies
## expects: which colony, its three independent upgrade levels, its rolled
## route type, and what it's currently holding. is_capital isn't captured -
## it's re-derived from the colony id on restore (see RunState's class doc on
## `colonies` for why).
func _capture_colonies() -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for colony: Colony in Game.colonies.all():
		out.append({
			"colony_id": colony.colony_id,
			"production_level": colony.production_level,
			"cargo_level": colony.cargo_level,
			"speed_level": colony.speed_level,
			"route_type": colony.route_type,
			"local_stock": colony.local_stock.duplicate(),
		})
	return out


func _restore_colonies(snapshots: Array[Dictionary]) -> void:
	Game.colonies.clear()
	for snapshot: Dictionary in snapshots:
		var colony_id: StringName = snapshot.get("colony_id", &"")
		var colony := Colony.new(colony_id)
		colony.production_level = int(snapshot.get("production_level", 0))
		colony.cargo_level = int(snapshot.get("cargo_level", 0))
		colony.speed_level = int(snapshot.get("speed_level", 0))
		colony.route_type = snapshot.get("route_type", Colony.RouteType.LAND) as Colony.RouteType
		colony.local_stock = (snapshot.get("local_stock", {}) as Dictionary).duplicate()
		Game.colonies.register(colony)


## Snapshots every auto-craft station that's been created this run (see
## CraftingStations.get_or_create) - a recipe never touched by the player
## simply has no station and needs nothing saved.
func _capture_workshops() -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for station: CraftingStation in Game.crafting_stations.all():
		out.append({
			"recipe_id": station.recipe_id,
			"auto_craft": station.auto_craft,
			"cycle_accumulated": station.cycle.accumulated,
		})
	return out


func _restore_workshops(snapshots: Array[Dictionary]) -> void:
	Game.crafting_stations.clear()
	for snapshot: Dictionary in snapshots:
		var recipe_id: StringName = snapshot.get("recipe_id", &"")
		var station: CraftingStation = Game.crafting_stations.get_or_create(recipe_id)
		station.auto_craft = bool(snapshot.get("auto_craft", false))
		station.cycle.accumulated = float(snapshot.get("cycle_accumulated", 0.0))


## No migrations exist yet - version 1 is the only shape that has ever
## existed, so this is a no-op today. A future format change adds a step here
## (e.g. _migrate_1_to_2(data) -> Dictionary) and this loop applies each one in
## order until `data` is caught up to CURRENT_SAVE_VERSION. Task S2 is what
## actually exercises this against a real old-format save fixture.
func _migrate(data: Dictionary, from_version: int) -> Dictionary:
	var version: int = from_version
	while version < CURRENT_SAVE_VERSION:
		break
	return data
