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
	_label.custom_minimum_size.x = 10
	_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(_label)
	var x := UI.button("✕", "button", 48)
	x.custom_minimum_size.x = 48
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
func _pick() -> Array:
	var run: RunState = Game.run
	if run == null:
		return []
	var meta: MetaState = Game.meta
	var cap: RunState.ColonyState = run.colony("capital")
	var cap_name: String = Content.colony_name(run.nation_id, 0)
	var candidates: Array = []

	if Balance.independence_ready(run):
		candidates.append(["declare", "The colonies are rich and armed. Congress awaits your Declaration of Independence!", "tab:3"])
	if run.lifetime_gold >= Balance.v("independence_gold") and int(run.crafted.get("muskets", 0)) < 1:
		candidates.append(["muskets", "Congress will not declare without an armed militia. Build an Armory and craft Muskets from Tools and Planks.", "tab:1"])
	if cap.prod_level == 0:
		candidates.append(["upgrade_capital", "Your capital sells timber straight to Europe. Tap %s on the map to improve its production." % cap_name, "colony:capital"])
	if run.colonists_owned == 0 and cap.prod_level > 0 and run.gold >= Balance.colonist_cost(run, meta):
		candidates.append(["recruit", "Recruit a colonist at the Docks of Europe, then put them to work in a colony. Each one doubles its output.", "tab:2"])
	if run.colonists_idle() > 0 and run.colonists_owned <= 3:
		candidates.append(["assign_%d" % run.colonists_owned, "You have an idle colonist. Tap a colony on the map and press + to put them to work.", "colony:capital"])
	var next: RunState.ColonyState = run.next_unfounded()
	if next != null and run.founded_count() == 1 and cap.prod_level > 0:
		var cost: float = Balance.found_cost(run, meta, next.id)
		candidates.append(["found_first", "Save %s gold to found your first colony. Its flag is on the coast to the south." % Format.num(cost), "colony:" + next.id])
	for c: RunState.ColonyState in run.colonies:
		if c.founded and c.id != "capital" and c.stock > Balance.cargo_capacity(run, meta, c) * 2.0:
			var n: String = Content.colony_name(run.nation_id, Content.colony_index(c.id))
			candidates.append(["bottleneck_" + c.id, "Goods are piling up at %s faster than they can be shipped. Upgrade its %s." % [n, "ships" if Balance.is_sea(c) else "wagons and roads"], "colony:" + c.id])
			break
	for def: Dictionary in Content.recipes:
		var w: RunState.WorkshopState = run.workshop(def["id"])
		if w.built and w.colonists == 0:
			candidates.append(["staff_" + w.id, "Your %s stands empty. Assign colonists to start crafting." % def["building"], "tab:1"])
			break
	var planks: RunState.WorkshopState = run.workshop("planks")
	if not planks.built and run.gold >= Balance.workshop_build_cost("planks") and run.founded_count() >= 2:
		candidates.append(["workshop", "Timber sawn into planks sells for double. Build a Carpenter's Shop in Workshops.", "tab:1"])
	for f: Dictionary in Content.fathers:
		if not run.has_father(f["id"]) and Game.father_affordable(f["id"]):
			candidates.append(["father_" + str(f["id"]), "%s is ready to join your Congress." % f["name"], "tab:3"])
			break
	if run.fathers.is_empty() and run.founded_count() >= 2 and not run.is_held("timber"):
		candidates.append(["father_intro", "Founding Fathers want gold and kept goods. Peter Minuit asks for timber - keep some in the Warehouse.", "tab:3"])

	for cand: Array in candidates:
		if not _seen(cand[0]):
			return cand
	return []
