## Autoload: static content registry (ResourceDef, RecipeDef, RegionDef, UpgradeDef, ...).
## Scans res://data/<kind>/*.tres at boot, indexes every definition by its `id`, and
## reports problems loudly instead of leaving a null reference for something else to
## discover later - see docs/GODOT_MIGRATION_ANALYSIS.md §B2 for the Unity failure mode
## this is built to avoid (48 of 50 resources silently shipped with no icon, and nobody
## noticed because nothing validated the data at load time).
extends Node

const RESOURCES_DIR: String = "res://data/resources/"
const RECIPES_DIR: String = "res://data/recipes/"
const REGIONS_DIR: String = "res://data/regions/"
const UPGRADES_DIR: String = "res://data/upgrades/"

var _resources: Dictionary = {}  # StringName -> ResourceDef
var _recipes: Dictionary = {}  # StringName -> Resource (RecipeDef once it exists)
var _regions: Dictionary = {}  # StringName -> Resource (RegionDef once it exists)
var _upgrades: Dictionary = {}  # StringName -> Resource (UpgradeDef once it exists)


func _ready() -> void:
	var resources_result: Dictionary = _evaluate_directory(RESOURCES_DIR)
	var recipes_result: Dictionary = _evaluate_directory(RECIPES_DIR)
	var regions_result: Dictionary = _evaluate_directory(REGIONS_DIR)
	var upgrades_result: Dictionary = _evaluate_directory(UPGRADES_DIR)

	_resources = resources_result.valid
	_recipes = recipes_result.valid
	_regions = regions_result.valid
	_upgrades = upgrades_result.valid

	print(
		"Db: loaded %d resources, %d recipes, %d regions, %d upgrades" % [
			_resources.size(), _recipes.size(), _regions.size(), _upgrades.size()
		]
	)

	var all_problems: Array[String] = []
	all_problems.append_array(resources_result.problems)
	all_problems.append_array(recipes_result.problems)
	all_problems.append_array(regions_result.problems)
	all_problems.append_array(upgrades_result.problems)
	for problem: String in all_problems:
		push_error("Db: %s" % problem)


func resource(id: StringName) -> ResourceDef:
	var found: Variant = _resources.get(id)
	if found == null:
		push_error("Db.resource: no ResourceDef with id '%s'" % id)
		return null
	return found as ResourceDef


func recipe(id: StringName) -> Resource:
	var found: Variant = _recipes.get(id)
	if found == null:
		push_error("Db.recipe: no definition with id '%s'" % id)
		return null
	return found as Resource


func region(id: StringName) -> Resource:
	var found: Variant = _regions.get(id)
	if found == null:
		push_error("Db.region: no definition with id '%s'" % id)
		return null
	return found as Resource


func upgrade(id: StringName) -> Resource:
	var found: Variant = _upgrades.get(id)
	if found == null:
		push_error("Db.upgrade: no definition with id '%s'" % id)
		return null
	return found as Resource


func all_resources() -> Array[ResourceDef]:
	var out: Array[ResourceDef] = []
	for def: ResourceDef in _resources.values():
		out.append(def)
	return out


## Re-scans every collection and returns every problem found, without touching the
## live registry. Intended for tests, CI, and the boot-time push_error sweep above.
func validate() -> Array[String]:
	var problems: Array[String] = []
	problems.append_array(_evaluate_directory(RESOURCES_DIR).problems)
	problems.append_array(_evaluate_directory(RECIPES_DIR).problems)
	problems.append_array(_evaluate_directory(REGIONS_DIR).problems)
	problems.append_array(_evaluate_directory(UPGRADES_DIR).problems)
	return problems


## Scans every `.tres` directly inside `dir_path` and returns:
##   valid:    Dictionary[StringName, Resource] - entries with no problems
##   problems: Array[String] - one entry per problem found (a single file can
##             contribute more than one, e.g. both a filename mismatch AND a
##             duplicate id)
##
## Duplicate-id detection is deliberately independent of the filename-match check:
## since filenames are unique within a directory, two entries can only ever share
## a *declared* id if at least one of them already has a mismatched filename - so
## gating duplicate detection behind "filename matched" would make it unreachable.
func _evaluate_directory(dir_path: String) -> Dictionary:
	var valid: Dictionary = {}
	var problems: Array[String] = []
	var seen_ids: Dictionary = {}  # String -> String (id -> first path that claimed it)

	for entry: Dictionary in _scan_tres_files(dir_path):
		var path: String = entry["path"]
		var filename_id: String = entry["filename_id"]
		var def: Resource = load(path)

		if def == null:
			problems.append("%s: failed to load" % path)
			continue

		var id_value: Variant = def.get("id")
		if id_value == null:
			problems.append("%s: has no `id` property" % path)
			continue

		var id: String = String(id_value as StringName)
		if id.is_empty():
			problems.append("%s: empty id" % path)
			continue

		var entry_ok: bool = true

		if id != filename_id:
			problems.append("%s: id '%s' does not match filename" % [path, id])
			entry_ok = false

		if seen_ids.has(id):
			problems.append(
				"%s: duplicate id '%s' (already used by %s)" % [path, id, seen_ids[id]]
			)
			entry_ok = false
		else:
			seen_ids[id] = path

		if entry_ok:
			valid[StringName(id)] = def

	return {"valid": valid, "problems": problems}


## Lists every `.tres` file directly inside `dir_path`, returning its `res://` path and
## the id implied by its filename (`timber.tres` -> `timber`).
func _scan_tres_files(dir_path: String) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	var dir: DirAccess = DirAccess.open(dir_path)
	if dir == null:
		return out

	dir.list_dir_begin()
	var filename: String = dir.get_next()
	while filename != "":
		if not dir.current_is_dir() and filename.ends_with(".tres"):
			out.append({
				"path": dir_path + filename,
				"filename_id": filename.trim_suffix(".tres"),
			})
		filename = dir.get_next()
	dir.list_dir_end()

	return out
