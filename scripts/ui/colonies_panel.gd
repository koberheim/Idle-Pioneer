## The Colonies tab. One row per colony, in docs/GAME_DESIGN.md §5's fixed
## order: a founded colony shows its live stats and upgrade buttons, the
## next colony in sequence shows a "Found" button, and anything further down
## the order shows locked.
##
## Rebuilt from scratch on every refresh() rather than diffed - simple and
## correct matters more here than avoiding a bit of node churn a few times a
## second (see MainScreen's refresh cadence). All rows are built in code,
## not laid out in the editor, so there's nothing scene-side to keep in sync
## with the data every time a colony is added or an art asset changes -
## see the class doc pattern shared with MarketPanel/CraftingPanel/PrestigePanel.
extends Control

const ICON_SIZE := Vector2(48, 48)

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
	for def: ColonyDef in Db.all_colonies():
		_list.add_child(_build_row(def))
	_list.add_child(HSeparator.new())


func _build_row(def: ColonyDef) -> Control:
	var row := PanelContainer.new()
	var hbox := HBoxContainer.new()
	row.add_child(hbox)

	if def.icon != null:
		hbox.add_child(_make_icon(def.icon))

	var info := VBoxContainer.new()
	info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hbox.add_child(info)

	var name_label := Label.new()
	name_label.text = def.display_name
	info.add_child(name_label)

	var colony: Colony = Game.colonies.get_colony(def.id)
	if colony != null:
		info.add_child(_build_founded_stats(colony, def))
	elif _is_next_to_found(def):
		info.add_child(_build_found_button(def))
	else:
		var locked := Label.new()
		locked.text = "Locked"
		locked.modulate = Color(1, 1, 1, 0.5)
		info.add_child(locked)

	return row


func _is_next_to_found(def: ColonyDef) -> bool:
	var next: ColonyDef = Game.colonies.next_to_found()
	return next != null and next.id == def.id


func _build_founded_stats(colony: Colony, def: ColonyDef) -> Control:
	var box := VBoxContainer.new()

	var stats := Label.new()
	stats.text = "Rate %.2f/s   Cargo %.1f   Round trip %.1fs" % [
		colony.production_rate(), colony.cargo_capacity(), colony.round_trip_seconds()
	]
	box.add_child(stats)

	if not colony.is_capital:
		var route: Route = Game.routes.for_colony(def.id)
		var status := Label.new()
		var state_text := "At origin"
		if route != null:
			match route.state:
				Route.State.TRAVELING_TO_HUB:
					state_text = "Shipping to Capital (%d%%)" % int(route.progress() * 100.0)
				Route.State.TRAVELING_TO_ORIGIN:
					state_text = "Returning (%d%%)" % int(route.progress() * 100.0)
		var route_kind := "Sea" if colony.route_type == Colony.RouteType.SEA else "Land"
		status.text = "%s - %s route" % [state_text, route_kind]
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


func _build_found_button(def: ColonyDef) -> Control:
	var cost: float = Game.economy.colony_cost(def.id)
	var button := Button.new()
	button.text = "Found for %.0f gold" % cost
	button.disabled = Game.economy.gold < cost
	button.pressed.connect(func() -> void:
		Game.colonies.found(def.id)
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
