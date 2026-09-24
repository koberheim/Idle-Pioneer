## First-time tips, one at a time, each shown once when it becomes relevant.
## The player can turn them off here or in Settings.
class_name Tutorial
extends PanelContainer

signal go(target: String)

var _label: Label
var _current: Dictionary = {}
var _cooldown: float = 2.0
var _market_period: int = -1


func _init() -> void:
	add_theme_stylebox_override("panel", UI.frame("panel", 14, 16))
	mouse_filter = Control.MOUSE_FILTER_STOP
	visible = false
	var v := UI.vbox(10)
	add_child(v)
	var head := UI.hbox(12)
	head.add_child(UI.icon_rect(UI.icon("portrait"), 56))
	var hv := UI.vbox(2)
	hv.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hv.add_child(UI.label("Your Advisor", UI.SIZE_BIG, UI.INK, true))
	_label = UI.wrap_label("", UI.SIZE_BODY, UI.INK)
	hv.add_child(_label)
	head.add_child(hv)
	v.add_child(head)
	var row := UI.hbox(10)
	row.alignment = BoxContainer.ALIGNMENT_END
	var hide := UI.button("Hide tips", "button", 56)
	hide.custom_minimum_size.x = 160
	hide.add_theme_font_size_override("font_size", UI.SIZE_SMALL)
	hide.pressed.connect(func() -> void:
		Sfx.play("click")
		Game.meta.tips_on = false
		_dismiss())
	var show := UI.button("Show me", "button", 56)
	show.custom_minimum_size.x = 160
	show.add_theme_font_size_override("font_size", UI.SIZE_SMALL)
	show.name = "ShowMe"
	show.pressed.connect(func() -> void:
		Sfx.play("click")
		var target: String = _current.get("target", "")
		_dismiss()
		if target != "":
			go.emit(target))
	var ok := UI.button("Got it", "button_gold", 56)
	ok.custom_minimum_size.x = 160
	ok.pressed.connect(func() -> void:
		Sfx.play("click")
		_dismiss())
	row.add_child(hide)
	row.add_child(show)
	row.add_child(ok)
	v.add_child(row)


func _dismiss() -> void:
	if not _current.is_empty():
		Game.mark_hint_seen("tip_" + str(_current["id"]))
	_current = {}
	visible = false
	_cooldown = 4.0
	Game.save()


func _process(delta: float) -> void:
	if Game.run == null or not Game.meta.tips_on:
		visible = false
		return
	if not _current.is_empty():
		return
	_cooldown -= delta
	if _cooldown > 0.0:
		return
	_cooldown = 1.0
	for tip: Dictionary in _tips():
		if Game.meta.hints_seen.has("tip_" + str(tip["id"])):
			continue
		if (tip["when"] as Callable).call():
			_current = tip
			_label.text = tip["text"]
			(find_child("ShowMe", true, false) as Button).visible = str(tip.get("target", "")) != ""
			visible = true
			Sfx.play("discover")
			return


func _tips() -> Array[Dictionary]:
	var run: RunState = Game.run
	var meta: MetaState = Game.meta
	var cap_name: String = Content.colony_name(run.nation_id, 0)
	var market_changed: bool = false
	var period: int = int(Balance.market_state(run)["period"])
	if _market_period >= 0 and period != _market_period:
		market_changed = true
	_market_period = period
	return [
		{"id": "welcome", "target": "colony:c0",
			"text": "Welcome to the New World! %s cuts timber and sells it to Europe for gold. Tap it on the map to improve its production." % cap_name,
			"when": func() -> bool: return true},
		{"id": "buying", "target": "",
			"text": "Every upgrade raises output. Hold a buy button to keep buying, or switch between x1, x10, x100 and Max.",
			"when": func() -> bool: return run.capital().prod_level > 0},
		{"id": "colonists", "target": "tab:2",
			"text": "Recruit colonists at the Docks of Europe. Each one doubles a colony's output, or can work in a workshop.",
			"when": func() -> bool: return run.colonists_owned == 0 and run.gold >= Balance.colonist_cost(run, meta)},
		{"id": "assign", "target": "colony:c0",
			"text": "You have an idle colonist. Tap a colony and press + to put them to work.",
			"when": func() -> bool: return run.colonists_idle() > 0 and run.colonists_owned <= 2},
		{"id": "next_site", "target": "site",
			"text": "Your surveyors have flagged a site for the next colony. Its terrain decides what it produces, and whether wagons or ships will carry its goods.",
			"when": func() -> bool: return run.colonies.size() == 1 and run.gold >= Balance.found_cost(run, meta) * 0.4},
		{"id": "routes", "target": "colony:c1",
			"text": "Goods travel to the capital by wagon or by ship. Ships are slower but carry far more. If goods pile up at a colony, upgrade its cargo and speed.",
			"when": func() -> bool: return run.colonies.size() >= 2},
		{"id": "map", "target": "",
			"text": "Drag to explore, pinch or use + and - to zoom, and tap the scroll for the continental map. Each colony you found reveals more of the land.",
			"when": func() -> bool: return run.colonies.size() >= 2},
		{"id": "sawmill", "target": "tab:1",
			"text": "Raw timber sells cheap. Build a Sawmill in Workshops to turn it into lumber worth more than twice as much.",
			"when": func() -> bool: return not run.workshop("lumber").built and run.gold >= Balance.workshop_build_cost("lumber")},
		{"id": "keeping", "target": "tab:2",
			"text": "Workshops take their inputs from the warehouse, so staffing one keeps those goods instead of selling them. You can change what is kept in the Europe tab.",
			"when": func() -> bool: return run.workshop("lumber").colonists > 0},
		{"id": "chains", "target": "tab:1",
			"text": "Finer goods are made from other crafted goods: charcoal and iron ore make pig iron, pig iron and lumber make tools. The deeper the chain, the richer the reward.",
			"when": func() -> bool: return run.discovered.has("iron_ore")},
		{"id": "fathers", "target": "tab:3",
			"text": "Founding Fathers will join your Congress for gold and kept goods. Each grants a bonus for the rest of this expedition.",
			"when": func() -> bool: return run.lifetime_gold >= 2000.0},
		{"id": "market", "target": "tab:2",
			"text": "Demand in Europe shifts every half hour. Goods marked Wanted sell for much more, so it can pay to keep them until the price is right.",
			"when": func() -> bool: return market_changed or run.play_seconds > Balance.v("market_period_seconds")},
		{"id": "favor", "target": "",
			"text": "The Crown is in a generous mood. Tap \"×2 Favor\" at the top to double production for a while. You can ask again every two hours.",
			"when": func() -> bool: return run.colonies.size() >= 3 and Game.favor_ready_in() <= 0.0},
		{"id": "independence", "target": "tab:3",
			"text": "Once the colonies have earned a billion gold and armed a militia with Muskets, you can declare independence. You'll earn Liberty for lasting reforms, then start a new expedition stronger than before.",
			"when": func() -> bool: return run.lifetime_gold >= Balance.v("independence_gold") * 0.1},
	]
