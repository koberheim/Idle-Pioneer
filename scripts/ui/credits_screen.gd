## Credits & Licenses: who made what, and the license texts the game must
## carry (Godot and its third-party components, the fonts).
class_name CreditsScreen
extends Control

const CREDITS_PATH := "res://data/credits.json"


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	var bg := PanelContainer.new()
	bg.add_theme_stylebox_override("panel", UI.frame("panel_dark", 14, 0))
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(bg)
	var root := UI.vbox(10)
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.offset_left = 16
	root.offset_right = -16
	root.offset_top = 16
	root.offset_bottom = -16
	add_child(root)
	var head := UI.hbox(10)
	var title := UI.label("Credits & Licenses", UI.SIZE_TITLE, UI.GOLD, true)
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(title)
	var close := UI.button("✕", "button", 60)
	close.custom_minimum_size.x = 60
	close.pressed.connect(func() -> void:
		Sfx.play("click")
		queue_free())
	head.add_child(close)
	root.add_child(head)

	var scroll := ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_RESERVE
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	root.add_child(scroll)
	var list := UI.vbox(12)
	list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(list)

	var data: Dictionary = {}
	var f := FileAccess.open(CREDITS_PATH, FileAccess.READ)
	if f != null:
		var parsed: Variant = JSON.parse_string(f.get_as_text())
		if parsed is Dictionary:
			data = parsed
	for s: Variant in data.get("sections", []):
		var sec: Dictionary = s
		var card := UI.card("card")
		var v := UI.vbox(4)
		card.add_child(v)
		v.add_child(UI.label(str(sec.get("title", "")), UI.SIZE_BIG, UI.INK, true))
		for line: Variant in sec.get("lines", []):
			v.add_child(UI.wrap_label(str(line), UI.SIZE_SMALL, UI.INK))
		list.add_child(card)

	list.add_child(UI.label("Licenses", UI.SIZE_BIG, UI.GOLD, true))
	for l: Variant in data.get("licenses", []):
		var lic: Dictionary = l
		var name: String = str(lic.get("name", ""))
		var file: String = str(lic.get("file", ""))
		var b := UI.button(name, "button", 56)
		b.add_theme_font_size_override("font_size", UI.SIZE_SMALL)
		b.pressed.connect(func() -> void: _show_license(name, file))
		list.add_child(b)


func _show_license(name: String, file: String) -> void:
	Sfx.play("click")
	var text: String = ""
	if file == "engine":
		text = Engine.get_license_text() + "\n\n" + _third_party()
	else:
		var f := FileAccess.open(file, FileAccess.READ)
		text = f.get_as_text() if f != null else "(license file missing)"
	var m := Control.new()
	m.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	m.mouse_filter = Control.MOUSE_FILTER_STOP
	var bg := PanelContainer.new()
	bg.add_theme_stylebox_override("panel", UI.frame("panel", 14, 20))
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	m.add_child(bg)
	var v := UI.vbox(10)
	bg.add_child(v)
	var head := UI.hbox(10)
	var t := UI.label(name, UI.SIZE_BIG, UI.INK, true)
	t.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	t.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	t.resized.connect(t.update_minimum_size)
	t.custom_minimum_size.x = 10
	head.add_child(t)
	var close := UI.button("✕", "button", 60)
	close.custom_minimum_size.x = 60
	close.pressed.connect(func() -> void: m.queue_free())
	head.add_child(close)
	v.add_child(head)
	var body := RichTextLabel.new()
	body.text = text
	body.scroll_active = true
	body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	body.add_theme_font_size_override("normal_font_size", 16)
	v.add_child(body)
	add_child(m)


func _third_party() -> String:
	var out: PackedStringArray = ["Third-party components:"]
	for info: Dictionary in Engine.get_copyright_info():
		out.append("\n" + str(info.get("name", "")))
		for part: Dictionary in info.get("parts", []):
			var files: String = ", ".join(PackedStringArray(part.get("files", [])))
			var holders: String = "; ".join(PackedStringArray(part.get("copyright", [])))
			out.append("  %s  (%s)  %s" % [files, str(part.get("license", "")), holders])
	var licenses: Dictionary = Engine.get_license_info()
	for k: String in licenses.keys():
		out.append("\n--- %s ---\n%s" % [k, str(licenses[k])])
	return "\n".join(out)
