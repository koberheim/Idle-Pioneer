## Base for the scrolling tab pages: a wooden backdrop, a header, and a list
## of cards. Subclasses fill `list` and update it in refresh().
class_name Page
extends Control

var list: VBoxContainer
var scroll: ScrollContainer


func _ready() -> void:
	var bg := PanelContainer.new()
	bg.add_theme_stylebox_override("panel", UI.frame("panel_dark", 14, 0))
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(bg)

	scroll = ScrollContainer.new()
	scroll.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	scroll.offset_left = 14
	scroll.offset_right = -14
	scroll.offset_top = 12
	scroll.offset_bottom = -8
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_RESERVE
	add_child(scroll)

	var outer := UI.vbox(14)
	outer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(outer)
	var header := UI.vbox(10)
	outer.add_child(header)
	_build_header(header)
	list = UI.vbox(14)
	list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	outer.add_child(list)
	var pad := Control.new()
	pad.custom_minimum_size.y = 24
	outer.add_child(pad)


func _build_header(_box: VBoxContainer) -> void:
	pass


func refresh() -> void:
	pass


func clear_list() -> void:
	for c: Node in list.get_children():
		list.remove_child(c)
		c.queue_free()


func page_title(text: String, subtitle: String = "") -> Control:
	var v := UI.vbox(2)
	v.add_child(UI.label(text, UI.SIZE_TITLE, UI.GOLD, true))
	if subtitle != "":
		v.add_child(UI.wrap_label(subtitle, UI.SIZE_SMALL, UI.LIGHT_SOFT))
	return v


func section(text: String) -> Label:
	var l := UI.label(text, UI.SIZE_BIG, UI.GOLD, true)
	return l
