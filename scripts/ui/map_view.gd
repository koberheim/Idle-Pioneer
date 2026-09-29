## The New World: a pannable, zoomable map of the run's world with colonies,
## trade routes, and the wagons and ships moving goods to the capital.
## Terrain comes from a shader over a small per-tile data texture; nothing
## here changes game state.
class_name MapView
extends Control

signal colony_tapped(colony_id: String)
signal next_site_tapped
signal treasure_tapped(world_pos: Vector2)
signal overview_requested
signal consult_requested

const TERRAIN_SHADER := preload("res://assets/shaders/terrain.gdshader")
const TILE := 24.0
const ART := TILE / 16.0
## Map sprites are drawn at twice the decor density (see tools/hd/map_sprites.py).
const SPRITE_DENSITY := 2.0
const DRAG_THRESHOLD := 14.0
const EUROPE_TRIP_SECONDS := 40.0
const MIN_ZOOM_FLOOR := 0.35
const MAX_ZOOM := 2.6

var world: Node2D
var _terrain: Sprite2D
var _decor: Node2D
## The rewarded "Consult the Almanac" button (dimmed while cooling down).
var consult_button: Button
var _dynamic: Node2D
var _labels: Control
var _data_img: Image
var _data_tex: ImageTexture
var _relief_tex: ImageTexture
var _decor_atlas: Texture2D
var _decor_regions: Dictionary = {}
var _sprites: Dictionary = {}
var _font: Font = UI.FONT_BODY

var _zoom: float = 1.0
var _center: Vector2 = Vector2.ZERO
var _touches: Dictionary = {}
var _pinch_start_dist: float = 0.0
var _pinch_start_zoom: float = 1.0
var _press_pos: Vector2
var _moved: bool = false
var _dragging: bool = false
var _velocity: Vector2 = Vector2.ZERO
var _last_drag: Vector2
var _tween: Tween

var _time: float = 0.0
var _world_ref: WorldMap
var _explored_key: String = ""
var _path_cache: Dictionary = {}
var _floaters: Array[Dictionary] = []
var _pending_gold: float = 0.0
var _gold_timer: float = 0.0
var _highlight: String = ""
var _treasure: Variant = null
var _treasure_age: float = 0.0
var _treasure_timer: float = 45.0


func _ready() -> void:
	clip_contents = true
	mouse_filter = Control.MOUSE_FILTER_STOP
	world = Node2D.new()
	add_child(world)
	_terrain = Sprite2D.new()
	_terrain.centered = false
	_terrain.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	world.add_child(_terrain)
	_decor = Node2D.new()
	_decor.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_decor.draw.connect(_draw_decor)
	world.add_child(_decor)
	_dynamic = Node2D.new()
	_dynamic.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST_WITH_MIPMAPS
	_dynamic.draw.connect(_draw_dynamic)
	world.add_child(_dynamic)
	_labels = Control.new()
	_labels.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_labels.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_labels.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	_labels.draw.connect(_draw_labels)
	add_child(_labels)
	_build_buttons()

	_decor_atlas = UI.tex("res://assets/sprites/decor.png")
	var f := FileAccess.open("res://data/decor.json", FileAccess.READ)
	if f != null:
		_decor_regions = JSON.parse_string(f.get_as_text())
	for n: String in ["colony_1", "colony_2", "colony_3", "capital", "site", "wagon", "ship", "merchantman", "chest"]:
		_sprites[n] = UI.tex("res://assets/sprites/map/%s.png" % n)

	resized.connect(func() -> void: _apply_camera())
	Game.gold_earned.connect(func(a: float) -> void: _pending_gold += a)
	Game.shipment_arrived.connect(_on_shipment)


func _build_buttons() -> void:
	var box := UI.vbox(8)
	box.set_anchors_and_offsets_preset(Control.PRESET_TOP_RIGHT)
	box.offset_left = -84
	box.offset_right = -12
	box.offset_top = 12
	add_child(box)
	for spec: Array in [["+", func() -> void: zoom_by(1.35)], ["−", func() -> void: zoom_by(1.0 / 1.35)]]:
		var b := UI.button(spec[0], "button", 64)
		b.custom_minimum_size.x = 64
		b.add_theme_font_size_override("font_size", UI.SIZE_BIG)
		var cb: Callable = spec[1]
		b.pressed.connect(func() -> void:
			Sfx.play("click")
			cb.call())
		box.add_child(b)
	var m := Button.new()
	m.icon = UI.icon("scroll")
	m.expand_icon = true
	m.focus_mode = Control.FOCUS_NONE
	m.custom_minimum_size = Vector2(64, 64)
	m.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	m.add_theme_constant_override("icon_max_width", 40)
	m.tooltip_text = "Continental map"
	m.pressed.connect(func() -> void:
		Sfx.play("click")
		overview_requested.emit())
	box.add_child(m)
	consult_button = Button.new()
	consult_button.icon = UI.icon("almanac")
	consult_button.expand_icon = true
	consult_button.focus_mode = Control.FOCUS_NONE
	consult_button.custom_minimum_size = Vector2(64, 64)
	consult_button.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	consult_button.add_theme_constant_override("icon_max_width", 40)
	consult_button.tooltip_text = "Consult the Almanac"
	consult_button.pressed.connect(func() -> void:
		Sfx.play("click")
		consult_requested.emit())
	box.add_child(consult_button)


# --- World data -----------------------------------------------------------------

func _ensure_world() -> bool:
	if Game.run == null:
		return false
	var w: WorldMap = Game.run.world
	if w != _world_ref:
		_world_ref = w
		_path_cache.clear()
		_build_textures(w)
		_explored_key = ""
		_treasure = null
		center_on_colony("c0", false)
	var key: String = "%d:%.2f" % [Game.run.colonies.size(), Balance.explore_mult(Game.run)]
	if key != _explored_key:
		_explored_key = key
		_update_explored()
		_decor.queue_redraw()
	return true


static func build_data_image(w: WorldMap, explored: PackedByteArray) -> Image:
	var img := Image.create(WorldMap.W, WorldMap.H, false, Image.FORMAT_RGBA8)
	for y in WorldMap.H:
		for x in WorldMap.W:
			var i: int = w.idx(x, y)
			var land: bool = w.is_land(x, y)
			var depth: float = 0.0 if land else clampf(w.water_depth[i] / 12.0, 0.0, 1.0)
			var ex: float = 1.0 if explored.is_empty() or explored[i] == 1 else 0.0
			img.set_pixel(x, y, Color(w.terrain[i] * 16.0 / 255.0, 1.0 if land else 0.0, depth, ex))
	return img


static func build_relief_image(w: WorldMap) -> Image:
	var img := Image.create(WorldMap.W, WorldMap.H, false, Image.FORMAT_L8)
	for y in WorldMap.H:
		for x in WorldMap.W:
			var h: float = w.height[w.idx(x, y)] if w.is_land(x, y) else 0.0
			if w.t_at(x, y) == WorldMap.T.MOUNTAINS:
				h = maxf(h, 0.85)
			img.set_pixel(x, y, Color(h, h, h))
	return img


## Lighter map shading for low-end phones: no animated water or extra noise.
func apply_lite() -> void:
	if _terrain.material != null:
		(_terrain.material as ShaderMaterial).set_shader_parameter("lite", Game.meta.lite_map)


func _build_textures(w: WorldMap) -> void:
	_data_img = build_data_image(w, Game.run.explored(Balance.explore_mult(Game.run)))
	_data_tex = ImageTexture.create_from_image(_data_img)
	_relief_tex = ImageTexture.create_from_image(build_relief_image(w))
	var mat := ShaderMaterial.new()
	mat.shader = TERRAIN_SHADER
	mat.set_shader_parameter("data_n", _data_tex)
	mat.set_shader_parameter("data_l", _data_tex)
	mat.set_shader_parameter("relief", _relief_tex)
	mat.set_shader_parameter("grid", Vector2(WorldMap.W, WorldMap.H))
	mat.set_shader_parameter("lite", Game.meta.lite_map)
	_terrain.material = mat
	_terrain.texture = _data_tex
	_terrain.scale = Vector2(TILE, TILE)


func _update_explored() -> void:
	var ex: PackedByteArray = Game.run.explored(Balance.explore_mult(Game.run))
	for y in WorldMap.H:
		for x in WorldMap.W:
			var c: Color = _data_img.get_pixel(x, y)
			c.a = 1.0 if ex[y * WorldMap.W + x] == 1 else 0.0
			_data_img.set_pixel(x, y, c)
	_data_tex.update(_data_img)


func data_texture() -> ImageTexture:
	_ensure_world()
	return _data_tex


func relief_texture() -> ImageTexture:
	_ensure_world()
	return _relief_tex


# --- Camera ---------------------------------------------------------------------

func min_zoom() -> float:
	return maxf(MIN_ZOOM_FLOOR, size.x / (WorldMap.W * TILE))


func _apply_camera() -> void:
	_zoom = clampf(_zoom, min_zoom(), MAX_ZOOM)
	var half: Vector2 = size / (2.0 * _zoom)
	var world_size := Vector2(WorldMap.W, WorldMap.H) * TILE
	_center.x = clampf(_center.x, half.x, maxf(half.x, world_size.x - half.x)) if world_size.x > half.x * 2.0 else world_size.x / 2.0
	_center.y = clampf(_center.y, half.y, maxf(half.y, world_size.y - half.y)) if world_size.y > half.y * 2.0 else world_size.y / 2.0
	world.scale = Vector2(_zoom, _zoom)
	world.position = size / 2.0 - _center * _zoom


func zoom_by(factor: float, focus: Variant = null) -> void:
	var f: Vector2 = focus if focus != null else size / 2.0
	var before: Vector2 = screen_to_world(f)
	_zoom = clampf(_zoom * factor, min_zoom(), MAX_ZOOM)
	_center = before - (f - size / 2.0) / _zoom
	_apply_camera()


func screen_to_world(p: Vector2) -> Vector2:
	return (p - world.position) / world.scale.x


func world_to_screen(p: Vector2) -> Vector2:
	return p * world.scale.x + world.position


func tile_to_world(t: Vector2) -> Vector2:
	return (t + Vector2(0.5, 0.5)) * TILE


func site_world(site_index: int) -> Vector2:
	var s: Dictionary = Game.run.world.sites[site_index]
	return tile_to_world(Vector2(int(s["x"]), int(s["y"])))


func colony_world(c: RunState.ColonyState) -> Vector2:
	return site_world(c.site)


## Pans (animated) so the world point sits at `frac` down the visible area.
func look_at_world(p: Vector2, frac_y: float = 0.4, animate: bool = true) -> void:
	var target := p + Vector2(0, (0.5 - frac_y) * size.y / _zoom)
	_velocity = Vector2.ZERO
	if _tween != null:
		_tween.kill()
	if not animate:
		_center = target
		_apply_camera()
		return
	_tween = create_tween().set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	_tween.tween_method(func(v: Vector2) -> void:
		_center = v
		_apply_camera(), _center, target, 0.35)


func center_on_colony(colony_id: String, animate: bool = true, frac_y: float = 0.4) -> void:
	if Game.run == null:
		return
	var c: RunState.ColonyState = Game.run.colony(colony_id)
	if c != null:
		look_at_world(colony_world(c), frac_y, animate)


func center_on_next_site(frac_y: float = 0.4) -> void:
	if Game.run != null and Game.run.next_site() >= 0:
		look_at_world(site_world(Game.run.next_site()), frac_y)


func set_highlight(colony_id: String) -> void:
	_highlight = colony_id


# --- Frame ------------------------------------------------------------------------

func _process(delta: float) -> void:
	if not _ensure_world():
		return
	_time += delta
	if not _dragging and _velocity.length() > 5.0:
		_center -= _velocity * delta / _zoom
		_velocity = _velocity.lerp(Vector2.ZERO, clampf(delta * 4.0, 0.0, 1.0))
		_apply_camera()
	_gold_timer += delta
	if _gold_timer >= 1.2 and _pending_gold > 0.0:
		_gold_timer = 0.0
		_spawn_floater(colony_world(Game.run.capital()) + Vector2(0, -40), "+" + Format.num(_pending_gold), UI.GOLD, "gold")
		_pending_gold = 0.0
	var i: int = _floaters.size() - 1
	while i >= 0:
		_floaters[i]["t"] = float(_floaters[i]["t"]) + delta
		if float(_floaters[i]["t"]) > 1.6:
			_floaters.remove_at(i)
		i -= 1
	_update_treasure(delta)
	_dynamic.queue_redraw()
	_labels.queue_redraw()


func _on_shipment(colony_id: String, resource_id: String, qty: float) -> void:
	if not is_visible_in_tree() or Game.run == null:
		return
	var at: Vector2 = colony_world(Game.run.capital()) + Vector2(randf_range(-24, 24), -12)
	_spawn_floater(at, "+" + Format.num(qty), UI.LIGHT, resource_id)


func _spawn_floater(at: Vector2, text: String, color: Color, icon_name: String) -> void:
	if _floaters.size() > 12:
		_floaters.pop_front()
	_floaters.append({"pos": at, "text": text, "color": color, "icon": icon_name, "t": 0.0})


# --- Input --------------------------------------------------------------------

func _gui_input(event: InputEvent) -> void:
	# On touch screens every touch also arrives as an emulated mouse event;
	# the touch events are the ones to trust.
	if (event is InputEventMouseButton or event is InputEventMouseMotion) and event.device == InputEvent.DEVICE_ID_EMULATION:
		return
	if event is InputEventMouseButton:
		var mb := event as InputEventMouseButton
		if mb.pressed and (mb.button_index == MOUSE_BUTTON_WHEEL_UP or mb.button_index == MOUSE_BUTTON_WHEEL_DOWN):
			zoom_by(1.12 if mb.button_index == MOUSE_BUTTON_WHEEL_UP else 1.0 / 1.12, mb.position)
			accept_event()
			return
		if mb.button_index != MOUSE_BUTTON_LEFT:
			return
		_pointer(0, mb.position, mb.pressed)
		accept_event()
	elif event is InputEventScreenTouch:
		var st := event as InputEventScreenTouch
		_pointer(st.index, st.position, st.pressed)
		accept_event()
	elif event is InputEventMouseMotion:
		if _touches.has(0):
			_pointer_move(0, (event as InputEventMouseMotion).position)
			accept_event()
	elif event is InputEventScreenDrag:
		var sd := event as InputEventScreenDrag
		_pointer_move(sd.index, sd.position)
		accept_event()
	elif event is InputEventMagnifyGesture:
		var mg := event as InputEventMagnifyGesture
		zoom_by(mg.factor, mg.position)
		accept_event()


func _pointer(index: int, pos: Vector2, pressed: bool) -> void:
	if pressed:
		_touches[index] = pos
		if _touches.size() == 1:
			_dragging = true
			_moved = false
			_press_pos = pos
			_last_drag = pos
			_velocity = Vector2.ZERO
			if _tween != null:
				_tween.kill()
		elif _touches.size() == 2:
			var pts: Array = _touches.values()
			_pinch_start_dist = (pts[0] as Vector2).distance_to(pts[1])
			_pinch_start_zoom = _zoom
			_moved = true
	else:
		var was_single: bool = _touches.size() == 1
		_touches.erase(index)
		if _touches.is_empty():
			_dragging = false
			if was_single and not _moved:
				_velocity = Vector2.ZERO
				_tap(screen_to_world(pos))


func _pointer_move(index: int, pos: Vector2) -> void:
	if not _touches.has(index):
		return
	_touches[index] = pos
	if _touches.size() >= 2:
		var pts: Array = _touches.values()
		var a: Vector2 = pts[0]
		var b: Vector2 = pts[1]
		if _pinch_start_dist > 1.0:
			var target: float = _pinch_start_zoom * a.distance_to(b) / _pinch_start_dist
			zoom_by(target / _zoom, (a + b) / 2.0)
		return
	if pos.distance_to(_press_pos) > DRAG_THRESHOLD:
		_moved = true
	if _moved:
		var d: Vector2 = pos - _last_drag
		_center -= d / _zoom
		_apply_camera()
		var dt: float = maxf(get_process_delta_time(), 0.001)
		_velocity = _velocity.lerp(d / dt, 0.4)
	_last_drag = pos


func _tap(p: Vector2) -> void:
	if Game.run == null:
		return
	var reach: float = maxf(34.0, 30.0 / _zoom)
	if _treasure != null and (_treasure as Vector2).distance_to(p) < reach:
		var at: Vector2 = _treasure
		_treasure = null
		_treasure_timer = randf_range(Balance.v("treasure_min_seconds"), Balance.v("treasure_max_seconds"))
		var amount: float = Game.collect_treasure()
		_spawn_floater(at + Vector2(-10, -20), "+" + Format.num(amount), UI.GOLD, "gold")
		treasure_tapped.emit(at)
		return
	var best: String = ""
	var best_d: float = reach
	for c: RunState.ColonyState in Game.run.colonies:
		var d: float = (colony_world(c) + Vector2(0, -6)).distance_to(p)
		if d < best_d:
			best_d = d
			best = c.id
	var n: int = Game.run.next_site()
	if n >= 0 and site_world(n).distance_to(p) < best_d:
		next_site_tapped.emit()
		return
	if best != "":
		colony_tapped.emit(best)


# --- Decor layer (redrawn only when exploration changes) -----------------------

func _draw_decor() -> void:
	if Game.run == null or _decor_regions.is_empty():
		return
	var w: WorldMap = Game.run.world
	var ex: PackedByteArray = Game.run.explored(Balance.explore_mult(Game.run))
	var near_site := {}
	for c: RunState.ColonyState in Game.run.colonies:
		var s: Dictionary = w.sites[c.site]
		near_site[Vector2i(int(s["x"]), int(s["y"]))] = true
	if Game.run.next_site() >= 0:
		var ns: Dictionary = w.sites[Game.run.next_site()]
		near_site[Vector2i(int(ns["x"]), int(ns["y"]))] = true
	var items: Array = []
	for y in WorldMap.H:
		for x in WorldMap.W:
			if ex[y * WorldMap.W + x] == 0 or not w.is_land(x, y):
				continue
			if near_site.has(Vector2i(x, y)):
				continue
			var rng := RandomNumberGenerator.new()
			rng.seed = hash([w.seed_value, x, y])
			var coast: bool = w.is_coastal(x, y)
			for spec: Array in _decor_for(w.t_at(x, y), rng, coast):
				var pos := Vector2(x + rng.randf_range(0.1, 0.9), y + rng.randf_range(0.25, 0.95)) * TILE
				items.append([pos.y, spec[0], pos])
	items.sort_custom(func(a: Array, b: Array) -> bool: return a[0] < b[0])
	for it: Array in items:
		var r: Array = _decor_regions.get(it[1], [])
		if r.is_empty():
			continue
		var src := Rect2(r[0], r[1], r[2], r[3])
		var sz: Vector2 = src.size * ART
		var p: Vector2 = it[2]
		_decor.draw_texture_rect_region(_decor_atlas, Rect2(p - Vector2(sz.x / 2.0, sz.y), sz), src)


func _decor_for(t: int, rng: RandomNumberGenerator, coast: bool) -> Array:
	var out: Array = []
	match t:
		WorldMap.T.FOREST:
			for i in rng.randi_range(3, 5):
				out.append(["tree%d" % rng.randi_range(0, 3)])
		WorldMap.T.CONIFER:
			for i in rng.randi_range(3, 5):
				out.append(["pine%d" % rng.randi_range(0, 3)])
		WorldMap.T.TUNDRA:
			if rng.randf() < 0.45:
				out.append(["snowpine%d" % rng.randi_range(0, 1)])
			if rng.randf() < 0.3:
				out.append(["rock%d" % rng.randi_range(0, 1)])
		WorldMap.T.TROPICAL:
			for i in rng.randi_range(2, 3):
				out.append(["palm%d" % rng.randi_range(0, 2)])
			if rng.randf() < 0.6:
				out.append(["bush%d" % rng.randi_range(0, 2)])
		WorldMap.T.SAVANNAH:
			if rng.randf() < 0.5:
				out.append(["acacia%d" % rng.randi_range(0, 1)])
			if rng.randf() < 0.3:
				out.append(["bush%d" % rng.randi_range(0, 2)])
		WorldMap.T.GRASSLAND:
			if rng.randf() < 0.35:
				out.append(["bush%d" % rng.randi_range(0, 2)])
			if rng.randf() < 0.15:
				out.append(["tree%d" % rng.randi_range(0, 3)])
		WorldMap.T.PLAINS:
			if rng.randf() < 0.2:
				out.append(["tree%d" % rng.randi_range(0, 3)])
			if rng.randf() < 0.2:
				out.append(["bush%d" % rng.randi_range(0, 2)])
		WorldMap.T.MARSH:
			for i in rng.randi_range(1, 2):
				out.append(["reeds%d" % rng.randi_range(0, 1)])
			if rng.randf() < 0.3:
				out.append(["tree%d" % rng.randi_range(0, 3)])
		WorldMap.T.HILLS:
			out.append(["hill%d" % rng.randi_range(0, 2)])
			if rng.randf() < 0.4:
				out.append(["pine%d" % rng.randi_range(0, 3)])
		WorldMap.T.MOUNTAINS:
			out.append(["mtn%d" % rng.randi_range(0, 2)])
			if rng.randf() < 0.5:
				out.append(["peak%d" % rng.randi_range(0, 1)])
	return out


# --- Dynamic layer ----------------------------------------------------------------

func path_of(c: RunState.ColonyState) -> PackedVector2Array:
	if _path_cache.has(c.site):
		return _path_cache[c.site]
	var pts: PackedVector2Array = Game.run.world.route(c.site)["points"]
	var out := PackedVector2Array()
	for p: Vector2 in pts:
		out.append(tile_to_world(p))
	out = _smooth(out)
	_path_cache[c.site] = out
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


func _draw_dynamic() -> void:
	if Game.run == null:
		return
	var run: RunState = Game.run
	var nation_col: Color = UI.nation_color(run.nation_id)
	for c: RunState.ColonyState in run.colonies:
		if c.tier > 0:
			_draw_route(c)
	_draw_europe_ship()
	for c: RunState.ColonyState in run.colonies:
		if c.tier > 0:
			_draw_unit(c)
	if run.next_site() >= 0:
		_draw_site(run.next_site())
	for c: RunState.ColonyState in run.colonies:
		_draw_colony(c, nation_col)
	_draw_treasure()
	_draw_clouds()


func _draw_route(c: RunState.ColonyState) -> void:
	var pts: PackedVector2Array = path_of(c)
	if pts.size() < 2:
		return
	if not Balance.is_sea(Game.run, c):
		_dynamic.draw_polyline(pts, Color(0.34, 0.25, 0.15, 0.55), 5.0)
		_dynamic.draw_polyline(pts, Color(0.74, 0.62, 0.42, 0.9), 2.5)
		return
	var col := Color(0.95, 0.97, 1.0, 0.4)
	var dash: float = 9.0
	var gap: float = 8.0
	var carry: float = 0.0
	for i in pts.size() - 1:
		var a: Vector2 = pts[i]
		var b: Vector2 = pts[i + 1]
		var seg: float = a.distance_to(b)
		var dir: Vector2 = (b - a) / maxf(seg, 0.001)
		var d: float = carry
		while d < seg:
			var to: float = minf(d + dash, seg)
			_dynamic.draw_line(a + dir * d, a + dir * to, col, 2.0)
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


func _draw_unit(c: RunState.ColonyState) -> void:
	var pts: PackedVector2Array = path_of(c)
	if pts.size() < 2:
		return
	var going_out: bool = c.trip > 0.0 and c.trip < 0.5
	var f: float
	if c.trip <= 0.0:
		f = 0.04
	elif c.trip < 0.5:
		f = c.trip / 0.5
	else:
		f = 1.0 - (c.trip - 0.5) / 0.5
	var at: Array = _point_along(pts, f)
	var p: Vector2 = at[0]
	var dx: float = float(at[1]) if going_out else -float(at[1])
	var sea: bool = Balance.is_sea(Game.run, c)
	var tex: Texture2D = _sprites["ship"] if sea else _sprites["wagon"]
	var sz: Vector2 = tex.get_size() / SPRITE_DENSITY * ART * 0.8
	var bob: float = sin(_time * 3.0 + float(c.tier)) * (1.2 if sea else 0.4)
	var r := Rect2(p - Vector2(sz.x / 2, sz.y * 0.8) + Vector2(0, bob), sz)
	if dx < 0:
		_dynamic.draw_texture_rect(tex, Rect2(r.position + Vector2(sz.x, 0), Vector2(-sz.x, sz.y)), false)
	else:
		_dynamic.draw_texture_rect(tex, r, false)
	if going_out and c.cargo > 0.0:
		_dynamic.draw_texture_rect(UI.icon(Game.run.resource_of(c)), Rect2(r.position + Vector2(sz.x * 0.3, -9), Vector2(12, 12)), false)


func _draw_europe_ship() -> void:
	var lane: PackedVector2Array = Game.run.world.europe_lane()
	if lane.size() < 2:
		return
	var pts := PackedVector2Array()
	for p: Vector2 in lane:
		pts.append(tile_to_world(p))
	var phase: float = fmod(_time, EUROPE_TRIP_SECONDS) / EUROPE_TRIP_SECONDS
	var f: float = phase * 2.0 if phase < 0.5 else 2.0 - phase * 2.0
	var at: Array = _point_along(pts, 0.06 + f * 0.94)
	var p: Vector2 = at[0]
	var tex: Texture2D = _sprites["merchantman"]
	var sz: Vector2 = tex.get_size() / SPRITE_DENSITY * ART
	var r := Rect2(p - Vector2(sz.x / 2, sz.y * 0.8) + Vector2(0, sin(_time * 2.2)), sz)
	if phase >= 0.5:
		_dynamic.draw_texture_rect(tex, Rect2(r.position + Vector2(sz.x, 0), Vector2(-sz.x, sz.y)), false)
	else:
		_dynamic.draw_texture_rect(tex, r, false)


func _draw_colony(c: RunState.ColonyState, nation_col: Color) -> void:
	var center: Vector2 = colony_world(c)
	var tex: Texture2D = _sprites[UI.colony_sprite_name(c)]
	var sz: Vector2 = tex.get_size() / SPRITE_DENSITY * ART * 1.35
	var r := Rect2(center - Vector2(sz.x / 2, sz.y * 0.62), sz)
	if c.id == _highlight:
		var pulse: float = 0.5 + 0.5 * sin(_time * 5.0)
		_dynamic.draw_circle(center + Vector2(0, -3), sz.x * 0.58, Color(1, 0.9, 0.5, 0.18 + 0.12 * pulse))
	_dynamic.draw_texture_rect(tex, r, false)
	# Chimney smoke.
	var origin := r.position + Vector2(sz.x * 0.34, sz.y * 0.2)
	for i in 3:
		var t: float = fmod(_time * 0.35 + float(i) * 0.33 + center.x * 0.013, 1.0)
		var sp := origin + Vector2(sin(t * 5.0 + center.x) * 2.0 + t * 5.0, -t * 14.0)
		_dynamic.draw_rect(Rect2(sp.snapped(Vector2(ART, ART)), Vector2.ONE * (1.0 + t * 2.0) * ART), Color(0.86, 0.84, 0.8, 0.5 * (1.0 - t)))
	# Flag.
	var pole := r.position + Vector2(sz.x * 0.82, sz.y * 0.08)
	_dynamic.draw_line(pole, pole + Vector2(0, -12), Color("3a2a1c"), 1.5)
	var wave: float = sin(_time * 4.0 + center.x)
	var flag := PackedVector2Array([pole + Vector2(0, -12), pole + Vector2(9, -11 + wave), pole + Vector2(9, -6 + wave), pole + Vector2(0, -7)])
	_dynamic.draw_colored_polygon(flag, nation_col)
	# Goods piling up faster than the route can carry them.
	if c.tier > 0 and c.stock > Balance.cargo_capacity(Game.run, Game.meta, c) * 1.5:
		var bounce: float = absf(sin(_time * 3.0)) * 3.0
		_dynamic.draw_texture_rect(UI.icon("crate"), Rect2(r.position + Vector2(sz.x * 0.72, sz.y * 0.4 - bounce), Vector2(14, 14)), false)


func _draw_site(site_index: int) -> void:
	var center: Vector2 = site_world(site_index)
	var afford: bool = Game.run.gold >= Balance.found_cost(Game.run, Game.meta)
	if afford:
		var pulse: float = 0.5 + 0.5 * sin(_time * 4.0)
		_dynamic.draw_circle(center + Vector2(0, -4), 26.0 + pulse * 4.0, Color(1, 0.85, 0.4, 0.22 + pulse * 0.15))
	var tex: Texture2D = _sprites["site"]
	var sz: Vector2 = tex.get_size() / SPRITE_DENSITY * ART * 1.2
	var bob: float = sin(_time * 2.5) * 1.5
	_dynamic.draw_texture_rect(tex, Rect2(center - Vector2(sz.x / 2, sz.y * 0.85 - bob), sz), false)


func _draw_clouds() -> void:
	var ws := Vector2(WorldMap.W, WorldMap.H) * TILE
	for i in 7:
		var speed: float = 5.0 + float(i) * 1.3
		var x: float = fmod(_time * speed + float(i) * 311.0, ws.x + 400.0) - 200.0
		var y: float = fmod(float(i) * 577.0 + 140.0, ws.y)
		for j in 4:
			var off := Vector2(float(j) * 34.0 - 50.0, sin(float(i * 3 + j)) * 14.0)
			_dynamic.draw_circle(Vector2(x, y) + off, 40.0 + float((i + j) % 3) * 12.0, Color(0.05, 0.08, 0.12, 0.04))


func _update_treasure(delta: float) -> void:
	if not is_visible_in_tree():
		return
	if _treasure != null:
		_treasure_age += delta
		_treasure = (_treasure as Vector2) + Vector2(3.0 * delta, sin(_time * 0.7) * 1.5 * delta)
		if _treasure_age > Balance.v("treasure_lifetime_seconds"):
			_treasure = null
			_treasure_timer = randf_range(Balance.v("treasure_min_seconds"), Balance.v("treasure_max_seconds"))
		return
	_treasure_timer -= delta
	if _treasure_timer > 0.0:
		return
	var w: WorldMap = Game.run.world
	var ex: PackedByteArray = Game.run.explored(Balance.explore_mult(Game.run))
	for attempt in 40:
		var sp := Vector2(randf_range(40.0, size.x - 80.0), randf_range(60.0, size.y - 120.0))
		var wp: Vector2 = screen_to_world(sp)
		var t := Vector2i(wp / TILE)
		if w.is_ocean(t.x, t.y) and w.water_depth[w.idx(t.x, t.y)] >= 2.0 and ex[w.idx(t.x, t.y)] == 1:
			_treasure = wp
			_treasure_age = 0.0
			return
	_treasure_timer = 5.0


func _draw_treasure() -> void:
	if _treasure == null:
		return
	var p: Vector2 = _treasure
	var tex: Texture2D = _sprites["chest"]
	var sz: Vector2 = tex.get_size() / SPRITE_DENSITY * ART * 1.3
	var bob: float = sin(_time * 3.0) * 2.0
	var fade: float = clampf((Balance.v("treasure_lifetime_seconds") - _treasure_age) / 3.0, 0.0, 1.0)
	var pulse: float = 0.5 + 0.5 * sin(_time * 5.0)
	_dynamic.draw_circle(p, 24.0 + pulse * 5.0, Color(1.0, 0.78, 0.25, (0.28 + pulse * 0.2) * fade))
	_dynamic.draw_texture_rect(tex, Rect2(p - sz / 2.0 + Vector2(0, bob), sz), false, Color(1, 1, 1, fade))


# --- Screen-space labels ------------------------------------------------------------

func _draw_labels() -> void:
	if Game.run == null:
		return
	var run: RunState = Game.run
	var show_names: bool = _zoom >= 0.8
	for c: RunState.ColonyState in run.colonies:
		var sp: Vector2 = world_to_screen(colony_world(c))
		if not Rect2(Vector2(-80, -80), size + Vector2(160, 160)).has_point(sp):
			continue
		var below: float = 0.4 * 64.0 * _zoom
		if show_names or c.tier == 0:
			_plate(sp + Vector2(0, below), Content.colony_name(run.nation_id, c.tier), c.tier == 0, UI.LIGHT, Color(0.13, 0.09, 0.06, 0.8))
		if c.colonists > 0 and _zoom >= 0.55:
			var box := Rect2(sp + Vector2(-26 * _zoom - 18, -30 * _zoom - 10), Vector2(20, 18))
			_labels.draw_rect(box, Color("f5e9cc"))
			_labels.draw_rect(box, Color("2c1e14"), false, 2.0)
			_labels.draw_string(_font, box.position + Vector2(0, 14), str(c.colonists), HORIZONTAL_ALIGNMENT_CENTER, box.size.x, 14, Color("2c1e14"))
	var n: int = run.next_site()
	if n >= 0 and _zoom >= 0.6:
		var sp2: Vector2 = world_to_screen(site_world(n))
		var cost: float = Balance.found_cost(run, Game.meta)
		var afford: bool = run.gold >= cost
		_plate(sp2 + Vector2(0, 18 * _zoom + 6), "Found  " + Format.num(cost), false, UI.LIGHT, Color(0.3, 0.52, 0.22, 0.92) if afford else Color(0.13, 0.09, 0.06, 0.8), "gold")
	for f: Dictionary in _floaters:
		var t: float = float(f["t"])
		var a: float = clampf(1.6 - t, 0.0, 1.0)
		var p: Vector2 = world_to_screen(f["pos"]) + Vector2(0, -t * 40.0)
		_labels.draw_texture_rect(UI.icon(str(f["icon"])), Rect2(p + Vector2(-32, -22), Vector2(26, 26)), false, Color(1, 1, 1, a))
		_labels.draw_string_outline(_font, p, str(f["text"]), HORIZONTAL_ALIGNMENT_LEFT, -1, 20, 6, Color(0.1, 0.07, 0.05, a))
		_labels.draw_string(_font, p, str(f["text"]), HORIZONTAL_ALIGNMENT_LEFT, -1, 20, Color((f["color"] as Color), a))


func _plate(at: Vector2, text: String, bold: bool, fg: Color, bg: Color, icon_name: String = "") -> void:
	var fs: int = 18 if not bold else 20
	var icon_w: float = 26.0 if icon_name != "" else 0.0
	var w: float = _font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x + 16.0 + icon_w
	var r := Rect2(at - Vector2(w / 2, 0), Vector2(w, fs + 10))
	_labels.draw_rect(r, bg)
	_labels.draw_rect(r, Color(0.78, 0.6, 0.3, 0.9), false, 1.5)
	_labels.draw_string(_font, r.position + Vector2(8, fs + 2), text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, fg)
	if icon_name != "":
		_labels.draw_texture_rect(UI.icon(icon_name), Rect2(r.position + Vector2(w - 30, 3), Vector2(22, 22)), false)


## A drag or pinch in progress when the app loses focus would otherwise stick.
func _notification(what: int) -> void:
	if what in [NOTIFICATION_APPLICATION_PAUSED, NOTIFICATION_APPLICATION_FOCUS_OUT, NOTIFICATION_WM_WINDOW_FOCUS_OUT]:
		_touches.clear()
		_dragging = false
