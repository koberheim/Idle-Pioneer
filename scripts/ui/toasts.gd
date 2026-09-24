## Short-lived notices that slide in below the top bar.
class_name Toasts
extends VBoxContainer

const MAX_VISIBLE := 3


func _init() -> void:
	add_theme_constant_override("separation", 6)
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func push(text: String, icon_name: String = "star", seconds: float = 3.0) -> void:
	while get_child_count() >= MAX_VISIBLE:
		var old: Node = get_child(0)
		remove_child(old)
		old.queue_free()
	var p := PanelContainer.new()
	p.add_theme_stylebox_override("panel", UI.frame("panel_dark", 14, 10))
	p.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var row := UI.hbox(10)
	row.add_child(UI.icon_rect(UI.icon(icon_name), 36))
	var l := UI.label(text, UI.SIZE_SMALL, UI.LIGHT)
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.resized.connect(l.update_minimum_size)
	l.custom_minimum_size.x = 10
	l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(l)
	p.add_child(row)
	p.modulate.a = 0.0
	add_child(p)
	var tw := p.create_tween()
	tw.tween_property(p, "modulate:a", 1.0, 0.2)
	tw.tween_interval(seconds)
	tw.tween_property(p, "modulate:a", 0.0, 0.4)
	tw.tween_callback(p.queue_free)
