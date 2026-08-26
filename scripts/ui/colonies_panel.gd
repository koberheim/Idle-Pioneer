## The Colonies tab. One row per generated colony slot (rework task:
## randomized map - RunState.colony_slots, generated once per run by
## MapGenerator), in slot order: a founded colony shows its live stats and
## upgrade buttons, the next slot in sequence shows a "Found" button, and
## anything further down shows locked. Real per-slot distance and land/sea
## (from the generated map) are shown wherever known.
##
## Rebuilt from scratch on every refresh() rather than diffed - simple and
## correct matters more here than avoiding a bit of node churn a few times a
## second (see MainScreen's refresh cadence). All rows are built in code,
## not laid out in the editor, so there's nothing scene-side to keep in sync
## with the data every time a colony is added or an art asset changes -
## see the class doc pattern shared with MarketPanel/CraftingPanel/PrestigePanel.
extends Control

const ICON_SIZE := Vector2(48, 48)
const CYCLE_SUFFIXES: Array[String] = ["", " II", " III", " IV", " V", " VI"]

var _list: VBoxContainer


func _ready() -> void:
	var scroll := ScrollContainer.new()
	scroll.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(scroll)

	_list = VBoxContainer.new()
	_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(_list)

	# No initial refresh() here - MainScreen calls it once boot (a real run,
	# via new_run() or a loaded save) actually exists. Godot readies children
	# before their parent, so refreshing here would run before that boot
	# state is set up at all.


func refresh() -> void:
	for child: Node in _list.get_children():
		child.queue_free()

	if Game.run == null:
		return

	_list.add_child(_build_colonist_pool_row())
	_list.add_child(HSeparator.new())

	for slot: Dictionary in Game.run.colony_slots:
		_list.add_child(_build_row(slot))
	_list.add_child(HSeparator.new())


const TYPE_LABELS: Dictionary = {
	Colonist.Type.RESOURCE: "Resource",
	Colonist.Type.CARGO: "Cargo",
	Colonist.Type.SPEED: "Speed",
}


## Docs/GAME_DESIGN.md §4's "central tension," now with real shape to it
## (rework: typed colonist roster) - Influence (a currency separate from
## gold - see Balance's influence_earn_rate_per_gold placeholder for how
## it's earned for now) recruits individual, typed colonists here; assigning
## one to a colony below is what actually boosts that colony's output.
func _build_colonist_pool_row() -> Control:
	var box := VBoxContainer.new()

	var summary := Label.new()
	summary.text = "Influence: %.1f   Colonists owned: %d   Idle: %d" % [
		Game.colonists.influence(), Game.colonists.colonists_owned(), Game.colonists.idle_colonists().size()
	]
	box.add_child(summary)

	var recruit_row := HBoxContainer.new()
	box.add_child(recruit_row)
	var cost: float = Game.colonists.next_recruit_cost()
	for type: Colonist.Type in [Colonist.Type.RESOURCE, Colonist.Type.CARGO, Colonist.Type.SPEED]:
		var button := Button.new()
		button.text = "Recruit %s (%.1f)" % [TYPE_LABELS[type], cost]
		button.disabled = Game.colonists.influence() < cost
		button.pressed.connect(func() -> void:
			Game.colonists.recruit(type)
			refresh()
		)
		recruit_row.add_child(button)

	return box


func _build_row(slot: Dictionary) -> Control:
	var slot_index: int = int(slot["slot_index"])
	var tier_def: ColonyDef = Db.colony_by_order(int(slot["tier_order"]))

	var row := PanelContainer.new()
	var hbox := HBoxContainer.new()
	row.add_child(hbox)

	if tier_def != null and tier_def.icon != null:
		hbox.add_child(_make_icon(tier_def.icon))

	var info := VBoxContainer.new()
	info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hbox.add_child(info)

	var name_label := Label.new()
	name_label.text = _display_name(tier_def, slot_index)
	info.add_child(name_label)

	var colony: Colony = Game.colonies.get_colony(StringName("slot_%d" % slot_index))
	if colony != null:
		info.add_child(_build_founded_stats(colony))
	elif _is_next_to_found(slot_index):
		info.add_child(_build_found_button(slot_index, slot))
	else:
		var locked := Label.new()
		locked.text = "Locked"
		locked.modulate = Color(1, 1, 1, 0.5)
		info.add_child(locked)

	return row


## Founded colonies beyond the 7th (once tiers start repeating) get a
## cycle-count suffix so nothing reads as an accidental duplicate - see the
## class doc. A real per-tier name pool (ColonyDef.name_pool) can replace
## this later without touching slot generation at all.
func _display_name(tier_def: ColonyDef, slot_index: int) -> String:
	if tier_def == null:
		return "Unknown"
	if slot_index == 0:
		return tier_def.display_name
	var cycle: int = (slot_index - 1) / 7
	var suffix: String = CYCLE_SUFFIXES[cycle] if cycle < CYCLE_SUFFIXES.size() else " x%d" % (cycle + 1)
	return tier_def.display_name + suffix


func _is_next_to_found(slot_index: int) -> bool:
	var next: Dictionary = Game.colonies.next_to_found()
	return not next.is_empty() and int(next["slot_index"]) == slot_index


func _build_founded_stats(colony: Colony) -> Control:
	var box := VBoxContainer.new()

	var stats := Label.new()
	stats.text = "Rate %.2f/s   Cargo %.1f   Round trip %.1fs" % [
		colony.production_rate(), colony.cargo_capacity(), colony.round_trip_seconds()
	]
	box.add_child(stats)

	if not colony.is_capital:
		var route: Route = Game.routes.for_colony(colony.colony_id)
		var status := Label.new()
		var state_text := "At origin"
		if route != null:
			match route.state:
				Route.State.TRAVELING_TO_HUB:
					state_text = "Shipping to Capital (%d%%)" % int(route.progress() * 100.0)
				Route.State.TRAVELING_TO_ORIGIN:
					state_text = "Returning (%d%%)" % int(route.progress() * 100.0)
		var route_kind := "Sea" if colony.route_type == Colony.RouteType.SEA else "Land"
		status.text = "%s - %s route, distance %.1f" % [state_text, route_kind, colony.distance()]
		box.add_child(status)

	box.add_child(_build_colonist_assignment_row(colony))

	var buttons := HBoxContainer.new()
	box.add_child(buttons)
	buttons.add_child(_upgrade_button(
		"Production +25%% (%.0fg)" % colony.next_production_level_cost(),
		colony.next_production_level_cost(), colony.purchase_production_level
	))
	buttons.add_child(_upgrade_button(
		"Cargo +50%% (%.0fg)" % colony.next_cargo_level_cost(),
		colony.next_cargo_level_cost(), colony.purchase_cargo_level
	))
	buttons.add_child(_upgrade_button(
		"Speed +50%% (%.0fg)" % colony.next_speed_level_cost(),
		colony.next_speed_level_cost(), colony.purchase_speed_level
	))

	return box


## Rework: typed colonist roster - a colony has exactly one slot per type
## (never two Resource colonists at once). Each slot is either empty (an
## "Assign" button, enabled only if a matching idle colonist exists - hands
## over the highest-level one) or shows the assigned colonist's level with
## Upgrade/Unassign buttons.
func _build_colonist_assignment_row(colony: Colony) -> Control:
	var box := VBoxContainer.new()
	for type: Colonist.Type in [Colonist.Type.RESOURCE, Colonist.Type.CARGO, Colonist.Type.SPEED]:
		box.add_child(_build_colonist_slot(colony, type))
	return box


func _build_colonist_slot(colony: Colony, type: Colonist.Type) -> Control:
	var row := HBoxContainer.new()

	var colonist: Colonist = Game.colonists.colonist_at(colony.colony_id, type)
	var label := Label.new()
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL

	if colonist == null:
		label.text = "%s: empty" % TYPE_LABELS[type]
		row.add_child(label)

		var has_idle_match := false
		for c: Colonist in Game.colonists.idle_colonists():
			if c.type == type:
				has_idle_match = true
				break

		var assign_button := Button.new()
		assign_button.text = "Assign"
		assign_button.disabled = not has_idle_match
		assign_button.pressed.connect(func() -> void:
			Game.colonists.assign_best(colony.colony_id, type)
			refresh()
		)
		row.add_child(assign_button)
	else:
		label.text = "%s: level %d" % [TYPE_LABELS[type], colonist.level]
		row.add_child(label)

		var upgrade_cost: float = Game.colonists.next_upgrade_cost(colonist.id)
		var upgrade_button := Button.new()
		upgrade_button.text = "Upgrade (%.1f)" % upgrade_cost
		upgrade_button.disabled = Game.colonists.influence() < upgrade_cost
		upgrade_button.pressed.connect(func() -> void:
			Game.colonists.upgrade(colonist.id)
			refresh()
		)
		row.add_child(upgrade_button)

		var unassign_button := Button.new()
		unassign_button.text = "Unassign"
		unassign_button.pressed.connect(func() -> void:
			Game.colonists.unassign(colonist.id)
			refresh()
		)
		row.add_child(unassign_button)

	return row


func _build_found_button(slot_index: int, slot: Dictionary) -> Control:
	var cost: float = Balance.next_colony_slot_cost(slot_index, Game.prestige.cost_discount_multiplier())
	var button := Button.new()
	button.text = "Found for %.0f gold (distance %.1f, %s)" % [
		cost, float(slot["distance_cells"]), "sea" if bool(slot["is_coastal"]) else "land"
	]
	button.disabled = Game.economy.gold < cost
	button.pressed.connect(func() -> void:
		Game.colonies.found(slot_index)
		refresh()
	)
	return button


func _upgrade_button(text: String, cost: float, purchase_fn: Callable) -> Button:
	var button := Button.new()
	button.text = text
	button.disabled = Game.economy.gold < cost
	button.pressed.connect(func() -> void:
		purchase_fn.call()
		refresh()
	)
	return button


func _make_icon(texture: Texture2D) -> TextureRect:
	var icon := TextureRect.new()
	icon.texture = texture
	icon.custom_minimum_size = ICON_SIZE
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.stretch_mode = TextureRect.STRETCH_SCALE
	return icon
