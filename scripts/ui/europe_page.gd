## Europe: recruit colonists at the docks and manage the warehouse - which goods
## are sold on arrival and which are kept for crafting or the Congress.
class_name EuropePage
extends Page

var _recruit: BuyButton
var _docks_info: Label
var _rows: Dictionary = {}
var _structure: int = -1
var _market_timer: Label
var _market_up: HBoxContainer
var _market_down: HBoxContainer
var _market_period: int = -1


func _build_header(box: VBoxContainer) -> void:
	var banner := TextureRect.new()
	banner.texture = UI.tex("res://assets/sprites/harbor.png")
	banner.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	banner.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	banner.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	banner.custom_minimum_size.y = 250
	banner.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var frame := PanelContainer.new()
	frame.add_theme_stylebox_override("panel", UI.frame("panel_navy", 14, 6))
	frame.add_child(banner)
	box.add_child(frame)
	box.add_child(page_title("The Docks of Europe"))

	var docks := UI.card("card")
	var dv := UI.vbox(10)
	docks.add_child(dv)
	var head := UI.hbox(12)
	head.add_child(UI.icon_rect(UI.icon("colonist"), 56))
	var hv := UI.vbox(2)
	hv.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hv.add_child(UI.label("Recruit Colonists", UI.SIZE_BIG, UI.INK, true))
	_docks_info = UI.wrap_label("", UI.SIZE_SMALL, UI.INK_SOFT)
	hv.add_child(_docks_info)
	head.add_child(hv)
	dv.add_child(head)
	var sel := BuyAmountSelector.new(true)
	dv.add_child(sel)
	_recruit = BuyButton.new(func() -> bool: return Game.recruit_colonists())
	_recruit.custom_minimum_size.y = 80
	dv.add_child(_recruit)
	box.add_child(docks)

	var market := UI.card("card")
	var mv := UI.vbox(8)
	market.add_child(mv)
	var mh := UI.hbox(10)
	var mt := UI.label("Prices in Europe", UI.SIZE_BIG, UI.INK, true)
	mt.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	mh.add_child(mt)
	mh.add_child(UI.icon_rect(UI.icon("hourglass"), 28))
	_market_timer = UI.label("", UI.SIZE_SMALL, UI.INK_SOFT)
	mh.add_child(_market_timer)
	mv.add_child(mh)
	_market_up = UI.hbox(8)
	_market_down = UI.hbox(8)
	mv.add_child(_market_up)
	mv.add_child(_market_down)
	box.add_child(market)

	var wh := UI.hbox(10)
	var t := section("Warehouse")
	t.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	wh.add_child(t)
	var sell_all := UI.button("Sell everything held", "button_gold", 56)
	sell_all.add_theme_font_size_override("font_size", UI.SIZE_SMALL)
	sell_all.pressed.connect(func() -> void:
		Game.sell_all_stock()
		Sfx.play("coin")
		refresh())
	wh.add_child(sell_all)
	box.add_child(wh)
	box.add_child(UI.wrap_label("Goods arriving at the capital are sold at once unless you keep them. Kept goods feed workshops and Founding Fathers.", UI.SIZE_SMALL, UI.LIGHT_SOFT))


func refresh() -> void:
	var run: RunState = Game.run
	if run == null:
		return
	var n: int = Game.colonist_count_to_buy()
	var cost: float = Balance.colonist_cost(run, Game.meta, n)
	_recruit.set_cost("Recruit %d  ·  %s" % [n, Format.num(cost)], run.gold >= cost)
	_docks_info.text = "%d colonists, %d idle. Each works a colony (+%d%% output) or staffs a workshop. Prices rise with every recruit." % [
		run.colonists_owned, run.colonists_idle(), int(Balance.v("colonist_production_bonus") * 100.0)]

	_refresh_market(run)
	if run.discovered.size() != _structure:
		_structure = run.discovered.size()
		_rebuild()
	for id: String in _rows.keys():
		_update_row(id)


func _rebuild() -> void:
	clear_list()
	_rows.clear()
	for id: String in Game.run.discovered:
		var card := UI.card("card")
		var row := UI.hbox(10)
		card.add_child(row)
		row.add_child(UI.icon_rect(UI.icon(id), 48))
		var v := UI.vbox(0)
		v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		var name_l := UI.label(Content.resource_name(id), UI.SIZE_BODY, UI.INK)
		# Wraps: a good used by many workshops would otherwise widen the page past the screen.
		var info := UI.wrap_label("", UI.SIZE_SMALL, UI.INK_SOFT)
		v.add_child(name_l)
		v.add_child(info)
		row.add_child(v)
		var sell := UI.button("Sell", "button", 64)
		sell.custom_minimum_size.x = 88
		sell.add_theme_font_size_override("font_size", UI.SIZE_SMALL)
		var rid: String = id
		sell.pressed.connect(func() -> void:
			Game.sell_stock(rid)
			Sfx.play("coin")
			refresh())
		row.add_child(sell)
		var toggle := UI.button("", "button", 64)
		toggle.custom_minimum_size.x = 150
		toggle.add_theme_font_size_override("font_size", UI.SIZE_SMALL)
		toggle.pressed.connect(func() -> void:
			Game.set_hold(rid, not Game.run.is_held(rid))
			Sfx.play("click")
			refresh())
		row.add_child(toggle)
		card.set_meta("info", info)
		card.set_meta("sell", sell)
		card.set_meta("toggle", toggle)
		_rows[id] = card
		list.add_child(card)


func _update_row(id: String) -> void:
	var card: Control = _rows[id]
	var run: RunState = Game.run
	var stock: float = run.stock_of(id)
	var info: Label = card.get_meta("info")
	var mm: float = Balance.market_mult(run, id)
	var arrow: String = " ▲" if mm > 1.0 else (" ▼" if mm < 1.0 else "")
	var users: PackedStringArray = []
	for def: Dictionary in Content.recipes:
		var w: RunState.WorkshopState = run.workshop(str(def["id"]))
		if w != null and w.built and w.colonists > 0 and Balance.recipe_inputs(run, w.id).has(id):
			users.append(str(def["building"]))
	var used: String = ("
Used by: " + ", ".join(users)) if not users.is_empty() else ""
	# Keeping a good nothing uses just piles it up instead of selling it.
	if run.is_held(id) and users.is_empty() and stock > 0.0:
		used = "
Kept but no staffed workshop uses it: set it to Selling?"
	info.add_theme_color_override("font_color", UI.RED if run.is_held(id) and users.is_empty() and stock > 0.0 else UI.INK_SOFT)
	info.text = "%s each%s  ·  held: %s%s" % [Format.num(Balance.sell_price(run, Game.meta, id), 1), arrow, Format.num(stock), used]
	info.add_theme_color_override("font_color", UI.GREEN if mm > 1.0 else (UI.RED if mm < 1.0 else UI.INK_SOFT))
	(card.get_meta("sell") as Button).disabled = stock < 1.0
	var held: bool = run.is_held(id)
	var toggle: Button = card.get_meta("toggle")
	toggle.text = "Keeping" if held else "Selling"
	toggle.add_theme_stylebox_override("normal", UI.frame("button_gold" if held else "button_buy", 14, 8))
	toggle.add_theme_color_override("font_color", UI.INK if held else UI.LIGHT)


func _refresh_market(run: RunState) -> void:
	var m: Dictionary = Balance.market_state(run)
	var secs: int = int(m["remaining"])
	_market_timer.text = "%d:%02d" % [secs / 60, secs % 60]
	if int(m["period"]) == _market_period:
		return
	_market_period = int(m["period"])
	_fill_market_row(_market_up, "Wanted ×%s" % str(Balance.v("market_up_mult")), m["up"], UI.GREEN)
	_fill_market_row(_market_down, "Glut ×%s" % str(Balance.v("market_down_mult")), m["down"], UI.RED)


func _fill_market_row(row: HBoxContainer, title: String, ids: Array, color: Color) -> void:
	for c: Node in row.get_children():
		c.queue_free()
	var t := UI.label(title, UI.SIZE_SMALL, color)
	t.custom_minimum_size.x = 130
	t.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	row.add_child(t)
	# Icons with the goods' names beneath, so nothing is a mystery silhouette.
	var col := UI.vbox(2)
	col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var icons := UI.hbox(6)
	var names: PackedStringArray = []
	for id: Variant in ids:
		var rid: String = str(id)
		var known: bool = Game.run.discovered.has(rid)
		var ic := UI.icon_rect(UI.icon(rid), 36)
		ic.modulate = Color.WHITE if known else Color(0.15, 0.12, 0.1, 0.6)
		ic.tooltip_text = Content.resource_name(rid)
		icons.add_child(ic)
		names.append(Content.resource_name(rid) + ("" if known else " (not yet found)"))
	col.add_child(icons)
	col.add_child(UI.wrap_label(", ".join(names), UI.SIZE_MIN, UI.INK_SOFT))
	row.add_child(col)
