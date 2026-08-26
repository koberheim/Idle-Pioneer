## Autoload: writes the player's progress to a file and reads it back
## (task S1). This is the only place that touches disk - nothing else in the
## project should read or write save data directly.
##
## The file has two parts, matching the split established in tasks G1/G2/G3:
## `meta` (permanent - Liberty, lifetime totals, survives everything) and
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
	Game.run.routes = _capture_routes()

	var payload: Dictionary = {
		"save_version": CURRENT_SAVE_VERSION,
		# What load()'s offline catch-up measures elapsed time against (see
		# _apply_offline_catch_up).
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


## Loads game state from disk into Game.meta/Game.run/Game.colonies, then
## fast-forwards the simulation through however long the player was away
## (rework task: offline catch-up) - capped at
## Balance.offline_catch_up_cap_seconds() regardless of the real gap, and
## skipped entirely if the save predates `saved_at_unix` existing (0/missing
## - there's nothing reliable to measure from). Returns false on anything
## short of a clean, valid save - a missing file (first launch) is not an
## error and is reported the same way as a corrupt one: both just mean
## "nothing to load," and it's up to the caller (see task V1) to start a
## fresh run when this returns false. Never crashes on bad input.
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
		_restore_routes(Game.run.routes)
		_apply_offline_catch_up(int(data.get("saved_at_unix", 0)))
	else:
		Game.run = null
		Game.colonies.clear()
		Game.crafting_stations.clear()
		Game.routes.clear()

	return true


## Fast-forwards colonies, routes, and crafting through the real time that
## passed since `saved_at_unix`, in one call each - the exact same
## exact-math/bounded-loop tick() methods that already handle a live frame's
## delta handle an arbitrarily large one just as correctly (see Colony,
## Route, and CraftingStation's own class docs). A non-positive or missing
## timestamp is treated as "nothing to catch up" rather than guessed at.
func _apply_offline_catch_up(saved_at_unix: int) -> void:
	if saved_at_unix <= 0:
		return
	var now: int = Time.get_unix_time_from_system()
	var elapsed: float = clampf(float(now - saved_at_unix), 0.0, Balance.offline_catch_up_cap_seconds())
	if elapsed <= 0.0:
		return

	Game.colonies.tick(elapsed)
	Game.routes.tick(elapsed)
	Game.crafting_stations.tick(elapsed)
	Game.run.elapsed_seconds += elapsed


## Snapshots every live colony into the plain-dictionary shape RunState.colonies
## expects: which colony, which tier it draws from, its three independent
## upgrade levels, and what it's currently holding. is_capital, distance,
## and coastal-ness aren't captured here - is_capital is re-derived from
## tier_id, and the rest comes from the matching Game.run.colony_slots entry
## on restore (see RunState's class doc on `colonies` for why).
func _capture_colonies() -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for colony: Colony in Game.colonies.all():
		out.append({
			"colony_id": colony.colony_id,
			"tier_id": colony.tier_id,
			"slot_index": colony.slot_index,
			"production_level": colony.production_level,
			"cargo_level": colony.cargo_level,
			"speed_level": colony.speed_level,
			"local_stock": colony.local_stock.duplicate(),
		})
	return out


## Must run after Game.run is set (needs Game.run.colony_slots to restore
## each colony's distance/coastal-ness).
func _restore_colonies(snapshots: Array[Dictionary]) -> void:
	Game.colonies.clear()
	for snapshot: Dictionary in snapshots:
		var colony_id: StringName = snapshot.get("colony_id", &"")
		var tier_id: StringName = snapshot.get("tier_id", &"")
		var slot_index: int = int(snapshot.get("slot_index", 0))

		var colony := Colony.new(tier_id, colony_id)
		colony.slot_index = slot_index
		colony.production_level = int(snapshot.get("production_level", 0))
		colony.cargo_level = int(snapshot.get("cargo_level", 0))
		colony.speed_level = int(snapshot.get("speed_level", 0))
		colony.local_stock = (snapshot.get("local_stock", {}) as Dictionary).duplicate()

		var slot: Dictionary = _find_colony_slot(slot_index)
		if not slot.is_empty():
			colony.distance_cells = float(slot.get("distance_cells", 0.0))
			colony.is_coastal = bool(slot.get("is_coastal", colony.is_capital))

		Game.colonies.register(colony)


func _find_colony_slot(slot_index: int) -> Dictionary:
	if Game.run == null:
		return {}
	for slot: Dictionary in Game.run.colony_slots:
		if int(slot.get("slot_index", -1)) == slot_index:
			return slot
	return {}


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


## Snapshots every live route's in-flight state - see RunState.routes' class
## doc for why this is the only route data that needs saving at all (routes
## themselves are rebuilt automatically from the colony list, not stored).
func _capture_routes() -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for route: Route in Game.routes.all():
		out.append({
			"colony_id": route.origin.colony_id,
			"state": route.state,
			"cargo": route.cargo.duplicate(),
			"leg_elapsed": route.leg_elapsed,
		})
	return out


## Must run after _restore_colonies() - a route needs its origin (and the
## Capital) to already be live. Routes.sync_with_colonies() (called
## implicitly by the first Game.routes.tick()) creates the route itself;
## this only needs to overwrite the in-flight fields on top of that, for
## whichever colonies actually have a saved snapshot. A colony with no
## snapshot (this save predates it, or it was founded but never shipped
## anything) just gets a fresh route, exactly as sync_with_colonies() already
## does on its own.
func _restore_routes(snapshots: Array[Dictionary]) -> void:
	Game.routes.clear()
	Game.routes.sync_with_colonies()
	for snapshot: Dictionary in snapshots:
		var colony_id: StringName = snapshot.get("colony_id", &"")
		var route: Route = Game.routes.for_colony(colony_id)
		if route == null:
			continue
		route.state = int(snapshot.get("state", 0)) as Route.State
		route.cargo = (snapshot.get("cargo", {}) as Dictionary).duplicate()
		route.leg_elapsed = float(snapshot.get("leg_elapsed", 0.0))


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
