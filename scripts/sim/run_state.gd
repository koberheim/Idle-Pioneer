## Everything that is wiped when the player declares independence.
## Declaring independence replaces the whole object; nothing is reset field by field.
class_name RunState
extends RefCounted


class ColonyState:
	var id: String
	var founded: bool = false
	## Index into Content.colony_sites(id); decides the map position and whether
	## goods travel by land or by sea. Rolled once per run.
	var site: int = 0
	var colonists: int = 0
	var prod_level: int = 0
	var cargo_level: int = 0
	var speed_level: int = 0
	var stock: float = 0.0
	var cargo: float = 0.0
	## Round-trip progress, 0..1. 0 means waiting at the colony; the outbound
	## leg ends (and cargo is delivered) at 0.5.
	var trip: float = 0.0

	func to_dict() -> Dictionary:
		return {
			"id": id, "founded": founded, "site": site, "colonists": colonists,
			"prod_level": prod_level, "cargo_level": cargo_level, "speed_level": speed_level,
			"stock": stock, "cargo": cargo, "trip": trip,
		}

	static func from_dict(d: Dictionary) -> ColonyState:
		var c := ColonyState.new()
		c.id = str(d.get("id", ""))
		c.founded = bool(d.get("founded", false))
		c.site = int(d.get("site", 0))
		c.colonists = int(d.get("colonists", 0))
		c.prod_level = int(d.get("prod_level", 0))
		c.cargo_level = int(d.get("cargo_level", 0))
		c.speed_level = int(d.get("speed_level", 0))
		c.stock = float(d.get("stock", 0.0))
		c.cargo = float(d.get("cargo", 0.0))
		c.trip = clampf(float(d.get("trip", 0.0)), 0.0, 0.999999)
		return c


class WorkshopState:
	var id: String
	var built: bool = false
	var colonists: int = 0
	var level: int = 0
	## Seconds of work put into the item currently on the bench.
	var progress: float = 0.0

	func to_dict() -> Dictionary:
		return {"id": id, "built": built, "colonists": colonists, "level": level, "progress": progress}

	static func from_dict(d: Dictionary) -> WorkshopState:
		var w := WorkshopState.new()
		w.id = str(d.get("id", ""))
		w.built = bool(d.get("built", false))
		w.colonists = int(d.get("colonists", 0))
		w.level = int(d.get("level", 0))
		w.progress = float(d.get("progress", 0.0))
		return w


var nation_id: String = ""
var started_unix: float = 0.0
## Simulated seconds this run, including offline catch-up.
var play_seconds: float = 0.0
var gold: float = 0.0
var lifetime_gold: float = 0.0
var colonists_owned: int = 0
var colonies: Array[ColonyState] = []
var workshops: Dictionary = {}  # recipe id -> WorkshopState
var warehouse: Dictionary = {}  # resource id -> float
var hold: Dictionary = {}  # resource id -> true when reserved instead of sold
var discovered: Array[String] = []
var fathers: Array[String] = []
var crafted: Dictionary = {}  # resource id -> int, crafted this run
var shipments: int = 0


static func create(p_nation_id: String, rng: RandomNumberGenerator) -> RunState:
	var r := RunState.new()
	r.nation_id = p_nation_id
	r.started_unix = Time.get_unix_time_from_system()
	for def: Dictionary in Content.colonies:
		var c := ColonyState.new()
		c.id = def["id"]
		var sites: Array = Content.colony_sites(c.id)
		c.site = rng.randi_range(0, maxi(sites.size() - 1, 0))
		r.colonies.append(c)
	r.colonies[0].founded = true
	for def: Dictionary in Content.recipes:
		var w := WorkshopState.new()
		w.id = def["id"]
		r.workshops[w.id] = w
	return r


func colony(id: String) -> ColonyState:
	for c: ColonyState in colonies:
		if c.id == id:
			return c
	return null


func workshop(id: String) -> WorkshopState:
	return workshops.get(id) as WorkshopState


func stock_of(resource_id: String) -> float:
	return float(warehouse.get(resource_id, 0.0))


func is_held(resource_id: String) -> bool:
	return bool(hold.get(resource_id, false))


func has_father(id: String) -> bool:
	return fathers.has(id)


func colonists_assigned() -> int:
	var n: int = 0
	for c: ColonyState in colonies:
		n += c.colonists
	for w: WorkshopState in workshops.values():
		n += w.colonists
	return n


func colonists_idle() -> int:
	return colonists_owned - colonists_assigned()


func founded_count() -> int:
	var n: int = 0
	for c: ColonyState in colonies:
		if c.founded:
			n += 1
	return n


## The next colony in founding order, or null once all are founded.
func next_unfounded() -> ColonyState:
	for c: ColonyState in colonies:
		if not c.founded:
			return c
	return null


func to_dict() -> Dictionary:
	var cols: Array = []
	for c: ColonyState in colonies:
		cols.append(c.to_dict())
	var ws: Dictionary = {}
	for id: String in workshops.keys():
		ws[id] = (workshops[id] as WorkshopState).to_dict()
	return {
		"nation_id": nation_id, "started_unix": started_unix, "play_seconds": play_seconds,
		"gold": gold, "lifetime_gold": lifetime_gold, "colonists_owned": colonists_owned,
		"colonies": cols, "workshops": ws, "warehouse": warehouse.duplicate(),
		"hold": hold.duplicate(), "discovered": discovered.duplicate(), "fathers": fathers.duplicate(),
		"crafted": crafted.duplicate(), "shipments": shipments,
	}


## Tolerant of old or partial saves: anything missing falls back to the
## defaults of a fresh run, and content added since the save was written
## (new colonies, recipes) is filled in rather than dropped.
static func from_dict(d: Dictionary) -> RunState:
	var rng := RandomNumberGenerator.new()
	var r := RunState.create(str(d.get("nation_id", "english")), rng)
	r.started_unix = float(d.get("started_unix", r.started_unix))
	r.play_seconds = float(d.get("play_seconds", 0.0))
	r.gold = float(d.get("gold", 0.0))
	r.lifetime_gold = float(d.get("lifetime_gold", 0.0))
	r.colonists_owned = int(d.get("colonists_owned", 0))
	for cd: Variant in d.get("colonies", []):
		var loaded := ColonyState.from_dict(cd as Dictionary)
		for i in r.colonies.size():
			if r.colonies[i].id == loaded.id:
				r.colonies[i] = loaded
	r.colonies[0].founded = true
	var ws: Dictionary = d.get("workshops", {})
	for id: String in ws.keys():
		if r.workshops.has(id):
			r.workshops[id] = WorkshopState.from_dict(ws[id] as Dictionary)
	for k: String in (d.get("warehouse", {}) as Dictionary).keys():
		r.warehouse[k] = float(d["warehouse"][k])
	for k: String in (d.get("hold", {}) as Dictionary).keys():
		r.hold[k] = bool(d["hold"][k])
	for v: Variant in d.get("discovered", []):
		r.discovered.append(str(v))
	for v: Variant in d.get("fathers", []):
		r.fathers.append(str(v))
	for k: String in (d.get("crafted", {}) as Dictionary).keys():
		r.crafted[k] = int(d["crafted"][k])
	r.shipments = int(d.get("shipments", 0))
	# Colonists assigned beyond what's owned would make idle go negative.
	if r.colonists_assigned() > r.colonists_owned:
		r.colonists_owned = r.colonists_assigned()
	return r
