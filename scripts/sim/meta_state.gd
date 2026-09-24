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
## Permanent roster (Idle Planet Miner's managers): {id, name, type, rank}.
var governors: Array[Dictionary] = []
var next_governor_id: int = 1
## Real-world time the Royal Favor can next be requested.
var favor_ready_unix: float = 0.0


func governor(governor_id: int) -> Dictionary:
	for g: Dictionary in governors:
		if int(g["id"]) == governor_id:
			return g
	return {}


func level(upgrade_id: String) -> int:
	return int(upgrades.get(upgrade_id, 0))


func to_dict() -> Dictionary:
	return {
		"liberty": liberty, "lifetime_liberty": lifetime_liberty, "upgrades": upgrades.duplicate(),
		"runs_completed": runs_completed, "best_run_gold": best_run_gold,
		"fastest_run_seconds": fastest_run_seconds, "music_on": music_on, "sfx_on": sfx_on,
		"hints_seen": hints_seen.duplicate(), "governors": governors.duplicate(true),
		"next_governor_id": next_governor_id, "favor_ready_unix": favor_ready_unix,
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
	for v: Variant in d.get("governors", []):
		var g: Dictionary = v
		m.governors.append({"id": int(g.get("id", 0)), "name": str(g.get("name", "")),
			"type": str(g.get("type", "prod")), "rank": int(g.get("rank", 1))})
	m.favor_ready_unix = float(d.get("favor_ready_unix", 0.0))
	m.next_governor_id = int(d.get("next_governor_id", m.governors.size() + 1))
	return m
