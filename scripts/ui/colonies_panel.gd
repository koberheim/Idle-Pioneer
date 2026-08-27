## The Colonies tab. One row per colony slot the player actually knows
## about - a founded colony shows its live stats and upgrade buttons, and
## the single next slot in sequence shows a "Found" button. Direct request:
## anything further down the sequence is hidden entirely (not shown as
## "Locked") until it's actually the next one foundable - same rule
## MapView's markers follow, for the same reason: an unsettled colony isn't
## information yet, it's noise. Real per-slot distance and land/sea (from
## the generated map) are shown wherever known.
##
## Colonist management (recruit/upgrade/assign) moved out to ColonistsPanel
## (direct request) - this panel keeps only a read-only per-slot summary so
## a colony's row still tells the whole story at a glance.
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

const TYPE_LABELS: Dictionary = {
	Colonist.Type.RESOURCE: "Resource",
	Colonist.Type.CARGO: "Cargo",
	Colonist.Type.SPEED: "Speed",
}

var _scroll: ScrollContainer
var _list: VBoxContainer

## slot_index -> its row Control, rebuilt every refresh() - what
## scroll_to_slot() (MapView marker taps, MainScreen) uses to find where to
## scroll without keeping its own separate lookup.
var _row_by_slot: Dictionary = {}


func _ready() -> void:
	_scroll = ScrollContainer.new()
	_scroll.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(_scroll)

	_list = VBoxContainer.new()
	_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_scroll.add_child(_list)

	# No initial refresh() here - MainScreen calls it once boot (a real run,
	# via new_run() or a loaded save) actually exists. Godot readies children
	# before their parent, so refreshing here would run before that boot
	# state is set up at all.


func refresh() -> void:
	for child: Node in _list.get_children():
		child.queue_free()
	_row_by_slot.clear()

	if Game.run == null:
		return

	var next_slot_index: int = _next_to_found_slot_index()
	for slot: Dictionary in Game.run.colony_slots:
		var slot_index: int = int(slot["slot_index"])
		if bool(slot["founded"]) or slot_index == next_slot_index:
			var row: Control = _build_row(slot)
			_list.add_child(row)
			_row_by_slot[slot_index] = row
	_list.add_child(HSeparator.new())


## Scrolls this tab so `slot_index`'s row is visible - a no-op if that slot
## isn't currently shown (hidden/locked, or refresh() hasn't run yet).
func scroll_to_slot(slot_index: int) -> void:
	var row: Control = _row_by_slot.get(slot_index)
	if row != null:
		_scroll.ensure_control_visible(row)


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
		# Direct request: stacked on the right side of the row instead of a
		# full-width row of their own below the stats.
		hbox.add_child(_build_upgrade_buttons(colony))
	else:
		info.add_child(_build_found_button(slot_index, slot))

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


func _next_to_found_slot_index() -> int:
	var next: Dictionary = Game.colonies.next_to_found()
	if next.is_empty():
		return -1
	return int(next["slot_index"])


func _build_founded_stats(colony: Colony) -> Control:
	var box := VBoxContainer.new()

	var stats := Label.new()
	stats.text = "Rate %.2f/s   Cargo %.1f   Round trip %.1fs" % [
		colony.production_rate(), colony.cargo_capacity(), colony.round_trip_seconds()
	]
	stats.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
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
		status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		box.add_child(status)

	box.add_child(_build_colonist_summary(colony))

	return box


## Stacked vertically on the right side of the colony's row (direct
## request, replacing a full-width row of its own below the stats). Each
## button shows the track's current level - direct request: "Production
## +25%" alone didn't say whether this was the colony's first upgrade or
## its tenth.
func _build_upgrade_buttons(colony: Colony) -> Control:
	var box := VBoxContainer.new()
	box.add_child(_upgrade_button(
		"Prod. Lv %d\n+25%% (%sg)" % [colony.production_level, Format.number(colony.next_production_level_cost())],
		colony.next_production_level_cost(), colony.purchase_production_level
	))
	box.add_child(_upgrade_button(
		"Cargo Lv %d\n+50%% (%sg)" % [colony.cargo_level, Format.number(colony.next_cargo_level_cost())],
		colony.next_cargo_level_cost(), colony.purchase_cargo_level
	))
	box.add_child(_upgrade_button(
		"Speed Lv %d\n+50%% (%sg)" % [colony.speed_level, Format.number(colony.next_speed_level_cost())],
		colony.next_speed_level_cost(), colony.purchase_speed_level
	))
	return box


## Read-only - actually assigning/upgrading a colonist happens on the
## Colonists tab now (direct request). Still worth one line here so a
## colony's row answers "who's working here" without a tab switch.
func _build_colonist_summary(colony: Colony) -> Control:
	var parts: Array[String] = []
	for type: Colonist.Type in [Colonist.Type.RESOURCE, Colonist.Type.CARGO, Colonist.Type.SPEED]:
		var colonist: Colonist = Game.colonists.colonist_at(colony.colony_id, type)
		if colonist == null:
			parts.append("%s: empty" % TYPE_LABELS[type])
		else:
			parts.append("%s: level %d" % [TYPE_LABELS[type], colonist.level])
	var label := Label.new()
	label.text = "  ".join(parts)
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	return label


func _build_found_button(slot_index: int, slot: Dictionary) -> Control:
	var cost: float = Balance.next_colony_slot_cost(
		slot_index, Game.prestige.cost_discount_multiplier() * Game.nation_colony_cost_multiplier()
	)
	var button := Button.new()
	button.text = "Found for %s gold (distance %.1f, %s)" % [
		Format.number(cost), float(slot["distance_cells"]), "sea" if bool(slot["is_coastal"]) else "land"
	]
	button.disabled = Game.economy.gold < cost
	button.pressed.connect(func() -> void:
		Game.colonies.found(slot_index)
		refresh()
	)
	return button


const UPGRADE_BUTTON_WIDTH: float = 120.0


## Fixed, capped width (direct request: stack these on the right instead of
## a full-width row) - without a cap, a GridContainer-style "size to fit the
## widest cell" problem shows up here too: the button's natural (unwrapped)
## text width can push the whole row past the screen's right edge instead
## of wrapping. autowrap + a fixed width instead let the button grow
## taller, never wider.
func _upgrade_button(text: String, cost: float, purchase_fn: Callable) -> Button:
	var button := Button.new()
	button.text = text
	button.custom_minimum_size.x = UPGRADE_BUTTON_WIDTH
	button.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
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
	# Rows can grow much taller than the icon (colonist slots, upgrade
	# buttons) - without pinning vertical size the HBoxContainer stretches
	# the icon to match the row's full height, distorting the texture.
	icon.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	return icon
