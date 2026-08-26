## The permanent layer that survives prestige (task G2 - see docs/GODOT_PLAN.md
## Phase 6, Option B). Plain RefCounted data, same reasoning as RunState: this is
## save state, not authored content, not a live subsystem.
##
## `lifetime_gold_earned` accumulates from day one even though nothing reads it
## yet - the eventual Doubloon payout formula (task PrestigeManager-equivalent,
## post-MVP) needs history to work from, and that's cheap to start capturing now
## versus reconstructing later. This is Phase 10 rule 5's third-ish exception in
## spirit, though the actual field is small enough not to be worth its own bullet
## there.
class_name MetaState
extends RefCounted

var doubloons: int = 0
var meta_upgrades: Array[StringName] = []
var lifetime_gold_earned: float = 0.0
var runs_completed: int = 0


func to_dict() -> Dictionary:
	return {
		"doubloons": doubloons,
		"meta_upgrades": meta_upgrades.map(func(id: StringName) -> String: return String(id)),
		"lifetime_gold_earned": lifetime_gold_earned,
		"runs_completed": runs_completed,
	}


static func from_dict(d: Dictionary) -> MetaState:
	var s := MetaState.new()
	# JSON has no integer type - cast explicitly (see RunState.from_dict for the
	# same gotcha, first handled in task G1).
	s.doubloons = int(d.get("doubloons", 0))

	var upgrades: Array[StringName] = []
	for entry: Variant in (d.get("meta_upgrades", []) as Array):
		upgrades.append(StringName(entry as String))
	s.meta_upgrades = upgrades

	s.lifetime_gold_earned = float(d.get("lifetime_gold_earned", 0.0))
	s.runs_completed = int(d.get("runs_completed", 0))
	return s
