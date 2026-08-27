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

## Seeds this run's generated map (rework task: randomized map) - captured
## once at new_run() and never touched again, so the SAME map regenerates
## deterministically if ever needed, and so a save file can prove which map
## a run was on. The actual generated terrain lives in `map` below; this is
## just provenance.
var map_seed: int = 0

## The generated map's terrain (MapGrid.to_dict()'s own shape) - generated
## once at new_run() and persisted so reload never reshuffles it (confirmed
## directly: the map stays fixed for a run's whole lifetime, only a prestige
## reset generates a new one). Nothing during normal play reads this back
## into a live MapGrid - every colony slot already carries its own
## precomputed distance/coastal-ness (see `colony_slots` below), so there's
## no gameplay reason to re-query the grid after generation. Saved purely
## for completeness and for a future map view (out of scope for v1 - see
## docs/GAME_DESIGN.md §12).
var map: Dictionary = {}

## Every colony site this run's map generated - one entry per slot, in
## founding order (slot 0 is always the Capital). `founded` is the only
## field that changes after generation; everything else (position, distance,
## coastal-ness) is baked in once and never recomputed - see MapGenerator.
## Each entry:
## {"slot_index": int, "tier_order": int, "cell_x": int, "cell_y": int,
## "distance_cells": float, "is_coastal": bool, "founded": bool}
var colony_slots: Array[Dictionary] = []

var elapsed_seconds: float = 0.0
var gold: float = 0.0

## Unix time this run began - Game.new_run() stamps it. What the "fastest
## run" stat (Game.meta.stats) is measured against, since nothing drives a
## real elapsed-time clock yet (see docs/GODOT_PLAN.md's design realignment
## section on continuous crafting/offline catch-up) - wall-clock time is the
## only elapsed-time signal that actually exists right now.
var started_at_unix: int = 0

## Total gold ever earned this run, never decreasing even as gold is spent -
## what §8's prestige gate/payout actually reads (lifetime_coin_this_run),
## as opposed to current on-hand `gold` above. Resets to 0 with every new
## run, same as everything else in RunState; Game.meta.lifetime_gold_earned
## is the separate, permanent, never-reset total across every run.
var lifetime_gold_earned_this_run: float = 0.0

## Currency spent recruiting/upgrading colonists (rework: typed colonist
## roster - docs/GAME_DESIGN.md §4's "central tension," now with real shape:
## Resource/Cargo/Speed colonists, one of each per colony). Separate from
## gold; how it's earned is still undecided - see Balance's
## influence_earn_rate_per_gold placeholder. Resets each run, same as gold.
var influence: float = 0.0

## One entry per owned colonist (Colonist.to_dict()'s own shape - id, type,
## level, assigned_colony_id). Colonists owns all behaviour that reads or
## writes this; RunState just persists it, same as `inventory` or `gold`.
var colonist_roster: Array[Dictionary] = []

## Hands out each new colonist's stable per-run id (Colonists.recruit()) -
## only ever increments, never reused, so an id stays unique even after the
## colonist it named is long gone (there's no "delete a colonist" action,
## but this is cheap insurance against ever adding one and forgetting this
## constraint).
var next_colonist_id: int = 1

## StringName -> float. Central resource stock (task R1 owns the behaviour;
## this is just where it's persisted).
var inventory: Dictionary = {}

## Per-colony save state. Each entry:
## {"colony_id": StringName, "tier_id": StringName, "slot_index": int,
## "production_level": int, "cargo_level": int, "speed_level": int,
## "local_stock": Dictionary[StringName, float]}
## Neither is_capital nor position/distance/coastal-ness is stored here -
## is_capital is derived from tier_id via ColonyDef, and the rest comes from
## the matching entry in `colony_slots` above via slot_index. Storing either
## a second time would just be a second source of truth for the same fact
## (rework task: randomized map - colony_slots is what actually owns
## position now, colonies here only owns purchased-upgrade state).
var colonies: Array[Dictionary] = []

var upgrades_purchased: Array[StringName] = []
var colonies_founded: int = 0

## Which resources/recipes this run has actually encountered, in the order
## first encountered (Discoveries owns the behaviour - see its class doc).
## Run-scoped, unlike MetaState.recipes_ever_unlocked's permanent "ever
## crafted" stat - a fresh run starts back at nothing discovered.
var discovered_resources: Array[StringName] = []
var discovered_recipes: Array[StringName] = []

## Per-recipe auto-craft save state (rework task: continuous crafting).
## Field names match docs/GAME_DESIGN.md §9's own "workshops" example, minus
## "colonists"/"level" - those belong to a colonist-driven crafting-speed
## formula that hasn't been asked for or designed yet (see CraftingStation's
## class doc). Each entry:
## {"recipe_id": StringName, "auto_craft": bool, "cycle_accumulated": float}
var workshops: Array[Dictionary] = []

## StringName (resource id) -> StringName ("sell" or "reserve") - per-resource
## routing at the Capital (docs/GAME_DESIGN.md §2/§9). Game.routing owns the
## behaviour and the SELL/RESERVE constants; this is just where it's
## persisted. A resource with no entry here defaults to RESERVE (see
## Routing.mode_for) - goods pile up in storage exactly like before this
## system existed, unless the player explicitly opts a resource into
## auto-selling.
var resource_routing: Dictionary = {}

## Per-route save state (rework task: live simulation driver). Routes are
## rebuilt automatically (Routes.sync_with_colonies(), keyed by colony_id) -
## this is only the in-flight state that can't be re-derived: where the
## shipment currently is, and what it's carrying. Without this, activating
## routes for real play would silently drop any cargo in transit on every
## save/load. Each entry:
## {"colony_id": StringName, "state": String ("at_origin"/"traveling_to_hub"/
## "traveling_to_origin"), "cargo": Dictionary[StringName, float],
## "leg_elapsed": float}
var routes: Array[Dictionary] = []


func to_dict() -> Dictionary:
	return {
		"map_id": String(map_id),
		"map_seed": map_seed,
		"map": map,
		"colony_slots": colony_slots.map(_colony_slot_to_dict),
		"started_at_unix": started_at_unix,
		"elapsed_seconds": elapsed_seconds,
		"gold": gold,
		"lifetime_gold_earned_this_run": lifetime_gold_earned_this_run,
		"influence": influence,
		"colonist_roster": colonist_roster,
		"next_colonist_id": next_colonist_id,
		"inventory": _stringname_float_dict_to_json(inventory),
		"colonies": colonies.map(_colony_to_dict),
		"upgrades_purchased": upgrades_purchased.map(func(id: StringName) -> String: return String(id)),
		"colonies_founded": colonies_founded,
		"discovered_resources": discovered_resources.map(func(id: StringName) -> String: return String(id)),
		"discovered_recipes": discovered_recipes.map(func(id: StringName) -> String: return String(id)),
		"workshops": workshops.map(_workshop_to_dict),
		"resource_routing": _stringname_string_dict_to_json(resource_routing),
		"routes": routes.map(_route_to_dict),
	}


static func from_dict(d: Dictionary) -> RunState:
	var s := RunState.new()
	s.map_id = StringName(d.get("map_id", ""))
	# JSON has no integer type - every number round-trips as float. Cast
	# explicitly wherever the field is meant to be an int (see docs/GODOT_PLAN.md
	# Phase 8, task G1's stated regression risk).
	s.map_seed = int(d.get("map_seed", 0))
	s.map = d.get("map", {})

	var colony_slots: Array[Dictionary] = []
	for entry: Variant in (d.get("colony_slots", []) as Array):
		colony_slots.append(_colony_slot_from_dict(entry as Dictionary))
	s.colony_slots = colony_slots

	s.started_at_unix = int(d.get("started_at_unix", 0))
	s.elapsed_seconds = float(d.get("elapsed_seconds", 0.0))
	s.gold = float(d.get("gold", 0.0))
	s.lifetime_gold_earned_this_run = float(d.get("lifetime_gold_earned_this_run", 0.0))
	s.influence = float(d.get("influence", 0.0))

	var colonist_roster: Array[Dictionary] = []
	for entry: Variant in (d.get("colonist_roster", []) as Array):
		colonist_roster.append(entry as Dictionary)
	s.colonist_roster = colonist_roster

	s.next_colonist_id = int(d.get("next_colonist_id", 1))
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

	var discovered_resources: Array[StringName] = []
	for entry: Variant in (d.get("discovered_resources", []) as Array):
		discovered_resources.append(StringName(entry as String))
	s.discovered_resources = discovered_resources

	var discovered_recipes: Array[StringName] = []
	for entry: Variant in (d.get("discovered_recipes", []) as Array):
		discovered_recipes.append(StringName(entry as String))
	s.discovered_recipes = discovered_recipes

	var workshops: Array[Dictionary] = []
	for entry: Variant in (d.get("workshops", []) as Array):
		workshops.append(_workshop_from_dict(entry as Dictionary))
	s.workshops = workshops

	s.resource_routing = _json_to_stringname_string_dict(d.get("resource_routing", {}))

	var routes: Array[Dictionary] = []
	for entry: Variant in (d.get("routes", []) as Array):
		routes.append(_route_from_dict(entry as Dictionary))
	s.routes = routes

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


static func _stringname_string_dict_to_json(source: Dictionary) -> Dictionary:
	var out: Dictionary = {}
	for key: StringName in source.keys():
		out[String(key)] = String(source[key])
	return out


static func _json_to_stringname_string_dict(source: Dictionary) -> Dictionary:
	var out: Dictionary = {}
	for key: String in source.keys():
		out[StringName(key)] = StringName(source[key])
	return out


static func _colony_to_dict(colony: Dictionary) -> Dictionary:
	var local_stock: Dictionary = colony.get("local_stock", {})
	return {
		"colony_id": String(colony.get("colony_id", &"")),
		"tier_id": String(colony.get("tier_id", &"")),
		"slot_index": int(colony.get("slot_index", 0)),
		"production_level": int(colony.get("production_level", 0)),
		"cargo_level": int(colony.get("cargo_level", 0)),
		"speed_level": int(colony.get("speed_level", 0)),
		"local_stock": _stringname_float_dict_to_json(local_stock),
	}


static func _colony_from_dict(d: Dictionary) -> Dictionary:
	return {
		"colony_id": StringName(d.get("colony_id", "")),
		"tier_id": StringName(d.get("tier_id", "")),
		"slot_index": int(d.get("slot_index", 0)),
		"production_level": int(d.get("production_level", 0)),
		"cargo_level": int(d.get("cargo_level", 0)),
		"speed_level": int(d.get("speed_level", 0)),
		"local_stock": _json_to_stringname_float_dict(d.get("local_stock", {})),
	}


static func _colony_slot_to_dict(slot: Dictionary) -> Dictionary:
	var cell: Vector2i = slot.get("cell", Vector2i.ZERO)
	return {
		"slot_index": int(slot.get("slot_index", 0)),
		"tier_order": int(slot.get("tier_order", 0)),
		"cell_x": cell.x,
		"cell_y": cell.y,
		"distance_cells": float(slot.get("distance_cells", 0.0)),
		"is_coastal": bool(slot.get("is_coastal", false)),
		"founded": bool(slot.get("founded", false)),
	}


static func _colony_slot_from_dict(d: Dictionary) -> Dictionary:
	return {
		"slot_index": int(d.get("slot_index", 0)),
		"tier_order": int(d.get("tier_order", 0)),
		"cell": Vector2i(int(d.get("cell_x", 0)), int(d.get("cell_y", 0))),
		"distance_cells": float(d.get("distance_cells", 0.0)),
		"is_coastal": bool(d.get("is_coastal", false)),
		"founded": bool(d.get("founded", false)),
	}


const _ROUTE_STATE_NAMES: Array[String] = ["at_origin", "traveling_to_hub", "traveling_to_origin"]


static func _route_to_dict(route: Dictionary) -> Dictionary:
	var state: int = int(route.get("state", 0))
	return {
		"colony_id": String(route.get("colony_id", &"")),
		"state": _ROUTE_STATE_NAMES[state] if state >= 0 and state < _ROUTE_STATE_NAMES.size() else _ROUTE_STATE_NAMES[0],
		"cargo": _stringname_float_dict_to_json(route.get("cargo", {})),
		"leg_elapsed": float(route.get("leg_elapsed", 0.0)),
	}


static func _route_from_dict(d: Dictionary) -> Dictionary:
	var state_name: String = String(d.get("state", "at_origin"))
	var state: int = _ROUTE_STATE_NAMES.find(state_name)
	return {
		"colony_id": StringName(d.get("colony_id", "")),
		"state": state if state >= 0 else 0,
		"cargo": _json_to_stringname_float_dict(d.get("cargo", {})),
		"leg_elapsed": float(d.get("leg_elapsed", 0.0)),
	}


static func _workshop_to_dict(workshop: Dictionary) -> Dictionary:
	return {
		"recipe_id": String(workshop.get("recipe_id", &"")),
		"auto_craft": bool(workshop.get("auto_craft", false)),
		"cycle_accumulated": float(workshop.get("cycle_accumulated", 0.0)),
	}


static func _workshop_from_dict(d: Dictionary) -> Dictionary:
	return {
		"recipe_id": StringName(d.get("recipe_id", "")),
		"auto_craft": bool(d.get("auto_craft", false)),
		"cycle_accumulated": float(d.get("cycle_accumulated", 0.0)),
	}
