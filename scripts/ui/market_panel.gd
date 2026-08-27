## The Market tab, split into two sub-tabs (direct request): Raw Materials
## (what a colony produces directly) and Crafted Goods (recipe outputs) -
## previously one undifferentiated list mixing both. Each sub-tab is the
## same row shape: current stock, sale value, a single Auto Sell on/off
## toggle (Game.routing - direct request, replacing separate Sell/Reserve
## buttons that read ambiguously as two different actions instead of one
## on/off state), and a manual "Sell All" that cashes out immediately
## regardless of that toggle (docs/GAME_DESIGN.md §4: "manual Sell All
## available").
##
## Direct request: only resources the run has actually discovered are
## listed (Game.discoveries - see its class doc), in the order discovered,
## not the full authored resource table up front.
##
## Built entirely in code, same pattern as ColoniesPanel - see that class
## doc for why.
extends Control

const ICON_SIZE := Vector2(40, 40)

var _raw_button: Button
var _crafted_button: Button
var _list: VBoxContainer
var _showing_crafted: bool = false


func _ready() -> void:
	var root := VBoxContainer.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(root)

	var sub_tabs := HBoxContainer.new()
	root.add_child(sub_tabs)

	var group := ButtonGroup.new()

	_raw_button = Button.new()
	_raw_button.text = "Raw Materials"
	_raw_button.toggle_mode = true
	_raw_button.button_pressed = true
	_raw_button.button_group = group
	_raw_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_raw_button.pressed.connect(func() -> void:
		_showing_crafted = false
		refresh()
	)
	sub_tabs.add_child(_raw_button)

	_crafted_button = Button.new()
	_crafted_button.text = "Crafted Goods"
	_crafted_button.toggle_mode = true
	_crafted_button.button_group = group
	_crafted_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_crafted_button.pressed.connect(func() -> void:
		_showing_crafted = true
		refresh()
	)
	sub_tabs.add_child(_crafted_button)

	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	root.add_child(scroll)

	_list = VBoxContainer.new()
	_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(_list)

	# No initial refresh() here - see ColoniesPanel's class doc: MainScreen
	# calls it once real boot state (new_run()/a loaded save) exists.


func refresh() -> void:
	for child: Node in _list.get_children():
		child.queue_free()

	for id: StringName in Game.discoveries.discovered_resources():
		if Db.is_crafted_resource(id) != _showing_crafted:
			continue
		var def: ResourceDef = Db.resource(id)
		if def != null:
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
	label.text = "%s: %s  (%sg each)" % [def.display_name, Format.number(amount, 1), Format.number(def.base_value)]
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hbox.add_child(label)

	hbox.add_child(_build_auto_sell_toggle(def.id))

	var sell_all := Button.new()
	sell_all.text = "Sell All"
	sell_all.disabled = amount <= 0.0
	sell_all.pressed.connect(func() -> void:
		Game.economy.sell(def.id, Game.inventory.get_amount(def.id))
		refresh()
	)
	hbox.add_child(sell_all)

	return row


const AUTO_SELL_ON_COLOR := Color(0.34, 0.58, 0.32, 1)
const AUTO_SELL_BORDER_COLOR := Color(0.85, 0.98, 0.8, 1)

## Single on/off toggle (direct request, replacing separate Sell/Reserve
## buttons - "not intuitive on whether it is selling or reserving"). ON
## gets a distinct green fill plus a border that pulses in and out
## (Tween, looped) so an active toggle reads as visibly "live" at a glance,
## not just a difference in button text.
func _build_auto_sell_toggle(resource_id: StringName) -> Button:
	var is_selling: bool = Game.routing.mode_for(resource_id) == Game.routing.SELL

	var toggle := Button.new()
	toggle.toggle_mode = true
	toggle.button_pressed = is_selling
	toggle.text = "Auto Sell: ON" if is_selling else "Auto Sell: OFF"

	if is_selling:
		var style := StyleBoxFlat.new()
		style.bg_color = AUTO_SELL_ON_COLOR
		style.border_color = AUTO_SELL_BORDER_COLOR
		style.border_width_left = 2
		style.border_width_top = 2
		style.border_width_right = 2
		style.border_width_bottom = 2
		style.corner_radius_top_left = 4
		style.corner_radius_top_right = 4
		style.corner_radius_bottom_left = 4
		style.corner_radius_bottom_right = 4
		style.content_margin_left = 14.0
		style.content_margin_top = 8.0
		style.content_margin_right = 14.0
		style.content_margin_bottom = 8.0
		for state: String in ["normal", "hover", "pressed"]:
			toggle.add_theme_stylebox_override(state, style)

		var tween: Tween = toggle.create_tween()
		tween.set_loops()
		tween.tween_property(style, "border_color:a", 0.15, 0.7).set_trans(Tween.TRANS_SINE)
		tween.tween_property(style, "border_color:a", 1.0, 0.7).set_trans(Tween.TRANS_SINE)

	toggle.pressed.connect(func() -> void:
		Game.routing.set_mode(resource_id, Game.routing.RESERVE if is_selling else Game.routing.SELL)
		refresh()
	)
	return toggle
