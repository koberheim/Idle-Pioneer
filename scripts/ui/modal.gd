## A centred parchment dialog over a dimmed screen.
class_name Modal
extends Control

signal dismissed

var body: VBoxContainer
var buttons: HBoxContainer
var panel: PanelContainer


func _init(title: String) -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	var dim := ColorRect.new()
	dim.color = Color(0.05, 0.04, 0.03, 0.72)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(dim)
	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(center)
	panel = PanelContainer.new()
	panel.add_theme_stylebox_override("panel", UI.frame("panel", 14, 26))
	panel.custom_minimum_size.x = 620
	center.add_child(panel)
	var v := UI.vbox(14)
	panel.add_child(v)
	var t := UI.label(title, UI.SIZE_TITLE, UI.INK, true)
	t.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(t)
	body = UI.vbox(10)
	v.add_child(body)
	buttons = UI.hbox(12)
	buttons.alignment = BoxContainer.ALIGNMENT_CENTER
	v.add_child(buttons)


func add_text(text: String, size: int = UI.SIZE_BODY, color: Color = UI.INK) -> Label:
	var l := UI.label(text, size, color)
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.custom_minimum_size.x = 10
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	body.add_child(l)
	return l


func add_line(icon_name: String, text: String) -> void:
	var row := UI.hbox(10)
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_child(UI.icon_rect(UI.icon(icon_name), 40))
	row.add_child(UI.label(text, UI.SIZE_BODY, UI.INK))
	body.add_child(row)


func add_button(text: String, style: String = "button", action: Callable = Callable()) -> Button:
	var b := UI.button(text, style, 72)
	b.custom_minimum_size.x = 220
	b.pressed.connect(func() -> void:
		Sfx.play("click")
		if action.is_valid():
			action.call()
		close())
	buttons.add_child(b)
	return b


func close() -> void:
	dismissed.emit()
	queue_free()
