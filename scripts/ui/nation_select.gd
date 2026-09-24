## Start of every run: pick the nation you sail for. Between runs this is also
## where Liberty is spent on permanent reforms.
class_name NationSelect
extends Control

signal nation_chosen(nation_id: String, map_style: String)

var _reform_rows: Dictionary = {}
var _liberty_label: Label
var _roster: GovernorRoster
var _map_style: String = WorldMap.STYLE_RANDOM
var _style_buttons: Dictionary = {}


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	# A sample coast, rendered live, behind the menu.
	var sample := WorldMap.build(WorldMap.STYLE_RANDOM, 1607)
	var data := ImageTexture.create_from_image(MapView.build_data_image(sample, PackedByteArray()))
	var mat := ShaderMaterial.new()
	mat.shader = preload("res://assets/shaders/terrain.gdshader")
	mat.set_shader_parameter("data_n", data)
	mat.set_shader_parameter("data_l", data)
	mat.set_shader_parameter("relief", ImageTexture.create_from_image(MapView.build_relief_image(sample)))
	mat.set_shader_parameter("grid", Vector2(WorldMap.W, WorldMap.H))
	var bg := TextureRect.new()
	bg.texture = data
	bg.material = mat
	bg.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	bg.stretch_mode = TextureRect.STRETCH_SCALE
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(bg)
	var dim := ColorRect.new()
	dim.color = Color(0.06, 0.05, 0.08, 0.35)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(dim)

	var scroll := ScrollContainer.new()
	scroll.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	add_child(scroll)
	var margin := MarginContainer.new()
	margin.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	for side: String in ["left", "right"]:
		margin.add_theme_constant_override("margin_" + side, 28)
	margin.add_theme_constant_override("margin_top", 60)
	margin.add_theme_constant_override("margin_bottom", 40)
	scroll.add_child(margin)
	var v := UI.vbox(16)
	margin.add_child(v)

	var title := UI.label("Idle Pioneer", 64, UI.GOLD, true)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_color_override("font_outline_color", Color("1a120c"))
	title.add_theme_constant_override("outline_size", 10)
	v.add_child(title)

	var runs: int = Game.meta.runs_completed
	var sub_text: String = "The year is 1607. A new world lies across the Atlantic." if runs == 0 else "A new frontier awaits. Expedition #%d." % (runs + 1)
	var sub := UI.label(sub_text, UI.SIZE_BODY, UI.LIGHT)
	sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	sub.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	sub.resized.connect(sub.update_minimum_size)
	sub.custom_minimum_size.x = 10
	sub.add_theme_color_override("font_outline_color", Color("1a120c"))
	sub.add_theme_constant_override("outline_size", 6)
	v.add_child(sub)

	if runs > 0 or Game.meta.liberty > 0:
		v.add_child(_reforms_panel())

	var map_label := UI.label("Which shore?", UI.SIZE_BIG, UI.LIGHT, true)
	map_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	map_label.add_theme_color_override("font_outline_color", Color("1a120c"))
	map_label.add_theme_constant_override("outline_size", 6)
	v.add_child(map_label)
	var styles := UI.hbox(12)
	for spec: Array in [[WorldMap.STYLE_RANDOM, "Uncharted Coast", "A new land every time"], [WorldMap.STYLE_NORTH_AMERICA, "North America", "The coast as history knew it"]]:
		var b := Button.new()
		b.focus_mode = Control.FOCUS_NONE
		b.custom_minimum_size = Vector2(0, 104)
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		var bv := UI.vbox(0)
		bv.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		bv.alignment = BoxContainer.ALIGNMENT_CENTER
		bv.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var t1 := UI.label(spec[1], UI.SIZE_BIG, UI.INK, true)
		t1.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		var t2 := UI.label(spec[2], UI.SIZE_SMALL, UI.INK_SOFT)
		t2.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		bv.add_child(t1)
		bv.add_child(t2)
		b.add_child(bv)
		var style_id: String = spec[0]
		b.pressed.connect(func() -> void:
			_map_style = style_id
			Sfx.play("click")
			_sync_styles())
		_style_buttons[style_id] = b
		styles.add_child(b)
	v.add_child(styles)
	_sync_styles()

	var pick := UI.label("Choose the Crown you sail for", UI.SIZE_BIG, UI.LIGHT, true)
	pick.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	pick.add_theme_color_override("font_outline_color", Color("1a120c"))
	pick.add_theme_constant_override("outline_size", 6)
	v.add_child(pick)
	for n: Dictionary in Content.nations:
		v.add_child(_nation_card(n))
	_refresh_reforms()


func _nation_card(n: Dictionary) -> Control:
	var id: String = n["id"]
	var b := Button.new()
	b.focus_mode = Control.FOCUS_NONE
	b.custom_minimum_size.y = 118
	b.add_theme_stylebox_override("normal", UI.frame("card", 14, 12))
	b.add_theme_stylebox_override("hover", UI.frame("panel", 14, 12))
	b.add_theme_stylebox_override("pressed", UI.frame("panel", 14, 12))
	var row := UI.hbox(16)
	row.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	row.offset_left = 18
	row.offset_right = -18
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var flag := Flag.new(id)
	flag.custom_minimum_size = Vector2(84, 56)
	flag.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(flag)
	var tv := UI.vbox(2)
	tv.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	tv.alignment = BoxContainer.ALIGNMENT_CENTER
	tv.mouse_filter = Control.MOUSE_FILTER_IGNORE
	tv.add_child(UI.label(str(n["name"]), UI.SIZE_BIG, UI.INK, true))
	tv.add_child(UI.label(str(n["desc"]), UI.SIZE_SMALL, UI.GREEN))
	tv.add_child(UI.label("Capital: " + Content.colony_name(id, 0), UI.SIZE_SMALL, UI.INK_SOFT))
	row.add_child(tv)
	b.add_child(row)
	b.pressed.connect(func() -> void:
		Sfx.play("found")
		nation_chosen.emit(id, _map_style))
	return b


func _reforms_panel() -> Control:
	var card := UI.card("panel")
	var v := UI.vbox(8)
	card.add_child(v)
	var head := UI.hbox(10)
	head.add_child(UI.icon_rect(UI.icon("liberty"), 48))
	var hv := UI.vbox(0)
	hv.add_child(UI.label("Liberty Reforms", UI.SIZE_BIG, UI.INK, true))
	_liberty_label = UI.label("", UI.SIZE_BODY, UI.INK)
	hv.add_child(_liberty_label)
	head.add_child(hv)
	v.add_child(head)
	var icons: Dictionary = {"industry": "pick", "navigation": "ship_icon", "settlement": "colonist", "commerce": "gold", "manufacture": "hammer"}
	for def: Dictionary in Content.liberty_upgrades:
		var id: String = def["id"]
		var row := UpgradeRow.new(str(icons.get(id, "star")), func() -> bool:
			var ok: bool = Game.buy_liberty_upgrade(id)
			_refresh_reforms()
			return ok)
		_reform_rows[id] = row
		v.add_child(row)
	v.add_child(UI.label("Governors", UI.SIZE_BIG, UI.INK, true))
	_roster = GovernorRoster.new()
	v.add_child(_roster)
	return card


func _process(_delta: float) -> void:
	_refresh_reforms()


func _refresh_reforms() -> void:
	if _liberty_label == null:
		return
	_liberty_label.text = "%d Liberty to spend" % Game.meta.liberty
	if _roster != null:
		_roster.refresh()
	for id: String in _reform_rows.keys():
		var def: Dictionary = Content.liberty_upgrade(id)
		var row: UpgradeRow = _reform_rows[id]
		var lvl: int = Game.meta.level(id)
		var cost: int = Balance.liberty_upgrade_cost(Game.meta, id)
		row.title.text = "%s  Lv %d" % [def["name"], lvl]
		row.detail.text = str(def["desc"])
		if cost < 0:
			row.buy.set_cost("Complete", false, "")
		else:
			row.buy.set_cost(str(cost), Game.meta.liberty >= cost, "liberty")


func _sync_styles() -> void:
	for id: String in _style_buttons.keys():
		var b: Button = _style_buttons[id]
		var style: String = "button_gold" if id == _map_style else "card"
		for st: String in ["normal", "hover", "pressed", "hover_pressed"]:
			b.add_theme_stylebox_override(st, UI.frame(style, 14, 8))
