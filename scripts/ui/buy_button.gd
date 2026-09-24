## A purchase button showing a gold cost. Holding it down keeps buying,
## which matters on a phone where tapping forty times is miserable.
class_name BuyButton
extends Button

signal bought

const REPEAT_DELAY := 0.4
const REPEAT_INTERVAL := 0.11

var action: Callable
var _held: float = -1.0
var _repeat: float = 0.0
var _cost_label: Label
var _icon: TextureRect
var _affordable: bool = true


func _init(p_action: Callable = Callable()) -> void:
	action = p_action
	focus_mode = Control.FOCUS_NONE
	custom_minimum_size = Vector2(190, 70)
	var box := UI.hbox(6)
	box.alignment = BoxContainer.ALIGNMENT_CENTER
	box.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_icon = UI.icon_rect(UI.icon("gold"), 30)
	box.add_child(_icon)
	_cost_label = UI.label("", UI.SIZE_BODY, UI.LIGHT)
	_cost_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.add_child(_cost_label)
	add_child(box)
	_apply_style(true)
	button_down.connect(func() -> void:
		_held = 0.0
		_repeat = 0.0)
	button_up.connect(func() -> void: _held = -1.0)
	pressed.connect(_fire)


func set_cost(text: String, affordable: bool, icon_name: String = "gold") -> void:
	if _cost_label.text != text:
		_cost_label.text = text
	_icon.texture = UI.icon(icon_name)
	_icon.visible = icon_name != ""
	if affordable != _affordable:
		_apply_style(affordable)
	_affordable = affordable


func _apply_style(affordable: bool) -> void:
	var style: String = "button_buy" if affordable else "button_disabled"
	add_theme_stylebox_override("normal", UI.frame(style, 14, 8))
	add_theme_stylebox_override("hover", UI.frame(style, 14, 8))
	add_theme_stylebox_override("pressed", UI.frame(("button_buy_pressed" if affordable else "button_disabled"), 14, 8))
	add_theme_stylebox_override("hover_pressed", UI.frame(("button_buy_pressed" if affordable else "button_disabled"), 14, 8))
	_cost_label.add_theme_color_override("font_color", UI.LIGHT if affordable else Color("4a3e34"))


func _fire() -> void:
	if not action.is_valid():
		return
	var ok: Variant = action.call()
	if ok is bool and ok:
		Sfx.play("buy")
		bought.emit()
	elif ok is bool:
		Sfx.play("deny")


func _process(delta: float) -> void:
	if _held < 0.0 or not is_pressed():
		_held = -1.0
		return
	_held += delta
	if _held < REPEAT_DELAY:
		return
	_repeat += delta
	if _repeat >= REPEAT_INTERVAL:
		_repeat = 0.0
		if _affordable:
			_fire()
