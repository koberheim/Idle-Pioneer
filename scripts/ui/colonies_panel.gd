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

	for slot: Dictionary in Game.run.colony_slots:
		_list.add_child(_build_row(slot))
	_list.add_child(HSeparator.new())


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
