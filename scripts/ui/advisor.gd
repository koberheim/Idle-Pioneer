## The colonial advisor: one short, relevant suggestion at a time, so a new
## player always knows a sensible next step. Tapping it jumps to the place
## where that step is taken.
class_name Advisor
extends PanelContainer

## target is "colony:<id>", "tab:<index>" or "".
signal go(target: String)

var _label: Label
var _hint_id: String = ""
var _target: String = ""


func _init() -> void:
	add_theme_stylebox_override("panel", UI.frame("panel", 14, 10))
	mouse_filter = Control.MOUSE_FILTER_STOP
	var row := UI.hbox(10)
	add_child(row)
	row.add_child(UI.icon_rect(UI.icon("portrait"), 52))
	_label = UI.label("", UI.SIZE_SMALL, UI.INK)
	_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_label.resized.connect(_label.update_minimum_size)
	_label.custom_minimum_size.x = 10
	_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(_label)
	var x := UI.button("✕", "button", 60)
	x.custom_minimum_size.x = 60
	x.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	x.pressed.connect(func() -> void:
		Game.mark_hint_seen(_hint_id)
		Sfx.play("click")
		refresh())
	row.add_child(x)
	gui_input.connect(func(e: InputEvent) -> void:
		if e is InputEventMouseButton and (e as InputEventMouseButton).pressed and _target != "":
			Sfx.play("click")
			go.emit(_target))


func refresh() -> void:
	var h: Array = _pick()
	if h.is_empty():
		visible = false
		_hint_id = ""
		return
	_hint_id = h[0]
	_label.text = h[1]
	_target = h[2]
	visible = true


func _seen(id: String) -> bool:
	return Game.meta.hints_seen.has(id)


## Returns [id, text, target] for the most useful hint right now, or [].
## Recurring situations only; one-off teaching lives in Tutorial.
func _pick() -> Array:
	var run: RunState = Game.run
	if run == null or not Game.meta.tips_on:
		return []
	var meta: MetaState = Game.meta
	var candidates: Array = []
	if Balance.independence_ready(run):
		candidates.append(["declare_%d" % meta.runs_completed, "The colonies are rich and armed. Congress awaits your Declaration of Independence!", "tab:3"])
	if run.lifetime_gold >= Balance.v("independence_gold") and run.stock_of("muskets") < Balance.v("independence_muskets"):
		candidates.append(["muskets_%d" % meta.runs_completed, "Congress will not declare without an armed militia. An Armory makes Muskets from pig iron, lumber and tools; the first is kept for the militia.", "tab:1"])
	for c: RunState.ColonyState in run.colonies:
		if c.tier > 0 and c.stock > Balance.cargo_capacity(run, meta, c) * 2.0:
			var n: String = Content.colony_name(run.nation_id, c.tier)
			candidates.append(["bottleneck_%s_%d" % [c.id, c.cargo_level + c.speed_level], "Goods are piling up at %s faster than they can be shipped. Upgrade its %s." % [n, "ships" if Balance.is_sea(run, c) else "wagons and roads"], "colony:" + c.id])
			break
	for def: Dictionary in Content.recipes:
		var w: RunState.WorkshopState = run.workshop(def["id"])
		if w.built and w.colonists == 0:
			candidates.append(["staff_" + w.id, "Your %s stands empty. Assign colonists to start work." % def["building"], "tab:1"])
			break
	for g: Dictionary in meta.governors:
		if run.colony_of_governor(int(g["id"])) == "":
			candidates.append(["gov_idle_%d_%d" % [int(g["id"]), run.colonies.size()], "Governor %s awaits a posting. Tap a colony and appoint them." % g["name"], "colony:c0"])
			break
	for c: RunState.ColonyState in run.colonies:
		if Game.charter_affordable(c.id):
			var cn: String = Content.colony_name(run.nation_id, c.tier)
			candidates.append(["charter_%s_%d" % [c.id, c.charter], "You have the goods to grant %s a new charter: more production and cargo." % cn, "colony:" + c.id])
			break
	for f: Dictionary in Balance.fathers_offered(run):
		if not run.has_father(f["id"]) and Game.father_affordable(f["id"]):
			candidates.append(["father_" + str(f["id"]), "%s is ready to join your Congress." % f["name"], "tab:3"])
			break
	var n2: int = run.next_site()
	if n2 >= 0 and run.gold >= Balance.found_cost(run, meta):
		candidates.append(["found_%d" % run.colonies.size(), "You can afford to found the next colony. Its site is flagged on the map.", "site"])
	for cand: Array in candidates:
		if not _seen(cand[0]):
			return cand
	return []
