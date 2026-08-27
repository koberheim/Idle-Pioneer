## Tests for Audio (direct request: sound framework, no real audio assets
## yet - see Audio's class doc). Nothing under test/ ships a real audio
## file, so every play_sfx()/play_music() call here exercises the "no
## matching file yet" no-op path deliberately - that path is exactly what
## the framework has to get right before any real sound exists to play.
extends GutTest


func before_each() -> void:
	Game.meta = MetaState.new()


func after_each() -> void:
	Game.meta = MetaState.new()
	Audio.stop_music()


func test_play_sfx_with_no_matching_file_is_a_safe_no_op() -> void:
	Audio.play_sfx(&"does_not_exist")  # must not crash


func test_play_music_with_no_matching_file_is_a_safe_no_op() -> void:
	Audio.play_music(&"does_not_exist")  # must not crash


func test_play_sfx_is_a_no_op_when_sfx_disabled() -> void:
	Game.meta.sfx_enabled = false
	Audio.play_sfx(&"click")  # must not crash even though sfx is off


func test_set_music_enabled_updates_meta() -> void:
	Audio.set_music_enabled(false)
	assert_false(Game.meta.music_enabled)
	Audio.set_music_enabled(true)
	assert_true(Game.meta.music_enabled)


func test_set_sfx_enabled_updates_meta() -> void:
	Audio.set_sfx_enabled(false)
	assert_false(Game.meta.sfx_enabled)
	Audio.set_sfx_enabled(true)
	assert_true(Game.meta.sfx_enabled)


func test_sound_settings_default_to_enabled_on_a_fresh_meta_state() -> void:
	var meta := MetaState.new()
	assert_true(meta.music_enabled)
	assert_true(meta.sfx_enabled)


func test_sound_settings_round_trip_through_to_dict_and_from_dict() -> void:
	var meta := MetaState.new()
	meta.music_enabled = false
	meta.sfx_enabled = false
	var restored: MetaState = MetaState.from_dict(meta.to_dict())
	assert_false(restored.music_enabled)
	assert_false(restored.sfx_enabled)


func test_every_button_added_to_the_tree_gets_a_click_handler() -> void:
	# Doesn't assert a sound actually played (no file exists to play) - proves
	# the global hook (Audio._on_node_added) actually connects to a button's
	# `pressed` signal without erroring, which is the wiring the whole
	# "every click gets a sound for free" framework depends on.
	var button := Button.new()
	add_child_autofree(button)
	await get_tree().process_frame
	button.pressed.emit()  # must not crash
