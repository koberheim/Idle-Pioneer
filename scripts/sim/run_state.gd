## Everything that is wiped when the player declares independence.
## Declaring independence replaces the whole object; nothing is reset field by field.
class_name RunState
extends RefCounted


class ColonyState:
	var id: String
	## Settlement order: 0 is the capital. Drives the colony's scale.
	var tier: int = 0
	## Index into the run's WorldMap.sites.
	var site: int = 0
	var colonists: int = 0
	var prod_level: int = 0
	var cargo_level: int = 0
	var speed_level: int = 0
	## Charter rank, bought with crafted goods.
	var charter: int = 0
	var stock: float = 0.0
	var cargo: float = 0.0
	## Round-trip progress, 0..1. 0 means waiting at the colony; the outbound
	## leg ends (and cargo is delivered) at 0.5.
	var trip: float = 0.0

	func to_dict() -> Dictionary:
		return {
			"id": id, "tier": tier, "site": site, "colonists": colonists,
			"prod_level": prod_level, "cargo_level": cargo_level, "speed_level": speed_level,
			"charter": charter, "stock": stock, "cargo": cargo, "trip": trip,
		}

	static func from_dict(d: Dictionary) -> ColonyState:
		var c := ColonyState.new()
		c.id = str(d.get("id", ""))
		c.tier = int(d.get("tier", 0))
		c.site = int(d.get("site", 0))
		c.colonists = int(d.get("colonists", 0))
		c.prod_level = int(d.get("prod_level", 0))
		c.cargo_level = int(d.get("cargo_level", 0))
		c.speed_level = int(d.get("speed_level", 0))
		c.charter = int(d.get("charter", 0))
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
var map_style: String = WorldMap.STYLE_RANDOM
var map_seed: int = 0
## Rebuilt from map_style/map_seed, never saved.
var world: WorldMap
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
## colony id -> governor id (from MetaState.governors) posted there this run.
var governors: Dictionary = {}
## Simulated seconds of Royal Favor (doubled production) remaining.
var favor_seconds: float = 0.0

var _explored: PackedByteArray
var _explored_key: String = ""


static func create(p_nation_id: String, p_style: String, p_seed: int) -> RunState:
	var r := RunState.new()
	r.nation_id = p_nation_id
	r.map_style = p_style
	r.map_seed = p_seed
	r.started_unix = Time.get_unix_time_from_system()
	r.world = WorldMap.build(p_style, p_seed)
	r._add_colony()
	for def: Dictionary in Content.recipes:
		var w := WorkshopState.new()
		w.id = def["id"]
		r.workshops[w.id] = w
	return r


func _add_colony() -> ColonyState:
	var c := ColonyState.new()
	c.tier = colonies.size()
	c.id = "c%d" % c.tier
	c.site = world.colony_order[c.tier]
	colonies.append(c)
	return c


## The site the next colony will be founded on, or -1 once the map is full.
func next_site() -> int:
	if colonies.size() >= world.colony_order.size():
		return -1
	return world.colony_order[colonies.size()]


func found_next() -> ColonyState:
	if next_site() < 0:
		return null
	return _add_colony()


func colony(id: String) -> ColonyState:
	for c: ColonyState in colonies:
		if c.id == id:
			return c
	return null


func capital() -> ColonyState:
	return colonies[0]


func site_of(c: ColonyState) -> Dictionary:
	return world.sites[c.site]


func resource_of(c: ColonyState) -> String:
	return str(world.sites[c.site]["resource"])


func workshop(id: String) -> WorkshopState:
	return workshops.get(id) as WorkshopState


func stock_of(resource_id: String) -> float:
	return float(warehouse.get(resource_id, 0.0))


func is_held(resource_id: String) -> bool:
	return bool(hold.get(resource_id, false))


func has_father(id: String) -> bool:
	return fathers.has(id)


func governor_at(colony_id: String) -> int:
	return int(governors.get(colony_id, -1))


func colony_of_governor(governor_id: int) -> String:
	for k: String in governors.keys():
		if int(governors[k]) == governor_id:
			return k
	return ""


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
	return colonies.size()


## Fog of war: 1 where the map has been scouted. Recomputed only when the
## set of colonies or the scouting bonus changes.
func explored(radius_mult: float) -> PackedByteArray:
	var key: String = "%d:%.2f" % [colonies.size(), radius_mult]
	if key == _explored_key:
		return _explored
	_explored_key = key
	_explored = PackedByteArray()
	_explored.resize(WorldMap.W * WorldMap.H)
	for c: ColonyState in colonies:
		var s: Dictionary = site_of(c)
		var r: float = (Balance.v("explore_radius_capital") if c.tier == 0 else Balance.v("explore_radius_colony")) * radius_mult
		_reveal(Vector2(int(s["x"]), int(s["y"])), r)
		# The route itself is scouted too.
		for p: Vector2 in world.route(c.site)["points"]:
			_reveal(p, 2.5)
	var n: int = next_site()
	if n >= 0:
		_reveal(Vector2(int(world.sites[n]["x"]), int(world.sites[n]["y"])), 3.0)
	return _explored


func _reveal(center: Vector2, r: float) -> void:
	for y in range(maxi(0, int(center.y - r)), mini(WorldMap.H, int(center.y + r) + 1)):
		for x in range(maxi(0, int(center.x - r)), mini(WorldMap.W, int(center.x + r) + 1)):
			if Vector2(x - center.x, (y - center.y)).length() <= r:
				_explored[y * WorldMap.W + x] = 1


func to_dict() -> Dictionary:
	var cols: Array = []
	for c: ColonyState in colonies:
		cols.append(c.to_dict())
	var ws: Dictionary = {}
	for id: String in workshops.keys():
		ws[id] = (workshops[id] as WorkshopState).to_dict()
	return {
		"nation_id": nation_id, "map_style": map_style, "map_seed": map_seed,
		"started_unix": started_unix, "play_seconds": play_seconds,
		"gold": gold, "lifetime_gold": lifetime_gold, "colonists_owned": colonists_owned,
		"colonies": cols, "workshops": ws, "warehouse": warehouse.duplicate(),
		"hold": hold.duplicate(), "discovered": discovered.duplicate(), "fathers": fathers.duplicate(),
		"crafted": crafted.duplicate(), "shipments": shipments, "governors": governors.duplicate(),
		"favor_seconds": favor_seconds,
	}


## Tolerant of partial saves; content added since the save was written is
## filled in rather than dropped. Returns null for saves from before random
## maps existed, which can't be converted.
static func from_dict(d: Dictionary) -> RunState:
	if not d.has("map_seed"):
		return null
	var r := RunState.new()
	r.nation_id = str(d.get("nation_id", "english"))
	r.map_style = str(d.get("map_style", WorldMap.STYLE_RANDOM))
	r.map_seed = int(d.get("map_seed", 0))
	r.world = WorldMap.build(r.map_style, r.map_seed)
	r.started_unix = float(d.get("started_unix", Time.get_unix_time_from_system()))
	r.play_seconds = float(d.get("play_seconds", 0.0))
	r.gold = float(d.get("gold", 0.0))
	r.lifetime_gold = float(d.get("lifetime_gold", 0.0))
	r.colonists_owned = int(d.get("colonists_owned", 0))
	for cd: Variant in d.get("colonies", []):
		var c := ColonyState.from_dict(cd as Dictionary)
		if c.site >= 0 and c.site < r.world.sites.size():
			r.colonies.append(c)
	if r.colonies.is_empty():
		r._add_colony()
	for def: Dictionary in Content.recipes:
		var w := WorkshopState.new()
		w.id = def["id"]
		r.workshops[w.id] = w
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
	r.favor_seconds = float(d.get("favor_seconds", 0.0))
	for k: String in (d.get("governors", {}) as Dictionary).keys():
		r.governors[k] = int(d["governors"][k])
	if r.colonists_assigned() > r.colonists_owned:
		r.colonists_owned = r.colonists_assigned()
	return r
