## The whole world at a glance, drawn as an old engraved chart: parchment,
## hatched relief, a compass rose and a title cartouche. Tapping a spot jumps
## the main map there.
class_name ContinentalMap
extends Control

signal jump_to(world_pos: Vector2)
signal closed

const TERRAIN_SHADER := preload("res://assets/shaders/terrain.gdshader")
const INK := Color(0.24, 0.16, 0.09)

var data_tex: Texture2D
var relief_tex: Texture2D
var _chart: TextureRect
var _ink: Control
var _font: Font = UI.FONT_TITLE
var _body_font: Font = UI.FONT_BODY


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	var bg := ColorRect.new()
	bg.color = Color(0.1, 0.07, 0.05, 0.92)
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(bg)

	var frame := PanelContainer.new()
	frame.add_theme_stylebox_override("panel", UI.frame("panel", 14, 12))
	add_child(frame)
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
	mat.set_shader_parameter("px_per_tile", 12.0)
	mat.set_shader_parameter("style", 1)
	_chart.material = mat
	_chart.mouse_filter = Control.MOUSE_FILTER_STOP
	_chart.gui_input.connect(_on_chart_input)
	frame.add_child(_chart)
	_ink = Control.new()
	_ink.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_ink.draw.connect(_draw_ink)
	_chart.add_child(_ink)

	var close := UI.button("Close", "button_gold", 64)
	close.custom_minimum_size.x = 180
	close.set_anchors_and_offsets_preset(Control.PRESET_CENTER_BOTTOM)
	close.offset_top = -84
	close.offset_bottom = -20
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
	var avail := size - Vector2(40, 140)
	var aspect: float = float(WorldMap.W) / WorldMap.H
	var w: float = minf(avail.x, avail.y * aspect)
	var h: float = w / aspect
	var frame: Control = get_child(1)
	frame.position = Vector2((size.x - w) / 2.0 - 12, 20)
	frame.size = Vector2(w + 24, h + 24)
	_chart.custom_minimum_size = Vector2(w, h)
	_ink.size = Vector2(w, h)


func _tile_to_chart(t: Vector2) -> Vector2:
	return (t + Vector2(0.5, 0.5)) / Vector2(WorldMap.W, WorldMap.H) * _chart.size


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
	if Game.run == null:
		return
	var run: RunState = Game.run
	var w: WorldMap = run.world
	var sz: Vector2 = _ink.size
	var ex: PackedByteArray = run.explored(Balance.explore_mult(run))

	# Latin sea names and the unknown.
	_label_center(Vector2(sz.x * 0.86, sz.y * 0.35), "MARE", 22, INK.lightened(0.25))
	_label_center(Vector2(sz.x * 0.86, sz.y * 0.35 + 24), "ATLANTICUM", 22, INK.lightened(0.25))
	var unknown_spots: Array[Vector2] = []
	for y in range(4, WorldMap.H, 18):
		for x in range(4, WorldMap.W - 6, 20):
			if ex[w.idx(x, y)] == 0 and w.is_land(x, y):
				unknown_spots.append(Vector2(x, y))
	for i in mini(unknown_spots.size(), 4):
		var p: Vector2 = _tile_to_chart(unknown_spots[i * maxi(1, unknown_spots.size() / 4)])
		_label_center(p, "Terra Incognita", 18, INK.lightened(0.35))

	# Routes and colonies.
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
		_ink.draw_string(_body_font, p + Vector2(8, 5), Content.colony_name(run.nation_id, c.tier), HORIZONTAL_ALIGNMENT_LEFT, -1, 14, INK)
	if run.next_site() >= 0:
		var ns: Dictionary = w.sites[run.next_site()]
		var np: Vector2 = _tile_to_chart(Vector2(int(ns["x"]), int(ns["y"])))
		_ink.draw_arc(np, 7.0, 0.0, TAU, 16, INK, 1.5)
		_ink.draw_string(_body_font, np + Vector2(9, 5), "?", HORIZONTAL_ALIGNMENT_LEFT, -1, 16, INK)

	_draw_compass(Vector2(sz.x * 0.84, sz.y * 0.62), minf(sz.x, sz.y) * 0.1)
	_draw_cartouche(Vector2(sz.x * 0.5, sz.y * 0.955), run)


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


func _draw_cartouche(at: Vector2, run: RunState) -> void:
	var nation: Dictionary = Content.nation(run.nation_id)
	var title: String = "New %s" % str(nation.get("name", "World")) if run.map_style != WorldMap.STYLE_NORTH_AMERICA else "America Septentrionalis"
	var fs: int = 26
	var tw: float = _font.get_string_size(title, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x + 60.0
	var r := Rect2(at - Vector2(tw / 2.0, 34), Vector2(tw, 44))
	_ink.draw_rect(r, Color(0.93, 0.87, 0.72, 0.95))
	_ink.draw_rect(r, INK, false, 2.0)
	_ink.draw_rect(r.grow(-4), Color(INK, 0.6), false, 1.0)
	_label_center(at + Vector2(0, -3), title, fs, INK)
