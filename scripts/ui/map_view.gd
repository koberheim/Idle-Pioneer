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
##
## Zoom/pan (direct request, second polish pass): a single _zoom factor and
## a _pan pixel offset, applied uniformly in _draw() and in hit-testing -
## there's no Camera2D/viewport transform involved since this is 2D UI
## drawing in Control space, not a world scene.
class_name MapView
extends Control

signal slot_selected(slot_index: int)

const MARKER_RADIUS: float = 5.0
## How far (in pixels) a tap can land from a marker's center and still hit
## it - wider than the drawn radius since a fingertip is not a mouse cursor.
const MARKER_HIT_RADIUS: float = 16.0
const MARKER_ICON_SIZE: float = 28.0

const MIN_ZOOM: float = 1.0
const MAX_ZOOM: float = 4.0
const ZOOM_STEP: float = 1.15
## A press that moves less than this many pixels before release is a tap
## (marker selection), not a pan drag.
const DRAG_THRESHOLD: float = 6.0

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

var _zoom: float = 1.0
var _pan: Vector2 = Vector2.ZERO  # top-left of the drawn grid, in local pixels

var _dragging: bool = false
var _drag_moved: bool = false
var _drag_last_pos: Vector2 = Vector2.ZERO


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	resized.connect(func() -> void:
		_clamp_pan()
		queue_redraw()
	)


func refresh() -> void:
	if Game.run == null:
		_grid = null
		_grid_built_for_run = null
		queue_redraw()
		return
	if _grid_built_for_run != Game.run:
		_grid = MapGrid.from_dict(Game.run.map)
		_grid_built_for_run = Game.run
		_zoom = 1.0
		_pan = Vector2.ZERO
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
			var pos: Vector2 = _pan + Vector2(x, y) * cell_size
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
		_draw_marker(center, slot_index, slot)


## Real colony/outpost art (ColonyDef.icon, the same art ColoniesPanel's
## rows already use) where it exists; a flat colored dot as a fallback for
## any tier without one, same colors as before this pass (gold Capital,
## green founded, blue next-to-found).
func _draw_marker(center: Vector2, slot_index: int, slot: Dictionary) -> void:
	var tier_def: ColonyDef = Db.colony_by_order(int(slot["tier_order"]))
	var icon: Texture2D = tier_def.icon if tier_def != null else null

	if icon != null:
		var icon_size: float = MARKER_ICON_SIZE * clampf(_zoom, 1.0, 2.0)
		var rect := Rect2(center - Vector2(icon_size, icon_size) * 0.5, Vector2(icon_size, icon_size))
		draw_texture_rect(icon, rect, false)
		draw_arc(center, icon_size * 0.5, 0.0, TAU, 16, _marker_color(slot_index, slot), 2.0)
		return

	var color: Color = _marker_color(slot_index, slot)
	draw_circle(center, MARKER_RADIUS, color)
	draw_arc(center, MARKER_RADIUS, 0.0, TAU, 16, MARKER_OUTLINE, 1.0)


func _gui_input(event: InputEvent) -> void:
	if _grid == null or Game.run == null:
		return

	if event is InputEventMouseButton:
		var mb := event as InputEventMouseButton
		if mb.button_index == MOUSE_BUTTON_LEFT:
			if mb.pressed:
				_dragging = true
				_drag_moved = false
				_drag_last_pos = mb.position
			elif _dragging:
				_dragging = false
				if not _drag_moved:
					_handle_tap(mb.position)
		elif mb.pressed and mb.button_index == MOUSE_BUTTON_WHEEL_UP:
			_zoom_at(mb.position, ZOOM_STEP)
		elif mb.pressed and mb.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			_zoom_at(mb.position, 1.0 / ZOOM_STEP)
		return

	if event is InputEventMouseMotion and _dragging:
		var motion := event as InputEventMouseMotion
		var delta: Vector2 = motion.position - _drag_last_pos
		if delta.length() > DRAG_THRESHOLD:
			_drag_moved = true
		if _drag_moved:
			_pan += delta
			_clamp_pan()
			queue_redraw()
		_drag_last_pos = motion.position
		return

	if event is InputEventMagnifyGesture:
		_zoom_at(get_local_mouse_position(), (event as InputEventMagnifyGesture).factor)
	elif event is InputEventPanGesture:
		_pan -= (event as InputEventPanGesture).delta
		_clamp_pan()
		queue_redraw()


func _handle_tap(local_pos: Vector2) -> void:
	var cell_size: Vector2 = _cell_size()
	if cell_size.x <= 0.0 or cell_size.y <= 0.0:
		return

	var next_slot_index: int = _next_to_found_slot_index()
	var best_slot_index: int = -1
	var best_dist: float = MARKER_HIT_RADIUS * clampf(_zoom, 1.0, 2.0)
	for slot: Dictionary in Game.run.colony_slots:
		var slot_index: int = int(slot["slot_index"])
		if not (bool(slot["founded"]) or slot_index == next_slot_index):
			continue
		var center: Vector2 = _slot_center(slot, cell_size)
		var dist: float = local_pos.distance_to(center)
		if dist <= best_dist:
			best_dist = dist
			best_slot_index = slot_index

	if best_slot_index >= 0:
		slot_selected.emit(best_slot_index)


## Keeps whatever world point was under `screen_pos` still under it after
## the zoom changes, instead of always zooming toward the top-left corner.
func _zoom_at(screen_pos: Vector2, factor: float) -> void:
	var old_zoom: float = _zoom
	_zoom = clampf(_zoom * factor, MIN_ZOOM, MAX_ZOOM)
	if is_equal_approx(_zoom, old_zoom):
		return
	var world_point: Vector2 = (screen_pos - _pan) / old_zoom
	_pan = screen_pos - world_point * _zoom
	_clamp_pan()
	queue_redraw()


## Keeps the drawn grid covering the whole control - once zoomed in past
## MIN_ZOOM, panning can never pull an edge inward and leave a gap; at
## MIN_ZOOM (the whole grid already exactly fills the control) panning is
## locked to (0, 0), matching the no-zoom behavior before this pass.
func _clamp_pan() -> void:
	if _grid == null or _grid.width <= 0 or _grid.height <= 0:
		_pan = Vector2.ZERO
		return
	var base: Vector2 = Vector2(size.x / float(_grid.width), size.y / float(_grid.height))
	var drawn: Vector2 = base * _zoom * Vector2(_grid.width, _grid.height)
	_pan.x = clampf(_pan.x, minf(size.x - drawn.x, 0.0), 0.0)
	_pan.y = clampf(_pan.y, minf(size.y - drawn.y, 0.0), 0.0)


func _slot_center(slot: Dictionary, cell_size: Vector2) -> Vector2:
	var cell: Vector2i = slot["cell"]
	return _pan + (Vector2(cell) + Vector2(0.5, 0.5)) * cell_size


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


## Scales x and y independently to fill the whole control at zoom 1.0 - a
## simple grid (the chosen fidelity for this first pass) doesn't need
## square cells, and letterboxing a square 60x60 grid inside a tall
## portrait screen would leave large empty bands top and bottom instead.
## Zoom scales this uniformly on top.
func _cell_size() -> Vector2:
	if _grid == null or _grid.width <= 0 or _grid.height <= 0:
		return Vector2.ZERO
	return Vector2(size.x / float(_grid.width), size.y / float(_grid.height)) * _zoom
