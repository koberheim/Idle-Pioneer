## Start of every run: pick the nation you sail for. Between runs this is also
## where Liberty is spent on permanent reforms.
class_name NationSelect
extends Control

signal nation_chosen(nation_id: String)

var _reform_rows: Dictionary = {}
var _liberty_label: Label


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	var bg := TextureRect.new()
	bg.texture = UI.tex("res://assets/sprites/map.png")
	bg.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	bg.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	bg.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(bg)
	var dim := ColorRect.new()
	dim.color = Color(0.06, 0.05, 0.08, 0.55)
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
	sub.custom_minimum_size.x = 10
	sub.add_theme_color_override("font_outline_color", Color("1a120c"))
	sub.add_theme_constant_override("outline_size", 6)
	v.add_child(sub)

	if runs > 0 or Game.meta.liberty > 0:
		v.add_child(_reforms_panel())

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
		nation_chosen.emit(id))
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
	var icons: Dictionary = {"industry": "pick", "navigation": "ship_icon", "settlement": "colonist", "commerce": "gold"}
	for def: Dictionary in Content.liberty_upgrades:
		var id: String = def["id"]
		var row := UpgradeRow.new(str(icons.get(id, "star")), func() -> bool:
			var ok: bool = Game.buy_liberty_upgrade(id)
			_refresh_reforms()
			return ok)
		_reform_rows[id] = row
		v.add_child(row)
	return card


func _refresh_reforms() -> void:
	if _liberty_label == null:
		return
	_liberty_label.text = "%d Liberty to spend" % Game.meta.liberty
	for id: String in _reform_rows.keys():
		var def: Dictionary = Content.liberty_upgrade(id)
		var row: UpgradeRow = _reform_rows[id]
		var lvl: int = Game.meta.level(id)
		var cost: int = Balance.liberty_upgrade_cost(Game.meta, id)
		row.title.text = "%s  %d/%d" % [def["name"], lvl, (def["costs"] as Array).size()]
		row.detail.text = str(def["desc"])
		if cost < 0:
			row.buy.set_cost("Complete", false, "")
		else:
			row.buy.set_cost(str(cost), Game.meta.liberty >= cost, "liberty")
