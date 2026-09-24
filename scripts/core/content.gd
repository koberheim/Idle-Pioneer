## Static game content, loaded once from data/*.json. Nothing here changes at
## runtime; tuning the game means editing the JSON, not code.
extends Node

const CONTENT_PATH := "res://data/content.json"
const NAMES_PATH := "res://data/colony_names.json"
const MAP_PATH := "res://data/map.json"

var resources: Array[Dictionary] = []
var colonies: Array[Dictionary] = []
var recipes: Array[Dictionary] = []
var fathers: Array[Dictionary] = []
var nations: Array[Dictionary] = []
var liberty_upgrades: Array[Dictionary] = []
var charters: Array[Dictionary] = []
var governor_types: Array[Dictionary] = []
var governor_names: Array = []
var colony_names: Dictionary = {}
var map: Dictionary = {}

var _resource_by_id: Dictionary = {}
var _colony_by_id: Dictionary = {}
var _recipe_by_id: Dictionary = {}
var _father_by_id: Dictionary = {}
var _nation_by_id: Dictionary = {}
var _upgrade_by_id: Dictionary = {}


func _init() -> void:
	var data: Dictionary = _load_json(CONTENT_PATH)
	resources = _typed(data.get("resources", []))
	colonies = _typed(data.get("colonies", []))
	recipes = _typed(data.get("recipes", []))
	fathers = _typed(data.get("fathers", []))
	nations = _typed(data.get("nations", []))
	liberty_upgrades = _typed(data.get("liberty_upgrades", []))
	charters = _typed(data.get("charters", []))
	governor_types = _typed(data.get("governor_types", []))
	governor_names = data.get("governor_names", [])
	colony_names = _load_json(NAMES_PATH)
	map = _load_json(MAP_PATH)

	_index(resources, _resource_by_id)
	_index(colonies, _colony_by_id)
	_index(recipes, _recipe_by_id)
	_index(fathers, _father_by_id)
	_index(nations, _nation_by_id)
	_index(liberty_upgrades, _upgrade_by_id)
	_validate()


func resource(id: String) -> Dictionary:
	return _resource_by_id.get(id, {})


func colony(id: String) -> Dictionary:
	return _colony_by_id.get(id, {})


func recipe(id: String) -> Dictionary:
	return _recipe_by_id.get(id, {})


func father(id: String) -> Dictionary:
	return _father_by_id.get(id, {})


func nation(id: String) -> Dictionary:
	return _nation_by_id.get(id, {})


func liberty_upgrade(id: String) -> Dictionary:
	return _upgrade_by_id.get(id, {})


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


func colony_index(colony_id: String) -> int:
	for i in colonies.size():
		if colonies[i]["id"] == colony_id:
			return i
	return -1


## The recipe that produces `resource_id`, or {} for raw goods.
func recipe_for_output(resource_id: String) -> Dictionary:
	return recipe(resource_id)


func colony_name(nation_id: String, colony_index_: int) -> String:
	var names: Array = colony_names.get(nation_id, [])
	if colony_index_ >= 0 and colony_index_ < names.size():
		return str(names[colony_index_])
	return str(colonies[colony_index_]["id"]).capitalize()


## Map sites for a colony: an Array of {x, y, route} where route is "land" or "sea".
func colony_sites(colony_id: String) -> Array:
	return map.get("sites", {}).get(colony_id, [])


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
	for c: Dictionary in colonies:
		if not _resource_by_id.has(c["resource"]):
			push_error("Content: colony %s produces unknown resource %s" % [c["id"], c["resource"]])
		if map.size() > 0 and colony_sites(c["id"]).is_empty():
			push_error("Content: colony %s has no map sites" % c["id"])
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
