## The New World: a pannable map with colonies, trade routes, and the wagons
## and ships moving goods to the capital. Everything on top of the terrain is
## drawn in one _draw() pass; nothing here changes game state.
class_name MapView
extends Control

signal colony_tapped(colony_id: String)
signal treasure_tapped(world_pos: Vector2)

const WATER_SHADER := preload("res://assets/shaders/water.gdshader")
const DRAG_THRESHOLD := 14.0
const EUROPE_TRIP_SECONDS := 36.0

var _map_tex: TextureRect
var _overlay: Control
var _world: Control
var _scroll: float = 0.0
var _velocity: float = 0.0
var _dragging: bool = false
var _press_pos: Vector2
var _press_scroll: float = 0.0
var _moved: bool = false
var _last_drag_y: float = 0.0
var _time: float = 0.0
var _floaters: Array[Dictionary] = []
var _pending_gold: float = 0.0
var _gold_timer: float = 0.0
var _highlight: String = ""

var _tile: float = 12.0
var _map_px: Vector2 = Vector2(360, 720)
var _font: Font = UI.FONT_BODY
var _sprites: Dictionary = {}
var _path_cache: Dictionary = {}
var _water: Image
## World position of the drifting treasure, or null. Seconds until the next
## one appears, and how long the current one has been afloat.
var _treasure: Variant = null
var _treasure_age: float = 0.0
var _treasure_timer: float = 45.0


func _ready() -> void:
	clip_contents = true
	mouse_filter = Control.MOUSE_FILTER_STOP
	_tile = float(Content.map.get("tile", 12))
	_map_px = Vector2(float(Content.map["width"]) * _tile, float(Content.map["height"]) * _tile)

	_world = Control.new()
	_world.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_world)

	_map_tex = TextureRect.new()
	_map_tex.texture = UI.tex("res://assets/sprites/map.png")
	_map_tex.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_map_tex.stretch_mode = TextureRect.STRETCH_SCALE
	_map_tex.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_map_tex.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var mat := ShaderMaterial.new()
	mat.shader = WATER_SHADER
	mat.set_shader_parameter("water_mask", UI.tex("res://assets/sprites/map_water.png"))
	mat.set_shader_parameter("map_pixels", _map_px)
	_map_tex.material = mat
	_world.add_child(_map_tex)

	_overlay = Control.new()
	_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_overlay.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_overlay.draw.connect(_draw_overlay)
	_world.add_child(_overlay)

	_water = UI.tex("res://assets/sprites/map_water.png").get_image()
	for n: String in ["colony_1", "colony_2", "colony_3", "capital", "site", "wagon", "ship", "merchantman", "chest"]:
		_sprites[n] = UI.tex("res://assets/sprites/map/%s.png" % n)

	resized.connect(_layout)
	Game.gold_earned.connect(func(a: float) -> void: _pending_gold += a)
	Game.shipment_arrived.connect(_on_shipment)
	_layout()


func scale_factor() -> float:
	return size.x / _map_px.x


func _layout() -> void:
	var s: float = scale_factor()
	var world_size := _map_px * s
	_world.size = world_size
	_map_tex.size = world_size
	_overlay.size = world_size
	_clamp_scroll()


func _max_scroll() -> float:
	return maxf(0.0, _map_px.y * scale_factor() - size.y)


func _clamp_scroll() -> void:
	_scroll = clampf(_scroll, 0.0, _max_scroll())
	_world.position = Vector2(0, -_scroll)


## Map-pixel coordinates of a tile's centre, in world (unscrolled) space.
func tile_to_world(t: Vector2) -> Vector2:
	return (t + Vector2(0.5, 0.5)) * _tile * scale_factor()


func site_of(colony_id: String) -> Vector2:
	var sites: Array = Content.colony_sites(colony_id)
	if sites.is_empty():
		return Vector2.ZERO
	var idx: int = 0
	if Game.run != null:
		var c: RunState.ColonyState = Game.run.colony(colony_id)
		if c != null:
			idx = clampi(c.site, 0, sites.size() - 1)
	var s: Dictionary = sites[idx]
	return Vector2(float(s["x"]), float(s["y"]))


func path_of(colony_id: String) -> PackedVector2Array:
	var out := PackedVector2Array()
	var all: Array = Content.map.get("paths", {}).get(colony_id, [])
	if all.is_empty() or Game.run == null:
		return out
	var c: RunState.ColonyState = Game.run.colony(colony_id)
	var key: String = "%s:%d:%f" % [colony_id, c.site, scale_factor()]
	if _path_cache.has(key):
		return _path_cache[key]
	var pts: Array = all[clampi(c.site, 0, all.size() - 1)]
	for p: Variant in pts:
		var arr: Array = p
		out.append(tile_to_world(Vector2(float(arr[0]), float(arr[1]))))
	out = _smooth(out)
	_path_cache[key] = out
	return out


## Chaikin smoothing so routes curve like roads and sea lanes, not grid steps.
func _smooth(pts: PackedVector2Array) -> PackedVector2Array:
	var cur := pts
	for i in 2:
		if cur.size() < 3:
			return cur
		var nxt := PackedVector2Array()
		nxt.append(cur[0])
		for j in cur.size() - 1:
			nxt.append(cur[j].lerp(cur[j + 1], 0.25))
			nxt.append(cur[j].lerp(cur[j + 1], 0.75))
		nxt.append(cur[cur.size() - 1])
		cur = nxt
	return cur


func scroll_to_colony(colony_id: String) -> void:
	scroll_to_colony_at(colony_id, 0.4)


## Scrolls so the colony sits `frac` of the way down the visible map.
func scroll_to_colony_at(colony_id: String, frac: float, animate: bool = true) -> void:
	var p: Vector2 = tile_to_world(site_of(colony_id))
	var target: float = clampf(p.y - size.y * frac, 0.0, _max_scroll())
	_velocity = 0.0
	if not animate:
		_scroll = target
		_clamp_scroll()
		return
	var tw := create_tween().set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	tw.tween_method(func(v: float) -> void:
		_scroll = v
		_clamp_scroll(), _scroll, target, 0.35)


func set_highlight(colony_id: String) -> void:
	_highlight = colony_id


func _process(delta: float) -> void:
	_time += delta
	if not _dragging and absf(_velocity) > 1.0:
		_scroll += _velocity * delta
		_velocity = lerpf(_velocity, 0.0, clampf(delta * 4.0, 0.0, 1.0))
		_clamp_scroll()
	_gold_timer += delta
	if _gold_timer >= 1.2 and _pending_gold > 0.0:
		_gold_timer = 0.0
		_spawn_floater(tile_to_world(site_of("capital")) + Vector2(0, -60), "+" + Format.num(_pending_gold), UI.GOLD, "gold")
		_pending_gold = 0.0
	_update_treasure(delta)
	var i: int = _floaters.size() - 1
	while i >= 0:
		_floaters[i]["t"] = float(_floaters[i]["t"]) + delta
		if float(_floaters[i]["t"]) > 1.6:
			_floaters.remove_at(i)
		i -= 1
	_overlay.queue_redraw()


func _on_shipment(colony_id: String, resource_id: String, qty: float) -> void:
	if not is_visible_in_tree():
		return
	var at: Vector2 = tile_to_world(site_of("capital")) + Vector2(randf_range(-30, 30), -20)
	_spawn_floater(at, "+" + Format.num(qty), UI.LIGHT, resource_id)


func _spawn_floater(at: Vector2, text: String, color: Color, icon_name: String) -> void:
	if _floaters.size() > 12:
		_floaters.pop_front()
	_floaters.append({"pos": at, "text": text, "color": color, "icon": icon_name, "t": 0.0})


# --- Input --------------------------------------------------------------------

func _gui_input(event: InputEvent) -> void:
	var pressed_evt: bool = false
	var released_evt: bool = false
	var pos: Vector2
	if event is InputEventMouseButton:
		var mb := event as InputEventMouseButton
		if mb.button_index == MOUSE_BUTTON_WHEEL_UP and mb.pressed:
			_scroll -= 80.0
			_clamp_scroll()
			return
		if mb.button_index == MOUSE_BUTTON_WHEEL_DOWN and mb.pressed:
			_scroll += 80.0
			_clamp_scroll()
			return
		if mb.button_index != MOUSE_BUTTON_LEFT:
			return
		pos = mb.position
		pressed_evt = mb.pressed
		released_evt = not mb.pressed
	elif event is InputEventScreenTouch:
		var st := event as InputEventScreenTouch
		if st.index != 0:
			return
		pos = st.position
		pressed_evt = st.pressed
		released_evt = not st.pressed
	elif event is InputEventMouseMotion or event is InputEventScreenDrag:
		if not _dragging:
			return
		var p: Vector2 = event.position
		if p.distance_to(_press_pos) > DRAG_THRESHOLD:
			_moved = true
		if _moved:
			var dy: float = p.y - _last_drag_y
			_scroll = _press_scroll - (p.y - _press_pos.y)
			_clamp_scroll()
			var dt: float = maxf(get_process_delta_time(), 0.001)
			_velocity = lerpf(_velocity, -dy / dt, 0.4)
		_last_drag_y = p.y
		accept_event()
		return
	else:
		return

	if pressed_evt:
		_dragging = true
		_moved = false
		_press_pos = pos
		_press_scroll = _scroll
		_last_drag_y = pos.y
		_velocity = 0.0
		accept_event()
	elif released_evt and _dragging:
		_dragging = false
		if not _moved:
			_velocity = 0.0
			_tap(pos + Vector2(0, _scroll))
		accept_event()


func _tap(world: Vector2) -> void:
	if Game.run == null:
		return
	if _treasure != null and (_treasure as Vector2).distance_to(world) < 34.0 * scale_factor():
		var at: Vector2 = _treasure
		_treasure = null
		_treasure_timer = randf_range(Balance.v("treasure_min_seconds"), Balance.v("treasure_max_seconds"))
		var amount: float = Game.collect_treasure()
		_spawn_floater(at + Vector2(-10, -30), "+" + Format.num(amount), UI.GOLD, "gold")
		treasure_tapped.emit(at)
		return
	var best: String = ""
	var best_d: float = 90.0 * scale_factor() / 2.0
	for c: RunState.ColonyState in Game.run.colonies:
		if not c.founded and Game.run.next_unfounded() != c:
			continue
		var p: Vector2 = tile_to_world(site_of(c.id)) + Vector2(0, -8 * scale_factor())
		var d: float = p.distance_to(world)
		if d < best_d:
			best_d = d
			best = c.id
	if best != "":
		colony_tapped.emit(best)


# --- Drawing --------------------------------------------------------------------

func _draw_overlay() -> void:
	if Game.run == null:
		return
	var s: float = scale_factor()
	var run: RunState = Game.run
	var nation_col: Color = UI.nation_color(run.nation_id)

	for c: RunState.ColonyState in run.colonies:
		if c.founded and c.id != "capital":
			_draw_route(c, s)

	_draw_europe_ship(s)

	for c: RunState.ColonyState in run.colonies:
		if c.founded and c.id != "capital":
			_draw_unit(c, s)

	var next: RunState.ColonyState = run.next_unfounded()
	if next != null:
		_draw_site(next, s)
	for c: RunState.ColonyState in run.colonies:
		if c.founded:
			_draw_colony(c, s, nation_col)

	_draw_treasure(s)
	_draw_clouds(s)

	for f: Dictionary in _floaters:
		var t: float = float(f["t"])
		var a: float = clampf(1.6 - t, 0.0, 1.0)
		var p: Vector2 = (f["pos"] as Vector2) + Vector2(0, -t * 40.0)
		var ic: Texture2D = UI.icon(str(f["icon"]))
		_overlay.draw_texture_rect(ic, Rect2(p + Vector2(-34, -24), Vector2(28, 28)), false, Color(1, 1, 1, a))
		_overlay.draw_string_outline(_font, p + Vector2(-2, -3), str(f["text"]), HORIZONTAL_ALIGNMENT_LEFT, -1, 22, 6, Color(0.1, 0.07, 0.05, a))
		_overlay.draw_string(_font, p + Vector2(-2, -3), str(f["text"]), HORIZONTAL_ALIGNMENT_LEFT, -1, 22, Color((f["color"] as Color), a))


func _draw_route(c: RunState.ColonyState, s: float) -> void:
	var pts: PackedVector2Array = path_of(c.id)
	if pts.size() < 2:
		return
	var sea: bool = Balance.is_sea(c)
	if not sea:
		_overlay.draw_polyline(pts, Color(0.36, 0.27, 0.16, 0.55), 4.0 * s)
		_overlay.draw_polyline(pts, Color(0.72, 0.6, 0.4, 0.85), 2.0 * s)
		return
	var col: Color = Color(0.95, 0.97, 1.0, 0.35)
	var dash: float = 10.0 if sea else 7.0
	var gap: float = 10.0 if sea else 5.0
	var carry: float = 0.0
	for i in pts.size() - 1:
		var a: Vector2 = pts[i]
		var b: Vector2 = pts[i + 1]
		var seg: float = a.distance_to(b)
		var dir: Vector2 = (b - a) / maxf(seg, 0.001)
		var d: float = -carry
		while d < seg:
			var from: float = maxf(d, 0.0)
			var to: float = minf(d + dash, seg)
			if to > from:
				_overlay.draw_line(a + dir * from, a + dir * to, col, 2.0 * s if not sea else 1.5 * s)
			d += dash + gap
		carry = d - seg


func _point_along(pts: PackedVector2Array, f: float) -> Array:
	var total: float = 0.0
	for i in pts.size() - 1:
		total += pts[i].distance_to(pts[i + 1])
	var target: float = clampf(f, 0.0, 1.0) * total
	for i in pts.size() - 1:
		var seg: float = pts[i].distance_to(pts[i + 1])
		if target <= seg or i == pts.size() - 2:
			var p: Vector2 = pts[i].lerp(pts[i + 1], clampf(target / maxf(seg, 0.001), 0.0, 1.0))
			return [p, pts[i + 1].x - pts[i].x]
		target -= seg
	return [pts[0], 0.0]


func _draw_unit(c: RunState.ColonyState, s: float) -> void:
	var pts: PackedVector2Array = path_of(c.id)
	if pts.size() < 2:
		return
	var f: float
	var going_out: bool = c.trip > 0.0 and c.trip < 0.5
	if c.trip <= 0.0:
		f = 0.06
	elif c.trip < 0.5:
		f = c.trip / 0.5
	else:
		f = 1.0 - (c.trip - 0.5) / 0.5
	var at: Array = _point_along(pts, f)
	var p: Vector2 = at[0]
	var dx: float = float(at[1])
	if not going_out:
		dx = -dx
	var sea: bool = Balance.is_sea(c)
	var tex: Texture2D = _sprites["ship"] if sea else _sprites["wagon"]
	var sz: Vector2 = tex.get_size() * s * (1.0 if sea else 0.9)
	var bob: float = sin(_time * 3.0 + float(c.id.hash() % 7)) * (1.5 if sea else 0.6) * s * 0.5
	var r := Rect2(p - Vector2(sz.x / 2, sz.y * 0.8) + Vector2(0, bob), sz)
	_overlay.draw_set_transform(Vector2.ZERO)
	if dx < 0:
		_overlay.draw_texture_rect(tex, Rect2(r.position + Vector2(sz.x, 0), Vector2(-sz.x, sz.y)), false)
	else:
		_overlay.draw_texture_rect(tex, r, false)
	if going_out and c.cargo > 0.0:
		var ic: Texture2D = UI.icon(str(Content.colony(c.id)["resource"]))
		_overlay.draw_texture_rect(ic, Rect2(r.position + Vector2(sz.x * 0.25, -sz.y * 0.55), Vector2(12, 12) * s), false)


func _draw_europe_ship(s: float) -> void:
	var lane: Array = Content.map.get("europe_lane", [])
	if lane.size() < 2:
		return
	var pts := PackedVector2Array()
	for p: Variant in lane:
		var arr: Array = p
		pts.append(tile_to_world(Vector2(float(arr[0]), float(arr[1]))))
	var phase: float = fmod(_time, EUROPE_TRIP_SECONDS) / EUROPE_TRIP_SECONDS
	var f: float = phase * 2.0 if phase < 0.5 else 2.0 - phase * 2.0
	f = 0.08 + f * 0.92
	var at: Array = _point_along(pts, f)
	var p: Vector2 = at[0]
	var tex: Texture2D = _sprites["merchantman"]
	var sz: Vector2 = tex.get_size() * s * 1.2
	var bob: float = sin(_time * 2.2) * s
	var r := Rect2(p - Vector2(sz.x / 2, sz.y * 0.8) + Vector2(0, bob), sz)
	if phase >= 0.5:
		_overlay.draw_texture_rect(tex, Rect2(r.position + Vector2(sz.x, 0), Vector2(-sz.x, sz.y)), false)
	else:
		_overlay.draw_texture_rect(tex, r, false)


func _stage_texture(c: RunState.ColonyState) -> Texture2D:
	return _sprites[UI.colony_sprite_name(c)]


func _draw_colony(c: RunState.ColonyState, s: float, nation_col: Color) -> void:
	var center: Vector2 = tile_to_world(site_of(c.id))
	var tex: Texture2D = _stage_texture(c)
	var sz: Vector2 = tex.get_size() * s
	var r := Rect2(center - Vector2(sz.x / 2, sz.y * 0.62), sz)
	if c.id == _highlight:
		var pulse: float = 0.5 + 0.5 * sin(_time * 5.0)
		_overlay.draw_circle(center + Vector2(0, -4 * s), sz.x * 0.56, Color(1, 0.9, 0.5, 0.18 + 0.12 * pulse))
	_overlay.draw_texture_rect(tex, r, false)
	_draw_smoke(r, s, center.x)

	# Flag on a pole at the top-right, waving.
	var pole := r.position + Vector2(sz.x * 0.82, sz.y * 0.1)
	_overlay.draw_line(pole, pole + Vector2(0, -12 * s), Color("3a2a1c"), 1.0 * s)
	var wave: float = sin(_time * 4.0 + center.x) * 1.0 * s
	var flag := PackedVector2Array([
		pole + Vector2(0, -12 * s), pole + Vector2(8 * s, -11 * s + wave),
		pole + Vector2(8 * s, -7 * s + wave), pole + Vector2(0, -8 * s)])
	_overlay.draw_colored_polygon(flag, nation_col)
	_overlay.draw_polyline(flag + PackedVector2Array([flag[0]]), nation_col.darkened(0.5), 1.0)

	# Colonist count box, as on the 1994 map.
	if c.colonists > 0:
		var box := Rect2(r.position + Vector2(-2 * s, sz.y * 0.1), Vector2(10, 9) * s)
		_overlay.draw_rect(box, Color("f5e9cc"))
		_overlay.draw_rect(box, Color("2c1e14"), false, 2.0)
		_overlay.draw_string(_font, box.position + Vector2(0, box.size.y - 5), str(c.colonists), HORIZONTAL_ALIGNMENT_CENTER, box.size.x, 16, Color("2c1e14"))

	# Name plate.
	var name_text: String = Content.colony_name(Game.run.nation_id, Content.colony_index(c.id))
	_name_plate(center + Vector2(0, sz.y * 0.42), name_text, c.id == "capital")

	# Goods piling up faster than the route can carry them.
	if c.id != "capital" and c.stock > Balance.cargo_capacity(Game.run, Game.meta, c) * 1.5:
		var ic: Texture2D = UI.icon("crate")
		var bounce: float = absf(sin(_time * 3.0)) * 4.0
		var ip := r.position + Vector2(sz.x * 0.72, sz.y * 0.45 - bounce)
		_overlay.draw_texture_rect(ic, Rect2(ip, Vector2(14, 14) * s), false)


func _name_plate(at: Vector2, text: String, bold: bool) -> void:
	var fs: int = 18 if not bold else 20
	var w: float = _font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x + 14.0
	var r := Rect2(at - Vector2(w / 2, 0), Vector2(w, fs + 8))
	_overlay.draw_rect(r, Color(0.13, 0.09, 0.06, 0.78))
	_overlay.draw_rect(r, Color(0.78, 0.6, 0.3, 0.9), false, 1.5)
	_overlay.draw_string(_font, r.position + Vector2(0, fs + 1), text, HORIZONTAL_ALIGNMENT_CENTER, w, fs, UI.LIGHT)


func _draw_site(c: RunState.ColonyState, s: float) -> void:
	var center: Vector2 = tile_to_world(site_of(c.id))
	var tex: Texture2D = _sprites["site"]
	var sz: Vector2 = tex.get_size() * s * 1.4
	var bob: float = sin(_time * 2.5) * 2.0
	var r := Rect2(center - Vector2(sz.x / 2, sz.y * 0.8 - bob), sz)
	var cost: float = Balance.found_cost(Game.run, Game.meta, c.id)
	var afford: bool = Game.run.gold >= cost
	if afford:
		var pulse: float = 0.5 + 0.5 * sin(_time * 4.0)
		_overlay.draw_circle(center + Vector2(0, -6), 34.0 + pulse * 6.0, Color(1, 0.85, 0.4, 0.22 + pulse * 0.15))
	_overlay.draw_texture_rect(tex, r, false)
	var text: String = "Found  " + Format.num(cost)
	var fs: int = 18
	var w: float = _font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x + 44.0
	var plate := Rect2(center + Vector2(-w / 2, sz.y * 0.3), Vector2(w, fs + 12))
	_overlay.draw_rect(plate, Color(0.35, 0.55, 0.25, 0.92) if afford else Color(0.13, 0.09, 0.06, 0.78))
	_overlay.draw_rect(plate, Color(0.78, 0.6, 0.3, 0.9), false, 1.5)
	_overlay.draw_texture_rect(UI.icon("gold"), Rect2(plate.position + Vector2(w - 34, 4), Vector2(24, 24)), false)
	_overlay.draw_string(_font, plate.position + Vector2(8, fs + 3), text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, UI.LIGHT)


## A few pixel puffs rising from the chimneys.
func _draw_smoke(r: Rect2, s: float, seed_x: float) -> void:
	var origin := r.position + Vector2(r.size.x * 0.34, r.size.y * 0.2)
	for i in 4:
		var t: float = fmod(_time * 0.35 + float(i) * 0.25 + seed_x * 0.013, 1.0)
		var p := origin + Vector2(sin(t * 5.0 + seed_x) * 3.0 * s + t * 6.0 * s, -t * 18.0 * s)
		var sz: float = (1.0 + t * 2.0) * s
		_overlay.draw_rect(Rect2(p.snapped(Vector2(s, s)), Vector2(sz, sz)), Color(0.86, 0.84, 0.8, 0.55 * (1.0 - t)))


## Slow cloud shadows drifting across the land and sea.
func _draw_clouds(s: float) -> void:
	var w: float = _overlay.size.x
	var h: float = _overlay.size.y
	for i in 5:
		var speed: float = 6.0 + float(i) * 1.7
		var x: float = fmod(_time * speed + float(i) * 311.0, w + 500.0) - 250.0
		var y: float = fmod(float(i) * 577.0 + 140.0, h)
		var base := Vector2(x, y)
		for j in 4:
			var off := Vector2(float(j) * 38.0 - 60.0, sin(float(i * 3 + j)) * 18.0)
			_overlay.draw_circle(base + off, 46.0 + float((i + j) % 3) * 14.0, Color(0.05, 0.08, 0.12, 0.07))


func _update_treasure(delta: float) -> void:
	if Game.run == null or not is_visible_in_tree():
		return
	if _treasure != null:
		_treasure_age += delta
		_treasure = (_treasure as Vector2) + Vector2(4.0 * delta, sin(_time * 0.7) * 2.0 * delta)
		if _treasure_age > Balance.v("treasure_lifetime_seconds"):
			_treasure = null
			_treasure_timer = randf_range(Balance.v("treasure_min_seconds"), Balance.v("treasure_max_seconds"))
		return
	_treasure_timer -= delta
	if _treasure_timer > 0.0:
		return
	var s: float = scale_factor()
	for attempt in 40:
		var world := Vector2(randf_range(60.0, size.x - 90.0), _scroll + randf_range(80.0, size.y - 160.0))
		var px := Vector2i(world / s)
		if px.x < 0 or px.y < 0 or px.x >= _water.get_width() or px.y >= _water.get_height():
			continue
		if _water.get_pixelv(px).r > 0.5 and _water.get_pixelv(px + Vector2i(8, 0)).r > 0.5 and _water.get_pixelv(px - Vector2i(8, 0)).r > 0.5:
			_treasure = world
			_treasure_age = 0.0
			return
	_treasure_timer = 5.0


func _draw_treasure(s: float) -> void:
	if _treasure == null:
		return
	var p: Vector2 = _treasure
	var tex: Texture2D = _sprites["chest"]
	var sz: Vector2 = tex.get_size() * s * 1.6
	var bob: float = sin(_time * 3.0) * 3.0
	var fade: float = clampf((Balance.v("treasure_lifetime_seconds") - _treasure_age) / 3.0, 0.0, 1.0)
	var pulse: float = 0.5 + 0.5 * sin(_time * 5.0)
	_overlay.draw_circle(p, 34.0 + pulse * 6.0, Color(1.0, 0.78, 0.25, (0.28 + pulse * 0.2) * fade))
	_overlay.draw_circle(p, 22.0, Color(1.0, 0.92, 0.6, 0.35 * fade))
	_overlay.draw_texture_rect(tex, Rect2(p - sz / 2.0 + Vector2(0, bob), sz), false, Color(1, 1, 1, fade))
	for i in 3:
		var a: float = _time * 2.0 + float(i) * 2.1
		var sp := p + Vector2(cos(a), sin(a)) * 26.0 + Vector2(0, bob)
		_overlay.draw_rect(Rect2(sp, Vector2(s * 1.5, s * 1.5)), Color(1, 0.95, 0.7, 0.8 * fade * absf(sin(a * 1.7))))
