## Everything that survives declaring independence.
class_name MetaState
extends RefCounted

var liberty: int = 0
var lifetime_liberty: int = 0
var upgrades: Dictionary = {}  # liberty upgrade id -> level
var runs_completed: int = 0
var best_run_gold: float = 0.0
var fastest_run_seconds: float = 0.0
var music_on: bool = true
var sfx_on: bool = true
var hints_seen: Array[String] = []


func level(upgrade_id: String) -> int:
	return int(upgrades.get(upgrade_id, 0))


func to_dict() -> Dictionary:
	return {
		"liberty": liberty, "lifetime_liberty": lifetime_liberty, "upgrades": upgrades.duplicate(),
		"runs_completed": runs_completed, "best_run_gold": best_run_gold,
		"fastest_run_seconds": fastest_run_seconds, "music_on": music_on, "sfx_on": sfx_on,
		"hints_seen": hints_seen.duplicate(),
	}


static func from_dict(d: Dictionary) -> MetaState:
	var m := MetaState.new()
	m.liberty = int(d.get("liberty", 0))
	m.lifetime_liberty = int(d.get("lifetime_liberty", 0))
	for k: String in (d.get("upgrades", {}) as Dictionary).keys():
		m.upgrades[k] = int(d["upgrades"][k])
	m.runs_completed = int(d.get("runs_completed", 0))
	m.best_run_gold = float(d.get("best_run_gold", 0.0))
	m.fastest_run_seconds = float(d.get("fastest_run_seconds", 0.0))
	m.music_on = bool(d.get("music_on", true))
	m.sfx_on = bool(d.get("sfx_on", true))
	for v: Variant in d.get("hints_seen", []):
		m.hints_seen.append(str(v))
	return m
