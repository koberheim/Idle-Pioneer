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
var tips_on: bool = true
## Permanent roster of governors, kept across runs: {id, name, type, rank}.
var governors: Array[Dictionary] = []
var next_governor_id: int = 1
## Real-world time the Royal Favor can next be requested.
var favor_ready_unix: float = 0.0
## Relics found, by id. Permanent.
var relics: Array[String] = []
## Almanac pages: each skips ahead an hour of production.
var almanacs: int = 0
## Most colonies ever founded in one run (relic and almanac rewards).
var best_colonies: int = 1
## Colony-record rewards already paid, kept apart from the record itself so
## records set before relics unlock still pay out once they do.
var record_relics_claimed: Array[int] = []
var record_almanac_claimed: int = 0
## Counters for the Ledger: stat id -> float. See Game.stat().
var stats: Dictionary = {}
## The latest wall-clock time this save has seen. Offline time is only
## granted beyond it, so winding the device clock back and forth pays nothing.
var max_seen_unix: float = 0.0
## Lighter map rendering for low-end phones.
var lite_map: bool = false
## Interface size: text and buttons scaled up for readability.
var large_ui: bool = false
## Real-world time "Consult the Almanac" (the rewarded skip) is next ready.
var ad_skip_ready_unix: float = 0.0
## When the last between-expeditions ad was shown.
var last_interstitial_unix: float = 0.0


func governor(governor_id: int) -> Dictionary:
	for g: Dictionary in governors:
		if int(g["id"]) == governor_id:
			return g
	return {}


func has_relic(id: String) -> bool:
	return relics.has(id)


func set_complete(set_id: String) -> bool:
	for r: Dictionary in Content.relics_in_set(set_id):
		if not relics.has(str(r["id"])):
			return false
	return true


func stat(id: String) -> float:
	return float(stats.get(id, 0.0))


func add_stat(id: String, amount: float = 1.0) -> void:
	stats[id] = float(stats.get(id, 0.0)) + amount


func level(upgrade_id: String) -> int:
	return int(upgrades.get(upgrade_id, 0))


func to_dict() -> Dictionary:
	return {
		"liberty": liberty, "lifetime_liberty": lifetime_liberty, "upgrades": upgrades.duplicate(),
		"runs_completed": runs_completed, "best_run_gold": best_run_gold,
		"fastest_run_seconds": fastest_run_seconds, "music_on": music_on, "sfx_on": sfx_on,
		"hints_seen": hints_seen.duplicate(), "tips_on": tips_on, "governors": governors.duplicate(true),
		"next_governor_id": next_governor_id, "favor_ready_unix": favor_ready_unix,
		"relics": relics.duplicate(), "almanacs": almanacs, "best_colonies": best_colonies,
		"record_relics_claimed": record_relics_claimed.duplicate(), "record_almanac_claimed": record_almanac_claimed,
		"stats": stats.duplicate(), "max_seen_unix": max_seen_unix, "lite_map": lite_map, "large_ui": large_ui, "ad_skip_ready_unix": ad_skip_ready_unix, "last_interstitial_unix": last_interstitial_unix,
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
	m.tips_on = bool(d.get("tips_on", true))
	for v: Variant in d.get("hints_seen", []):
		m.hints_seen.append(str(v))
	for v: Variant in d.get("governors", []):
		var g: Dictionary = v
		m.governors.append({"id": int(g.get("id", 0)), "name": str(g.get("name", "")),
			"type": str(g.get("type", "prod")), "rank": int(g.get("rank", 1))})
	m.favor_ready_unix = float(d.get("favor_ready_unix", 0.0))
	m.next_governor_id = int(d.get("next_governor_id", m.governors.size() + 1))
	# Relics renamed since a save was written keep their place in the collection.
	const RENAMED := {"scrimshaw": "bill_of_lading"}
	for v: Variant in d.get("relics", []):
		var rid: String = str(RENAMED.get(str(v), str(v)))
		if not Content.relic(rid).is_empty() and not m.relics.has(rid):
			m.relics.append(rid)
	m.almanacs = int(d.get("almanacs", 0))
	m.best_colonies = int(d.get("best_colonies", 1))
	for v: Variant in d.get("record_relics_claimed", []):
		m.record_relics_claimed.append(int(v))
	m.record_almanac_claimed = int(d.get("record_almanac_claimed", 0))
	m.max_seen_unix = float(d.get("max_seen_unix", 0.0))
	m.lite_map = bool(d.get("lite_map", false))
	m.large_ui = bool(d.get("large_ui", false))
	m.ad_skip_ready_unix = float(d.get("ad_skip_ready_unix", 0.0))
	m.last_interstitial_unix = float(d.get("last_interstitial_unix", 0.0))
	for k: String in (d.get("stats", {}) as Dictionary).keys():
		m.stats[k] = float(d["stats"][k])
	return m
