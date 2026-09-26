## Bottom sheet for one colony: its stats, colonists, governor, charter and
## the three upgrade tracks - or, for the next site the surveyors have found,
## what founding it will bring.
class_name ColonySheet
extends PanelContainer

signal closed
signal modal_requested(modal: Control)

## Colony id, or "" while showing the next site.
var colony_id: String = ""

var _title: Label
var _subtitle: Label
var _portrait: TextureRect
var _scroll: ScrollContainer
var _body: VBoxContainer
var _stats: Label
var _trip_bar: ProgressBar
var _trip_label: Label
var _colonist_label: Label
var _minus: Button
var _plus: Button
var _rows: Dictionary = {}
var _found_box: VBoxContainer
var _found_detail: Label
var _found_flavor: Label
var _found_button: BuyButton
var _manage_box: VBoxContainer
var _selector: BuyAmountSelector
var _gov_label: Label
var _gov_button: Button
var _charter_title: Label
var _charter_costs: HFlowContainer
var _charter_button: BuyButton
var _charter_level: int = -1
var _spec_box: VBoxContainer
var _good_flavor: Label
var _spec_key: String = ""

const FLAVOR := {
	"timber": "Tall stands of oak and pine, ready for the axe.",
	"grain": "Good black soil for wheat and rye.",
	"cod": "The banks offshore teem with cod.",
	"hemp": "Rich bottomland where hemp grows taller than a man.",
	"sugar_cane": "Hot, wet ground made for cane fields.",
	"hides": "Herds of wild cattle roam the open country.",
	"tobacco": "Warm loam that grows a prized leaf.",
	"cotton": "Long summers and light soil: cotton country.",
	"iron_ore": "Red streaks of bog iron and hillside ore.",
	"indigo": "Swampy fields where indigo thrives.",
	"furs": "Beaver streams and deep woods for trappers.",
	"whale_oil": "Cold waters where whales pass each season.",
	"horses": "Open range where wild horses run.",
	"silver": "A glint of silver in the rock above the valley.",
}


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
	_subtitle.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_subtitle.resized.connect(_subtitle.update_minimum_size)
	_subtitle.custom_minimum_size.x = 10
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
	# Always reserve the scrollbar's width, so text never rewraps (and the
	# sheet never changes height) when the bar comes and goes.
	_scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_RESERVE
	root.add_child(_scroll)
	_body = UI.vbox(10)
	_body.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_scroll.add_child(_body)

	# --- a founded colony ---
	_manage_box = UI.vbox(10)
	_body.add_child(_manage_box)
	_stats = UI.label("", UI.SIZE_SMALL, UI.LIGHT)
	_stats.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_stats.resized.connect(_stats.update_minimum_size)
	_stats.custom_minimum_size.x = 10
	_manage_box.add_child(_stats)
	_good_flavor = UI.wrap_label("", 17, UI.LIGHT_SOFT)
	_manage_box.add_child(_good_flavor)
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
	_colonist_label.resized.connect(_colonist_label.update_minimum_size)
	_colonist_label.custom_minimum_size.x = 10
	col_row.add_child(_colonist_label)
	_minus = _small_button("−", func() -> void: _assign(-1))
	_plus = _small_button("+", func() -> void: _assign(1))
	col_row.add_child(_minus)
	col_row.add_child(_plus)
	col_card.add_child(col_row)
	_manage_box.add_child(col_card)

	var gov_card := UI.card("card")
	var gov_row := UI.hbox(10)
	gov_row.add_child(UI.icon_rect(UI.icon("scroll"), 44))
	_gov_label = UI.label("", UI.SIZE_SMALL, UI.INK)
	_gov_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_gov_label.resized.connect(_gov_label.update_minimum_size)
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
	_charter_title.resized.connect(_charter_title.update_minimum_size)
	_charter_title.custom_minimum_size.x = 10
	_charter_title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	ch_head.add_child(_charter_title)
	_charter_button = BuyButton.new(func() -> bool:
		var ok: bool = Game.charter_colony(colony_id)
		if ok:
			Sfx.play("father")
			refresh()
		return ok)
	_charter_button.custom_minimum_size = Vector2(150, 64)
	ch_head.add_child(_charter_button)
	ch_v.add_child(ch_head)
	_charter_costs = HFlowContainer.new()
	_charter_costs.add_theme_constant_override("h_separation", 14)
	ch_v.add_child(_charter_costs)
	_manage_box.add_child(ch_card)

	# A chartered colony chooses what kind of town it becomes.
	_spec_box = UI.vbox(8)
	_manage_box.add_child(_spec_box)

	# --- the next site ---
	_found_box = UI.vbox(12)
	_body.add_child(_found_box)
	_found_detail = UI.label("", UI.SIZE_BODY, UI.LIGHT)
	_found_detail.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_found_detail.resized.connect(_found_detail.update_minimum_size)
	_found_detail.custom_minimum_size.x = 10
	_found_box.add_child(_found_detail)
	_found_flavor = UI.wrap_label("", UI.SIZE_SMALL, UI.LIGHT_SOFT)
	_found_box.add_child(_found_flavor)
	_found_button = BuyButton.new(func() -> bool: return Game.found_colony())
	_found_button.custom_minimum_size = Vector2(0, 84)
	_found_box.add_child(_found_button)


func _small_button(text: String, action: Callable) -> Button:
	var b := UI.button(text, "button", 60)
	b.custom_minimum_size.x = 64
	b.add_theme_font_size_override("font_size", UI.SIZE_BIG)
	b.pressed.connect(action)
	return b


func show_colony(id: String) -> void:
	colony_id = id
	_charter_level = -1
	refresh()


func show_next_site() -> void:
	colony_id = ""
	refresh()


func _assign(delta: int) -> void:
	Sfx.play("click" if Game.assign_to_colony(colony_id, delta) else "deny")
	refresh()


## Caps the sheet to `max_height`, scrolling the body when it doesn't fit.
func fit(max_height: float) -> void:
	# Whole pixels only, and only when the target really changes: otherwise
	# the sheet and its content chase each other by a pixel every frame.
	var header_h: float = get_combined_minimum_size().y - _scroll.get_combined_minimum_size().y
	var want: float = _body.get_combined_minimum_size().y
	var h: float = floorf(clampf(want, 0.0, maxf(max_height - header_h, 120.0)))
	if absf(_scroll.custom_minimum_size.y - h) >= 1.0:
		_scroll.custom_minimum_size.y = h


static func site_summary(run: RunState, site: Dictionary) -> String:
	var route_text: String = "Sea route" if site["route"] == "sea" else "Land route"
	var rich: float = float(site.get("richness", 1.0))
	var quality: String = "rich" if rich >= 1.2 else ("poor" if rich < 0.95 else "fair")
	return "%s  ·  %s  ·  %s ground" % [Content.terrain_name(int(site["terrain"])), route_text, quality]


func refresh() -> void:
	if Game.run == null:
		return
	var run: RunState = Game.run
	var meta: MetaState = Game.meta
	var c: RunState.ColonyState = run.colony(colony_id) if colony_id != "" else null
	_manage_box.visible = c != null
	_found_box.visible = c == null
	if c == null:
		_refresh_next_site(run, meta)
		return

	var site: Dictionary = run.site_of(c)
	var res: String = run.resource_of(c)
	var res_name: String = Content.resource_name(res)
	var sea: bool = Balance.is_sea(run, c)
	_title.text = Content.colony_name(run.nation_id, c.tier)
	_subtitle.text = "%s  ·  %s" % [res_name, "Capital" if c.tier == 0 else site_summary(run, site)]
	_portrait.texture = UI.tex("res://assets/sprites/map/%s.png" % UI.colony_sprite_name(c))
	var fl: String = Content.good_flavor(res)
	_good_flavor.visible = fl != ""
	if _good_flavor.text != fl:
		_good_flavor.text = fl

	var rate: float = Balance.production_rate(run, meta, c)
	if c.tier == 0:
		_stats.text = "Producing %s %s/s, sold straight off the wharf." % [Format.rate(rate), res_name.to_lower()]
		_trip_bar.get_parent().visible = false
	else:
		var tp: float = Balance.route_throughput(run, meta, c)
		var warn: String = ""
		if rate > tp * 1.02:
			warn = "\nThe %s can't keep up - upgrade cargo or speed." % ("ships" if sea else "wagons")
		_stats.text = "Producing %s/s  ·  Shipping up to %s/s  ·  Waiting: %s%s" % [Format.rate(rate), Format.rate(tp), Format.num(c.stock), warn]
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

	var bonus: float = Balance.v("colonist_production_bonus") * 100.0
	_colonist_label.text = "Colonists: %d   (+%d%% each)\n%d idle of %d" % [c.colonists, int(bonus), run.colonists_idle(), run.colonists_owned]
	_minus.disabled = c.colonists <= 0
	_plus.disabled = run.colonists_idle() <= 0
	_refresh_governor(c)
	_refresh_charter(c)
	_refresh_spec(c)

	_update_row("prod", c, "Production", func() -> String:
		var before: float = Balance.production_rate(run, meta, c)
		var n: int = Game.colony_track_levels(c, "prod")
		c.prod_level += n
		var after: float = Balance.production_rate(run, meta, c)
		c.prod_level -= n
		return "%s → %s %s/s" % [Format.rate(before), Format.rate(after), res_name.to_lower()])
	(_rows["cargo"] as Control).visible = c.tier > 0
	(_rows["speed"] as Control).visible = c.tier > 0
	if c.tier == 0:
		return
	_update_row("cargo", c, "Cargo Holds" if sea else "Wagons", func() -> String:
		var before: float = Balance.cargo_capacity(run, meta, c)
		var n: int = Game.colony_track_levels(c, "cargo")
		c.cargo_level += n
		var after: float = Balance.cargo_capacity(run, meta, c)
		c.cargo_level -= n
		return "%s → %s per trip" % [Format.num(before), Format.num(after)])
	_update_row("speed", c, "Faster Ships" if sea else "Roads", func() -> String:
		var before: float = Balance.round_trip_seconds(run, meta, c)
		var n: int = Game.colony_track_levels(c, "speed")
		c.speed_level += n
		var after: float = Balance.round_trip_seconds(run, meta, c)
		c.speed_level -= n
		return "Round trip %s → %s" % [Format.duration(before), Format.duration(after)])


func _refresh_next_site(run: RunState, meta: MetaState) -> void:
	var n: int = run.next_site()
	if n < 0:
		_title.text = "The map is full"
		_subtitle.text = ""
		_found_detail.text = "Every colony site has been settled."
		_found_flavor.text = ""
		_found_button.visible = false
		return
	var site: Dictionary = run.world.sites[n]
	var res: String = site["resource"]
	var tier: int = run.colonies.size()
	_title.text = Content.colony_name(run.nation_id, tier)
	_subtitle.text = site_summary(run, site)
	_portrait.texture = UI.tex("res://assets/sprites/map/site.png")
	var how: String = "Ships will carry its %s to the capital." if site["route"] == "sea" else "Wagon trains will haul its %s overland to the capital."
	var value: float = Balance.tier_value(tier) * float(site.get("richness", 1.0))
	_found_detail.text = ("Your surveyors have found a site for colony number %d. " % (tier + 1)) + (how % Content.resource_name(res).to_lower()) + "\nWorth about %s gold a second from the start." % Format.num(value)
	_found_flavor.text = str(FLAVOR.get(res, ""))
	var cost: float = Balance.found_cost(run, meta)
	_found_button.visible = true
	_found_button.set_cost("Found colony  ·  " + Format.num(cost), run.gold >= cost)


func _update_row(track: String, c: RunState.ColonyState, label_text: String, preview: Callable) -> void:
	var row: UpgradeRow = _rows[track]
	var n: int = Game.colony_track_levels(c, track)
	var cost: float = Balance.colony_upgrade_cost(Game.run, track, c, n)
	var title: String = "%s  Lv %d" % [label_text, Balance.track_level(c, track)]
	if n > 1:
		title += "  (+%d)" % n
	row.set_values(title, preview.call(), cost, Game.run.gold >= cost)
	var per: float = Balance.v({"prod": "milestone_prod_mult", "cargo": "milestone_cargo_mult", "speed": "milestone_speed_mult"}[track])
	row.set_milestone(Balance.track_level(c, track), "×%s %s" % [Format.mult(per), {"prod": "output", "cargo": "cargo", "speed": "speed"}[track]])


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
			where = " (at %s)" % Content.colony_name(Game.run.nation_id, Game.run.colony(at).tier)
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


func _refresh_governor(c: RunState.ColonyState) -> void:
	var gid: int = Game.run.governor_at(c.id)
	if gid < 0:
		_gov_label.text = "No governor posted." if not Game.meta.governors.is_empty() else "No governor. Commission governors with Liberty in the Congress."
		_gov_button.text = "Appoint"
		_gov_button.disabled = Game.meta.governors.is_empty()
		return
	var g: Dictionary = Game.meta.governor(gid)
	var t: Dictionary = Content.governor_type(str(g["type"]))
	_gov_label.text = "Governor %s\n%s %s  ·  ×%s %s" % [g["name"], t.get("title", ""), "★".repeat(int(g["rank"])), Format.rate(Balance.governor_multiplier_for_rank(int(g["rank"]))), t.get("desc", "")]
	_gov_button.text = "Change"
	_gov_button.disabled = false


func _refresh_spec(c: RunState.ColonyState) -> void:
	_spec_box.visible = Balance.unlocked(Game.meta, "specializations")
	var key: String = "%s:%s:%d" % [c.id, c.spec, mini(c.charter, 1)]
	if key == _spec_key:
		return
	_spec_key = key
	for n: Node in _spec_box.get_children():
		n.queue_free()
	var offered: Array[Dictionary] = Balance.specs_offered(Game.run, c)
	if c.spec != "":
		var s: Dictionary = Content.specialization(c.spec)
		_spec_box.add_child(_spec_card(s, "Chosen", null))
		return
	var head := UI.label("Specialization" + ("" if c.charter >= 1 else "  (after the first charter)"), UI.SIZE_BODY, UI.GOLD, true)
	_spec_box.add_child(head)
	_spec_box.add_child(UI.wrap_label("Choose one. It can't be changed this run.", UI.SIZE_SMALL, UI.LIGHT_SOFT))
	for s: Dictionary in offered:
		var id: String = str(s["id"])
		_spec_box.add_child(_spec_card(s, "Choose" if c.charter >= 1 else "Locked", func() -> void:
			if Game.choose_specialization(colony_id, id):
				Sfx.play("father")
				_spec_key = ""
				refresh()
			else:
				Sfx.play("deny")))


func _spec_card(s: Dictionary, button_text: String, action: Variant) -> PanelContainer:
	var card := UI.card("card")
	var row := UI.hbox(10)
	card.add_child(row)
	row.add_child(UI.icon_rect(UI.icon("spec_" + str(s["id"])), 48))
	var v := UI.vbox(0)
	v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	v.add_child(UI.label(str(s["name"]), UI.SIZE_BODY, UI.INK, true))
	v.add_child(UI.wrap_label(str(s["desc"]), UI.SIZE_SMALL, UI.INK_SOFT))
	row.add_child(v)
	if action == null:
		var tag := UI.label("★ " + button_text, UI.SIZE_SMALL, UI.GREEN)
		row.add_child(tag)
	else:
		var b := UI.button(button_text, "button_gold" if button_text == "Choose" else "button", 56)
		b.custom_minimum_size.x = 120
		b.add_theme_font_size_override("font_size", UI.SIZE_SMALL)
		b.disabled = button_text != "Choose"
		b.pressed.connect(action as Callable)
		row.add_child(b)
	return card


func _refresh_charter(c: RunState.ColonyState) -> void:
	var next: int = c.charter + 1
	var title: String = "No charter" if c.charter == 0 else str(Content.charters[c.charter - 1]["title"])
	var pct: int = int(Balance.v("charter_bonus_per_level") * 100.0)
	var next_title: String = str(Content.charters[next - 1]["title"]) if next <= Content.charters.size() else ""
	_charter_title.text = "Charter: %s  %s\n+%d%% production and cargo per rank%s" % [title, "★".repeat(c.charter), pct, ("\nNext: " + next_title) if next_title != "" else ""]
	var cost: Dictionary = Balance.charter_cost(Game.run, c, next)
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
		if not item.has_meta("res") or item.is_queued_for_deletion():
			continue
		var key: String = item.get_meta("res")
		var need: float = float(cost.get(key, 0.0))
		var have: float = Game.run.stock_of(key)
		var l: Label = item.get_node("Amount")
		l.text = "%s / %s" % [Format.num(have), Format.num(need)]
		l.add_theme_color_override("font_color", UI.GREEN if have >= need else UI.RED)
	_charter_button.set_cost("Grant", Game.charter_affordable(c.id), "")
