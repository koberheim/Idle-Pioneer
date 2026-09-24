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
	picker.emit_signal("nation_chosen", "spanish")
	await wait_process_frames(3)
	assert_not_null(Game.run)
	assert_eq(Game.run.nation_id, "spanish")
	assert_eq(Game.run.gold, Balance.v("start_gold"))


func test_every_screen_and_button_survives_use() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 2
	Game.run = RunState.create("french", rng)
	Game.run.gold = 1e12
	Game.run.lifetime_gold = 1e12
	for c: RunState.ColonyState in Game.run.colonies.slice(0, 6):
		c.founded = true
	for id: String in ["timber", "cod", "tobacco", "cotton", "iron_ore", "indigo", "planks", "pig_iron", "tools"]:
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
	assert_gt(Game.run.colony("capital").prod_level, 0)
	assert_true(Game.run.workshop("planks").built)
	assert_false(Game.run.fathers.is_empty())


func test_independence_ceremony_ends_the_run() -> void:
	var rng := RandomNumberGenerator.new()
	Game.run = RunState.create("swedish", rng)
	Game.run.lifetime_gold = Balance.v("independence_gold") * 9.0
	Game.run.crafted["muskets"] = 2
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
	overlay.emit_signal("signed")
	await wait_process_frames(2)
	assert_null(Game.run)
	# Swedish bonus: 6 * sqrt(9) * 1.15 = 20.7
	assert_eq(Game.meta.liberty, 20)
	assert_not_null(main.get("_nation_select"))
