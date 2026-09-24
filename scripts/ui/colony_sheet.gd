## Bottom sheet for one colony: its stats, colonists, and the three upgrade
## tracks - or, for the next unfounded colony, what founding it would bring.
class_name ColonySheet
extends PanelContainer

signal closed
signal modal_requested(modal: Control)

var colony_id: String = ""

var _title: Label
var _subtitle: Label
var _portrait: TextureRect
var _body: VBoxContainer
var _stats: Label
var _trip_bar: ProgressBar
var _trip_label: Label
var _colonist_label: Label
var _minus: Button
var _plus: Button
var _rows: Dictionary = {}
var _found_box: VBoxContainer
var _found_flavor: Label
var _found_detail: Label
var _found_button: BuyButton
var _manage_box: VBoxContainer
var _selector: BuyAmountSelector
var _gov_label: Label
var _gov_button: Button
var _charter_title: Label
var _charter_costs: HFlowContainer
var _charter_button: BuyButton
var _charter_level: int = -1
var _scroll: ScrollContainer


func _init() -> void:
	add_theme_stylebox_override("panel", UI.frame("panel_dark", 14, 18))
	mouse_filter = Control.MOUSE_FILTER_STOP
	var root := UI.vbox(10)
	add_child(root)

	var header := UI.hbox(14)
	_portrait = UI.icon_rect(null, 84)
	header.add_child(_portrait)
	var titles := UI.vbox(0)
	titles.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_title = UI.label("", UI.SIZE_TITLE, UI.GOLD, true)
	_subtitle = UI.label("", UI.SIZE_SMALL, UI.LIGHT_SOFT)
	titles.add_child(_title)
	titles.add_child(_subtitle)
	header.add_child(titles)
	var close := UI.button("✕", "button", 56)
	close.custom_minimum_size.x = 56
	close.pressed.connect(func() -> void:
		Sfx.play("click")
		closed.emit())
	close.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	header.add_child(close)
	root.add_child(header)

	_scroll = ScrollContainer.new()
	_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	root.add_child(_scroll)
	_body = UI.vbox(10)
	_body.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_scroll.add_child(_body)

	# --- founded colony ---
	_manage_box = UI.vbox(10)
	_body.add_child(_manage_box)
	_stats = UI.label("", UI.SIZE_SMALL, UI.LIGHT)
	_stats.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_stats.custom_minimum_size.x = 10
	_manage_box.add_child(_stats)
	var trip_row := UI.hbox(10)
	_trip_label = UI.label("", UI.SIZE_SMALL, UI.LIGHT_SOFT)
	_trip_label.custom_minimum_size.x = 220
	trip_row.add_child(_trip_label)
	_trip_bar = UI.bar("bar_fill_blue")
	_trip_bar.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_trip_bar.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	trip_row.add_child(_trip_bar)
	_manage_box.add_child(trip_row)

	_selector = BuyAmountSelector.new()
	_manage_box.add_child(_selector)

	for track: String in ["prod", "cargo", "speed"]:
		var icon_name: String = {"prod": "pick", "cargo": "crate", "speed": "speed"}[track]
		var t: String = track
		var row := UpgradeRow.new(icon_name, func() -> bool: return Game.upgrade_colony(colony_id, t))
		_rows[track] = row
		_manage_box.add_child(row)

	var col_card := UI.card("card")
	var col_row := UI.hbox(10)
	col_row.add_child(UI.icon_rect(UI.icon("colonist"), 44))
	_colonist_label = UI.label("", UI.SIZE_BODY, UI.INK)
	_colonist_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_colonist_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_colonist_label.custom_minimum_size.x = 10
	col_row.add_child(_colonist_label)
	_minus = UI.button("−", "button", 60)
	_minus.custom_minimum_size.x = 64
	_minus.add_theme_font_size_override("font_size", UI.SIZE_BIG)
	_minus.pressed.connect(func() -> void: _assign(-1))
	_plus = UI.button("+", "button", 60)
	_plus.custom_minimum_size.x = 64
	_plus.add_theme_font_size_override("font_size", UI.SIZE_BIG)
	_plus.pressed.connect(func() -> void: _assign(1))
	col_row.add_child(_minus)
	col_row.add_child(_plus)
	col_card.add_child(col_row)
	_manage_box.add_child(col_card)

	var gov_card := UI.card("card")
	var gov_row := UI.hbox(10)
	gov_row.add_child(UI.icon_rect(UI.icon("scroll"), 44))
	_gov_label = UI.label("", UI.SIZE_SMALL, UI.INK)
	_gov_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_gov_label.custom_minimum_size.x = 10
	_gov_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	gov_row.add_child(_gov_label)
	_gov_button = UI.button("Appoint", "button", 60)
	_gov_button.custom_minimum_size.x = 150
	_gov_button.add_theme_font_size_override("font_size", UI.SIZE_SMALL)
	_gov_button.pressed.connect(_open_governor_picker)
	gov_row.add_child(_gov_button)
	gov_card.add_child(gov_row)
	_manage_box.add_child(gov_card)

	var ch_card := UI.card("card")
	var ch_v := UI.vbox(6)
	ch_card.add_child(ch_v)
	var ch_head := UI.hbox(10)
	ch_head.add_child(UI.icon_rect(UI.icon("star"), 44))
	_charter_title = UI.label("", UI.SIZE_SMALL, UI.INK)
	_charter_title.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_charter_title.custom_minimum_size.x = 10
	_charter_title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	ch_head.add_child(_charter_title)
	_charter_button = BuyButton.new(func() -> bool:
		var ok: bool = Game.charter_colony(colony_id)
		if ok:
			Sfx.play("father")
			refresh()
		return ok)
	_charter_button.custom_minimum_size = Vector2(170, 64)
	ch_head.add_child(_charter_button)
	ch_v.add_child(ch_head)
	_charter_costs = HFlowContainer.new()
	_charter_costs.add_theme_constant_override("h_separation", 14)
	ch_v.add_child(_charter_costs)
	_manage_box.add_child(ch_card)


	# --- next colony to found ---
	_found_box = UI.vbox(12)
	_body.add_child(_found_box)
	_found_detail = UI.label("", UI.SIZE_BODY, UI.LIGHT)
	_found_detail.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_found_detail.custom_minimum_size.x = 10
	_found_box.add_child(_found_detail)
	_found_flavor = UI.wrap_label("", UI.SIZE_SMALL, UI.LIGHT_SOFT)
	_found_box.add_child(_found_flavor)
	_found_button = BuyButton.new(func() -> bool: return Game.found_colony(colony_id))
	_found_button.custom_minimum_size = Vector2(0, 84)
	_found_box.add_child(_found_button)


func show_colony(id: String) -> void:
	colony_id = id
	_charter_level = -1
	refresh()


func _open_governor_picker() -> void:
	Sfx.play("click")
	var m := Modal.new("Appoint a Governor")
	if Game.meta.governors.is_empty():
		m.add_text("You have no governors yet. Commission them with Liberty in the Congress.", UI.SIZE_BODY, UI.INK_SOFT)
	for g: Dictionary in Game.meta.governors:
		var gid: int = g["id"]
		var t: Dictionary = Content.governor_type(str(g["type"]))
		var at: String = Game.run.colony_of_governor(gid)
		var where: String = ""
		if at == colony_id:
			where = " (here)"
		elif at != "":
			where = " (at %s)" % Content.colony_name(Game.run.nation_id, Content.colony_index(at))
		var b := UI.button("%s  ·  %s %s  ×%s %s%s" % [g["name"], t.get("title", ""), "★".repeat(int(g["rank"])), Format.rate(Balance.governor_multiplier_for_rank(int(g["rank"]))), t.get("desc", ""), where], "button", 64)
		b.add_theme_font_size_override("font_size", UI.SIZE_SMALL)
		b.pressed.connect(func() -> void:
			Game.post_governor(colony_id, gid)
			Sfx.play("buy")
			m.close()
			refresh())
		m.body.add_child(b)
	if Game.run.governor_at(colony_id) >= 0:
		m.add_button("Recall", "button", func() -> void:
			Game.recall_governor(colony_id)
			refresh())
	m.add_button("Close", "button_gold")
	modal_requested.emit(m)


func _assign(delta: int) -> void:
	if Game.assign_to_colony(colony_id, delta):
		Sfx.play("click")
	else:
		Sfx.play("deny")
	refresh()


func refresh() -> void:
	if Game.run == null or colony_id == "":
		return
	var run: RunState = Game.run
	var meta: MetaState = Game.meta
	var c: RunState.ColonyState = run.colony(colony_id)
	var def: Dictionary = Content.colony(colony_id)
	var res: String = def["resource"]
	var res_name: String = Content.resource_name(res)
	var sea: bool = Balance.is_sea(c)
	var cname: String = Content.colony_name(run.nation_id, Content.colony_index(colony_id))
	_title.text = cname
	var route_text: String = "Capital" if colony_id == "capital" else ("Sea route" if sea else "Land route")
	_subtitle.text = "%s  ·  %s  ·  sells for %s each" % [res_name, route_text, Format.num(Balance.sell_price(run, meta, res), 1)]

	_manage_box.visible = c.founded
	_found_box.visible = not c.founded

	if not c.founded:
		_portrait.texture = UI.tex("res://assets/sprites/map/site.png")
		var cost: float = Balance.found_cost(run, meta, colony_id)
		var how: String = "Ships will carry its goods to the capital." if sea else "Wagon trains will haul its goods overland to the capital."
		_found_detail.text = "An unclaimed site rich in %s. %s" % [res_name.to_lower(), how]
		_found_flavor.text = str(def.get("flavor", ""))
		_found_button.set_cost("Found colony  ·  " + Format.num(cost), run.gold >= cost)
		return

	_portrait.texture = UI.tex("res://assets/sprites/map/%s.png" % UI.colony_sprite_name(c))
	var rate: float = Balance.production_rate(run, meta, c)
	if colony_id == "capital":
		_stats.text = "Producing %s %s/s, sold straight off the wharf." % [Format.rate(rate), res_name.to_lower()]
		_trip_bar.get_parent().visible = false
	else:
		var tp: float = Balance.route_throughput(run, meta, c)
		var rt: float = Balance.round_trip_seconds(run, meta, c)
		var warn: String = ""
		if rate > tp * 1.02:
			warn = "\nThe %s can't keep up - upgrade cargo or speed." % ("ships" if sea else "wagons")
		_stats.text = "Producing %s/s  ·  Shipping up to %s/s  ·  Waiting at colony: %s%s" % [
			Format.rate(rate), Format.rate(tp), Format.num(c.stock), warn]
		_trip_bar.get_parent().visible = true
		var unit: String = "Ship" if sea else "Wagon"
		if c.trip <= 0.0:
			_trip_label.text = "%s loading" % unit
			_trip_bar.value = 0.0
		elif c.trip < 0.5:
			_trip_label.text = "%s en route (%s)" % [unit, Format.num(c.cargo)]
			_trip_bar.value = c.trip * 2.0
		else:
			_trip_label.text = "%s returning" % unit
			_trip_bar.value = 1.0 - (c.trip - 0.5) * 2.0
		_trip_bar.tooltip_text = "Round trip %ss" % Format.rate(rt)

	_refresh_governor(c)
	_refresh_charter(c)

	var bonus: float = Balance.v("colonist_production_bonus") * 100.0
	_colonist_label.text = "Colonists: %d   (+%d%% each)\n%d idle of %d" % [c.colonists, int(bonus), run.colonists_idle(), run.colonists_owned]
	_minus.disabled = c.colonists <= 0
	_plus.disabled = run.colonists_idle() <= 0

	_update_row("prod", c, "Production", func() -> String:
		var before: float = Balance.production_rate(run, meta, c)
		var n: int = Game.colony_track_levels(c, "prod")
		c.prod_level += n
		var after: float = Balance.production_rate(run, meta, c)
		c.prod_level -= n
		return "%s → %s %s/s" % [Format.rate(before), Format.rate(after), res_name.to_lower()])
	var is_cap: bool = colony_id == "capital"
	(_rows["cargo"] as Control).visible = not is_cap
	(_rows["speed"] as Control).visible = not is_cap
	if is_cap:
		return
	_update_row("cargo", c, "Wagons" if not sea else "Cargo Holds", func() -> String:
		var before: float = Balance.cargo_capacity(run, meta, c)
		var n: int = Game.colony_track_levels(c, "cargo")
		c.cargo_level += n
		var after: float = Balance.cargo_capacity(run, meta, c)
		c.cargo_level -= n
		return "%s → %s per trip" % [Format.num(before), Format.num(after)])
	_update_row("speed", c, "Roads" if not sea else "Faster Ships", func() -> String:
		var before: float = Balance.round_trip_seconds(run, meta, c)
		var n: int = Game.colony_track_levels(c, "speed")
		c.speed_level += n
		var after: float = Balance.round_trip_seconds(run, meta, c)
		c.speed_level -= n
		return "Round trip %ss → %ss" % [Format.rate(before), Format.rate(after)])


func _update_row(track: String, c: RunState.ColonyState, label_text: String, preview: Callable) -> void:
	var row: UpgradeRow = _rows[track]
	var lvl: int = c.prod_level if track == "prod" else (c.cargo_level if track == "cargo" else c.speed_level)
	var n: int = Game.colony_track_levels(c, track)
	var cost: float = Balance.colony_upgrade_cost(track, c, n)
	var title: String = "%s  Lv %d" % [label_text, lvl]
	if n > 1:
		title += "  (+%d)" % n
	row.set_values(title, preview.call(), cost, Game.run.gold >= cost)



func _refresh_governor(c: RunState.ColonyState) -> void:
	var gid: int = Game.run.governor_at(c.id)
	if gid < 0:
		_gov_label.text = "No governor posted." if not Game.meta.governors.is_empty() else "No governor. Commission governors with Liberty in the Congress."
		_gov_button.text = "Appoint"
		_gov_button.disabled = Game.meta.governors.is_empty()
		return
	var g: Dictionary = Game.meta.governor(gid)
	var t: Dictionary = Content.governor_type(str(g["type"]))
	_gov_label.text = "Governor %s
%s %s  ·  ×%s %s" % [g["name"], t.get("title", ""), "★".repeat(int(g["rank"])), Format.rate(Balance.governor_multiplier_for_rank(int(g["rank"]))), t.get("desc", "")]
	_gov_button.text = "Change"
	_gov_button.disabled = false


func _refresh_charter(c: RunState.ColonyState) -> void:
	var next: int = c.charter + 1
	var title: String = "No charter" if c.charter == 0 else str(Content.charters[c.charter - 1]["title"])
	var pct: int = int(Balance.v("charter_bonus_per_level") * 100.0)
	var next_title: String = str(Content.charters[next - 1]["title"]) if next <= Content.charters.size() else ""
	_charter_title.text = "Charter: %s  %s
+%d%% production and cargo per rank%s" % [title, "★".repeat(c.charter), pct, ("
Next: " + next_title) if next_title != "" else ""]
	var cost: Dictionary = Balance.charter_cost(c.id, next)
	if cost.is_empty():
		_charter_button.set_cost("Free City", false, "")
		_charter_costs.visible = false
		return
	_charter_costs.visible = true
	if _charter_level != next:
		_charter_level = next
		for n: Node in _charter_costs.get_children():
			n.queue_free()
		for key: String in cost.keys():
			var item := UI.hbox(4)
			item.add_child(UI.icon_rect(UI.icon(key), 30))
			var l := UI.label("", UI.SIZE_SMALL, UI.INK)
			l.name = "Amount"
			item.add_child(l)
			item.set_meta("res", key)
			_charter_costs.add_child(item)
	for item: Node in _charter_costs.get_children():
		if not item.has_meta("res"):
			continue
		var key: String = item.get_meta("res")
		var need: float = float(cost.get(key, 0.0))
		var have: float = Game.run.stock_of(key)
		var l: Label = item.get_node("Amount")
		l.text = "%s / %s" % [Format.num(have), Format.num(need)]
		l.add_theme_color_override("font_color", UI.GREEN if have >= need else UI.RED)
	_charter_button.set_cost("Grant", Game.charter_affordable(c.id), "")


## Caps the sheet to `max_height`, scrolling the body when it doesn't fit.
func fit(max_height: float) -> void:
	var header_h: float = get_combined_minimum_size().y - _scroll.custom_minimum_size.y
	var want: float = _body.get_combined_minimum_size().y
	var h: float = clampf(want, 0.0, maxf(max_height - header_h, 120.0))
	if not is_equal_approx(_scroll.custom_minimum_size.y, h):
		_scroll.custom_minimum_size.y = h
