## The Ledger: pages of the almanac, the relics found so far, and the
## colonies' record in numbers, from the useful to the purely curious.
class_name LedgerPage
extends Page

signal modal_requested(modal: Control)

var _almanac_label: Label
var _almanac_button: Button
var _relic_count: Label
var _relic_buttons: Dictionary = {}  # relic id -> Button
var _set_labels: Dictionary = {}  # set id -> Label
var _stat_values: Array = []  # [Label, Callable]
var _relic_key: String = ""


func _build_header(box: VBoxContainer) -> void:
	box.add_child(page_title("The Ledger", "Keepsakes, almanac pages and the colonies' record, down to the last beaver pelt."))

	var card := UI.card("panel")
	var row := UI.hbox(12)
	card.add_child(row)
	row.add_child(UI.icon_rect(UI.icon("almanac"), 64))
	var v := UI.vbox(2)
	v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	v.add_child(UI.label("The Almanac", UI.SIZE_BIG, UI.INK, true))
	_almanac_label = UI.wrap_label("", UI.SIZE_SMALL, UI.INK_SOFT)
	v.add_child(_almanac_label)
	row.add_child(v)
	_almanac_button = UI.button("Read a page", "button_gold", 64)
	_almanac_button.custom_minimum_size.x = 170
	_almanac_button.add_theme_font_size_override("font_size", UI.SIZE_SMALL)
	_almanac_button.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	_almanac_button.pressed.connect(func() -> void:
		if not Game.read_almanac():
			Sfx.play("deny")
		refresh())
	row.add_child(_almanac_button)
	box.add_child(card)


func _ready() -> void:
	super._ready()
	_build_relics()
	_build_stats()
	refresh()


# --- Relics -----------------------------------------------------------------------

func _build_relics() -> void:
	var head := UI.hbox(8)
	head.add_child(section("Relics of the Colonies"))
	head.add_child(UI.spacer())
	_relic_count = UI.label("", UI.SIZE_SMALL, UI.LIGHT_SOFT)
	head.add_child(_relic_count)
	list.add_child(head)
	list.add_child(UI.wrap_label("Found in drifting wrecks, brought home from each independence, or turned up when you settle more colonies than ever before. Relics are kept forever; a full set adds its own bonus.", UI.SIZE_SMALL, UI.LIGHT_SOFT))
	for s: Dictionary in Content.relic_sets:
		var card := UI.card("card")
		var v := UI.vbox(6)
		card.add_child(v)
		var top := UI.hbox(8)
		top.add_child(UI.label(str(s["name"]), UI.SIZE_BODY, UI.INK, true))
		top.add_child(UI.spacer())
		var bonus := UI.label("", UI.SIZE_SMALL, UI.INK_SOFT)
		top.add_child(bonus)
		_set_labels[s["id"]] = bonus
		v.add_child(top)
		var grid := HBoxContainer.new()
		grid.add_theme_constant_override("separation", 8)
		grid.alignment = BoxContainer.ALIGNMENT_CENTER
		for r: Dictionary in Content.relics_in_set(str(s["id"])):
			var id: String = str(r["id"])
			var b := Button.new()
			b.custom_minimum_size = Vector2(100, 100)
			b.expand_icon = true
			b.icon_alignment = HORIZONTAL_ALIGNMENT_CENTER
			b.add_theme_constant_override("icon_max_width", 64)
			b.texture_filter = UI.icon_filter(64)
			b.focus_mode = Control.FOCUS_NONE
			for st: String in ["normal", "hover", "pressed", "hover_pressed", "disabled"]:
				b.add_theme_stylebox_override(st, UI.frame("card", 14, 8))
			b.pressed.connect(func() -> void: _show_relic(id))
			grid.add_child(b)
			_relic_buttons[id] = b
		v.add_child(grid)
		list.add_child(card)


func _refresh_relics() -> void:
	var meta: MetaState = Game.meta
	var key: String = ",".join(meta.relics)
	if key == _relic_key:
		return
	_relic_key = key
	_relic_count.text = "%d / %d found" % [meta.relics.size(), Content.relics.size()]
	for id: String in _relic_buttons.keys():
		var b: Button = _relic_buttons[id]
		var owned: bool = meta.has_relic(id)
		b.icon = UI.icon("relic_" + id) if owned else UI.icon("relic_locked")
		b.tooltip_text = str(Content.relic(id)["name"]) if owned else "Not yet found"
	for s: Dictionary in Content.relic_sets:
		var l: Label = _set_labels[s["id"]]
		var done: bool = meta.set_complete(str(s["id"]))
		l.text = ("★ " if done else "Set: ") + str(s["desc"])
		l.add_theme_color_override("font_color", UI.GREEN if done else UI.INK_SOFT)


func _show_relic(id: String) -> void:
	Sfx.play("click")
	var r: Dictionary = Content.relic(id)
	if not Game.meta.has_relic(id):
		var m0 := Modal.new("Not Yet Found")
		m0.add_text("Somewhere in the colonies a piece of history waits to be found.", UI.SIZE_BODY, UI.INK_SOFT)
		m0.add_button("Close", "button_gold")
		modal_requested.emit(m0)
		return
	var m := Modal.new(str(r["name"]))
	var icon := UI.icon_rect(UI.icon("relic_" + id), 144)
	icon.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	m.body.add_child(icon)
	m.add_text("%d  ·  %s" % [int(r["year"]), str(Content.relic_set(str(r["set"]))["name"])], UI.SIZE_SMALL, UI.INK_SOFT)
	m.add_text(str(r["lore"]), UI.SIZE_BODY, UI.INK)
	m.add_text(str(r["desc"]), UI.SIZE_BODY, UI.GREEN)
	m.add_button("Close", "button_gold")
	modal_requested.emit(m)


# --- Statistics ---------------------------------------------------------------------

func _build_stats() -> void:
	var run_rows: Array = [
		["Time this expedition", func(run: RunState, _m: MetaState) -> String: return Format.duration(run.play_seconds)],
		["Gold earned", func(run: RunState, _m: MetaState) -> String: return Format.num(run.lifetime_gold)],
		["Colonies", func(run: RunState, _m: MetaState) -> String: return "%d / %d" % [run.colonies.size(), run.world.colony_order.size()]],
		["Colonists", func(run: RunState, _m: MetaState) -> String: return Format.num(run.colonists_owned)],
		["Shipments unloaded", func(run: RunState, _m: MetaState) -> String: return Format.num(run.shipments)],
		["Goods crafted", func(run: RunState, _m: MetaState) -> String: return Format.num(_sum(run.crafted))],
		["Founding Fathers", func(run: RunState, _m: MetaState) -> String: return "%d" % run.fathers.size()],
		["Milestones reached", func(run: RunState, _m: MetaState) -> String: return "%d" % _run_milestones(run)],
		["Liberty if declared now", func(run: RunState, m: MetaState) -> String: return Format.num(Balance.liberty_payout(run, m))],
	]
	var all_rows: Array = [
		["Independences declared", func(_r: RunState, m: MetaState) -> String: return "%d" % m.runs_completed],
		["Liberty earned", func(_r: RunState, m: MetaState) -> String: return Format.num(m.lifetime_liberty)],
		["Gold earned", func(_r: RunState, m: MetaState) -> String: return Format.num(m.stat("gold_earned"))],
		["Best expedition", func(_r: RunState, m: MetaState) -> String: return Format.num(m.best_run_gold)],
		["Fastest independence", func(_r: RunState, m: MetaState) -> String: return Format.duration(m.fastest_run_seconds) if m.fastest_run_seconds > 0.0 else "-"],
		["Most colonies at once", func(_r: RunState, m: MetaState) -> String: return "%d" % m.best_colonies],
		["Colonies founded", func(_r: RunState, m: MetaState) -> String: return Format.num(m.stat("colonies_founded"))],
		["Colonists recruited", func(_r: RunState, m: MetaState) -> String: return Format.num(m.stat("colonists_recruited"))],
		["Shipments unloaded", func(_r: RunState, m: MetaState) -> String: return Format.num(m.stat("shipments"))],
		["Goods crafted", func(_r: RunState, m: MetaState) -> String: return Format.num(m.stat("crafted"))],
		["Upgrades bought", func(_r: RunState, m: MetaState) -> String: return Format.num(m.stat("upgrades_bought"))],
		["Milestones reached", func(_r: RunState, m: MetaState) -> String: return Format.num(m.stat("milestones"))],
		["Founding Fathers welcomed", func(_r: RunState, m: MetaState) -> String: return Format.num(m.stat("fathers_joined"))],
		["Treasures salvaged", func(_r: RunState, m: MetaState) -> String: return Format.num(m.stat("treasures"))],
		["Royal Favors granted", func(_r: RunState, m: MetaState) -> String: return Format.num(m.stat("favors"))],
		["Relics found", func(_r: RunState, m: MetaState) -> String: return "%d / %d" % [m.relics.size(), Content.relics.size()]],
		["Almanac pages read", func(_r: RunState, m: MetaState) -> String: return Format.num(m.stat("almanacs_read"))],
		["Leagues by wagon", func(_r: RunState, m: MetaState) -> String: return Format.num(m.stat("land_leagues"))],
		["Leagues under sail", func(_r: RunState, m: MetaState) -> String: return Format.num(m.stat("sea_leagues"))],
		["Time at the helm", func(_r: RunState, m: MetaState) -> String: return Format.duration(m.stat("seconds_played"))],
		["Time the colonies ran alone", func(_r: RunState, m: MetaState) -> String: return Format.duration(m.stat("offline_seconds"))],
		["Times you came back", func(_r: RunState, m: MetaState) -> String: return Format.num(m.stat("app_opens"))],
	]
	var odd_rows: Array = [
		["Lanterns hung in the Old North Church", func(_r: RunState, m: MetaState) -> String: return Format.num(m.stat("land_colonies") + 2.0 * m.stat("sea_colonies"))],
		["Chests of tea tipped into the harbor", func(_r: RunState, m: MetaState) -> String: return "342" if m.has_relic("tea_chest") else "0 (so far)"],
		["Kites flown in thunderstorms", func(_r: RunState, m: MetaState) -> String: return Format.num(m.stat("father_franklin"))],
		["Beaver pelts sent to the hatters", func(_r: RunState, m: MetaState) -> String: return Format.num(m.stat("delivered_furs"))],
		["Barrels of rum that went missing", func(_r: RunState, m: MetaState) -> String: return Format.num(floorf(m.stat("crafted_rum") * 0.03))],
		["Ship's biscuits eaten by sailors", func(_r: RunState, m: MetaState) -> String: return Format.num(m.stat("sea_leagues") * 36.0)],
		["Oxen who deserve a rest", func(_r: RunState, m: MetaState) -> String: return Format.num(m.stat("land_colonies") * 6.0)],
		["Quills worn down in Congress", func(_r: RunState, m: MetaState) -> String: return Format.num(m.stat("fathers_joined") * 12.0 + m.runs_completed * 56.0)],
		["Letters home to Europe", func(_r: RunState, m: MetaState) -> String: return Format.num(floorf(m.stat("shipments") / 3.0))],
		["Coffees at the London Coffee House", func(_r: RunState, m: MetaState) -> String: return Format.num(floorf(m.stat("seconds_played") / 900.0))],
		["Weight of all that gold, in tons", func(_r: RunState, m: MetaState) -> String: return Format.num(m.stat("gold_earned") * 8.4 / 907185.0, 2)],
		["Times Poor Richard was right", func(_r: RunState, m: MetaState) -> String: return Format.num(m.stat("almanacs_read") + m.stat("app_opens"))],
	]
	_stats_card("This Expedition", run_rows, true)
	_stats_card("All Time", all_rows, false)
	_stats_card("Curiosities", odd_rows, false)


func _stats_card(title: String, rows: Array, needs_run: bool) -> void:
	list.add_child(section(title))
	var card := UI.card("card")
	var grid := GridContainer.new()
	grid.columns = 2
	grid.add_theme_constant_override("h_separation", 16)
	grid.add_theme_constant_override("v_separation", 6)
	card.add_child(grid)
	for r: Array in rows:
		var name := UI.label(str(r[0]), UI.SIZE_SMALL, UI.INK_SOFT)
		name.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		name.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		name.resized.connect(name.update_minimum_size)
		name.custom_minimum_size.x = 10
		grid.add_child(name)
		var value := UI.label("", UI.SIZE_SMALL, UI.INK)
		value.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		grid.add_child(value)
		_stat_values.append([value, r[1], needs_run])
	list.add_child(card)


func _sum(d: Dictionary) -> float:
	var t: float = 0.0
	for v: Variant in d.values():
		t += float(v)
	return t


func _run_milestones(run: RunState) -> int:
	var n: int = 0
	for c: RunState.ColonyState in run.colonies:
		n += Balance.milestone_count(c.prod_level) + Balance.milestone_count(c.cargo_level) + Balance.milestone_count(c.speed_level)
	for w: RunState.WorkshopState in run.workshops.values():
		n += Balance.milestone_count(w.level)
	return n


func refresh() -> void:
	if not is_visible_in_tree():
		return
	var meta: MetaState = Game.meta
	var run: RunState = Game.run
	var pages: int = meta.almanacs
	_almanac_label.text = "%s. Each page skips ahead %s: the colonies work, the wagons roll and the gold comes in, all at once." % [
		("%d page%s saved" % [pages, "" if pages == 1 else "s"]) if pages > 0 else "No pages yet",
		Format.duration(Balance.v("almanac_seconds"))]
	_almanac_button.disabled = pages <= 0 or run == null
	_refresh_relics()
	for entry: Array in _stat_values:
		var l: Label = entry[0]
		var t: String = "-"
		if run != null or not bool(entry[2]):
			t = (entry[1] as Callable).call(run, meta)
		if l.text != t:
			l.text = t
