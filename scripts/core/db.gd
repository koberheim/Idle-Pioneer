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
const COLONIES_DIR: String = "res://data/colonies/"

## MVP has exactly one map. A per-region `map_id` field (and a dictionary of
## loaded grids keyed by it) is the obvious extension once a second map exists -
## not built ahead of that need, per docs/GODOT_PLAN.md Phase 10 rule 5.
const MAP_PATH: String = "res://data/maps/mvp_coast.txt"

var _resources: Dictionary = {}  # StringName -> ResourceDef
var _recipes: Dictionary = {}  # StringName -> RecipeDef
var _regions: Dictionary = {}  # StringName -> RegionDef (dormant - see design realignment, docs/GODOT_PLAN.md)
var _upgrades: Dictionary = {}  # StringName -> UpgradeDef
var _colonies: Dictionary = {}  # StringName -> ColonyDef
var _map_grid: MapGrid = null


func _ready() -> void:
	var resources_result: Dictionary = _evaluate_directory(RESOURCES_DIR)
	var recipes_result: Dictionary = _evaluate_directory(RECIPES_DIR)
	var regions_result: Dictionary = _evaluate_directory(REGIONS_DIR)
	var upgrades_result: Dictionary = _evaluate_directory(UPGRADES_DIR)
	var colonies_result: Dictionary = _evaluate_directory(COLONIES_DIR)

	# A region whose cell isn't a valid colony site on the map is exactly as
	# unusable as one with a duplicate id - see _placement_problems for why
	# this needs a second pass rather than living inside _evaluate_directory
	# (it's map-specific, not something every collection needs).
	var placement_problems: Array[String] = _placement_problems(regions_result.valid)
	var clean_regions: Dictionary = regions_result.valid.duplicate()
	for id: StringName in regions_result.valid.keys():
		var def: RegionDef = regions_result.valid[id] as RegionDef
		if not PlacementRules.is_valid_colony_site(map_grid(), def.cell):
			clean_regions.erase(id)

	_resources = resources_result.valid
	_recipes = recipes_result.valid
	_regions = clean_regions
	_upgrades = upgrades_result.valid
	_colonies = colonies_result.valid

	print(
		"Db: loaded %d resources, %d recipes, %d regions, %d upgrades, %d colonies" % [
			_resources.size(), _recipes.size(), _regions.size(), _upgrades.size(), _colonies.size()
		]
	)

	var all_problems: Array[String] = []
	all_problems.append_array(resources_result.problems)
	all_problems.append_array(recipes_result.problems)
	all_problems.append_array(regions_result.problems)
	all_problems.append_array(placement_problems)
	all_problems.append_array(upgrades_result.problems)
	all_problems.append_array(colonies_result.problems)
	all_problems.append_array(_colony_table_problems(_colonies))
	for problem: String in all_problems:
		push_error("Db: %s" % problem)


func resource(id: StringName) -> ResourceDef:
	var found: Variant = _resources.get(id)
	if found == null:
		push_error("Db.resource: no ResourceDef with id '%s'" % id)
		return null
	return found as ResourceDef


func recipe(id: StringName) -> RecipeDef:
	var found: Variant = _recipes.get(id)
	if found == null:
		push_error("Db.recipe: no definition with id '%s'" % id)
		return null
	return found as RecipeDef


## Recipes have no fixed display order in docs/GAME_DESIGN.md §7's table
## beyond "single-step goods before multi-step ones" - sorted by
## craft_seconds as a reasonable stand-in (shorter/simpler recipes first),
## not a claim that craft time is the design's actual ordering rule.
func all_recipes() -> Array[RecipeDef]:
	var out: Array[RecipeDef] = []
	for def: RecipeDef in _recipes.values():
		out.append(def)
	out.sort_custom(func(a: RecipeDef, b: RecipeDef) -> bool: return a.craft_seconds < b.craft_seconds)
	return out


## Direct request: Market splits raw materials from crafted goods into two
## sub-tabs. A resource counts as "crafted" if any recipe names it as an
## output - everything else (what a colony produces directly) is a raw
## material. Cheap enough to compute on demand (recipe count is tiny) rather
## than caching a second lookup table alongside _recipes.
func is_crafted_resource(id: StringName) -> bool:
	for def: RecipeDef in _recipes.values():
		if def.output_id == id:
			return true
	return false


func region(id: StringName) -> RegionDef:
	var found: Variant = _regions.get(id)
	if found == null:
		push_error("Db.region: no definition with id '%s'" % id)
		return null
	return found as RegionDef


func upgrade(id: StringName) -> UpgradeDef:
	var found: Variant = _upgrades.get(id)
	if found == null:
		push_error("Db.upgrade: no definition with id '%s'" % id)
		return null
	return found as UpgradeDef


func all_resources() -> Array[ResourceDef]:
	var out: Array[ResourceDef] = []
	for def: ResourceDef in _resources.values():
		out.append(def)
	return out


func all_upgrades() -> Array[UpgradeDef]:
	var out: Array[UpgradeDef] = []
	for def: UpgradeDef in _upgrades.values():
		out.append(def)
	return out


func colony(id: StringName) -> ColonyDef:
	var found: Variant = _colonies.get(id)
	if found == null:
		push_error("Db.colony: no ColonyDef with id '%s'" % id)
		return null
	return found as ColonyDef


## Every colony in fixed play order (docs/GAME_DESIGN.md §5 - order 0 is
## always the Capital). Never rely on Dictionary iteration order for this -
## sort explicitly every time, since nothing about a Dictionary guarantees
## insertion or scan order matches `order`.
func all_colonies() -> Array[ColonyDef]:
	var out: Array[ColonyDef] = []
	for def: ColonyDef in _colonies.values():
		out.append(def)
	out.sort_custom(func(a: ColonyDef, b: ColonyDef) -> bool: return a.order < b.order)
	return out


## The one colony with is_capital true. Null (with a push_error) if content is
## missing or misconfigured - every real save assumes exactly one exists.
func capital() -> ColonyDef:
	for def: ColonyDef in _colonies.values():
		if def.is_capital:
			return def
	push_error("Db.capital: no ColonyDef has is_capital = true")
	return null


## The ColonyDef whose `order` matches - used by Colonies' tier-cycling
## logic (rework task: randomized map) to look up which tier a given colony
## slot draws its resource/base stats from. Null (with a push_error) if no
## tier has that order.
func colony_by_order(order: int) -> ColonyDef:
	for def: ColonyDef in _colonies.values():
		if def.order == order:
			return def
	push_error("Db.colony_by_order: no ColonyDef has order %d" % order)
	return null


## Silent existence check - unlike resource(id), this never push_errors. For
## callers (e.g. task R1's Inventory) that want to report their own, more
## specific "unknown id" message without also triggering Db's generic one for
## the same call.
func has_resource(id: StringName) -> bool:
	return _resources.has(id)


## The MVP's one map (task M5 - see the MAP_PATH doc comment above), loaded
## once and cached. Returns null (with a push_error already emitted by
## MapLoader) if the file is missing or malformed.
func map_grid() -> MapGrid:
	if _map_grid == null:
		_map_grid = MapLoader.from_file(MAP_PATH)
	return _map_grid


## Whether a region sits on a coast cell - derived from the map every time
## this is called, never stored on RegionDef itself. See RegionDef's class doc
## (task D3) for why: two independent sources of truth for the same fact is
## how they drift apart.
func region_is_coastal(id: StringName) -> bool:
	var def: RegionDef = region(id)
	var grid: MapGrid = map_grid()
	if def == null or grid == null:
		return false
	return grid.is_coast(def.cell)


## Re-scans every collection and returns every problem found, without touching the
## live registry. Intended for tests, CI, and the boot-time push_error sweep above.
func validate() -> Array[String]:
	var problems: Array[String] = []
	problems.append_array(_evaluate_directory(RESOURCES_DIR).problems)
	problems.append_array(_evaluate_directory(RECIPES_DIR).problems)

	var regions_result: Dictionary = _evaluate_directory(REGIONS_DIR)
	problems.append_array(regions_result.problems)
	problems.append_array(_placement_problems(regions_result.valid))

	problems.append_array(_evaluate_directory(UPGRADES_DIR).problems)

	var colonies_result: Dictionary = _evaluate_directory(COLONIES_DIR)
	problems.append_array(colonies_result.problems)
	problems.append_array(_colony_table_problems(colonies_result.valid))

	return problems


## Table-level checks that don't fit per-entry validation: exactly one
## Capital, and no two colonies sharing the same play position. These are
## reported (not auto-fixed) - there's no sensible way to exclude a single
## entry to repair a table-wide problem the way _placement_problems can drop
## one bad region.
func _colony_table_problems(colonies_valid: Dictionary) -> Array[String]:
	var problems: Array[String] = []

	var capital_ids: Array[StringName] = []
	var seen_orders: Dictionary = {}  # int -> StringName (order -> first id that claimed it)

	for id: StringName in colonies_valid.keys():
		var def: ColonyDef = colonies_valid[id] as ColonyDef

		if def.is_capital:
			capital_ids.append(id)

		if seen_orders.has(def.order):
			problems.append(
				"colony '%s' has order %d, already used by '%s'" % [id, def.order, seen_orders[def.order]]
			)
		else:
			seen_orders[def.order] = id

	if capital_ids.is_empty():
		problems.append("no colony has is_capital = true")
	elif capital_ids.size() > 1:
		problems.append("more than one colony has is_capital = true: %s" % [capital_ids])

	return problems


## Every region in `regions_valid` (StringName -> RegionDef) whose cell isn't a
## valid colony site (land or coast) on the MVP map - task M5's guard rail. A
## region that fails this check is excluded from the live registry in _ready()
## exactly like any other malformed entry.
func _placement_problems(regions_valid: Dictionary) -> Array[String]:
	var problems: Array[String] = []
	var grid: MapGrid = map_grid()
	if grid == null:
		problems.append("could not load map '%s' to validate region placement" % MAP_PATH)
		return problems

	for id: StringName in regions_valid.keys():
		var def: RegionDef = regions_valid[id] as RegionDef
		if not PlacementRules.is_valid_colony_site(grid, def.cell):
			problems.append(
				"region '%s' at cell %s is not a valid colony site (must be land or coast) on '%s'" % [
					id, def.cell, MAP_PATH
				]
			)
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

		# Content types that define their own domain rules (e.g. RecipeDef.is_valid()
		# rejecting a recipe with no inputs - see docs/GODOT_MIGRATION_ANALYSIS.md §B2
		# for the Unity bug this exists to catch) get checked here too, so a definition
		# with a working is_valid() can never be silently loaded anyway.
		if def.has_method("is_valid") and not (def.call("is_valid") as bool):
			problems.append("%s: failed content validation (is_valid() returned false)" % path)
			entry_ok = false

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
