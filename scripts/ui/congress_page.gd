## Continental Congress: invite Founding Fathers (bonuses for this run), spend
## Liberty on permanent reforms, and - once ready - declare independence.
class_name CongressPage
extends Page

signal declare_requested

var _gold_bar: ProgressBar
var _gold_label: Label
var _musket_label: Label
var _liberty_label: Label
var _declare: Button
var _father_cards: Dictionary = {}
var _upgrade_rows: Dictionary = {}
var _liberty_have: Label
var _structure: String = ""
var _roster: GovernorRoster


func _build_header(box: VBoxContainer) -> void:
	box.add_child(page_title("Continental Congress"))
	var card := UI.card("panel")
	var v := UI.vbox(8)
	card.add_child(v)
	var head := UI.hbox(12)
	head.add_child(UI.icon_rect(UI.icon("liberty"), 64))
	var hv := UI.vbox(2)
	hv.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hv.add_child(UI.label("Declaration of Independence", UI.SIZE_BIG, UI.INK, true))
	hv.add_child(UI.wrap_label("When the colonies are rich and armed, declare independence. The expedition ends; you keep Liberty to spend on lasting reforms.", UI.SIZE_SMALL, UI.INK_SOFT))
	head.add_child(hv)
	v.add_child(head)
	_gold_label = UI.wrap_label("", UI.SIZE_SMALL, UI.INK)
	v.add_child(_gold_label)
	_gold_bar = UI.bar("bar_fill")
	v.add_child(_gold_bar)
	_musket_label = UI.wrap_label("", UI.SIZE_SMALL, UI.INK)
	v.add_child(_musket_label)
	_liberty_label = UI.wrap_label("", UI.SIZE_BODY, UI.INK)
	v.add_child(_liberty_label)
	_declare = UI.button("Declare Independence", "button_gold", 80)
	_declare.add_theme_font_override("font", UI.FONT_TITLE)
	_declare.add_theme_font_size_override("font_size", UI.SIZE_BIG)
	_declare.pressed.connect(func() -> void:
		Sfx.play("click")
		declare_requested.emit())
	v.add_child(_declare)
	box.add_child(card)


func refresh() -> void:
	var run: RunState = Game.run
	if run == null:
		return
	var gate: float = Balance.v("independence_gold")
	_gold_bar.value = clampf(run.lifetime_gold / gate, 0.0, 1.0)
	_gold_label.text = "Gold earned this expedition: %s / %s" % [Format.num(run.lifetime_gold), Format.num(gate)]
	var muskets: int = int(run.stock_of("muskets"))
	var need: int = int(Balance.v("independence_muskets"))
	_musket_label.text = ("✔ " if muskets >= need else "✘ ") + "Arm the militia: %d musket%s kept in the warehouse (%d)" % [need, "" if need == 1 else "s", muskets]
	_musket_label.add_theme_color_override("font_color", UI.GREEN if muskets >= need else UI.RED)
	var payout: int = Balance.liberty_payout(run)
	# Liberty grows with gold earned (a power below 1), so carrying on past
	# the goal pays: say how much.
	_liberty_label.text = ("Liberty on declaring: %s  (double your gold: about %s)" % [Format.num(payout), Format.num(floorf(payout * pow(2.0, Balance.v("liberty_exponent"))))]) if payout > 0 else "Liberty on declaring: none yet"
	var ready: bool = Balance.independence_ready(run)
	_declare.disabled = not ready

	var key: String = "%d:%d|" % [run.map_seed, int(run.started_unix)] + ",".join(run.fathers) + "|" + str(Game.meta.liberty > 0 or Game.meta.runs_completed > 0)
	if key != _structure:
		_structure = key
		_rebuild()
	for id: String in _father_cards.keys():
		_update_father(id)
	_update_upgrades()
	if _roster != null:
		_roster.refresh()


func _rebuild() -> void:
	clear_list()
	_father_cards.clear()
	_upgrade_rows.clear()

	list.add_child(section("Founding Fathers"))
	list.add_child(UI.wrap_label("Great figures join your Congress for this expedition in exchange for gold and kept goods.", UI.SIZE_SMALL, UI.LIGHT_SOFT))
	# Everyone offered this run is shown, by tier, so any figure can be
	# chosen (or skipped) regardless of the others.
	var offered: Array[Dictionary] = Balance.fathers_offered(Game.run)
	offered.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return int(a.get("tier", 1)) < int(b.get("tier", 1)))
	var tier_shown: int = 0
	const TIER_NAMES := ["", "First Congress", "Men and Women of Affairs", "The Cause", "The Founders"]
	for def: Dictionary in offered:
		var id: String = def["id"]
		var joined: bool = Game.run.has_father(id)
		var tier: int = int(def.get("tier", 1))
		if tier != tier_shown:
			tier_shown = tier
			list.add_child(UI.label(TIER_NAMES[clampi(tier, 1, 4)], UI.SIZE_BODY, UI.GOLD, true))
		var card := _father_card(def, joined)
		_father_cards[id] = card
		list.add_child(card)

	list.add_child(section("Liberty Reforms"))
	var lib_row := UI.hbox(8)
	lib_row.add_child(UI.icon_rect(UI.icon("liberty"), 36))
	_liberty_have = UI.label("", UI.SIZE_BODY, UI.LIGHT)
	lib_row.add_child(_liberty_have)
	list.add_child(lib_row)
	list.add_child(UI.wrap_label("Permanent. These survive every declaration of independence.", UI.SIZE_SMALL, UI.LIGHT_SOFT))
	var icons: Dictionary = {"industry": "pick", "navigation": "ship_icon", "settlement": "colonist", "commerce": "gold", "manufacture": "hammer"}
	for def: Dictionary in Content.liberty_upgrades:
		var id: String = def["id"]
		var row := UpgradeRow.new(str(icons.get(id, "star")), func() -> bool: return Game.buy_liberty_upgrade(id))
		_upgrade_rows[id] = row
		list.add_child(row)

	list.add_child(section("Governors"))
	_roster = GovernorRoster.new()
	list.add_child(_roster)


func _father_card(def: Dictionary, joined: bool) -> Control:
	var id: String = def["id"]
	var card := UI.card("card")
	var v := UI.vbox(8)
	card.add_child(v)
	var head := UI.hbox(12)
	var portrait := UI.icon_rect(UI.icon("portrait_" + id), 64)
	head.add_child(portrait)
	var hv := UI.vbox(0)
	hv.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hv.add_child(UI.label(str(def["name"]), UI.SIZE_BIG, UI.INK, true))
	hv.add_child(UI.label(str(def["title"]), UI.SIZE_SMALL, UI.INK_SOFT))
	var eff := UI.label(str(def["desc"]), UI.SIZE_BODY, UI.GREEN)
	eff.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	eff.resized.connect(eff.update_minimum_size)
	eff.custom_minimum_size.x = 10
	hv.add_child(eff)
	head.add_child(hv)
	v.add_child(head)
	if joined:
		card.modulate = Color(1, 1, 1, 0.85)
		v.add_child(UI.label("★ Serving in Congress", UI.SIZE_SMALL, UI.GREEN))
		return card
	var costs := HFlowContainer.new()
	costs.add_theme_constant_override("h_separation", 14)
	var cost_labels: Dictionary = {}
	for key: String in (def["cost"] as Dictionary).keys():
		var item := UI.hbox(4)
		item.add_child(UI.icon_rect(UI.icon(key), 30))
		var l := UI.label("", UI.SIZE_SMALL, UI.INK)
		item.add_child(l)
		cost_labels[key] = l
		costs.add_child(item)
	v.add_child(costs)
	card.set_meta("costs", cost_labels)
	var b := BuyButton.new(func() -> bool:
		var ok: bool = Game.join_father(id)
		if ok:
			Sfx.play("father")
			refresh()
		return ok)
	b.custom_minimum_size.y = 70
	v.add_child(b)
	card.set_meta("buy", b)
	return card


func _update_father(id: String) -> void:
	var card: Control = _father_cards[id]
	if not card.has_meta("buy"):
		return
	var def: Dictionary = Content.father(id)
	var labels: Dictionary = card.get_meta("costs")
	for key: String in labels.keys():
		var need: float = float(Balance.father_cost(Game.run, id)[key])
		var have: float = Game.run.gold if key == "gold" else Balance.spendable(Game.run, key)
		var l: Label = labels[key]
		l.text = Format.num(need) if key == "gold" else "%s / %s" % [Format.num(have), Format.num(need)]
		l.add_theme_color_override("font_color", UI.GREEN if have >= need else UI.RED)
	var ok: bool = Game.father_affordable(id)
	var hint: String = "Invite to Congress" if ok else "Keep the goods in the Warehouse"
	(card.get_meta("buy") as BuyButton).set_cost(hint, ok, "quill")


func _update_upgrades() -> void:
	if _liberty_have == null:
		return
	_liberty_have.text = "%d Liberty to spend" % Game.meta.liberty
	for id: String in _upgrade_rows.keys():
		var def: Dictionary = Content.liberty_upgrade(id)
		var row: UpgradeRow = _upgrade_rows[id]
		var lvl: int = Game.meta.level(id)
		var cost: int = Balance.liberty_upgrade_cost(Game.meta, id)
		row.title.text = "%s  Lv %d" % [def["name"], lvl]
		row.detail.text = "%s. %s" % [def["tagline"], def["desc"]]
		if cost < 0:
			row.buy.set_cost("Complete", false, "")
		else:
			row.buy.set_cost(str(cost), Game.meta.liberty >= cost, "liberty")
