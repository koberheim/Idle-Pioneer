## The resettable-on-prestige half of the save (task G1 - see docs/GODOT_PLAN.md
## Phase 6, Option B). Plain data, no Node, no autoload dependency - RefCounted like
## MapGrid, for the same reason: this is runtime state to serialise, not authored
## content (that's a Resource, e.g. ResourceDef) and not a live subsystem (that's a
## Node, e.g. Game.inventory).
##
## `Game.run = null` means "no run in progress" (main menu / fresh install).
## `Game.new_run(map_id)` replaces `Game.run` wholesale - that replacement IS
## prestige, once task G3 wires it up. See docs/GODOT_PLAN.md Phase 6 for why the
## reset boundary being structural (a whole object swap) rather than remembered
## (a loop over "run-scoped" fields) is the point of splitting Run/Meta at all.
class_name RunState
extends RefCounted

## Empty/zero for a hand-authored map (MVP; see MapGrid.seed_value). Which map
## this run is on.
var map_id: StringName = &""
var map_seed: int = 0

var elapsed_seconds: float = 0.0
var gold: float = 0.0

## How many colonists have been bought this run (docs/GAME_DESIGN.md §4 - the
## shared workforce split between gathering and crafting). Colonists owns the
## behaviour (buying, assigning); this is just where the total is persisted.
var colonists_owned: int = 0

## StringName -> float. Central resource stock (task R1 owns the behaviour;
## this is just where it's persisted).
var inventory: Dictionary = {}

## Per-colony save state, shaped to match docs/GAME_DESIGN.md §9's own save
## example directly (down to "route_type": "land"/"sea" as a string, exactly
## as shown there). Each entry:
## {"colony_id": StringName, "production_level": int, "cargo_level": int,
## "speed_level": int, "route_type": String ("land"/"sea"),
## "local_stock": Dictionary[StringName, float]}
## is_capital isn't stored - it's fully derived from ColonyDef via colony_id
## (Colony's own constructor looks it up), so storing it here would just be a
## second source of truth for the same fact.
var colonies: Array[Dictionary] = []

var upgrades_purchased: Array[StringName] = []
var colonies_founded: int = 0


func to_dict() -> Dictionary:
	return {
		"map_id": String(map_id),
		"map_seed": map_seed,
		"elapsed_seconds": elapsed_seconds,
		"gold": gold,
		"colonists_owned": colonists_owned,
		"inventory": _stringname_float_dict_to_json(inventory),
		"colonies": colonies.map(_colony_to_dict),
		"upgrades_purchased": upgrades_purchased.map(func(id: StringName) -> String: return String(id)),
		"colonies_founded": colonies_founded,
	}


static func from_dict(d: Dictionary) -> RunState:
	var s := RunState.new()
	s.map_id = StringName(d.get("map_id", ""))
	# JSON has no integer type - every number round-trips as float. Cast
	# explicitly wherever the field is meant to be an int (see docs/GODOT_PLAN.md
	# Phase 8, task G1's stated regression risk).
	s.map_seed = int(d.get("map_seed", 0))
	s.elapsed_seconds = float(d.get("elapsed_seconds", 0.0))
	s.gold = float(d.get("gold", 0.0))
	s.colonists_owned = int(d.get("colonists_owned", 0))
	s.inventory = _json_to_stringname_float_dict(d.get("inventory", {}))

	var colonies: Array[Dictionary] = []
	for entry: Variant in (d.get("colonies", []) as Array):
		colonies.append(_colony_from_dict(entry as Dictionary))
	s.colonies = colonies

	var upgrades: Array[StringName] = []
	for entry: Variant in (d.get("upgrades_purchased", []) as Array):
		upgrades.append(StringName(entry as String))
	s.upgrades_purchased = upgrades

	s.colonies_founded = int(d.get("colonies_founded", 0))
	return s


static func _stringname_float_dict_to_json(source: Dictionary) -> Dictionary:
	var out: Dictionary = {}
	for key: StringName in source.keys():
		out[String(key)] = float(source[key])
	return out


static func _json_to_stringname_float_dict(source: Dictionary) -> Dictionary:
	var out: Dictionary = {}
	for key: String in source.keys():
		out[StringName(key)] = float(source[key])
	return out


static func _colony_to_dict(colony: Dictionary) -> Dictionary:
	var local_stock: Dictionary = colony.get("local_stock", {})
	var route_type: int = int(colony.get("route_type", 0))  # Colony.RouteType.LAND = 0
	return {
		"colony_id": String(colony.get("colony_id", &"")),
		"production_level": int(colony.get("production_level", 0)),
		"cargo_level": int(colony.get("cargo_level", 0)),
		"speed_level": int(colony.get("speed_level", 0)),
		"route_type": "sea" if route_type == 1 else "land",
		"local_stock": _stringname_float_dict_to_json(local_stock),
	}


static func _colony_from_dict(d: Dictionary) -> Dictionary:
	return {
		"colony_id": StringName(d.get("colony_id", "")),
		"production_level": int(d.get("production_level", 0)),
		"cargo_level": int(d.get("cargo_level", 0)),
		"speed_level": int(d.get("speed_level", 0)),
		"route_type": 1 if String(d.get("route_type", "land")) == "sea" else 0,
		"local_stock": _json_to_stringname_float_dict(d.get("local_stock", {})),
	}
