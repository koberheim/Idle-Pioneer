## The land/water data layer (task M1 - see docs/GODOT_PLAN.md Phase 5).
##
## Pure data, no rendering, no Node. This is deliberate: it proves the land/water
## layer can be built and tested with zero visuals before any map art exists (Phase 5.4).
## The only consumer that touches pixels is a later MapView (task M4) - simulation code
## (PlacementRules, task M3) and tests both read this class directly.
##
## Mirrors Unity's `TileType` enum (DeepSea, ShallowSea, Land, Coast) - see
## docs/GODOT_MIGRATION_ANALYSIS.md §5 for why that four-way vocabulary, and
## specifically Coast as distinct from Land, is worth keeping: it's what lets a
## colony be ship-servable.
class_name MapGrid
extends RefCounted

enum Terrain {
	DEEP_WATER = 0,
	SHALLOW_WATER = 1,
	LAND = 2,
	COAST = 3,
}

const TERRAIN_GLYPH: Dictionary = {
	Terrain.DEEP_WATER: ".",
	Terrain.SHALLOW_WATER: "~",
	Terrain.LAND: "#",
	Terrain.COAST: "+",
}

var width: int = 0
var height: int = 0

## 0 for a hand-authored map (task M2); nonzero identifies a procedurally
## generated one (task M/8+, post-MVP).
var seed_value: int = 0

## One Terrain byte per cell, row-major: index = y * width + x.
var terrain: PackedByteArray = PackedByteArray()

## Parallel layer: index into `deposit_palette` per cell. 0 always means "no
## deposit" - deposit_palette[0] is reserved as the empty string for that reason.
var deposits: PackedByteArray = PackedByteArray()
var deposit_palette: Array[StringName] = [&""]


static func create(grid_width: int, grid_height: int, seed_value: int = 0) -> MapGrid:
	var grid := MapGrid.new()
	grid.width = grid_width
	grid.height = grid_height
	grid.seed_value = seed_value

	var cell_count: int = grid_width * grid_height
	grid.terrain = PackedByteArray()
	grid.terrain.resize(cell_count)
	grid.terrain.fill(Terrain.DEEP_WATER)

	grid.deposits = PackedByteArray()
	grid.deposits.resize(cell_count)
	grid.deposits.fill(0)

	return grid


func in_bounds(c: Vector2i) -> bool:
	return c.x >= 0 and c.x < width and c.y >= 0 and c.y < height


## Out-of-bounds reads return DEEP_WATER rather than crashing - a caller doing
## edge-of-map neighbour checks (see neighbours4) should never need to bounds-check
## first. This matches Unity's MapManager.GetTileTypeAt behaviour, which was correct.
func get_terrain(c: Vector2i) -> Terrain:
	if not in_bounds(c):
		return Terrain.DEEP_WATER
	return terrain[c.y * width + c.x] as Terrain


func set_terrain(c: Vector2i, t: Terrain) -> void:
	if not in_bounds(c):
		push_error("MapGrid.set_terrain: %s is out of bounds (%dx%d)" % [c, width, height])
		return
	terrain[c.y * width + c.x] = t


func is_land(c: Vector2i) -> bool:
	var t: Terrain = get_terrain(c)
	return t == Terrain.LAND or t == Terrain.COAST


func is_water(c: Vector2i) -> bool:
	var t: Terrain = get_terrain(c)
	return t == Terrain.DEEP_WATER or t == Terrain.SHALLOW_WATER


func is_coast(c: Vector2i) -> bool:
	return get_terrain(c) == Terrain.COAST


func neighbours4(c: Vector2i) -> Array[Vector2i]:
	var out: Array[Vector2i] = []
	for offset: Vector2i in [Vector2i.UP, Vector2i.DOWN, Vector2i.LEFT, Vector2i.RIGHT]:
		var n: Vector2i = c + offset
		if in_bounds(n):
			out.append(n)
	return out


## Registers `deposit_id` in the palette if it isn't already present and returns
## its palette index. Never returns 0 - that index is reserved for "no deposit".
func _deposit_index_for(deposit_id: StringName) -> int:
	if deposit_id == &"":
		return 0
	var existing: int = deposit_palette.find(deposit_id)
	if existing != -1:
		return existing
	deposit_palette.append(deposit_id)
	return deposit_palette.size() - 1


func set_deposit(c: Vector2i, deposit_id: StringName) -> void:
	if not in_bounds(c):
		push_error("MapGrid.set_deposit: %s is out of bounds (%dx%d)" % [c, width, height])
		return
	deposits[c.y * width + c.x] = _deposit_index_for(deposit_id)


func deposit_at(c: Vector2i) -> StringName:
	if not in_bounds(c):
		return &""
	var index: int = deposits[c.y * width + c.x]
	if index < 0 or index >= deposit_palette.size():
		return &""
	return deposit_palette[index]


## Terrain-only glyph grid for eyeballing in a test failure or a print statement.
## A cell with a deposit shows its deposit id's first letter, uppercased, instead
## of the plain terrain glyph, so both layers are visible at once.
func to_ascii() -> String:
	var lines: Array[String] = []
	for y: int in range(height):
		var row: String = ""
		for x: int in range(width):
			var c := Vector2i(x, y)
			var dep: StringName = deposit_at(c)
			if dep != &"":
				row += String(dep).left(1).to_upper()
			else:
				row += TERRAIN_GLYPH[get_terrain(c)] as String
		lines.append(row)
	return "\n".join(lines)


func to_dict() -> Dictionary:
	return {
		"width": width,
		"height": height,
		"seed_value": seed_value,
		"terrain": Marshalls.raw_to_base64(terrain),
		"deposits": Marshalls.raw_to_base64(deposits),
		"deposit_palette": deposit_palette.map(func(id: StringName) -> String: return String(id)),
	}


static func from_dict(d: Dictionary) -> MapGrid:
	var grid := MapGrid.new()
	grid.width = d["width"]
	grid.height = d["height"]
	grid.seed_value = d["seed_value"]
	grid.terrain = Marshalls.base64_to_raw(d["terrain"])
	grid.deposits = Marshalls.base64_to_raw(d["deposits"])

	var palette: Array[StringName] = []
	for entry: String in (d["deposit_palette"] as Array):
		palette.append(StringName(entry))
	grid.deposit_palette = palette

	return grid
