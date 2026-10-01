## The whole world at a glance, drawn as an old engraved chart: parchment,
## hatched relief, a compass rose and a title cartouche. Tapping a spot jumps
## the main map there.
class_name ContinentalMap
extends Control

signal jump_to(world_pos: Vector2)
signal closed

const TERRAIN_SHADER := preload("res://assets/shaders/terrain.gdshader")
const INK := Color(0.24, 0.16, 0.09)
const PARCH := Color(0.93, 0.87, 0.72)
## Chart framing: tiles of unknown country kept around what has been explored,
## the smallest area (in tiles) the chart zooms in to, and the deepest zoom
## relative to fitting the whole world.
const FRAME_MARGIN := 6
const MIN_SPAN := 26
const MAX_ZOOM := 2.6
## Label placement grid, in chart pixels.
const CELL := 8.0
const NAME_SIZE := 15

var data_tex: Texture2D
var relief_tex: Texture2D
var _chart: TextureRect
var _ink: Control
var _font: Font = UI.FONT_TITLE
var _body_font: Font = UI.FONT_BODY
var _name_font := FontVariation.new()   # body face, slightly emboldened for town names
var _atlas: Texture2D = UI.tex("res://assets/sprites/decor_ink.png")
var _regions: Dictionary = {}
var _view: Control          # the clipped window onto the chart, inside the frame
var _frame: PanelContainer
var _scale: float = 1.0     # chart pixels per tile
var _ex := PackedByteArray()


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_name_font.base_font = _body_font
	_name_font.variation_embolden = 0.6
	var f := FileAccess.open("res://data/decor.json", FileAccess.READ)
	if f != null:
		_regions = JSON.parse_string(f.get_as_text())
	mouse_filter = Control.MOUSE_FILTER_STOP
	var bg := ColorRect.new()
	bg.color = Color(0.1, 0.07, 0.05, 0.92)
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(bg)

	_frame = PanelContainer.new()
	_frame.add_theme_stylebox_override("panel", UI.frame("panel", 14, 12))
	add_child(_frame)
	# The chart is larger than the frame when zoomed; this window clips it
	# (drawing and input) and carries the ink layer in window coordinates.
	_view = Control.new()
	_view.clip_contents = true
	_view.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_frame.add_child(_view)
	_chart = TextureRect.new()
	_chart.texture = data_tex
	_chart.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_chart.stretch_mode = TextureRect.STRETCH_SCALE
	var mat := ShaderMaterial.new()
	mat.shader = TERRAIN_SHADER
	mat.set_shader_parameter("data_n", data_tex)
	mat.set_shader_parameter("data_l", data_tex)
	mat.set_shader_parameter("relief", relief_tex)
	mat.set_shader_parameter("grid", Vector2(WorldMap.W, WorldMap.H))
	mat.set_shader_parameter("px_per_tile", 10.0)
	mat.set_shader_parameter("style", 2)
	_chart.material = mat
	_chart.mouse_filter = Control.MOUSE_FILTER_STOP
	_chart.gui_input.connect(_on_chart_input)
	_view.add_child(_chart)
	_ink = Control.new()
	_ink.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_ink.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	_ink.draw.connect(_draw_ink)
	_view.add_child(_ink)

	var close := UI.button("Close", "button_gold", 64)
	close.custom_minimum_size.x = 180
	close.set_anchors_and_offsets_preset(Control.PRESET_CENTER_BOTTOM)
	close.offset_top = -84 - UI.safe_insets(self).y
	close.offset_bottom = -20 - UI.safe_insets(self).y
	close.offset_left = -90
	close.offset_right = 90
	close.pressed.connect(func() -> void:
		Sfx.play("click")
		closed.emit()
		queue_free())
	add_child(close)
	resized.connect(_layout)
	_layout()


func _layout() -> void:
	var inset: Vector2 = UI.safe_insets(self)
	var avail := size - Vector2(40, 140 + inset.x + inset.y)
	if avail.x <= 0.0 or avail.y <= 0.0:
		return
	var grid := Vector2(WorldMap.W, WorldMap.H)
	# Explored area plus a margin of unknown country, at least MIN_SPAN tiles.
	var lo := Vector2(grid)
	var hi := Vector2.ZERO
	_ex = PackedByteArray()
	if Game.run != null:
		_ex = Game.run.explored(Balance.explore_mult(Game.run))
		for y in WorldMap.H:
			for x in WorldMap.W:
				if _ex[y * WorldMap.W + x] != 0:
					lo = Vector2(minf(lo.x, x), minf(lo.y, y))
					hi = Vector2(maxf(hi.x, x + 1), maxf(hi.y, y + 1))
	if hi.x <= lo.x:
		lo = Vector2.ZERO
		hi = grid
	lo -= Vector2(FRAME_MARGIN, FRAME_MARGIN)
	hi += Vector2(FRAME_MARGIN, FRAME_MARGIN)
	var span: Vector2 = (hi - lo).max(Vector2(MIN_SPAN, MIN_SPAN)).min(grid)
	var centre: Vector2 = (lo + hi) / 2.0
	# Zoom so that area fits, never smaller than the whole world fitting the
	# frame and never deeper than MAX_ZOOM times that.
	var fit_all: float = minf(avail.x / grid.x, avail.y / grid.y)
	_scale = clampf(minf(avail.x / span.x, avail.y / span.y), fit_all, fit_all * MAX_ZOOM)
	# Use the full width; let the height grow a little past the area (more
	# unknown country for the cartouche and labels), but no further, so the
	# frame never shows a big empty half.
	var vw: float = minf(grid.x, avail.x / _scale)
	var vh: float = minf(minf(grid.y, avail.y / _scale), maxf(span.y * 1.25, vw * 1.1))
	var origin := Vector2(
		clampf(centre.x - vw / 2.0, 0.0, grid.x - vw),
		clampf(centre.y - vh / 2.0, 0.0, grid.y - vh))
	var w: float = vw * _scale
	var h: float = vh * _scale
	_frame.position = Vector2((size.x - w) / 2.0 - 12, 20 + inset.x + (avail.y - h) / 2.0)
	_frame.size = Vector2(w + 24, h + 24)
	_view.custom_minimum_size = Vector2(w, h)
	_chart.position = -origin * _scale
	_chart.size = grid * _scale
	_ink.position = Vector2.ZERO
	_ink.size = Vector2(w, h)
	# Keep roughly one art pixel per screen pixel as the chart zooms.
	(_chart.material as ShaderMaterial).set_shader_parameter("px_per_tile", clampf(roundf(_scale), 10.0, 16.0))
	_ink.queue_redraw()


## Tile coordinates to the ink layer (the visible window).
func _tile_to_chart(t: Vector2) -> Vector2:
	return _chart.position + (t + Vector2(0.5, 0.5)) * _scale


func _on_chart_input(event: InputEvent) -> void:
	var p: Variant = null
	if event is InputEventMouseButton and (event as InputEventMouseButton).pressed and (event as InputEventMouseButton).button_index == MOUSE_BUTTON_LEFT:
		p = (event as InputEventMouseButton).position
	elif event is InputEventScreenTouch and (event as InputEventScreenTouch).pressed:
		p = (event as InputEventScreenTouch).position
	if p == null:
		return
	var tile: Vector2 = (p as Vector2) / _chart.size * Vector2(WorldMap.W, WorldMap.H)
	Sfx.play("click")
	jump_to.emit(tile * MapView.TILE)
	closed.emit()
	queue_free()


func _draw_ink() -> void:
	if Game.run == null or _ex.is_empty():
		return
	var run: RunState = Game.run
	var w: WorldMap = run.world
	var sz: Vector2 = _ink.size
	var ex: PackedByteArray = _ex

	_draw_engravings(w, ex, sz)

	# Routes and colonies.
	var blocked: Array[Rect2] = []
	for c: RunState.ColonyState in run.colonies:
		if c.tier == 0:
			continue
		var pts: PackedVector2Array = w.route(c.site)["points"]
		var chart_pts := PackedVector2Array()
		for p: Vector2 in pts:
			chart_pts.append(_tile_to_chart(p))
		if chart_pts.size() >= 2:
			_ink.draw_polyline(chart_pts, Color(INK, 0.5), 1.5)
	for c: RunState.ColonyState in run.colonies:
		var s: Dictionary = w.sites[c.site]
		var p: Vector2 = _tile_to_chart(Vector2(int(s["x"]), int(s["y"])))
		var r: float = 6.0 if c.tier == 0 else 4.0
		_ink.draw_circle(p, r + 1.5, INK)
		_ink.draw_circle(p, r, UI.nation_color(run.nation_id))
		var nm: String = Content.colony_name(run.nation_id, c.tier)
		# A parchment halo keeps the name legible over forest and relief.
		_ink.draw_string_outline(_name_font, p + Vector2(8, 5), nm, HORIZONTAL_ALIGNMENT_LEFT, -1, NAME_SIZE, 6, PARCH)
		_ink.draw_string(_name_font, p + Vector2(8, 5), nm, HORIZONTAL_ALIGNMENT_LEFT, -1, NAME_SIZE, INK)
		var nw: float = _name_font.get_string_size(nm, HORIZONTAL_ALIGNMENT_LEFT, -1, NAME_SIZE).x
		blocked.append(Rect2(p - Vector2(r + 4, 14), Vector2(nw + r + 18, 24)))
	if run.next_site() >= 0:
		var ns: Dictionary = w.sites[run.next_site()]
		var np: Vector2 = _tile_to_chart(Vector2(int(ns["x"]), int(ns["y"])))
		_ink.draw_arc(np, 7.0, 0.0, TAU, 16, INK, 1.5)
		_ink.draw_string_outline(_name_font, np + Vector2(9, 5), "?", HORIZONTAL_ALIGNMENT_LEFT, -1, 16, 6, PARCH)
		_ink.draw_string(_name_font, np + Vector2(9, 5), "?", HORIZONTAL_ALIGNMENT_LEFT, -1, 16, INK)
		blocked.append(Rect2(np - Vector2(12, 14), Vector2(32, 26)))

	# Fixed furniture along the bottom; the rest goes where the chart is empty.
	var bar_at := Vector2(sz.x * 0.06, sz.y - 46.0)
	_draw_scale_bar(bar_at, sz.x * 0.26)
	blocked.append(Rect2(bar_at - Vector2(6, 22), Vector2(sz.x * 0.26 + 12, 46)))
	var cart_rect: Rect2 = _draw_cartouche(Vector2(sz.x * 0.5, sz.y - 14.0), run)
	blocked.append(cart_rect.grow(6))
	var places := LabelPlaces.new(self, w, ex, sz, blocked)

	var cr: float = clampf(minf(sz.x, sz.y) * 0.1, 34.0, 56.0)
	var compass: Variant = places.find(Vector2(cr * 2.0 + 8, cr * 2.0 + 30), Vector2(0.84, 0.66), LabelPlaces.ANY, [24.0, 12.0, 4.0])
	if compass != null:
		var cbox: Rect2 = compass
		_draw_compass(cbox.get_center() + Vector2(0, 11), cr)
		places.block(cbox, 20.0)

	# Latin sea name in open water, the unknown in blank country.
	# Smaller lettering if only a narrow bay is open.
	var sea: Variant = null
	var fs_sea: int = 0
	for fs: int in ([22, 18, 15] if sz.x > 520.0 else [18, 15, 13]):
		fs_sea = fs
		var sea_w: float = _font.get_string_size("ATLANTICUM", HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
		sea = places.find(Vector2(sea_w + 8, fs * 2.4), Vector2(0.82, 0.35), LabelPlaces.SEA, [32.0, 20.0, 12.0, 6.0, 3.0])
		if sea != null:
			break
	if sea != null:
		var sbox: Rect2 = sea
		_label_center(sbox.get_center() + Vector2(0, -fs_sea * 0.2), "MARE", fs_sea, INK.lightened(0.25))
		_label_center(sbox.get_center() + Vector2(0, fs_sea * 0.9), "ATLANTICUM", fs_sea, INK.lightened(0.25))
		places.block(sbox, 40.0)
	var fs_unk: int = 18 if sz.x > 520.0 else 16
	var unk := Vector2(_font.get_string_size("Terra Incognita", HORIZONTAL_ALIGNMENT_LEFT, -1, fs_unk).x + 8, 26)
	for pref: Vector2 in [Vector2(0.3, 0.2), Vector2(0.7, 0.8), Vector2(0.25, 0.7), Vector2(0.75, 0.15)]:
		var spot: Variant = places.find(unk, pref, LabelPlaces.UNKNOWN, [24.0, 14.0, 8.0])
		if spot == null:
			break
		var ubox: Rect2 = spot
		_label_center(ubox.get_center() + Vector2(0, 6), "Terra Incognita", fs_unk, INK.lightened(0.35))
		places.block(ubox, maxf(80.0, sz.x * 0.18))

	_draw_border(sz)


## Woodcut trees and mountains on known land, and the odd sea creature or
## ship in known waters, as on an engraved chart.
func _draw_engravings(w: WorldMap, ex: PackedByteArray, sz: Vector2) -> void:
	if _regions.is_empty():
		return
	var k: float = _scale / 16.0 * 0.95
	var vis := Rect2(Vector2.ZERO, sz).grow(_scale * 2.0)
	var items: Array = []
	for y in WorldMap.H:
		for x in WorldMap.W:
			if ex[w.idx(x, y)] == 0:
				continue
			var h: int = hash([w.seed_value, x, y, "chart"])
			var names: Array = []
			if w.is_land(x, y):
				match w.t_at(x, y):
					WorldMap.T.FOREST, WorldMap.T.MARSH:
						names = ["tree%d" % (h % 4), "tree%d" % ((h >> 3) % 4)]
					WorldMap.T.CONIFER:
						names = ["pine%d" % (h % 4), "pine%d" % ((h >> 3) % 4)]
					WorldMap.T.TUNDRA:
						names = ["pine%d" % (h % 4)] if h % 3 == 0 else []
					WorldMap.T.TROPICAL:
						names = ["palm%d" % (h % 3)]
					WorldMap.T.GRASSLAND, WorldMap.T.PLAINS:
						names = ["tree%d" % (h % 4)] if h % 5 == 0 else []
					WorldMap.T.HILLS:
						names = ["hill%d" % (h % 3)] if h % 2 == 0 else []
					WorldMap.T.MOUNTAINS:
						names = ["mtn%d" % (h % 3)]
			elif w.water_depth[w.idx(x, y)] >= 5.0 and h % 61 == 0:
				names = [["serpent0", "whale0"][h % 2]]
			for i in names.size():
				var jx: float = float((h >> (5 + i * 4)) % 16) / 16.0
				var jy: float = float((h >> (9 + i * 4)) % 16) / 16.0
				items.append([y + jy, names[i], Vector2(x + 0.15 + jx * 0.7, y + 0.4 + jy * 0.6)])
	items.sort_custom(func(a: Array, b: Array) -> bool: return a[0] < b[0])
	for it: Array in items:
		var r: Array = _regions.get(it[1], [])
		if r.is_empty():
			continue
		var src := Rect2(r[0], r[1], r[2], r[3])
		var ds: Vector2 = src.size * k * (1.6 if str(it[1]).begins_with("serpent") or str(it[1]).begins_with("whale") else 1.0)
		var p: Vector2 = _chart.position + (it[2] as Vector2) * _scale
		if not vis.has_point(p):
			continue
		_ink.draw_texture_rect_region(_atlas, Rect2(p - Vector2(ds.x / 2.0, ds.y), ds), src)


func _draw_scale_bar(at: Vector2, length: float) -> void:
	var h: float = 6.0
	for i in 4:
		var seg := Rect2(at + Vector2(length / 4.0 * i, 0), Vector2(length / 4.0, h))
		_ink.draw_rect(seg, INK if i % 2 == 0 else PARCH)
	_ink.draw_rect(Rect2(at, Vector2(length, h)), INK, false, 1.0)
	_ink.draw_string(_body_font, at + Vector2(0, -6), "Leagues", HORIZONTAL_ALIGNMENT_LEFT, -1, 13, INK)
	_ink.draw_string(_body_font, at + Vector2(0, h + 14), "0", HORIZONTAL_ALIGNMENT_LEFT, -1, 12, INK)
	_ink.draw_string(_body_font, at + Vector2(length - 16, h + 14), "100", HORIZONTAL_ALIGNMENT_LEFT, -1, 12, INK)


## Double rule with scrolled corner ornaments.
func _draw_border(sz: Vector2) -> void:
	var r := Rect2(Vector2(4, 4), sz - Vector2(8, 8))
	_ink.draw_rect(r, INK, false, 2.0)
	_ink.draw_rect(r.grow(-5), Color(INK, 0.7), false, 1.0)
	for i in 4:
		var c := Vector2(r.position.x if i % 2 == 0 else r.end.x, r.position.y if i < 2 else r.end.y)
		var d := Vector2(1.0 if i % 2 == 0 else -1.0, 1.0 if i < 2 else -1.0)
		var o: Vector2 = c + d * 14.0
		_ink.draw_circle(o, 9.0, Color(0.93, 0.87, 0.72))
		_ink.draw_arc(o, 9.0, 0.0, TAU, 24, INK, 1.5)
		_ink.draw_arc(o, 5.0, 0.0, TAU, 16, Color(INK, 0.8), 1.0)
		_ink.draw_circle(o, 2.0, Color(0.55, 0.2, 0.15))
		# curling leaves along both edges
		for s in [Vector2(d.x, 0.0), Vector2(0.0, d.y)]:
			var a: Vector2 = o + s * 12.0
			var perp := Vector2(s.y, s.x) * d
			_ink.draw_polyline(PackedVector2Array([a, a + s * 8.0 + perp * 4.0, a + s * 16.0, a + s * 22.0 - perp * 3.0, a + s * 26.0]), INK, 1.2)


func _label_center(at: Vector2, text: String, fs: int, col: Color) -> void:
	var w: float = _font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
	_ink.draw_string(_font, at - Vector2(w / 2.0, 0), text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, col)


func _draw_compass(c: Vector2, r: float) -> void:
	_ink.draw_arc(c, r * 0.72, 0.0, TAU, 48, Color(INK, 0.8), 1.5)
	_ink.draw_arc(c, r * 0.64, 0.0, TAU, 48, Color(INK, 0.6), 1.0)
	for i in 8:
		var a: float = -PI / 2.0 + i * PI / 4.0
		var long: bool = i % 2 == 0
		var tip: Vector2 = c + Vector2(cos(a), sin(a)) * (r if long else r * 0.6)
		var side: float = 0.13 if long else 0.1
		var l: Vector2 = c + Vector2(cos(a - PI / 2.0), sin(a - PI / 2.0)) * r * side
		var rr: Vector2 = c + Vector2(cos(a + PI / 2.0), sin(a + PI / 2.0)) * r * side
		_ink.draw_colored_polygon(PackedVector2Array([c, l, tip]), Color(0.93, 0.87, 0.72))
		_ink.draw_colored_polygon(PackedVector2Array([c, tip, rr]), Color(INK, 0.9) if long else Color(0.55, 0.2, 0.15))
		_ink.draw_polyline(PackedVector2Array([l, tip, rr]), INK, 1.0)
	_label_center(c + Vector2(0, -r - 6), "N", 20, INK)


func _draw_cartouche(at: Vector2, run: RunState) -> Rect2:
	var nation: Dictionary = Content.nation(run.nation_id)
	var title: String = "New %s" % str(nation.get("name", "World")) if run.map_style != WorldMap.STYLE_NORTH_AMERICA else "America Septentrionalis"
	var fs: int = 26
	var tw: float = _font.get_string_size(title, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x + 60.0
	var r := Rect2(at - Vector2(tw / 2.0, 34), Vector2(tw, 44))
	_ink.draw_rect(r, Color(0.93, 0.87, 0.72, 0.95))
	_ink.draw_rect(r, INK, false, 2.0)
	_ink.draw_rect(r.grow(-4), Color(INK, 0.6), false, 1.0)
	_label_center(at + Vector2(0, -3), title, fs, INK)
	return r


## Finds room for chart lettering where the chart is blank: a coarse grid over
## the visible window marks each cell as unknown country (not yet explored,
## clear of the coast fringe), open sea (explored water at least two tiles from
## land, or unexplored water) or busy; summed-area tables then test any box in
## constant time.
class LabelPlaces:
	const UNKNOWN := 0
	const SEA := 1
	const ANY := 2

	var cols: int
	var rows: int
	var cell: float
	var size: Vector2
	## Per class, (cols + 1) * (rows + 1) prefix sums of cells that are NOT usable.
	var sums: Array[PackedInt32Array] = []
	## Per class, a usable flag per cell.
	var kind: Array[PackedByteArray] = []

	func _init(chart: ContinentalMap, w: WorldMap, ex: PackedByteArray, sz: Vector2, blocked: Array[Rect2]) -> void:
		cell = ContinentalMap.CELL
		size = sz
		cols = int(ceil(sz.x / cell))
		rows = int(ceil(sz.y / cell))
		# Tile classes, eroded by one tile so labels keep clear of edges.
		var n: int = WorldMap.W * WorldMap.H
		var unk := PackedByteArray()
		var sea := PackedByteArray()
		unk.resize(n)
		sea.resize(n)
		for y in WorldMap.H:
			for x in WorldMap.W:
				var ok_u: bool = true
				var ok_s: bool = true
				for d: Vector2i in [Vector2i(0, 0), Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
					var xx: int = x + d.x
					var yy: int = y + d.y
					if not w.in_bounds(xx, yy):
						continue
					var i: int = yy * WorldMap.W + xx
					if ex[i] != 0:
						ok_u = false
					if ex[i] == 0 or w.is_land(xx, yy) or w.water_depth[i] < 2.0:
						ok_s = false
				unk[y * WorldMap.W + x] = 1 if ok_u else 0
				# Unexplored open water also counts as sea.
				sea[y * WorldMap.W + x] = 1 if ok_s or (ok_u and not w.is_land(x, y)) else 0
		for c in 3:
			var k := PackedByteArray()
			k.resize(cols * rows)
			kind.append(k)
		var org: Vector2 = chart._chart.position
		var sc: float = chart._scale
		for cy in rows:
			for cx in cols:
				var u: bool = true
				var s: bool = true
				# Every tile under the cell's corners must qualify.
				for corner: Vector2 in [Vector2(0, 0), Vector2(1, 0), Vector2(0, 1), Vector2(1, 1)]:
					var t: Vector2 = ((Vector2(cx, cy) + corner * 0.999) * cell - org) / sc
					var tx: int = int(floor(t.x))
					var ty: int = int(floor(t.y))
					if tx < 0 or ty < 0 or tx >= WorldMap.W or ty >= WorldMap.H:
						u = false
						s = false
						continue
					var i: int = ty * WorldMap.W + tx
					u = u and unk[i] == 1
					s = s and sea[i] == 1
				var ci: int = cy * cols + cx
				kind[UNKNOWN][ci] = 1 if u else 0
				kind[SEA][ci] = 1 if s else 0
				kind[ANY][ci] = 1 if (u or s) else 0
		# Keep inside the double rule and its corner ornaments.
		block(Rect2(Vector2.ZERO, Vector2(sz.x, 26)), 0.0)
		block(Rect2(Vector2(0, sz.y - 26), Vector2(sz.x, 26)), 0.0)
		block(Rect2(Vector2.ZERO, Vector2(22, sz.y)), 0.0)
		block(Rect2(Vector2(sz.x - 22, 0), Vector2(22, sz.y)), 0.0)
		for r: Rect2 in blocked:
			block(r, 0.0)

	func block(r: Rect2, pad: float) -> void:
		var g: Rect2 = r.grow(pad)
		var x0: int = clampi(int(floor(g.position.x / cell)), 0, cols)
		var y0: int = clampi(int(floor(g.position.y / cell)), 0, rows)
		var x1: int = clampi(int(ceil(g.end.x / cell)), 0, cols)
		var y1: int = clampi(int(ceil(g.end.y / cell)), 0, rows)
		for cy in range(y0, y1):
			for cx in range(x0, x1):
				for c in 3:
					kind[c][cy * cols + cx] = 0
		sums.clear()

	func _build() -> void:
		sums.clear()
		for c in 3:
			var s := PackedInt32Array()
			s.resize((cols + 1) * (rows + 1))
			for cy in rows:
				var run: int = 0
				for cx in cols:
					run += 1 - int(kind[c][cy * cols + cx])
					s[(cy + 1) * (cols + 1) + cx + 1] = s[cy * (cols + 1) + cx + 1] + run
			sums.append(s)

	func _bad(c: int, x0: int, y0: int, x1: int, y1: int) -> int:
		var s: PackedInt32Array = sums[c]
		var w1: int = cols + 1
		return s[y1 * w1 + x1] - s[y0 * w1 + x1] - s[y1 * w1 + x0] + s[y0 * w1 + x0]

	## A box of `box_size` whose surroundings (by the largest of `margins`
	## that fits anywhere) are all of class `c`, nearest the preferred point
	## (as a fraction of the window). Null if nothing fits even the smallest.
	func find(box_size: Vector2, pref: Vector2, c: int, margins: Array) -> Variant:
		if sums.is_empty():
			_build()
		var target: Vector2 = pref * size
		for m: float in margins:
			var bw: int = int(ceil((box_size.x + m * 2.0) / cell))
			var bh: int = int(ceil((box_size.y + m * 2.0) / cell))
			var best: Variant = null
			var best_d: float = INF
			for cy in range(0, rows - bh + 1):
				for cx in range(0, cols - bw + 1):
					if _bad(c, cx, cy, cx + bw, cy + bh) != 0:
						continue
					var centre: Vector2 = Vector2(cx + bw / 2.0, cy + bh / 2.0) * cell
					var d: float = centre.distance_squared_to(target)
					if d < best_d:
						best_d = d
						best = Rect2(centre - box_size / 2.0, box_size)
			if best != null:
				return best
		return null
