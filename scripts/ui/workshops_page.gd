## Workshops: turn raw goods into finer wares. Each is built once, staffed by
## colonists from the shared pool, and upgraded for speed.
class_name WorkshopsPage
extends Page

var _cards: Dictionary = {}
var _structure: String = ""


func _build_header(box: VBoxContainer) -> void:
	box.add_child(page_title("Workshops", "Colonists here turn held goods into wares worth far more. Staffing a workshop holds its inputs back from sale."))
	box.add_child(BuyAmountSelector.new())


func refresh() -> void:
	if Game.run == null:
		return
	var key: String = _structure_key()
	if key != _structure:
		_structure = key
		_rebuild()
	for id: String in _cards.keys():
		_update_card(id)


func _structure_key() -> String:
	var parts: PackedStringArray = []
	for def: Dictionary in Content.recipes:
		var id: String = def["id"]
		var w: RunState.WorkshopState = Game.run.workshop(id)
		parts.append("%s:%s" % [id, "b" if w.built else ("u" if Game.workshop_unlocked(id) else "l")])
	return ",".join(parts)


func _rebuild() -> void:
	clear_list()
	_cards.clear()
	var shown_locked: bool = false
	for def: Dictionary in Content.recipes:
		var id: String = def["id"]
		if not Game.workshop_unlocked(id):
			if not shown_locked:
				shown_locked = true
				list.add_child(_locked_card(def))
			continue
		var card := _workshop_card(def)
		_cards[id] = card
		list.add_child(card)


func _recipe_line(def: Dictionary) -> HBoxContainer:
	var row := UI.hbox(4)
	var inputs: Dictionary = def["inputs"]
	var first: bool = true
	for input_id: String in inputs.keys():
		if not first:
			row.add_child(UI.label("+", UI.SIZE_SMALL, UI.INK_SOFT))
		first = false
		row.add_child(UI.label("%d" % int(inputs[input_id]), UI.SIZE_SMALL, UI.INK))
		row.add_child(UI.icon_rect(UI.icon(input_id), 32))
	row.add_child(UI.label(" → 1", UI.SIZE_SMALL, UI.INK))
	row.add_child(UI.icon_rect(UI.icon(def["id"]), 32))
	return row


func _locked_card(def: Dictionary) -> Control:
	var card := UI.card("card")
	card.modulate = Color(1, 1, 1, 0.7)
	var row := UI.hbox(12)
	row.add_child(UI.icon_rect(UI.icon("lock"), 48))
	var v := UI.vbox(2)
	v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	v.add_child(UI.label(str(def["building"]), UI.SIZE_BODY, UI.INK))
	var need: PackedStringArray = []
	for input_id: String in (def["inputs"] as Dictionary).keys():
		if not Game.run.discovered.has(input_id):
			need.append(Content.resource_name(input_id))
	v.add_child(UI.wrap_label("Needs %s to reach the capital first." % " and ".join(need)))
	row.add_child(v)
	card.add_child(row)
	return card


func _workshop_card(def: Dictionary) -> Control:
	var id: String = def["id"]
	var card := UI.card("card")
	var v := UI.vbox(8)
	card.add_child(v)

	var head := UI.hbox(12)
	head.add_child(UI.icon_rect(UI.icon(id), 56))
	var titles := UI.vbox(2)
	titles.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	titles.add_child(UI.label(str(def["building"]), UI.SIZE_BIG, UI.INK, true))
	titles.add_child(_recipe_line(def))
	head.add_child(titles)
	v.add_child(head)

	var info := UI.label("", UI.SIZE_SMALL, UI.INK_SOFT)
	info.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	info.custom_minimum_size.x = 10
	v.add_child(info)
	card.set_meta("info", info)

	var w: RunState.WorkshopState = Game.run.workshop(id)
	if not w.built:
		var b := BuyButton.new(func() -> bool:
			var ok: bool = Game.build_workshop(id)
			if ok:
				refresh()
			return ok)
		b.custom_minimum_size.y = 76
		v.add_child(b)
		card.set_meta("build", b)
		return card

	var bar := UI.bar("bar_fill_green")
	v.add_child(bar)
	card.set_meta("bar", bar)

	var staff := UI.hbox(10)
	staff.add_child(UI.icon_rect(UI.icon("colonist"), 40))
	var staff_label := UI.label("", UI.SIZE_BODY, UI.INK)
	staff_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	staff.add_child(staff_label)
	card.set_meta("staff", staff_label)
	var minus := UI.button("−", "button", 60)
	minus.custom_minimum_size.x = 64
	minus.add_theme_font_size_override("font_size", UI.SIZE_BIG)
	minus.pressed.connect(func() -> void:
		Sfx.play("click" if Game.assign_to_workshop(id, -1) else "deny")
		refresh())
	var plus := UI.button("+", "button", 60)
	plus.custom_minimum_size.x = 64
	plus.add_theme_font_size_override("font_size", UI.SIZE_BIG)
	plus.pressed.connect(func() -> void:
		Sfx.play("click" if Game.assign_to_workshop(id, 1) else "deny")
		refresh())
	staff.add_child(minus)
	staff.add_child(plus)
	card.set_meta("minus", minus)
	card.set_meta("plus", plus)
	v.add_child(staff)

	var up := UpgradeRow.new("hammer", func() -> bool: return Game.upgrade_workshop(id))
	up.add_theme_stylebox_override("panel", StyleBoxEmpty.new())
	v.add_child(up)
	card.set_meta("upgrade", up)

	var sell_row := UI.hbox(10)
	var sell_label := UI.label("", UI.SIZE_SMALL, UI.INK_SOFT)
	sell_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	sell_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	sell_label.custom_minimum_size.x = 10
	sell_row.add_child(sell_label)
	var toggle := UI.button("", "button", 52)
	toggle.custom_minimum_size.x = 200
	toggle.add_theme_font_size_override("font_size", UI.SIZE_SMALL)
	toggle.pressed.connect(func() -> void:
		Game.set_hold(id, not Game.run.is_held(id))
		Sfx.play("click")
		refresh())
	sell_row.add_child(toggle)
	card.set_meta("sell_label", sell_label)
	card.set_meta("toggle", toggle)
	v.add_child(sell_row)
	return card


func _update_card(id: String) -> void:
	var card: Control = _cards[id]
	var run: RunState = Game.run
	var def: Dictionary = Content.recipe(id)
	var w: RunState.WorkshopState = run.workshop(id)
	var info: Label = card.get_meta("info")
	var price: float = Balance.sell_price(run, Game.meta, id)
	var in_value: float = 0.0
	for input_id: String in (def["inputs"] as Dictionary).keys():
		in_value += float(def["inputs"][input_id]) * Balance.sell_price(run, Game.meta, input_id)

	if not w.built:
		info.text = "%s sell for %s each - the inputs alone fetch %s." % [Content.resource_name(id), Format.num(price), Format.num(in_value)]
		var cost: float = Balance.workshop_build_cost(id)
		(card.get_meta("build") as BuyButton).set_cost("Build  ·  " + Format.num(cost), run.gold >= cost)
		return

	var secs: float = Balance.craft_seconds(run, Game.meta, w)
	var status: String
	var missing: PackedStringArray = []
	for input_id: String in (def["inputs"] as Dictionary).keys():
		if run.stock_of(input_id) + 0.001 < float(def["inputs"][input_id]):
			missing.append(Content.resource_name(input_id))
	if w.colonists <= 0:
		status = "Idle - assign colonists to start work."
	elif not missing.is_empty():
		status = "Waiting for %s." % " and ".join(missing)
	else:
		status = "Making %s %s/s." % [Format.rate(1.0 / secs), Content.resource_name(id).to_lower()]
	info.text = "%s   ·   %s made this run" % [status, Format.num(float(run.crafted.get(id, 0)))]

	var bar: ProgressBar = card.get_meta("bar")
	bar.value = clampf(w.progress / secs, 0.0, 1.0) if secs < INF and missing.is_empty() and secs > 0.25 else (1.0 if w.colonists > 0 and missing.is_empty() else 0.0)

	(card.get_meta("staff") as Label).text = "Colonists: %d   (%d idle)" % [w.colonists, run.colonists_idle()]
	(card.get_meta("minus") as Button).disabled = w.colonists <= 0
	(card.get_meta("plus") as Button).disabled = run.colonists_idle() <= 0

	var up: UpgradeRow = card.get_meta("upgrade")
	var n: int = Game.workshop_levels(w)
	var cost: float = Balance.workshop_upgrade_cost(run, w, n)
	var g: float = Balance.v("workshop_speed_growth")
	var before: float = pow(g, w.level)
	var after: float = pow(g, w.level + n)
	up.set_values("Tools & Benches  Lv %d%s" % [w.level, ("  (+%d)" % n) if n > 1 else ""], "Speed ×%s → ×%s" % [Format.rate(before), Format.rate(after)], cost, run.gold >= cost)

	var held: bool = run.is_held(id)
	(card.get_meta("sell_label") as Label).text = "%s sell for %s. In store: %s" % [Content.resource_name(id), Format.num(price), Format.num(run.stock_of(id))]
	var toggle: Button = card.get_meta("toggle")
	toggle.text = "Keep for crafting" if held else "Auto-sell"
	toggle.add_theme_stylebox_override("normal", UI.frame("button_gold" if held else "button", 14, 8))
	toggle.add_theme_color_override("font_color", UI.INK if held else UI.LIGHT)
