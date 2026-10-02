## Boots the real game screen and pokes every screen and button. Catches
## runtime script errors that unit tests of the simulation can't see.
extends GutTest

var _saved_path: String
var _saved_meta: MetaState
var _saved_run: RunState
var main: Control


func before_each() -> void:
	_saved_path = Game.save_path
	_saved_meta = Game.meta
	_saved_run = Game.run
	Game.save_path = "user://test_ui_save.json"
	SaveIO.delete(Game.save_path)
	Game.meta = MetaState.new()
	Game.run = null


func after_each() -> void:
	if main != null:
		main.queue_free()
		main = null
	Game.running = false
	SaveIO.delete(Game.save_path)
	Game.save_path = _saved_path
	Game.meta = _saved_meta
	Game.run = _saved_run


func _boot() -> void:
	main = (load("res://scenes/Main.tscn") as PackedScene).instantiate()
	add_child(main)
	await wait_process_frames(3)


func _press_all_buttons(node: Node) -> int:
	var n: int = 0
	for child: Node in node.get_children():
		if child is BaseButton and (child as BaseButton).is_visible_in_tree() and not (child as BaseButton).disabled:
			var b := child as BaseButton
			if b.text.begins_with("Reset") or b.text == "Erase":
				continue
			b.pressed.emit()
			n += 1
		n += _press_all_buttons(child)
	return n


func test_fresh_install_shows_nation_select_and_starts_a_run() -> void:
	await _boot()
	var picker: Node = main.get("_nation_select")
	assert_not_null(picker)
	picker.emit_signal("nation_chosen", "spanish", WorldMap.STYLE_RANDOM)
	await wait_process_frames(3)
	assert_not_null(Game.run)
	assert_eq(Game.run.nation_id, "spanish")
	assert_almost_eq(Game.run.gold, Balance.v("start_gold"), 2.0)


func test_every_screen_and_button_survives_use() -> void:
	Game.run = RunState.create("french", WorldMap.STYLE_RANDOM, 2)
	Game.run.gold = 1e12
	Game.run.lifetime_gold = 1e12
	for i in 5:
		Game.run.found_next()
	for id: String in ["timber", "cod", "grain", "cotton", "iron_ore", "indigo", "lumber", "charcoal", "tar", "pig_iron", "tools", "flour", "salt_cod", "cloth"]:
		Game.run.discovered.append(id)
		Game.run.warehouse[id] = 50000.0
	Game.run.colonists_owned = 20
	Game.running = true
	Game.save()
	await _boot()
	for colony: RunState.ColonyState in Game.run.colonies:
		main.call("_open_colony", colony.id)
		await wait_process_frames(2)
		_press_all_buttons(main.get("_sheet"))
	main.call("_open_next_site")
	await wait_process_frames(2)
	main.call("_show_overview")
	await wait_process_frames(3)
	for tab: int in [3, 1, 2, 0]:
		main.call("_select_tab", tab)
		await wait_process_frames(2)
		Game.run.gold = 1e12
		var pressed: int = _press_all_buttons(main.get("_pages")[tab])
		await wait_process_frames(2)
		if tab > 0:
			assert_gt(pressed, 0, "tab %d has buttons" % tab)
	main.call("_show_settings")
	await wait_process_frames(2)
	assert_gt(Game.run.colony("c0").prod_level, 0)
	assert_true(Game.run.workshop("lumber").built)
	assert_false(Game.run.fathers.is_empty())


func test_independence_ceremony_ends_the_run() -> void:
	Game.run = RunState.create("swedish", WorldMap.STYLE_NORTH_AMERICA, 3)
	Game.run.lifetime_gold = Balance.v("independence_gold") * 9.0
	Game.run.warehouse["muskets"] = 2.0
	Game.running = true
	Game.save()
	await _boot()
	main.call("_show_independence")
	await wait_process_frames(2)
	var overlay: Node = null
	for c: Node in (main.get("_overlay") as Node).get_children():
		if c is IndependenceOverlay:
			overlay = c
	assert_not_null(overlay)
	# Signing commits at once: the saved game already has no run and the
	# Liberty is paid, even if the player quits during the ceremony.
	overlay.call("_on_sign")
	await wait_process_frames(2)
	assert_null(Game.run)
	# Swedish bonus: liberty_base * 9^exponent * 1.15
	var expected: int = int(floor(Balance.v("liberty_base") * pow(9.0, Balance.v("liberty_exponent")) * 1.15))
	assert_eq(Game.meta.liberty, expected)
	var saved: Dictionary = SaveIO.read(Game.save_path)
	assert_true((saved.get("run", {}) as Dictionary).is_empty())
	assert_eq(int(saved["meta"]["liberty"]), expected)
	overlay.emit_signal("finished")
	await wait_process_frames(2)
	assert_not_null(main.get("_nation_select"))


func test_player_signs_the_declaration_and_the_ledger_keeps_it() -> void:
	Game.run = RunState.create("dutch", WorldMap.STYLE_NORTH_AMERICA, 4)
	Game.run.lifetime_gold = Balance.v("independence_gold") * 4.0
	Game.run.warehouse["muskets"] = 1.0
	Game.running = true
	Game.save()
	await _boot()
	main.call("_show_independence")
	await wait_process_frames(2)
	var overlay: IndependenceOverlay = null
	for c: Node in (main.get("_overlay") as Node).get_children():
		if c is IndependenceOverlay:
			overlay = c
	assert_not_null(overlay)
	var pad: Control = overlay.get("_signature")
	# A short stroke drawn with the finger (touch arrives as mouse events).
	var press := InputEventMouseButton.new()
	press.button_index = MOUSE_BUTTON_LEFT
	press.pressed = true
	press.position = Vector2(60, 100)
	overlay.call("_on_pad_input", press)
	for i in 10:
		var m := InputEventMouseMotion.new()
		m.position = Vector2(70 + i * 12, 100 + (i % 2) * 15)
		overlay.call("_on_pad_input", m)
	var release := InputEventMouseButton.new()
	release.button_index = MOUSE_BUTTON_LEFT
	release.pressed = false
	overlay.call("_on_pad_input", release)
	assert_gt(pad.size.x, 0.0)
	overlay.call("_on_sign")
	await wait_process_frames(2)
	assert_null(Game.run)
	assert_eq(Game.meta.signatures.size(), 1)
	var sig: Dictionary = Game.meta.signatures[0]
	assert_eq(sig["nation"], "dutch")
	assert_eq((sig["strokes"] as Array).size(), 1)
	assert_eq(((sig["strokes"] as Array)[0] as Array).size(), 22)
	# Drawing after signing does nothing.
	overlay.call("_on_pad_input", press)
	assert_eq((overlay.get("_ink") as Array).size(), 1)
	# It survives a save round trip.
	var saved: Dictionary = SaveIO.read(Game.save_path)
	assert_eq((saved["meta"]["signatures"] as Array).size(), 1)


func test_congress_shows_every_offered_figure() -> void:
	Game.start_run("english")
	Game.save()
	await _boot()
	main.call("_select_tab", 3)
	await wait_process_frames(3)
	var page: Node = main.get("_pages")[3]
	var cards: Dictionary = page.get("_father_cards")
	assert_eq(cards.size(), Balance.fathers_offered(Game.run).size())
