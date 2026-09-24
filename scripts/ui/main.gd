## Root of the game screen: top bar, the four tabs (New World map, Workshops,
## Europe, Congress), the sliding colony sheet, and every overlay.
extends Control

const REFRESH_SECONDS := 0.2
const TAB_NAMES: Array[String] = ["New World", "Workshops", "Europe", "Congress"]
const TAB_ICONS: Array[String] = ["map", "hammer", "ship_icon", "quill"]

var _gold_label: Label
var _income_label: Label
var _liberty_label: Label
var _colonist_label: Label
var _content: Control
var _map: MapView
var _pages: Array[Control] = []
var _tab_buttons: Array[Button] = []
var _tab: int = 0
var _sheet: ColonySheet
var _sheet_t: float = 0.0
var _sheet_tween: Tween
var _advisor: Advisor
var _overlay: Control
var _toasts: Toasts
var _nation_select: NationSelect
var _refresh_timer: float = 0.0
var _advisor_timer: float = 0.0
var _last_ship_sound: int = 0
var _top_pad: float = 0.0


func _ready() -> void:
	theme = UI.theme()
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_top_pad = _safe_top()
	_build()
	Game.offline_progress.connect(_on_offline)
	Game.colony_founded.connect(_on_founded)
	Game.resource_discovered.connect(_on_discovered)
	Game.father_joined.connect(func(id: String) -> void:
		_toasts.push("%s joins the Continental Congress!" % Content.father(id)["name"], "quill", 3.5))
	Game.workshop_built.connect(func(id: String) -> void:
		Sfx.play("found")
		_toasts.push("%s built. Assign colonists to begin." % Content.recipe(id)["building"], "hammer"))
	Game.shipment_arrived.connect(_on_shipment)
	get_tree().root.size_changed.connect(_layout_sheet)

	if Game.boot():
		_start_ui()
	else:
		_show_nation_select()


func _safe_top() -> float:
	if not OS.has_feature("mobile"):
		return 0.0
	var safe: Rect2i = DisplayServer.get_display_safe_area()
	var screen: Vector2i = DisplayServer.screen_get_size()
	if screen.y <= 0:
		return 0.0
	return float(safe.position.y) * get_viewport_rect().size.y / float(screen.y)


# --- Construction ---------------------------------------------------------------

func _build() -> void:
	var bg := ColorRect.new()
	bg.color = Color("161d33")
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(bg)

	var root := UI.vbox(0)
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(root)
	root.add_child(_build_top_bar())

	_content = Control.new()
	_content.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_content.clip_contents = true
	root.add_child(_content)

	_map = MapView.new()
	_map.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_map.colony_tapped.connect(_open_colony)
	_content.add_child(_map)
	_pages.append(_map)

	var workshops := WorkshopsPage.new()
	var europe := EuropePage.new()
	var congress := CongressPage.new()
	congress.declare_requested.connect(_show_independence)
	for p: Control in [workshops, europe, congress]:
		p.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		p.visible = false
		_content.add_child(p)
		_pages.append(p)

	_advisor = Advisor.new()
	_advisor.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
	_advisor.offset_left = 14
	_advisor.offset_right = -14
	_advisor.offset_bottom = -12
	_advisor.grow_vertical = Control.GROW_DIRECTION_BEGIN
	_advisor.go.connect(_on_advisor_go)
	_content.add_child(_advisor)

	_sheet = ColonySheet.new()
	_sheet.visible = false
	_sheet.closed.connect(_close_sheet)
	_content.add_child(_sheet)

	root.add_child(_build_nav())

	_overlay = Control.new()
	_overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_overlay)
	_toasts = Toasts.new()
	_toasts.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
	_toasts.offset_top = 118 + _top_pad
	_toasts.offset_left = 30
	_toasts.offset_right = -30
	_overlay.add_child(_toasts)


func _build_top_bar() -> Control:
	var bar := PanelContainer.new()
	var sb := UI.frame("panel_dark", 14, 12)
	sb.content_margin_top = 10.0 + _top_pad
	bar.add_theme_stylebox_override("panel", sb)
	var row := UI.hbox(10)
	bar.add_child(row)

	row.add_child(UI.icon_rect(UI.icon("gold"), 52))
	var gv := UI.vbox(-4)
	_gold_label = UI.label("0", 34, UI.GOLD, true)
	_income_label = UI.label("", UI.SIZE_SMALL, UI.LIGHT_SOFT)
	gv.add_child(_gold_label)
	gv.add_child(_income_label)
	gv.custom_minimum_size.x = 200
	row.add_child(gv)
	row.add_child(UI.spacer())

	row.add_child(UI.icon_rect(UI.icon("colonist"), 40))
	_colonist_label = UI.label("", UI.SIZE_BODY, UI.LIGHT)
	row.add_child(_colonist_label)
	row.add_child(UI.icon_rect(UI.icon("liberty"), 40))
	_liberty_label = UI.label("", UI.SIZE_BODY, UI.LIGHT)
	row.add_child(_liberty_label)

	var gear := Button.new()
	gear.icon = UI.icon("gear")
	gear.expand_icon = true
	gear.focus_mode = Control.FOCUS_NONE
	gear.custom_minimum_size = Vector2(68, 68)
	gear.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	gear.add_theme_constant_override("icon_max_width", 40)
	gear.pressed.connect(_show_settings)
	row.add_child(gear)
	return bar


func _build_nav() -> Control:
	var bar := PanelContainer.new()
	bar.add_theme_stylebox_override("panel", UI.frame("panel_dark", 14, 6))
	var row := UI.hbox(6)
	bar.add_child(row)
	for i in TAB_NAMES.size():
		var b := Button.new()
		b.text = TAB_NAMES[i]
		b.icon = UI.icon(TAB_ICONS[i])
		b.expand_icon = true
		b.icon_alignment = HORIZONTAL_ALIGNMENT_CENTER
		b.vertical_icon_alignment = VERTICAL_ALIGNMENT_TOP
		b.add_theme_constant_override("icon_max_width", 44)
		b.add_theme_font_size_override("font_size", UI.SIZE_SMALL)
		b.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		b.focus_mode = Control.FOCUS_NONE
		b.custom_minimum_size.y = 104
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		var idx: int = i
		b.pressed.connect(func() -> void:
			Sfx.play("tab")
			_select_tab(idx))
		row.add_child(b)
		_tab_buttons.append(b)
	_style_tabs()
	return bar


func _style_tabs() -> void:
	for i in _tab_buttons.size():
		var b: Button = _tab_buttons[i]
		var on: bool = i == _tab
		var style: String = "tab_active" if on else "tab"
		for s: String in ["normal", "hover", "pressed", "hover_pressed"]:
			b.add_theme_stylebox_override(s, UI.frame(style, 14, 6))
		var col: Color = UI.INK if on else UI.LIGHT_SOFT
		for s: String in ["font_color", "font_hover_color", "font_pressed_color", "font_hover_pressed_color"]:
			b.add_theme_color_override(s, col)


# --- Flow -----------------------------------------------------------------------

func _show_nation_select() -> void:
	_close_sheet()
	_nation_select = NationSelect.new()
	_nation_select.nation_chosen.connect(func(id: String) -> void:
		Game.start_run(id)
		_nation_select.queue_free()
		_nation_select = null
		_start_ui()
		_toasts.push("Your ships make landfall. Welcome to %s!" % Content.colony_name(id, 0), "ship_icon", 4.0))
	_overlay.add_child(_nation_select)
	_overlay.move_child(_nation_select, 0)


func _start_ui() -> void:
	_select_tab(0)
	_map.scroll_to_colony_at("capital", 0.35, false)
	Sfx.sync_music()
	_refresh()


func _select_tab(i: int) -> void:
	_tab = i
	for j in _pages.size():
		_pages[j].visible = j == i
	if i != 0:
		_close_sheet()
	_style_tabs()
	_advisor.visible = false
	_refresh()


func _open_colony(id: String) -> void:
	if _tab != 0:
		_select_tab(0)
	Sfx.play("click")
	_sheet.show_colony(id)
	_sheet.visible = true
	_map.set_highlight(id)
	_animate_sheet(1.0)
	_map.scroll_to_colony_at(id, 0.22)


func _close_sheet() -> void:
	if _sheet == null or not _sheet.visible:
		return
	_map.set_highlight("")
	_animate_sheet(0.0)


func _animate_sheet(target: float) -> void:
	if _sheet_tween != null:
		_sheet_tween.kill()
	_sheet_tween = create_tween()
	_sheet_tween.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	_sheet_tween.tween_method(func(t: float) -> void:
		_sheet_t = t
		_layout_sheet(), _sheet_t, target, 0.25)
	if target <= 0.0:
		_sheet_tween.tween_callback(func() -> void: _sheet.visible = false)


func _layout_sheet() -> void:
	if _sheet == null:
		return
	var w: float = _content.size.x
	_sheet.size = Vector2(w, 0)
	var h: float = _sheet.get_combined_minimum_size().y
	h = minf(h, _content.size.y)
	_sheet.size = Vector2(w, h)
	_sheet.position = Vector2(0, _content.size.y - h * _sheet_t)


func _on_advisor_go(target: String) -> void:
	if target.begins_with("colony:"):
		_open_colony(target.substr(7))
	elif target.begins_with("tab:"):
		_select_tab(int(target.substr(4)))


func _show_independence() -> void:
	var o := IndependenceOverlay.new()
	o.signed.connect(func() -> void:
		var liberty: int = Game.declare_independence()
		_show_nation_select()
		_toasts.push("Independence! You earned %d Liberty." % liberty, "liberty", 5.0))
	_overlay.add_child(o)


# --- Events ---------------------------------------------------------------------

func _on_offline(seconds: float, ev: SimEvents) -> void:
	var m := Modal.new("While You Were Away")
	var capped: float = minf(seconds, Balance.offline_cap_seconds(Game.run))
	m.add_text("Your colonies kept working for %s." % Format.duration(capped), UI.SIZE_BODY, UI.INK_SOFT)
	if seconds > capped + 1.0:
		m.add_text("(Colonists rest after %s without their governor.)" % Format.duration(Balance.offline_cap_seconds(Game.run)), UI.SIZE_SMALL, UI.INK_SOFT)
	m.add_line("gold", "+%s gold" % Format.num(ev.gold_earned))
	if ev.shipments.size() > 0:
		m.add_line("ship_icon", "%d shipment%s landed" % [ev.shipments.size(), "" if ev.shipments.size() == 1 else "s"])
	var crafted: float = 0.0
	for k: String in ev.crafted.keys():
		crafted += float(ev.crafted[k])
	if crafted > 0.0:
		m.add_line("hammer", "%s goods crafted" % Format.num(crafted))
	m.add_button("Splendid", "button_gold")
	_overlay.add_child(m)
	Sfx.play("coin")


func _on_founded(id: String) -> void:
	Sfx.play("found")
	var name: String = Content.colony_name(Game.run.nation_id, Content.colony_index(id))
	_toasts.push("%s is founded!" % name, "colonist", 3.5)
	_sheet.refresh()


func _on_discovered(id: String) -> void:
	if id == "timber":
		return
	Sfx.play("discover")
	var extra: String = " New workshops may be possible." if not Content.is_crafted(id) else ""
	_toasts.push("%s reaches the capital for the first time.%s" % [Content.resource_name(id), extra], id, 3.5)


func _on_shipment(_colony_id: String, _res: String, _qty: float) -> void:
	if _tab != 0:
		return
	var now: int = Time.get_ticks_msec()
	if now - _last_ship_sound > 5000:
		_last_ship_sound = now
		Sfx.play("coin")


func _show_settings() -> void:
	Sfx.play("click")
	var m := Modal.new("Settings")
	var music := UI.button("", "button", 64)
	var sound := UI.button("", "button", 64)
	var sync := func() -> void:
		music.text = "Music: " + ("On" if Game.meta.music_on else "Off")
		sound.text = "Sound: " + ("On" if Game.meta.sfx_on else "Off")
	sync.call()
	music.pressed.connect(func() -> void:
		Game.meta.music_on = not Game.meta.music_on
		Sfx.sync_music()
		sync.call())
	sound.pressed.connect(func() -> void:
		Game.meta.sfx_on = not Game.meta.sfx_on
		Sfx.play("click")
		sync.call())
	m.body.add_child(music)
	m.body.add_child(sound)
	var meta: MetaState = Game.meta
	var stats: String = "Independence declared: %d times\nLiberty earned in all: %d" % [meta.runs_completed, meta.lifetime_liberty]
	if meta.fastest_run_seconds > 0.0:
		stats += "\nFastest independence: %s" % Format.duration(meta.fastest_run_seconds)
	if Game.run != null:
		stats += "\nThis run: %s played, %d shipments" % [Format.duration(Game.run.play_seconds), Game.run.shipments]
	m.add_text(stats, UI.SIZE_SMALL, UI.INK_SOFT)
	var reset := UI.button("Reset all progress", "button", 56)
	reset.add_theme_font_size_override("font_size", UI.SIZE_SMALL)
	for s: String in ["normal", "hover"]:
		reset.add_theme_stylebox_override(s, UI.frame("button_disabled", 14, 8))
	for s: String in ["font_color", "font_hover_color"]:
		reset.add_theme_color_override(s, UI.RED)
	reset.pressed.connect(func() -> void:
		m.close()
		_confirm_reset())
	m.body.add_child(reset)
	m.add_button("Close", "button_gold", func() -> void: Game.save())
	_overlay.add_child(m)


func _confirm_reset() -> void:
	var m := Modal.new("Reset Everything?")
	m.add_text("This erases every colony, all Liberty and every reform. It cannot be undone.")
	m.add_button("Cancel", "button_gold")
	m.add_button("Erase", "button", func() -> void:
		Game.reset_all_progress()
		_show_nation_select())
	_overlay.add_child(m)


func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_GO_BACK_REQUEST:
		for c: Node in _overlay.get_children():
			if c is Modal:
				(c as Modal).close()
				return
		if _sheet != null and _sheet.visible:
			_close_sheet()
		elif _tab != 0:
			_select_tab(0)


# --- Refresh --------------------------------------------------------------------

func _process(delta: float) -> void:
	_refresh_timer += delta
	if _refresh_timer >= REFRESH_SECONDS:
		_refresh_timer = 0.0
		_refresh()
	_advisor_timer += delta
	if _advisor_timer >= 1.0:
		_advisor_timer = 0.0
		if _tab == 0 and Game.run != null and not _sheet.visible:
			_advisor.refresh()
		else:
			_advisor.visible = false
	if _sheet.visible:
		_layout_sheet()


func _refresh() -> void:
	if Game.run == null:
		return
	var run: RunState = Game.run
	_gold_label.text = Format.num(run.gold)
	_income_label.text = "+%s / sec" % Format.num(Game.income_rate, 1)
	_liberty_label.text = str(Game.meta.liberty)
	_colonist_label.text = "%d/%d" % [run.colonists_idle(), run.colonists_owned]
	if _tab > 0:
		(_pages[_tab] as Page).refresh()
	if _sheet.visible:
		_sheet.refresh()
	# Flag tabs that have something to act on.
	var ready: bool = Balance.independence_ready(run)
	_tab_buttons[3].text = TAB_NAMES[3] + (" !" if ready else "")
