## The American Philosophical Society: six branches of studies bought with
## goods and gold. Studies last for the current expedition only. Each branch
## has a main line and a few optional side paths that fork off it.
class_name ResearchScreen
extends Control

signal closed

const REFRESH_SECONDS := 0.4

var _branch: String = ""
var _tabs: Dictionary = {}  # branch id -> Button
var _list: VBoxContainer
var _scroll: ScrollContainer
var _branch_desc: Label
var _nodes: Dictionary = {}  # study id -> {card, button, reason, costs: {key: Label}, level}
var _timer: float = 0.0


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	var bg := PanelContainer.new()
	bg.add_theme_stylebox_override("panel", UI.frame("panel_dark", 14, 0))
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(bg)
	var root := UI.vbox(10)
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.offset_left = 14
	root.offset_right = -14
	root.offset_top = 14 + _safe_top()
	root.offset_bottom = -14 - _safe_bottom()
	add_child(root)

	var head := UI.hbox(12)
	head.add_child(UI.icon_rect(UI.icon("society"), 64))
	var hv := UI.vbox(0)
	hv.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hv.add_child(UI.label("The Philosophical Society", UI.SIZE_TITLE, UI.GOLD, true))
	hv.add_child(UI.wrap_label("\"For promoting useful knowledge\" - Franklin, 1743. Studies last for this expedition and are paid from goods kept in the warehouse (set them to Keeping on the Europe tab).", UI.SIZE_SMALL, UI.LIGHT_SOFT))
	head.add_child(hv)
	var close := UI.button("✕", "button", 60)
	close.custom_minimum_size.x = 60
	close.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	close.pressed.connect(func() -> void:
		Sfx.play("click")
		closed.emit()
		queue_free())
	head.add_child(close)
	root.add_child(head)

	var tabs := UI.hbox(6)
	for b: Dictionary in Content.research_branches:
		var id: String = str(b["id"])
		var t := Button.new()
		t.icon = UI.icon(str(b.get("icon", "star")))
		t.expand_icon = true
		t.icon_alignment = HORIZONTAL_ALIGNMENT_CENTER
		t.add_theme_constant_override("icon_max_width", 44)
		t.texture_filter = UI.icon_filter(44)
		t.focus_mode = Control.FOCUS_NONE
		t.custom_minimum_size = Vector2(0, 76)
		t.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		t.tooltip_text = str(b["name"])
		t.pressed.connect(func() -> void:
			Sfx.play("tab")
			_show_branch(id))
		tabs.add_child(t)
		_tabs[id] = t
	root.add_child(tabs)
	_branch_desc = UI.wrap_label("", UI.SIZE_SMALL, UI.LIGHT)
	root.add_child(_branch_desc)

	_scroll = ScrollContainer.new()
	_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	root.add_child(_scroll)
	_list = UI.vbox(10)
	_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_scroll.add_child(_list)

	if not Content.research_branches.is_empty():
		_show_branch(str(Content.research_branches[0]["id"]))


func _safe_top() -> float:
	var r: Rect2i = DisplayServer.get_display_safe_area()
	var s: Vector2i = DisplayServer.screen_get_size()
	if s.y <= 0 or r.size.y <= 0:
		return 0.0
	return float(r.position.y) * get_viewport_rect().size.y / float(s.y)


func _safe_bottom() -> float:
	var r: Rect2i = DisplayServer.get_display_safe_area()
	var s: Vector2i = DisplayServer.screen_get_size()
	if s.y <= 0 or r.size.y <= 0:
		return 0.0
	return maxf(0.0, float(s.y - r.end.y)) * get_viewport_rect().size.y / float(s.y)


func _process(delta: float) -> void:
	_timer += delta
	if _timer >= REFRESH_SECONDS:
		_timer = 0.0
		_refresh()


func _show_branch(id: String) -> void:
	_branch = id
	for bid: String in _tabs.keys():
		var t: Button = _tabs[bid]
		var style: String = "tab_active" if bid == id else "tab"
		for s: String in ["normal", "hover", "pressed", "hover_pressed"]:
			t.add_theme_stylebox_override(s, UI.frame(style, 14, 6))
	var b: Dictionary = {}
	for bd: Dictionary in Content.research_branches:
		if bd["id"] == id:
			b = bd
	for c: Node in _list.get_children():
		_list.remove_child(c)
		c.queue_free()
	_nodes.clear()
	_list.add_child(UI.label(str(b.get("name", "")), UI.SIZE_BIG, UI.GOLD, true))
	var studies: Array[Dictionary] = Content.studies_in_branch(id)
	studies.sort_custom(func(x: Dictionary, y: Dictionary) -> bool: return int(x["tier"]) < int(y["tier"]))
	# The main line first, then each side path under its own heading.
	var paths: Array[String] = [""]
	for s: Dictionary in studies:
		var p: String = str(s.get("path", ""))
		if not paths.has(p):
			paths.append(p)
	for p: String in paths:
		if p != "":
			var pname: String = str(b.get("path_" + p, "Side path"))
			var first: Dictionary = {}
			for s: Dictionary in studies:
				if str(s.get("path", "")) == p:
					first = s
					break
			var fork: String = ""
			for r: Variant in first.get("requires", []):
				var rd: Dictionary = Content.study(str(r))
				if not rd.is_empty() and rd["branch"] == id and str(rd.get("path", "")) != p:
					fork = str(rd["name"])
			var hl := UI.label("Side path: " + pname, UI.SIZE_BODY, UI.GOLD, true)
			_list.add_child(hl)
			if fork != "":
				_list.add_child(UI.wrap_label("Branches off %s. Optional." % fork, UI.SIZE_SMALL, UI.LIGHT_SOFT))
		for s: Dictionary in studies:
			if str(s.get("path", "")) == p:
				_list.add_child(_study_card(s))
	_scroll.scroll_vertical = 0
	_refresh()


func _study_card(def: Dictionary) -> Control:
	var id: String = str(def["id"])
	var card := UI.card("card")
	var v := UI.vbox(6)
	card.add_child(v)
	var row := UI.hbox(10)
	v.add_child(row)
	row.add_child(UI.icon_rect(UI.icon(str(def.get("icon", "star"))), 48))
	var tv := UI.vbox(1)
	tv.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var title := UI.label("%s  (%d)" % [def["name"], int(def.get("year", 0))], UI.SIZE_BODY, UI.INK, true)
	title.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	title.custom_minimum_size.x = 10
	tv.add_child(title)
	tv.add_child(UI.wrap_label(str(def.get("hook", "")), UI.SIZE_SMALL, UI.INK_SOFT))
	var desc := UI.wrap_label(str(def.get("desc", "")), UI.SIZE_SMALL, UI.GREEN)
	tv.add_child(desc)
	row.add_child(tv)
	var bottom := UI.hbox(10)
	var costs := HFlowContainer.new()
	costs.add_theme_constant_override("h_separation", 12)
	costs.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	bottom.add_child(costs)
	var button := UI.button("Study", "button_gold", 60)
	button.custom_minimum_size.x = 150
	button.add_theme_font_size_override("font_size", UI.SIZE_SMALL)
	button.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	button.pressed.connect(func() -> void:
		if Game.study(id):
			Sfx.play("father")
			_refresh()
		else:
			Sfx.play("deny"))
	bottom.add_child(button)
	v.add_child(bottom)
	var reason := UI.label("", UI.SIZE_SMALL, UI.INK_SOFT)
	v.add_child(reason)
	_nodes[id] = {"card": card, "button": button, "reason": reason, "costs": costs, "labels": {}, "cost_key": "", "title": title}
	return card


func _refresh() -> void:
	if Game.run == null:
		return
	var run: RunState = Game.run
	var done: int = 0
	var total: int = 0
	for s: Dictionary in Content.studies_in_branch(_branch):
		total += 1
		if run.study_level(str(s["id"])) > 0:
			done += 1
	for bd: Dictionary in Content.research_branches:
		if bd["id"] == _branch:
			_branch_desc.text = "%s  ·  %d of %d studied" % [bd.get("desc", ""), done, total]
	for id: String in _nodes.keys():
		_update_node(id)


func _update_node(id: String) -> void:
	var n: Dictionary = _nodes[id]
	var def: Dictionary = Content.study(id)
	var run: RunState = Game.run
	var lvl: int = run.study_level(id)
	var repeat: bool = bool(def.get("repeatable", false))
	var block: String = Balance.study_block(run, Game.meta, id)
	var button: Button = n["button"]
	var reason: Label = n["reason"]
	var card: Control = n["card"]
	var costs: HFlowContainer = n["costs"]
	var title: Label = n["title"]
	var name_text: String = "%s  (%d)%s" % [def["name"], int(def.get("year", 0)), ("  Lv %d" % lvl) if repeat and lvl > 0 else ""]
	if title.text != name_text:
		title.text = name_text
	if block == "Studied":
		costs.visible = false
		button.text = "✓ Studied"
		button.disabled = true
		reason.visible = false
		card.modulate = Color(1, 1, 1, 0.8)
		return
	card.modulate = Color(1, 1, 1, 1.0 if block == "" else 0.7)
	costs.visible = true
	var cost: Dictionary = Balance.study_cost(run, id)
	var key: String = ",".join(PackedStringArray(cost.keys()))
	var labels: Dictionary = n["labels"]
	if n["cost_key"] != key:
		n["cost_key"] = key
		for c: Node in costs.get_children():
			c.queue_free()
		labels.clear()
		for k: String in cost.keys():
			var item := UI.hbox(4)
			item.add_child(UI.icon_rect(UI.icon(k), 28))
			var l := UI.label("", UI.SIZE_SMALL, UI.INK)
			item.add_child(l)
			labels[k] = l
			costs.add_child(item)
	for k: String in cost.keys():
		var need: float = float(cost[k])
		var have: float = run.gold if k == "gold" else run.stock_of(k)
		var l: Label = labels[k]
		l.text = Format.num(need) if k == "gold" else "%s/%s" % [Format.num(have), Format.num(need)]
		l.add_theme_color_override("font_color", UI.GREEN if have >= need else UI.RED)
	reason.visible = block != ""
	reason.text = block
	var ok: bool = block == "" and Game.study_affordable(id)
	button.disabled = not ok
	button.text = ("Study again" if repeat and lvl > 0 else "Study") if block == "" else "Locked"
