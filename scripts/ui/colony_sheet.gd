## Bottom sheet for one colony: its stats, colonists, and the three upgrade
## tracks - or, for the next unfounded colony, what founding it would bring.
class_name ColonySheet
extends PanelContainer

signal closed

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

	_body = UI.vbox(10)
	root.add_child(_body)

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

	_selector = BuyAmountSelector.new()
	_manage_box.add_child(_selector)

	for track: String in ["prod", "cargo", "speed"]:
		var icon_name: String = {"prod": "pick", "cargo": "crate", "speed": "speed"}[track]
		var t: String = track
		var row := UpgradeRow.new(icon_name, func() -> bool: return Game.upgrade_colony(colony_id, t))
		_rows[track] = row
		_manage_box.add_child(row)

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
	refresh()


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

