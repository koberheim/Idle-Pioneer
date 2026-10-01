## The emotional peak of a run: the Declaration is read, signed with a quill,
## and sealed - then the run ends and Liberty is paid out.
class_name IndependenceOverlay
extends Control

## Emitted the moment the Declaration is signed; the handler must commit the
## independence and return the Liberty actually paid.
signal signed
## Emitted when the player leaves the ceremony for the next expedition.
signal finished
signal cancelled

## Commits independence and returns the Liberty paid (set by the owner).
var commit: Callable

const TEXT := "We, the representatives of the colonies of %s, assembled in Congress, do solemnly publish and declare that these united colonies are, and of right ought to be, free and independent. Our harbours are full, our militia armed, and our fortunes our own.\n\nLet the bells ring from %s to %s."

var _text: Label
var _sign_btn: Button
var _cancel_btn: Button
var _signature: Control
var _seal: Control
var _result: Label
var _stroke: float = 0.0
var _seal_scale: float = 0.0
var _liberty: int = 0
var _done: bool = false


func _enter_tree() -> void:
	Game.pause("ceremony")


func _exit_tree() -> void:
	Game.resume("ceremony")


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	var dim := ColorRect.new()
	dim.color = Color(0.04, 0.03, 0.02, 0.85)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(dim)
	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	center.offset_top = UI.safe_insets(self).x
	center.offset_bottom = -UI.safe_insets(self).y
	add_child(center)
	var panel := PanelContainer.new()
	panel.add_theme_stylebox_override("panel", UI.frame("panel", 14, 34))
	panel.custom_minimum_size = Vector2(650, 0)
	resized.connect(func() -> void:
		panel.custom_minimum_size.x = minf(650.0, maxf(size.x - 32.0, 280.0)))
	center.add_child(panel)
	var v := UI.vbox(16)
	panel.add_child(v)

	var t := UI.label("Declaration of Independence", 40, UI.INK, true)
	t.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	t.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	t.resized.connect(t.update_minimum_size)
	t.custom_minimum_size.x = 10
	v.add_child(t)

	var run: RunState = Game.run
	var n: Dictionary = Content.nation(run.nation_id)
	var first: String = Content.colony_name(run.nation_id, 0)
	var last_idx: int = maxi(run.founded_count() - 1, 0)
	var last: String = Content.colony_name(run.nation_id, last_idx)
	_text = UI.label(TEXT % ["New " + str(n.get("name", "World")), first, last], UI.SIZE_BODY, UI.INK)
	_text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_text.resized.connect(_text.update_minimum_size)
	_text.custom_minimum_size.x = 10
	_text.visible_ratio = 0.0
	v.add_child(_text)

	_liberty = Balance.liberty_payout(run)
	_result = UI.label("Liberty to be earned: %d" % _liberty, UI.SIZE_BIG, UI.INK, true)
	_result.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(_result)
	var keep := UI.wrap_label("You keep: Liberty, reforms, governors, relics and Almanac pages.  You lose: every colony, colonist, workshop, study, Founding Father and all gold.", UI.SIZE_SMALL, UI.INK_SOFT)
	keep.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(keep)

	var sig_row := Control.new()
	sig_row.custom_minimum_size = Vector2(0, 120)
	v.add_child(sig_row)
	_signature = Control.new()
	_signature.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_signature.draw.connect(_draw_signature)
	sig_row.add_child(_signature)
	_seal = Control.new()
	_seal.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_seal.draw.connect(_draw_seal)
	sig_row.add_child(_seal)

	var row := UI.hbox(14)
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	_cancel_btn = UI.button("Not yet", "button", 76)
	_cancel_btn.custom_minimum_size.x = 200
	_cancel_btn.pressed.connect(func() -> void:
		Sfx.play("click")
		cancelled.emit()
		queue_free())
	_sign_btn = UI.button("Sign the Declaration", "button_gold", 76)
	_sign_btn.custom_minimum_size.x = 320
	_sign_btn.add_theme_font_override("font", UI.FONT_TITLE)
	_sign_btn.add_theme_font_size_override("font_size", UI.SIZE_BIG)
	_sign_btn.pressed.connect(_on_sign)
	row.add_child(_cancel_btn)
	row.add_child(_sign_btn)
	v.add_child(row)

	var tw := create_tween()
	tw.tween_property(_text, "visible_ratio", 1.0, 3.0)


## Back button: before signing it's "Not yet"; after, it's "Begin a new
## frontier"; during the ceremony itself it does nothing.
func back() -> void:
	if _done:
		_on_sign()
	elif _cancel_btn.visible:
		cancelled.emit()
		queue_free()


func _on_sign() -> void:
	if _done:
		finished.emit()
		queue_free()
		return
	# Independence is won the moment the quill touches the page: commit and
	# save now, so closing the game during the ceremony can't undo it.
	if commit.is_valid():
		_liberty = int(commit.call())
		if Game.run != null:
			# Congress could not declare (the conditions no longer hold):
			# nothing has changed, so stay in the expedition.
			_result.text = "Congress cannot declare yet: the militia needs a musket and the gold must be earned."
			_result.add_theme_color_override("font_color", UI.RED)
			Sfx.play("deny")
			return
	signed.emit()
	_sign_btn.disabled = true
	_cancel_btn.visible = false
	_text.visible_ratio = 1.0
	Sfx.play("click")
	var tw := create_tween()
	tw.tween_method(func(f: float) -> void:
		_stroke = f
		_signature.queue_redraw(), 0.0, 1.0, 1.6)
	tw.tween_callback(func() -> void: Sfx.play("liberty"))
	tw.tween_method(func(f: float) -> void:
		_seal_scale = f
		_seal.queue_redraw(), 2.2, 1.0, 0.35).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.tween_callback(func() -> void:
		Sfx.set_music_context("independence")
		_result.text = "Independence! +%d Liberty" % _liberty if Game.save_ok else "Independence! +%d Liberty (saving...)" % _liberty
		_result.add_theme_color_override("font_color", UI.GREEN)
		_done = true
		_sign_btn.disabled = false
		_sign_btn.text = "Begin a new frontier")


func _draw_signature() -> void:
	var w: float = _signature.size.x
	var base_y: float = 84.0
	_signature.draw_line(Vector2(40, base_y + 12), Vector2(w * 0.62, base_y + 12), Color(0.35, 0.25, 0.18), 2.0)
	if _stroke <= 0.0:
		return
	var pts := PackedVector2Array()
	var steps: int = int(120 * _stroke)
	for i in steps:
		var t: float = float(i) / 120.0
		var x: float = 50.0 + t * (w * 0.55)
		var y: float = base_y - 10.0 + sin(t * 38.0) * 14.0 * (1.0 - t * 0.5) + sin(t * 11.0) * 6.0
		pts.append(Vector2(x, y))
	if pts.size() >= 2:
		_signature.draw_polyline(pts, Color(0.12, 0.08, 0.2), 3.0, true)


func _draw_seal() -> void:
	if _seal_scale <= 0.0:
		return
	var c := Vector2(_seal.size.x * 0.8, 60.0)
	var r: float = 44.0 * _seal_scale
	_seal.draw_circle(c, r * 1.08, Color(0.45, 0.08, 0.06))
	_seal.draw_circle(c, r, Color(0.7, 0.14, 0.1))
	_seal.draw_circle(c, r * 0.72, Color(0.58, 0.1, 0.08))
	var star := PackedVector2Array()
	for i in 10:
		var a: float = -PI / 2.0 + i * PI / 5.0
		var rr: float = r * (0.55 if i % 2 == 0 else 0.24)
		star.append(c + Vector2(cos(a), sin(a)) * rr)
	_seal.draw_colored_polygon(star, Color(0.95, 0.78, 0.4))
