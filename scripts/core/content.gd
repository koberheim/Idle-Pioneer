## Static game content, loaded once from data/*.json. Nothing here changes at
## runtime; tuning the game means editing the JSON, not code.
extends Node

const CONTENT_PATH := "res://data/content.json"
const NAMES_PATH := "res://data/colony_names.json"

const RESEARCH_PATH := "res://data/research.json"

var resources: Array[Dictionary] = []
var terrains: Array[Dictionary] = []
var recipes: Array[Dictionary] = []
var fathers: Array[Dictionary] = []
var nations: Array[Dictionary] = []
var liberty_upgrades: Array[Dictionary] = []
var charters: Array[Dictionary] = []
var governor_types: Array[Dictionary] = []
var governor_names: Array = []
var colony_names: Dictionary = {}
var relics: Array[Dictionary] = []
var relic_sets: Array[Dictionary] = []
var specializations: Array[Dictionary] = []
var research: Array[Dictionary] = []
var research_branches: Array[Dictionary] = []

var _resource_by_id: Dictionary = {}
var _recipe_by_id: Dictionary = {}
var _father_by_id: Dictionary = {}
var _nation_by_id: Dictionary = {}
var _upgrade_by_id: Dictionary = {}
var _relic_by_id: Dictionary = {}
var _relic_set_by_id: Dictionary = {}
var _spec_by_id: Dictionary = {}
var _research_by_id: Dictionary = {}


func _init() -> void:
	var data: Dictionary = _load_json(CONTENT_PATH)
	resources = _typed(data.get("resources", []))
	terrains = _typed(data.get("terrains", []))
	recipes = _typed(data.get("recipes", []))
	fathers = _typed(data.get("fathers", []))
	nations = _typed(data.get("nations", []))
	liberty_upgrades = _typed(data.get("liberty_upgrades", []))
	charters = _typed(data.get("charters", []))
	relics = _typed(data.get("relics", []))
	relic_sets = _typed(data.get("relic_sets", []))
	specializations = _typed(data.get("specializations", []))
	# The Philosophical Society's studies live in their own file.
	if FileAccess.file_exists(RESEARCH_PATH):
		var rd: Dictionary = _load_json(RESEARCH_PATH)
		research = _typed(rd.get("research", []))
		research_branches = _typed(rd.get("research_branches", []))
	governor_types = _typed(data.get("governor_types", []))
	governor_names = data.get("governor_names", [])
	colony_names = _load_json(NAMES_PATH)

	_index(resources, _resource_by_id)
	_index(recipes, _recipe_by_id)
	_index(fathers, _father_by_id)
	_index(nations, _nation_by_id)
	_index(liberty_upgrades, _upgrade_by_id)
	_index(relics, _relic_by_id)
	_index(relic_sets, _relic_set_by_id)
	_index(specializations, _spec_by_id)
	_index(research, _research_by_id)
	_validate()


func resource(id: String) -> Dictionary:
	return _resource_by_id.get(id, {})


func recipe(id: String) -> Dictionary:
	return _recipe_by_id.get(id, {})


func father(id: String) -> Dictionary:
	return _father_by_id.get(id, {})


func nation(id: String) -> Dictionary:
	return _nation_by_id.get(id, {})


func liberty_upgrade(id: String) -> Dictionary:
	return _upgrade_by_id.get(id, {})


func relic(id: String) -> Dictionary:
	return _relic_by_id.get(id, {})


func relic_set(id: String) -> Dictionary:
	return _relic_set_by_id.get(id, {})


func relics_in_set(set_id: String) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for r: Dictionary in relics:
		if r["set"] == set_id:
			out.append(r)
	return out


func study(id: String) -> Dictionary:
	return _research_by_id.get(id, {})


func studies_in_branch(branch_id: String) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for r: Dictionary in research:
		if r["branch"] == branch_id:
			out.append(r)
	return out


func specialization(id: String) -> Dictionary:
	return _spec_by_id.get(id, {})


func governor_type(type_id: String) -> Dictionary:
	for t: Dictionary in governor_types:
		if t["id"] == type_id:
			return t
	return {}


func price(resource_id: String) -> float:
	return float(resource(resource_id).get("price", 0.0))


func resource_name(resource_id: String) -> String:
	return str(resource(resource_id).get("name", resource_id))


func is_crafted(resource_id: String) -> bool:
	return resource(resource_id).get("kind", "") == "crafted"


## The recipe that produces `resource_id`, or {} for raw goods.
func recipe_for_output(resource_id: String) -> Dictionary:
	return recipe(resource_id)


func colony_name(nation_id: String, tier: int) -> String:
	var names: Array = colony_names.get(nation_id, [])
	if tier >= 0 and tier < names.size():
		return str(names[tier])
	return "Colony %d" % (tier + 1)


func terrain_name(terrain_id: int) -> String:
	return str(terrains[terrain_id].get("name", "?")) if terrain_id >= 0 and terrain_id < terrains.size() else "?"


func raw_resources() -> Array[String]:
	var out: Array[String] = []
	for r: Dictionary in resources:
		if r["kind"] == "raw":
			out.append(str(r["id"]))
	return out


func _load_json(path: String) -> Dictionary:
	var f := FileAccess.open(path, FileAccess.READ)
	if f == null:
		push_error("Content: cannot open %s" % path)
		return {}
	var parsed: Variant = JSON.parse_string(f.get_as_text())
	if parsed is Dictionary:
		return parsed
	push_error("Content: %s is not a JSON object" % path)
	return {}


func _typed(arr: Array) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for v: Variant in arr:
		out.append(v as Dictionary)
	return out


func _index(list: Array[Dictionary], into: Dictionary) -> void:
	for entry: Dictionary in list:
		var id: String = str(entry.get("id", ""))
		if id == "" or into.has(id):
			push_error("Content: missing or duplicate id '%s'" % id)
			continue
		into[id] = entry


## Fails loudly at boot on broken cross-references rather than letting a typo
## surface as a silent zero somewhere in the economy.
func _validate() -> void:
	for t: Dictionary in terrains:
		for key: String in (t.get("resources", {}) as Dictionary).keys() + (t.get("coastal", {}) as Dictionary).keys():
			if not _resource_by_id.has(key):
				push_error("Content: terrain %s yields unknown resource %s" % [t["id"], key])
	for r: Dictionary in recipes:
		if not _resource_by_id.has(r["id"]):
			push_error("Content: recipe %s has no matching output resource" % r["id"])
		for input_id: String in (r["inputs"] as Dictionary).keys():
			if not _resource_by_id.has(input_id):
				push_error("Content: recipe %s uses unknown input %s" % [r["id"], input_id])
	for ch: Dictionary in charters:
		for key: String in (ch["goods"] as Dictionary).keys():
			if not _resource_by_id.has(key):
				push_error("Content: charter uses unknown good %s" % key)
	for f: Dictionary in fathers:
		for key: String in (f["cost"] as Dictionary).keys():
			if key != "gold" and not _resource_by_id.has(key):
				push_error("Content: father %s costs unknown good %s" % [f["id"], key])
