## The Market tab. One row per known resource: current stock, sale value, a
## Sell/Reserve toggle (Game.routing - rework task: real Sell/Reserve
## mechanic), and a manual "Sell All" that cashes out immediately regardless
## of that toggle (docs/GAME_DESIGN.md §4: "manual Sell All available").
##
## Built entirely in code, same pattern as ColoniesPanel - see that class
## doc for why.
extends Control

const ICON_SIZE := Vector2(40, 40)

var _list: VBoxContainer


func _ready() -> void:
	var scroll := ScrollContainer.new()
	scroll.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(scroll)

	_list = VBoxContainer.new()
	_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(_list)

	# No initial refresh() here - see ColoniesPanel's class doc: MainScreen
	# calls it once real boot state (new_run()/a loaded save) exists.


func refresh() -> void:
	for child: Node in _list.get_children():
		child.queue_free()
	for def: ResourceDef in Db.all_resources():
		_list.add_child(_build_row(def))


func _build_row(def: ResourceDef) -> Control:
	var row := PanelContainer.new()
	var hbox := HBoxContainer.new()
	row.add_child(hbox)

	if def.icon != null:
		var icon := TextureRect.new()
		icon.texture = def.icon
		icon.custom_minimum_size = ICON_SIZE
		icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		icon.stretch_mode = TextureRect.STRETCH_SCALE
		hbox.add_child(icon)

	var amount: float = Game.inventory.get_amount(def.id)
	var label := Label.new()
	label.text = "%s: %.1f  (%.0fg each)" % [def.display_name, amount, def.base_value]
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hbox.add_child(label)

	var mode: StringName = Game.routing.mode_for(def.id)
	var is_sell: bool = mode == Game.routing.SELL
	var toggle := Button.new()
	toggle.toggle_mode = true
	toggle.button_pressed = is_sell
	toggle.text = "Auto-Sell" if is_sell else "Reserve"
	toggle.pressed.connect(func() -> void:
		Game.routing.set_mode(def.id, Game.routing.RESERVE if is_sell else Game.routing.SELL)
		refresh()
	)
	hbox.add_child(toggle)

	var sell_all := Button.new()
	sell_all.text = "Sell All"
	sell_all.disabled = amount <= 0.0
	sell_all.pressed.connect(func() -> void:
		Game.economy.sell(def.id, Game.inventory.get_amount(def.id))
		refresh()
	)
	hbox.add_child(sell_all)

	return row
