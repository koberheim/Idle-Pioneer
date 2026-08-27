## The permanent layer that survives prestige (task G2 - see docs/GODOT_PLAN.md
## Phase 6, Option B). Plain RefCounted data, same reasoning as RunState: this is
## save state, not authored content, not a live subsystem.
##
## `liberty`/`lifetime_liberty_earned`/`upgrades` are the real prestige currency
## and permanent upgrade tree from docs/GAME_DESIGN.md §8/§9 - Prestige (Game
## child, scripts/sim/prestige.gd) owns the behaviour; this is just where it's
## persisted. Replaces an earlier placeholder ("doubloons" / a flat
## meta_upgrades id list) that nothing had wired up yet - see docs/GODOT_PLAN.md's
## design realignment section.
class_name MetaState
extends RefCounted

var liberty: int = 0
var lifetime_liberty_earned: int = 0

## StringName (branch id - Prestige.BRANCH_*) -> int (level bought, permanent).
## Missing key means level 0, same convention as Colonists' _assignments.
var upgrades: Dictionary = {}

var lifetime_gold_earned: float = 0.0
var runs_completed: int = 0

## Sound settings (direct request: framework only for now, no audio assets
## exist yet - see Audio's class doc). A device-level preference, not a
## run-scoped one, so it lives here rather than on RunState - muting sound
## should survive a prestige reset the same way it survives reloading a
## save.
var music_enabled: bool = true
var sfx_enabled: bool = true

## Every recipe id ever successfully crafted at least once, across every run
## (docs/GAME_DESIGN.md §9). There's no recipe-unlock-gating mechanic built
## yet (§7's "unlock alongside their source colony" isn't implemented) -
## "unlocked" is read pragmatically as "the player has made this at least
## once," recorded by Crafting.craft_recipe() on a successful craft.
var recipes_ever_unlocked: Array[StringName] = []

## Best/fastest across every run so far (docs/GAME_DESIGN.md §9). Updated by
## Prestige.declare_independence() using this run's lifetime earnings and the
## real wall-clock time since RunState.started_at_unix - there's no simulated
## elapsed-time clock running yet (see docs/GODOT_PLAN.md's design
## realignment section), so wall-clock is the only elapsed-time signal that
## actually exists right now.
var stats: Dictionary = {
	"best_run_gold": 0.0,
	"fastest_run_seconds": 0,
}


func to_dict() -> Dictionary:
	return {
		"liberty": liberty,
		"lifetime_liberty_earned": lifetime_liberty_earned,
		"upgrades": _stringname_int_dict_to_json(upgrades),
		"lifetime_gold_earned": lifetime_gold_earned,
		"runs_completed": runs_completed,
		"music_enabled": music_enabled,
		"sfx_enabled": sfx_enabled,
		"recipes_ever_unlocked": recipes_ever_unlocked.map(func(id: StringName) -> String: return String(id)),
		"stats": {
			"best_run_gold": float(stats.get("best_run_gold", 0.0)),
			"fastest_run_seconds": int(stats.get("fastest_run_seconds", 0)),
		},
	}


static func from_dict(d: Dictionary) -> MetaState:
	var s := MetaState.new()
	# JSON has no integer type - cast explicitly (see RunState.from_dict for the
	# same gotcha, first handled in task G1).
	s.liberty = int(d.get("liberty", 0))
	s.lifetime_liberty_earned = int(d.get("lifetime_liberty_earned", 0))
	s.upgrades = _json_to_stringname_int_dict(d.get("upgrades", {}))
	s.lifetime_gold_earned = float(d.get("lifetime_gold_earned", 0.0))
	s.runs_completed = int(d.get("runs_completed", 0))
	s.music_enabled = bool(d.get("music_enabled", true))
	s.sfx_enabled = bool(d.get("sfx_enabled", true))

	var recipes: Array[StringName] = []
	for entry: Variant in (d.get("recipes_ever_unlocked", []) as Array):
		recipes.append(StringName(entry as String))
	s.recipes_ever_unlocked = recipes

	var stats_data: Dictionary = d.get("stats", {})
	s.stats = {
		"best_run_gold": float(stats_data.get("best_run_gold", 0.0)),
		"fastest_run_seconds": int(stats_data.get("fastest_run_seconds", 0)),
	}

	return s


static func _stringname_int_dict_to_json(source: Dictionary) -> Dictionary:
	var out: Dictionary = {}
	for key: StringName in source.keys():
		out[String(key)] = int(source[key])
	return out


static func _json_to_stringname_int_dict(source: Dictionary) -> Dictionary:
	var out: Dictionary = {}
	for key: String in source.keys():
		out[StringName(key)] = int(source[key])
	return out
