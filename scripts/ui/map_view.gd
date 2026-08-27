## Renders this run's generated terrain grid (MapGrid, built once per run by
## MapGenerator at Game.new_run() - previously only ever consumed by colony-
## slot placement, never drawn) and a marker for every colony slot. Direct
## request, after the list-based v1 interface shipped without one: this is
## the full-screen background layer behind the sliding tab sheet (see
## MainScreen), replacing the old static harbor image.
##
## Plain _draw()-based rendering rather than one node per cell - the grid is
## up to 60x60 (Balance.map_width/height), and a Sprite2D/ColorRect per cell
## would be 3600+ nodes for something that never animates per-cell. Colony
## markers are drawn the same way for the same reason.
class_name MapView
extends Control

signal slot_selected(slot_index: int)

const MARKER_RADIUS: float = 5.0
## How far (in pixels) a tap can land from a marker's center and still hit
## it - wider than the drawn radius since a fingertip is not a mouse cursor.
const MARKER_HIT_RADIUS: float = 16.0

const TERRAIN_COLORS: Dictionary = {
	MapGrid.Terrain.DEEP_WATER: Color(0.11, 0.22, 0.38),
	MapGrid.Terrain.SHALLOW_WATER: Color(0.22, 0.42, 0.58),
	MapGrid.Terrain.LAND: Color(0.36, 0.5, 0.24),
	MapGrid.Terrain.COAST: Color(0.62, 0.56, 0.36),
}
const CAPITAL_COLOR := Color(0.95, 0.85, 0.25)
const FOUNDED_COLOR := Color(0.3, 0.78, 0.35)
const NEXT_COLOR := Color(0.35, 0.65, 0.95)
const MARKER_OUTLINE := Color(0.05, 0.05, 0.05, 0.8)

var _grid: MapGrid
## Identity check, not a value comparison - only rebuild the parsed grid
## when Game.run itself has been swapped out (a fresh run or a prestige
## reset), not on every 0.25s MainScreen refresh.
var _grid_built_for_run: RunState


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	resized.connect(queue_redraw)


func refresh() -> void:
	if Game.run == null:
		_grid = null
		_grid_built_for_run = null
		queue_redraw()
		return
	if _grid_built_for_run != Game.run:
		_grid = MapGrid.from_dict(Game.run.map)
		_grid_built_for_run = Game.run
	queue_redraw()


func _draw() -> void:
	if _grid == null or _grid.width <= 0:
		return

	var cell_size: Vector2 = _cell_size()
	if cell_size.x <= 0.0 or cell_size.y <= 0.0:
		return

	for y: int in range(_grid.height):
		for x: int in range(_grid.width):
			var terrain: MapGrid.Terrain = _grid.get_terrain(Vector2i(x, y))
			var color: Color = TERRAIN_COLORS.get(terrain, Color.BLACK)
			var pos: Vector2 = Vector2(x, y) * cell_size
			draw_rect(Rect2(pos, cell_size), color)

	var next_slot_index: int = _next_to_found_slot_index()
	for slot: Dictionary in Game.run.colony_slots:
		var slot_index: int = int(slot["slot_index"])
		# Direct request: an unsettled colony stays hidden entirely (not a
		# gray "locked" dot) until it's actually the next one foundable -
		# same rule ColoniesPanel's row list follows.
		if not (bool(slot["founded"]) or slot_index == next_slot_index):
			continue
		var center: Vector2 = _slot_center(slot, cell_size)
		var color: Color = _marker_color(slot_index, slot)
		draw_circle(center, MARKER_RADIUS, color)
		draw_arc(center, MARKER_RADIUS, 0.0, TAU, 16, MARKER_OUTLINE, 1.0)


func _gui_input(event: InputEvent) -> void:
	if _grid == null or Game.run == null:
		return
	if not (event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT):
		return

	var cell_size: Vector2 = _cell_size()
	if cell_size.x <= 0.0 or cell_size.y <= 0.0:
		return

	var next_slot_index: int = _next_to_found_slot_index()
	var best_slot_index: int = -1
	var best_dist: float = MARKER_HIT_RADIUS
	for slot: Dictionary in Game.run.colony_slots:
		var slot_index: int = int(slot["slot_index"])
		if not (bool(slot["founded"]) or slot_index == next_slot_index):
			continue
		var center: Vector2 = _slot_center(slot, cell_size)
		var dist: float = event.position.distance_to(center)
		if dist <= best_dist:
			best_dist = dist
			best_slot_index = slot_index

	if best_slot_index >= 0:
		slot_selected.emit(best_slot_index)


func _slot_center(slot: Dictionary, cell_size: Vector2) -> Vector2:
	var cell: Vector2i = slot["cell"]
	return (Vector2(cell) + Vector2(0.5, 0.5)) * cell_size


## Only ever called for a founded or next-to-found slot now - a hidden
## locked slot never reaches this (see _draw()'s continue above).
func _marker_color(slot_index: int, slot: Dictionary) -> Color:
	if slot_index == 0:
		return CAPITAL_COLOR
	if bool(slot["founded"]):
		return FOUNDED_COLOR
	return NEXT_COLOR


func _next_to_found_slot_index() -> int:
	var next: Dictionary = Game.colonies.next_to_found()
	if next.is_empty():
		return -1
	return int(next["slot_index"])


## Scales x and y independently to fill the whole control - a simple grid
## (the chosen fidelity for this first pass) doesn't need square cells, and
## letterboxing a square 60x60 grid inside a tall portrait screen would
## leave large empty bands top and bottom instead.
func _cell_size() -> Vector2:
	if _grid == null or _grid.width <= 0 or _grid.height <= 0:
		return Vector2.ZERO
	return Vector2(size.x / float(_grid.width), size.y / float(_grid.height))
