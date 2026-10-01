## x1 / x10 / x100 / Max toggle shared by every purchase in the game.
class_name BuyAmountSelector
extends HBoxContainer

const OPTIONS: Array[int] = [1, 10, 100, -1]

var _buttons: Array[Button] = []


## `on_paper`: placed on a parchment card (dark label) rather than on wood.
func _init(on_paper: bool = false) -> void:
	add_theme_constant_override("separation", 6)
	alignment = BoxContainer.ALIGNMENT_END
	var lbl := UI.label("Buy", UI.SIZE_SMALL, UI.INK_SOFT if on_paper else UI.LIGHT_SOFT)
	lbl.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	add_child(lbl)
	for amount: int in OPTIONS:
		var b := UI.button("Max" if amount < 0 else "×%d" % amount, "button", 58)
		b.custom_minimum_size.x = 84
		b.toggle_mode = true
		b.add_theme_font_size_override("font_size", UI.SIZE_SMALL)
		b.pressed.connect(func() -> void:
			Game.buy_amount = amount
			Sfx.play("click")
			sync())
		_buttons.append(b)
		add_child(b)
	sync()


func sync() -> void:
	for i in OPTIONS.size():
		var on: bool = OPTIONS[i] == Game.buy_amount
		_buttons[i].set_pressed_no_signal(on)
		var style: String = "button_gold" if on else "button"
		for s: String in ["normal", "hover", "pressed", "hover_pressed"]:
			_buttons[i].add_theme_stylebox_override(s, UI.frame(style, 14, 6))
		for s: String in ["font_color", "font_hover_color", "font_pressed_color", "font_hover_pressed_color"]:
			_buttons[i].add_theme_color_override(s, UI.INK if on else UI.LIGHT)


func _process(_delta: float) -> void:
	# Another selector may have changed the shared amount.
	if is_visible_in_tree():
		for i in OPTIONS.size():
			if _buttons[i].button_pressed != (OPTIONS[i] == Game.buy_amount):
				sync()
				return
