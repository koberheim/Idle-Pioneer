## Root of the game screen: top bar, the four tabs (New World map, Workshops,
## Europe, Congress), the sliding colony sheet, and every overlay.
extends Control

const REFRESH_SECONDS := 0.2
const TAB_NAMES: Array[String] = ["New World", "Workshops", "Europe", "Congress", "Ledger"]
const TAB_ICONS: Array[String] = ["map", "hammer", "ship_icon", "quill", "ledger"]
## Music context per tab index (Sfx.set_music_context); unlisted tabs use the theme.
const TAB_MUSIC: Dictionary = {2: "europe", 3: "congress"}

var _gold_label: Label
var _income_label: Label
var _liberty_label: Label
var _colonist_label: Label
var _favor: Button
var _favor_state: String = ""
var _content: Control
var _map: MapView
var _pages: Array[Control] = []
var _tab_buttons: Array[Button] = []
var _tab: int = 0
var _sheet: ColonySheet
var _sheet_t: float = 0.0
var _sheet_tween: Tween
var _advisor: Advisor
var _tutorial: Tutorial
var _overlay: Control
var _toasts: Toasts
var _nation_select: NationSelect
var _refresh_timer: float = 0.0
var _advisor_timer: float = 0.0
var _last_ship_sound: int = 0
var _top_pad: float = 0.0


func _ready() -> void:
	theme = UI.theme()
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_top_pad = _safe_top()
	_build()
	Game.offline_progress.connect(_on_offline)
	Game.colony_founded.connect(_on_founded)
	Game.resource_discovered.connect(_on_discovered)
	Game.father_joined.connect(func(id: String) -> void:
		_toasts.push("%s joins the Continental Congress!" % Content.father(id)["name"], "quill", 3.5))
	Game.workshop_built.connect(func(id: String) -> void:
		Sfx.play("workshop")
		_toasts.push("%s built. Assign colonists to begin." % Content.recipe(id)["building"], "hammer"))
	Game.shipment_arrived.connect(_on_shipment)
	Game.market_changed.connect(func() -> void:
		var m: Dictionary = Balance.market_state(Game.run)
		var names: PackedStringArray = []
		for id: String in m["up"]:
			names.append(Content.resource_name(id))
		Sfx.play("market")
		_toasts.push("News from Europe: demand soars for %s." % ", ".join(names), "ship_icon", 4.0)
		# Now and then, a line from the colonial papers.
		if randf() < 0.5:
			var g: String = Content.flavor_line("gazette")
			if g != "":
				_toasts.push(g, "scroll", 4.5))
	Game.milestone_reached.connect(_on_milestone)
	Game.relic_found.connect(_on_relic)
	Game.almanac_gained.connect(func(count: int, source: String) -> void:
		if source == "independence":
			return
		Sfx.play("page")
		_toasts.push("You found %s of the Almanac! Read %s in the Ledger." % ["a page" if count == 1 else "%d pages" % count, "it" if count == 1 else "them"], "almanac", 4.0))
	Game.almanac_read.connect(_on_almanac_read)
	Game.catch_up_progress.connect(_on_catch_up_progress)
	Platform.rewarded_finished.connect(func(placement: String, completed: bool) -> void:
		if placement != "almanac":
			return
		if completed:
			if not Game.consult_almanac():
				_toasts.push("The almanac was already consulted; try again when it's ready.", "almanac", 3.0)
		else:
			_toasts.push("The almanac closes unread. No reward this time.", "almanac", 3.0))
	Platform.purchase_failed.connect(func(reason: String) -> void:
		Sfx.play("deny")
		_toasts.push(reason, "lock", 4.0))
	Platform.ad_free_changed.connect(func(owned: bool) -> void:
		if owned:
			Sfx.play("purchase")
			_toasts.push("Thank you! Ads are gone for good.", "star", 4.0))
	Game.save_status_changed.connect(func(ok: bool) -> void:
		_save_banner.visible = not ok
		if ok:
			_toasts.push("Progress saved.", "scroll", 2.0))
	get_tree().root.size_changed.connect(_layout_sheet)

	var booted: bool = Game.boot()
	apply_ui_scale()
	Format.notation = Game.meta.notation
	if booted:
		_start_ui()
	elif Game.save_from_newer_version:
		var m := Modal.new("Please Update the Game")
		m.add_text("Your saved colonies come from a newer version of Idle Pioneer. Update the game to continue; your progress is safe and has not been changed.", UI.SIZE_BODY, UI.INK_SOFT)
		_overlay.add_child(m)
	else:
		_show_nation_select()


const LARGE_UI_SCALE := 1.15


## Everything (text, buttons, icons) a little bigger for easier reading and
## tapping; the layout reflows into the narrower space.
func apply_ui_scale() -> void:
	get_tree().root.content_scale_factor = LARGE_UI_SCALE if Game.meta.large_ui else 1.0


func _safe_bottom() -> float:
	return UI.safe_insets(self).y


func _safe_top() -> float:
	return UI.safe_insets(self).x


# --- Construction ---------------------------------------------------------------

func _build() -> void:
	var bg := ColorRect.new()
	bg.color = Color("161d33")
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(bg)

	var root := UI.vbox(0)
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(root)
	root.add_child(_build_top_bar())

	_content = Control.new()
	_content.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_content.clip_contents = true
	root.add_child(_content)

	_map = MapView.new()
	_map.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_map.colony_tapped.connect(_open_colony)
	_map.treasure_tapped.connect(func(_at: Vector2) -> void:
		Sfx.play("treasure")
		_toasts.push("Salvaged a drifting cargo from a wrecked merchantman!", "chest", 2.5))
	_map.next_site_tapped.connect(_open_next_site)
	_map.overview_requested.connect(_show_overview)
	_map.consult_requested.connect(_on_consult)
	_content.add_child(_map)
	_pages.append(_map)

	var workshops := WorkshopsPage.new()
	workshops.research_requested.connect(func() -> void:
		var rs := ResearchScreen.new()
		_overlay.add_child(rs))
	var europe := EuropePage.new()
	var congress := CongressPage.new()
	congress.declare_requested.connect(_show_independence)
	var ledger := LedgerPage.new()
	ledger.modal_requested.connect(func(m: Control) -> void: _overlay.add_child(m))
	for p: Control in [workshops, europe, congress, ledger]:
		p.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		p.visible = false
		_content.add_child(p)
		_pages.append(p)

	_advisor = Advisor.new()
	_advisor.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
	_advisor.offset_left = 14
	_advisor.offset_right = -14
	_advisor.offset_bottom = -12
	_advisor.grow_vertical = Control.GROW_DIRECTION_BEGIN
	_advisor.go.connect(_on_advisor_go)
	_content.add_child(_advisor)

	_sheet = ColonySheet.new()
	_sheet.visible = false
	_sheet.closed.connect(_close_sheet)
	_sheet.modal_requested.connect(func(m: Control) -> void: _overlay.add_child(m))
	_content.add_child(_sheet)

	root.add_child(_build_nav())

	_overlay = Control.new()
	_overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_overlay)
	# Shown while saving is failing (full storage, say); hidden once it recovers.
	_save_banner = PanelContainer.new()
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color("7a2418")
	sb.set_content_margin_all(10)
	_save_banner.add_theme_stylebox_override("panel", sb)
	_save_banner.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
	_save_banner.offset_top = 104 + _top_pad
	_save_banner.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var sl := UI.label("Couldn't save your progress (is the device storage full?). Retrying...", UI.SIZE_SMALL, UI.LIGHT)
	sl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	sl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_save_banner.add_child(sl)
	_save_banner.visible = not Game.save_ok
	add_child(_save_banner)
	_toasts = Toasts.new()
	_toasts.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
	_toasts.offset_top = 118 + _top_pad
	_toasts.offset_left = 30
	_toasts.offset_right = -30
	_overlay.add_child(_toasts)
	_tutorial = Tutorial.new()
	_tutorial.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
	_tutorial.offset_top = 120 + _top_pad
	_tutorial.offset_left = 16
	# Leaves the map's button column (zoom, chart, almanac) uncovered.
	_tutorial.offset_right = -96
	_tutorial.go.connect(_on_advisor_go)
	_overlay.add_child(_tutorial)


func _build_top_bar() -> Control:
	var bar := PanelContainer.new()
	var sb := UI.frame("panel_dark", 14, 12)
	sb.content_margin_top = 10.0 + _top_pad
	bar.add_theme_stylebox_override("panel", sb)
	var row := UI.hbox(6)
	bar.add_child(row)

	row.add_child(UI.icon_rect(UI.icon("gold"), 52))
	var gv := UI.vbox(-4)
	_gold_label = UI.label("0", 34, UI.GOLD, true)
	_income_label = UI.label("", UI.SIZE_SMALL, UI.LIGHT_SOFT)
	gv.add_child(_gold_label)
	gv.add_child(_income_label)
	gv.custom_minimum_size.x = 150
	row.add_child(gv)
	row.add_child(UI.spacer())

	_favor = UI.button("", "button_gold", 60)
	_favor.custom_minimum_size.x = 104
	_favor.tooltip_text = "Royal Favor: double production for a while"
	_favor.icon = UI.icon("star")
	_favor.expand_icon = true
	_favor.texture_filter = UI.icon_filter(26)
	_favor.add_theme_constant_override("icon_max_width", 26)
	_favor.add_theme_font_size_override("font_size", UI.SIZE_SMALL)
	_favor.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	_favor.pressed.connect(_on_favor)
	row.add_child(_favor)

	row.add_child(UI.icon_rect(UI.icon("colonist"), 40))
	_colonist_label = UI.label("", UI.SIZE_BODY, UI.LIGHT)
	row.add_child(_colonist_label)
	row.add_child(UI.icon_rect(UI.icon("liberty"), 40))
	_liberty_label = UI.label("", UI.SIZE_BODY, UI.LIGHT)
	row.add_child(_liberty_label)

	var gear := Button.new()
	gear.icon = UI.icon("gear")
	gear.expand_icon = true
	gear.focus_mode = Control.FOCUS_NONE
	gear.custom_minimum_size = Vector2(68, 68)
	gear.texture_filter = UI.icon_filter(40)
	gear.add_theme_constant_override("icon_max_width", 40)
	gear.pressed.connect(_show_settings)
	row.add_child(gear)
	return bar


func _build_nav() -> Control:
	var bar := PanelContainer.new()
	var nsb := UI.frame("panel_dark", 14, 6)
	# Keep the tabs clear of the home indicator / gesture bar.
	nsb.content_margin_bottom = 6.0 + _safe_bottom()
	bar.add_theme_stylebox_override("panel", nsb)
	var row := UI.hbox(6)
	bar.add_child(row)
	for i in TAB_NAMES.size():
		var b := Button.new()
		b.text = TAB_NAMES[i]
		b.icon = UI.icon(TAB_ICONS[i])
		b.expand_icon = true
		b.icon_alignment = HORIZONTAL_ALIGNMENT_CENTER
		b.vertical_icon_alignment = VERTICAL_ALIGNMENT_TOP
		b.add_theme_constant_override("icon_max_width", 44)
		b.add_theme_font_size_override("font_size", UI.SIZE_SMALL)
		b.texture_filter = UI.icon_filter(44)
		b.focus_mode = Control.FOCUS_NONE
		b.custom_minimum_size.y = 104
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		var idx: int = i
		b.pressed.connect(func() -> void:
			Sfx.play("tab")
			_select_tab(idx))
		row.add_child(b)
		_tab_buttons.append(b)
	_style_tabs()
	return bar


var _congress_ready: bool = false


func _style_tabs() -> void:
	for i in _tab_buttons.size():
		var b: Button = _tab_buttons[i]
		var on: bool = i == _tab
		var style: String = "tab_active" if on else "tab"
		for s: String in ["normal", "hover", "pressed", "hover_pressed"]:
			b.add_theme_stylebox_override(s, UI.frame(style, 14, 6))
		var col: Color = UI.INK if on else UI.LIGHT_SOFT
		# Congress glows gold while independence can be declared.
		if i == 3 and _congress_ready and not on:
			col = UI.GOLD
		for s: String in ["font_color", "font_hover_color", "font_pressed_color", "font_hover_pressed_color"]:
			b.add_theme_color_override(s, col)


# --- Flow -----------------------------------------------------------------------

func _show_nation_select() -> void:
	_close_sheet()
	_nation_select = NationSelect.new()
	_nation_select.nation_chosen.connect(func(id: String, style: String) -> void:
		Game.start_run(id, style)
		_nation_select.queue_free()
		_nation_select = null
		_start_ui()
		_toasts.push("Your ships make landfall. Welcome to %s!" % Content.colony_name(id, 0), "ship_icon", 4.0)
		_announce_unlocks())
	_overlay.add_child(_nation_select)
	_overlay.move_child(_nation_select, 0)


## New systems open up over successive expeditions; introduce each once.
const UNLOCK_NOTES := {
	"ledger": ["ledger", "The Ledger", "A new tab with your colonial record, from gold earned to the oxen who deserve a rest."],
	"relics": ["relic_locked", "Relics", "Pieces of colonial history turn up in drifting wrecks, at each independence, and when you settle more colonies than ever before. Each gives a lasting bonus; full sets give more."],
	"almanac": ["almanac", "The Almanac", "Rare almanac pages skip an hour ahead when read, all at once. Find them in the Ledger."],
	"specializations": ["spec_boomtown", "Specializations", "When a colony earns its first charter, choose what kind of town it becomes: a Boomtown, a Market Town, a Deepwater Harbor..."],
	"research": ["society", "The Philosophical Society", "Franklin's society for useful knowledge opens on the Workshops tab. Pay goods and gold for studies across six branches; they last for this expedition."],
}


func _announce_unlocks() -> void:
	var fresh: Array = []
	for f: String in UNLOCK_NOTES.keys():
		var n: int = Balance.unlock_runs(f)
		if n > 0 and Game.meta.runs_completed >= n and not Game.meta.hints_seen.has("unlock_" + f):
			Game.mark_hint_seen("unlock_" + f)
			fresh.append(f)
	if fresh.is_empty():
		return
	var m := Modal.new("New in the Colonies")
	for f: String in fresh:
		var note: Array = UNLOCK_NOTES[f]
		var row := UI.hbox(12)
		row.add_child(UI.icon_rect(UI.icon(str(note[0])), 56))
		var v := UI.vbox(2)
		v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		v.add_child(UI.label(str(note[1]), UI.SIZE_BIG, UI.INK, true))
		v.add_child(UI.wrap_label(str(note[2]), UI.SIZE_SMALL, UI.INK_SOFT))
		row.add_child(v)
		m.body.add_child(row)
	m.add_button("Onward", "button_gold")
	_overlay.add_child(m)
	Sfx.play("unlock")


func _start_ui() -> void:
	_select_tab(0)
	_map.center_on_colony("c0", false, 0.45)
	Sfx.sync_music()
	_refresh()


func _select_tab(i: int) -> void:
	_tab = i
	for j in _pages.size():
		_pages[j].visible = j == i
	if i != 0:
		_close_sheet()
	_style_tabs()
	_advisor.visible = false
	Sfx.set_music_context(TAB_MUSIC.get(i, "theme"))
	_refresh()


func _open_colony(id: String) -> void:
	if _tab != 0:
		_select_tab(0)
	Sfx.play("click" if _sheet.visible else "sheet_up")
	_sheet.show_colony(id)
	_sheet.visible = true
	_map.set_highlight(id)
	_animate_sheet(1.0)
	_map.center_on_colony(id, true, 0.22)


func _open_next_site() -> void:
	if _tab != 0:
		_select_tab(0)
	Sfx.play("click" if _sheet.visible else "sheet_up")
	_sheet.show_next_site()
	_sheet.visible = true
	_map.set_highlight("")
	_animate_sheet(1.0)
	_map.center_on_next_site(0.22)


func _show_overview() -> void:
	var chart := ContinentalMap.new()
	chart.data_tex = _map.data_texture()
	chart.relief_tex = _map.relief_texture()
	chart.jump_to.connect(func(p: Vector2) -> void: _map.look_at_world(p, 0.45))
	_overlay.add_child(chart)


func _close_sheet() -> void:
	if _sheet == null or not _sheet.visible:
		return
	_map.set_highlight("")
	Sfx.play("sheet_down")
	_animate_sheet(0.0)


func _animate_sheet(target: float) -> void:
	if _sheet_tween != null:
		_sheet_tween.kill()
	_sheet_tween = create_tween()
	_sheet_tween.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	_sheet_tween.tween_method(func(t: float) -> void:
		_sheet_t = t
		_layout_sheet(), _sheet_t, target, 0.25)
	if target <= 0.0:
		_sheet_tween.tween_callback(func() -> void: _sheet.visible = false)


func _layout_sheet() -> void:
	if _sheet == null:
		return
	var w: float = _content.size.x
	_sheet.fit(floorf(_content.size.y * 0.74))
	var h: float = ceilf(minf(_sheet.get_combined_minimum_size().y, _content.size.y))
	if absf(_sheet.size.y - h) >= 1.0 or absf(_sheet.size.x - w) >= 1.0:
		_sheet.size = Vector2(w, h)
	_sheet.position = Vector2(0, roundf(_content.size.y - h * _sheet_t))


func _on_advisor_go(target: String) -> void:
	if target == "site":
		_open_next_site()
	elif target.begins_with("colony:"):
		_open_colony(target.substr(7))
	elif target.begins_with("tab:"):
		_select_tab(int(target.substr(4)))


func _show_independence() -> void:
	var o := IndependenceOverlay.new()
	o.commit = func() -> int: return Game.declare_independence()
	o.finished.connect(func() -> void:
		_show_nation_select()
		_maybe_interstitial()
		_toasts.push("Independence! A new frontier awaits.", "liberty", 5.0)
		_flush_deferred())
	_overlay.add_child(o)


# --- Events ---------------------------------------------------------------------

func _on_offline(seconds: float, ev: SimEvents) -> void:
	var m := Modal.new("While You Were Away")
	var capped: float = minf(seconds, Balance.offline_cap_seconds(Game.run, Game.meta))
	m.add_text("Your colonies kept working for %s, at half pace without you." % Format.duration(capped), UI.SIZE_BODY, UI.INK_SOFT)
	if seconds > capped + 1.0:
		m.add_text("(Colonists rest after %s without their governor.)" % Format.duration(Balance.offline_cap_seconds(Game.run)), UI.SIZE_SMALL, UI.INK_SOFT)
	m.add_line("gold", "+%s gold" % Format.num(ev.gold_earned))
	if ev.trips > 0:
		m.add_line("ship_icon", "%s shipment%s landed" % [Format.num(ev.trips), "" if ev.trips == 1 else "s"])
	var crafted: float = 0.0
	for k: String in ev.crafted.keys():
		crafted += float(ev.crafted[k])
	if crafted > 0.0:
		m.add_line("hammer", "%s goods crafted" % Format.num(crafted))
	m.add_button("Splendid", "button_gold")
	_overlay.add_child(m)
	Sfx.play("welcome")


func _on_milestone(what: String, track: String, level: int) -> void:
	Sfx.play("milestone")
	var name: String
	var effect: String
	if track == "workshop":
		name = str(Content.recipe(what)["building"])
		effect = "works ×%s faster" % Format.mult(Balance.v("milestone_workshop_mult"))
	else:
		var c: RunState.ColonyState = Game.run.colony(what)
		name = Content.colony_name(Game.run.nation_id, c.tier)
		effect = {"prod": "produces ×%s", "cargo": "carries ×%s", "speed": "travels ×%s faster"}[track] % Format.mult(Balance.v("milestone_%s_mult" % track))
	_toasts.push("Milestone! %s reaches level %d and %s." % [name, level, effect], "milestone", 3.5)


var _deferred: Array[Callable] = []
var _save_banner: PanelContainer
var _catch_screen: Control
var _catch_bar: ProgressBar


func _ceremony_open() -> bool:
	for c: Node in _overlay.get_children():
		if c is IndependenceOverlay:
			return true
	return false


func _flush_deferred() -> void:
	var calls: Array[Callable] = _deferred.duplicate()
	_deferred.clear()
	for c: Callable in calls:
		c.call()


func _on_relic(id: String, source: String) -> void:
	if _ceremony_open():
		_deferred.append(func() -> void: _on_relic(id, "independence"))
		return
	var r: Dictionary = Content.relic(id)
	var how: String = {"treasure": "Among the salvage you find something remarkable.",
		"independence": "A keepsake of independence, carried home.",
		"record": "Your largest settlement yet turns up a piece of history."}.get(source, "")
	var m := Modal.new("A Relic Found!")
	var icon := UI.icon_rect(UI.icon("relic_" + id), 144)
	icon.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	m.body.add_child(icon)
	m.add_text(str(r["name"]) + "  (%d)" % int(r["year"]), UI.SIZE_BIG, UI.INK)
	if how != "":
		m.add_text(how, UI.SIZE_SMALL, UI.INK_SOFT)
	m.add_text(str(r["lore"]), UI.SIZE_SMALL, UI.INK)
	m.add_text(str(r["desc"]) + ", forever.", UI.SIZE_BODY, UI.GREEN)
	if Game.meta.set_complete(str(r["set"])):
		var s: Dictionary = Content.relic_set(str(r["set"]))
		m.add_text("Set complete: %s! %s." % [s["name"], s["desc"]], UI.SIZE_BODY, UI.GREEN)
	m.add_button("Into the Ledger", "button_gold")
	_overlay.add_child(m)
	Sfx.play("relic")


func _on_almanac_read(seconds: float, ev: SimEvents) -> void:
	Sfx.play("consult")
	var m := Modal.new("A Page of the Almanac")
	m.add_text("You turn the page, and %s pass in the colonies." % Format.duration(seconds), UI.SIZE_BODY, UI.INK_SOFT)
	m.add_line("gold", "+%s gold" % Format.num(ev.gold_earned))
	if ev.trips > 0:
		m.add_line("ship_icon", "%s shipment%s landed" % [Format.num(ev.trips), "" if ev.trips == 1 else "s"])
	m.add_button("Splendid", "button_gold")
	_overlay.add_child(m)
	_refresh()


## While a long absence is being worked through, a small screen holds the
## player's attention (and input) so the game never looks frozen.
func _on_catch_up_progress(f: float) -> void:
	if _catch_screen == null and f < 1.0:
		_catch_screen = Control.new()
		_catch_screen.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		_catch_screen.mouse_filter = Control.MOUSE_FILTER_STOP
		var dim := ColorRect.new()
		dim.color = Color(0.05, 0.04, 0.03, 0.8)
		dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		_catch_screen.add_child(dim)
		var center := CenterContainer.new()
		center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		_catch_screen.add_child(center)
		var panel := PanelContainer.new()
		panel.add_theme_stylebox_override("panel", UI.frame("panel", 14, 26))
		panel.custom_minimum_size.x = 560
		center.add_child(panel)
		var v := UI.vbox(14)
		panel.add_child(v)
		var t := UI.label("The Colonies Report In", UI.SIZE_BIG, UI.INK, true)
		t.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		v.add_child(t)
		var sub := UI.wrap_label("Tallying the ledgers from while you were away...", UI.SIZE_SMALL, UI.INK_SOFT)
		sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		v.add_child(sub)
		_catch_bar = UI.bar("bar_fill")
		v.add_child(_catch_bar)
		_overlay.add_child(_catch_screen)
	if _catch_bar != null:
		_catch_bar.value = f
	if f >= 1.0 and _catch_screen != null:
		_catch_screen.queue_free()
		_catch_screen = null
		_catch_bar = null


## The rewarded bonus: a free half hour of the colonies' work every few
## hours. Ad-Free owners get it without watching anything.
func _on_consult() -> void:
	var wait: float = Game.consult_ready_in()
	if wait > 0.0:
		_toasts.push("The almanac can be consulted again in %s." % Format.duration(wait), "almanac", 3.0)
		return
	var m := Modal.new("Consult the Almanac")
	var mins: int = int(Balance.v("ad_skip_seconds") / 60.0)
	if Platform.is_ad_free():
		m.add_text("Skip ahead %d minutes: the colonies work at full pace, all at once. Ready again in %s." % [mins, Format.duration(Balance.v("ad_skip_cooldown_seconds"))], UI.SIZE_BODY, UI.INK_SOFT)
		m.add_button("Not now", "button")
		m.add_button("Consult", "button_gold", func() -> void: Game.consult_almanac())
	elif Platform.rewarded_ready():
		m.add_text("Watch a short ad to skip ahead %d minutes: the colonies work at full pace, all at once. Ready again in %s." % [mins, Format.duration(Balance.v("ad_skip_cooldown_seconds"))], UI.SIZE_BODY, UI.INK_SOFT)
		m.add_button("Not now", "button")
		m.add_button("Watch", "button_gold", func() -> void: Platform.show_rewarded("almanac"))
	else:
		m.add_text("The almanac is out of reach just now (no connection?). Try again later; nothing else is affected.", UI.SIZE_BODY, UI.INK_SOFT)
		m.add_button("Close", "button_gold")
	_overlay.add_child(m)


## Between expeditions, after independence is saved: at most one short ad,
## never after the first expedition, never for Ad-Free owners.
func _maybe_interstitial() -> void:
	var now: float = Time.get_unix_time_from_system()
	if Game.meta.runs_completed < int(Balance.v("interstitial_after_runs")):
		return
	if now - Game.meta.last_interstitial_unix < Balance.v("interstitial_min_gap_seconds"):
		return
	if Platform.show_interstitial("between_expeditions"):
		Game.meta.last_interstitial_unix = now
		Game.save()


func _on_founded(id: String) -> void:
	Sfx.play("found")
	var c: RunState.ColonyState = Game.run.colony(id)
	var name: String = Content.colony_name(Game.run.nation_id, c.tier)
	_toasts.push("%s is founded! It will produce %s." % [name, Content.resource_name(Game.run.resource_of(c)).to_lower()], Game.run.resource_of(c), 4.0)
	var fl: String = Content.flavor_line("founding")
	if fl != "":
		_toasts.push(fl, "colonist", 3.5)
	# The sheet was showing the site; now show the colony that stands there.
	if _sheet.visible and _sheet.colony_id == "":
		_sheet.show_colony(id)
		_map.set_highlight(id)


func _on_discovered(id: String) -> void:
	if id == "timber":
		return
	Sfx.play("discover")
	var extra: String = " New workshops may be possible." if not Content.is_crafted(id) else ""
	_toasts.push("%s reaches the capital for the first time.%s" % [Content.resource_name(id), extra], id, 3.5)


func _on_shipment(_colony_id: String, _res: String, _qty: float) -> void:
	if _tab != 0:
		return
	var now: int = Time.get_ticks_msec()
	if now - _last_ship_sound > 5000:
		_last_ship_sound = now
		Sfx.play("coin")


func _on_favor() -> void:
	if Game.run == null:
		return
	if Game.run.favor_seconds > 0.0 or Game.favor_ready_in() > 0.0:
		var m := Modal.new("Royal Favor")
		if Game.run.favor_seconds > 0.0:
			m.add_text("The Crown smiles on your colonies: production is doubled for another %s." % Format.duration(Game.run.favor_seconds))
		else:
			m.add_text("The Crown will hear your petition again in %s." % Format.duration(Game.favor_ready_in()))
		m.add_button("Very well", "button_gold")
		_overlay.add_child(m)
		return
	var m := Modal.new("Petition the Crown")
	m.add_text("Ask the King for his favor: every colony produces double for %s. The Crown hears petitions every %s." % [
		Format.duration(Balance.v("favor_seconds")), Format.duration(Balance.v("favor_cooldown_seconds"))])
	m.add_button("Not now", "button")
	m.add_button("Petition", "button_gold", func() -> void:
		if Game.request_favor():
			Sfx.play("fanfare")
			_toasts.push("Royal Favor granted! Production doubled.", "star", 3.0))
	_overlay.add_child(m)


func _refresh_favor() -> void:
	var run: RunState = Game.run
	var state: String
	if run.favor_seconds > 0.0:
		state = "active"
		_favor.text = Format.duration(run.favor_seconds)
	elif Game.favor_ready_in() > 0.0:
		state = "cooldown"
		_favor.text = Format.duration(Game.favor_ready_in())
	else:
		state = "ready"
		_favor.text = "×2"
	if state == _favor_state:
		return
	_favor_state = state
	var style: String = {"active": "button_buy", "cooldown": "button_disabled", "ready": "button_gold"}[state]
	for s: String in ["normal", "hover", "pressed", "hover_pressed"]:
		_favor.add_theme_stylebox_override(s, UI.frame(style, 14, 6))
	var col: Color = UI.LIGHT if state == "active" else (Color("4a3e34") if state == "cooldown" else UI.INK)
	for s: String in ["font_color", "font_hover_color", "font_pressed_color", "font_hover_pressed_color"]:
		_favor.add_theme_color_override(s, col)


func _show_settings() -> void:
	Sfx.play("click")
	var m := Modal.new("Settings")
	var music := UI.button("", "button", 64)
	var sound := UI.button("", "button", 64)
	var sync := func() -> void:
		music.text = "Music: " + ("On" if Game.meta.music_on else "Off")
		sound.text = "Sound: " + ("On" if Game.meta.sfx_on else "Off")
	sync.call()
	music.pressed.connect(func() -> void:
		Game.meta.music_on = not Game.meta.music_on
		Sfx.sync_music()
		sync.call())
	sound.pressed.connect(func() -> void:
		Game.meta.sfx_on = not Game.meta.sfx_on
		Sfx.play("click")
		sync.call())
	var tips := UI.button("", "button", 64)
	var sync_tips := func() -> void:
		tips.text = "Tutorial tips: " + ("On" if Game.meta.tips_on else "Off")
	sync_tips.call()
	tips.pressed.connect(func() -> void:
		Game.meta.tips_on = not Game.meta.tips_on
		Sfx.play("click")
		sync_tips.call())
	var lite := UI.button("", "button", 64)
	var sync_lite := func() -> void:
		lite.text = "Map effects: " + ("Light" if Game.meta.lite_map else "Full")
	sync_lite.call()
	lite.pressed.connect(func() -> void:
		Game.meta.lite_map = not Game.meta.lite_map
		Sfx.play("click")
		_map.apply_lite()
		sync_lite.call())
	m.body.add_child(music)
	m.body.add_child(sound)
	m.body.add_child(tips)
	m.body.add_child(lite)
	var big := UI.button("", "button", 64)
	var sync_big := func() -> void:
		big.text = "Text & buttons: " + ("Large" if Game.meta.large_ui else "Normal")
	sync_big.call()
	big.pressed.connect(func() -> void:
		Game.meta.large_ui = not Game.meta.large_ui
		Sfx.play("click")
		apply_ui_scale()
		sync_big.call())
	m.body.add_child(big)
	var nums := UI.button("", "button", 64)
	var sync_nums := func() -> void:
		nums.text = "Numbers: " + ("Scientific (1.23e15)" if Game.meta.notation == "scientific" else "Standard (1.23Qa)")
	sync_nums.call()
	nums.pressed.connect(func() -> void:
		Game.meta.notation = "standard" if Game.meta.notation == "scientific" else "scientific"
		Format.notation = Game.meta.notation
		Sfx.play("click")
		sync_nums.call()
		_refresh())
	m.body.add_child(nums)
	var codes := UI.hbox(10)
	var export_b := UI.button("Copy save code", "button", 56)
	export_b.add_theme_font_size_override("font_size", UI.SIZE_SMALL)
	export_b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	export_b.pressed.connect(func() -> void:
		DisplayServer.clipboard_set(Game.export_code())
		Sfx.play("click")
		_toasts.push("Save code copied. Keep it somewhere safe.", "scroll", 3.0))
	var import_b := UI.button("Restore from code", "button", 56)
	import_b.add_theme_font_size_override("font_size", UI.SIZE_SMALL)
	import_b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	import_b.pressed.connect(func() -> void:
		m.close()
		_confirm_import())
	codes.add_child(export_b)
	codes.add_child(import_b)
	m.body.add_child(codes)
	var credits := UI.button("Credits & Licenses", "button", 56)
	credits.add_theme_font_size_override("font_size", UI.SIZE_SMALL)
	credits.pressed.connect(func() -> void:
		m.close()
		_show_credits())
	m.body.add_child(credits)
	# Ad-Free, restore and privacy choices.
	var store_row := UI.hbox(10)
	var ad_free := UI.button("", "button_gold", 56)
	ad_free.add_theme_font_size_override("font_size", UI.SIZE_SMALL)
	ad_free.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var sync_store := func() -> void:
		if Platform.is_ad_free():
			ad_free.text = "Ad-Free: thank you!"
			ad_free.disabled = true
		else:
			var price: String = Platform.ad_free_price()
			ad_free.text = "Remove ads" + ("  ·  " + price if price != "" else "")
	sync_store.call()
	ad_free.pressed.connect(func() -> void:
		Sfx.play("click")
		Platform.buy_ad_free())
	Platform.ad_free_changed.connect(func(_o: bool) -> void:
		if is_instance_valid(ad_free):
			sync_store.call())
	var restore := UI.button("Restore purchases", "button", 56)
	restore.add_theme_font_size_override("font_size", UI.SIZE_SMALL)
	restore.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	restore.pressed.connect(func() -> void:
		Sfx.play("click")
		Platform.restore_purchases()
		_toasts.push("Checking with the store...", "scroll", 2.0))
	store_row.add_child(ad_free)
	store_row.add_child(restore)
	m.body.add_child(store_row)
	if Platform.privacy_options_required():
		var privacy := UI.button("Privacy choices", "button", 56)
		privacy.add_theme_font_size_override("font_size", UI.SIZE_SMALL)
		privacy.pressed.connect(func() -> void: Platform.show_privacy_options())
		m.body.add_child(privacy)
	var version := UI.label("Version %s" % str(ProjectSettings.get_setting("application/config/version", "dev")), UI.SIZE_MIN, UI.INK_SOFT)
	version.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	m.body.add_child(version)
	var meta: MetaState = Game.meta
	var stats: String = ("While you're away, colonies work at half pace for up to %s.\n" % Format.duration(Balance.offline_cap_seconds(Game.run, meta))) if Game.run != null else ""
	stats += "Independence declared: %d times\nLiberty earned in all: %d" % [meta.runs_completed, meta.lifetime_liberty]
	if meta.fastest_run_seconds > 0.0:
		stats += "\nFastest independence: %s" % Format.duration(meta.fastest_run_seconds)
	if Game.run != null:
		stats += "\nThis run: %s played, %d shipments" % [Format.duration(Game.run.play_seconds), Game.run.shipments]
	m.add_text(stats, UI.SIZE_SMALL, UI.INK_SOFT)
	var reset := UI.button("Reset all progress", "button", 56)
	reset.add_theme_font_size_override("font_size", UI.SIZE_SMALL)
	# A quiet, clearly dangerous style: red text on parchment, red outline.
	var rsb := StyleBoxFlat.new()
	rsb.bg_color = Color("f1e3c2")
	rsb.border_color = UI.RED
	rsb.set_border_width_all(2)
	rsb.set_corner_radius_all(4)
	rsb.set_content_margin_all(8)
	for s: String in ["normal", "hover", "pressed", "hover_pressed"]:
		reset.add_theme_stylebox_override(s, rsb)
	for s: String in ["font_color", "font_hover_color", "font_pressed_color"]:
		reset.add_theme_color_override(s, UI.RED)
	reset.pressed.connect(func() -> void:
		m.close()
		_confirm_reset())
	m.body.add_child(reset)
	m.add_button("Close", "button_gold", func() -> void: Game.save())
	_overlay.add_child(m)


func _confirm_reset() -> void:
	var m := Modal.new("Reset Everything?")
	m.add_text("This erases every colony, all Liberty and every reform. It cannot be undone.")
	m.add_button("Cancel", "button_gold")
	m.add_button("Erase", "button", func() -> void:
		Game.reset_all_progress()
		_show_nation_select())
	_overlay.add_child(m)


var _exit_armed_at: int = -100000


## Back on the home screen asks once ("press Back again"), then saves and
## leaves.
func _back_to_exit() -> void:
	var now: int = Time.get_ticks_msec()
	if now - _exit_armed_at > 2500:
		_exit_armed_at = now
		_toasts.push("Press Back again to leave. Your colonies keep working.", "scroll", 2.5)
		return
	if Game.running:
		Game.save()
	get_tree().quit()


func _confirm_import() -> void:
	var m := Modal.new("Restore From Code")
	m.add_text("Copy your save code, then tap Restore. This replaces the progress on this device.", UI.SIZE_BODY, UI.INK_SOFT)
	m.add_button("Cancel", "button")
	m.add_button("Restore", "button_gold", func() -> void:
		if Game.import_code(DisplayServer.clipboard_get()):
			get_tree().reload_current_scene()
		else:
			_toasts.push("That isn't a valid save code.", "lock", 3.0))
	_overlay.add_child(m)


func _show_credits() -> void:
	var cs := CreditsScreen.new()
	_overlay.add_child(cs)


func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_GO_BACK_REQUEST:
		# Close whatever is on top, newest first.
		var kids: Array[Node] = _overlay.get_children()
		kids.reverse()
		for c: Node in kids:
			if c.is_queued_for_deletion() or not (c as CanvasItem).visible:
				continue
			if c is Modal:
				(c as Modal).close()
				return
			if c is IndependenceOverlay:
				(c as IndependenceOverlay).back()
				return
			if c is ResearchScreen or c is ContinentalMap or c is CreditsScreen:
				c.queue_free()
				return
			if c is Tutorial and (c as Tutorial).visible:
				(c as Tutorial).visible = false
				return
			if c is NationSelect:
				_back_to_exit()
				return
		if _sheet != null and _sheet.visible:
			_close_sheet()
		elif _tab != 0:
			_select_tab(0)
		else:
			_back_to_exit()


# --- Refresh --------------------------------------------------------------------

func _process(delta: float) -> void:
	_refresh_timer += delta
	if _refresh_timer >= REFRESH_SECONDS:
		_refresh_timer = 0.0
		_refresh()
	_advisor_timer += delta
	if _advisor_timer >= 1.0:
		_advisor_timer = 0.0
		if _tab == 0 and Game.run != null and not _sheet.visible and not _tutorial.visible:
			_advisor.refresh()
		else:
			_advisor.visible = false
	if _sheet.visible:
		_layout_sheet()


func _refresh() -> void:
	if Game.run == null:
		return
	var run: RunState = Game.run
	_gold_label.text = Format.num(run.gold)
	_income_label.text = "+%s / sec" % Format.num(Game.income_rate, 1)
	_liberty_label.text = Format.num(Game.meta.liberty)
	# Idle of total while it's short; just the idle count once numbers grow.
	_colonist_label.text = "%s/%s" % [Format.num(run.colonists_idle()), Format.num(run.colonists_owned)] if run.colonists_owned < 1000 else Format.num(run.colonists_idle())
	_refresh_favor()
	if _map.consult_button != null:
		_map.consult_button.modulate.a = 1.0 if Game.consult_ready_in() <= 0.0 else 0.45
	if _tab > 0:
		(_pages[_tab] as Page).refresh()
	if _sheet.visible:
		_sheet.refresh()
	# Flag tabs that have something to act on.
	var ready: bool = Balance.independence_ready(run)
	if ready != _congress_ready:
		_congress_ready = ready
		_style_tabs()
	_tab_buttons[4].visible = Balance.unlocked(Game.meta, "ledger")
