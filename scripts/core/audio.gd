## Autoload: sound framework (direct request - "if you can generate high
## quality sound we can do that, otherwise put the framework and structure
## in and I can add later"). No audio assets exist in the project yet and
## nothing here can generate them - every play call below is a safe no-op
## until a real file is dropped into assets/audio/sfx/ or assets/audio/music/.
##
## SFX and music are both loaded by scanning their asset directories at
## boot and keying each file by its own filename (e.g.
## assets/audio/sfx/found_colony.ogg -> id &"found_colony") - the exact
## same directory-scan-and-key-by-name pattern Db already uses for every
## other content type. That's the point: dropping in a real audio file and
## naming it to match an id already called from code (see the call sites
## in main_screen.gd) makes it play with zero further code changes.
##
## Enabled/disabled state (Game.meta.music_enabled/sfx_enabled) is a
## device-level preference, not run-scoped - see MetaState's doc comment.
## Toggling either off here doesn't just gate future play() calls, it stops
## whatever's already audible immediately.
extends Node

const SFX_DIR: String = "res://assets/audio/sfx/"
const MUSIC_DIR: String = "res://assets/audio/music/"
const SFX_POOL_SIZE: int = 8
const SUPPORTED_EXTENSIONS: Array[String] = ["ogg", "wav", "mp3"]

var _sfx_streams: Dictionary = {}  # StringName -> AudioStream
var _music_streams: Dictionary = {}  # StringName -> AudioStream

var _sfx_pool: Array[AudioStreamPlayer] = []
var _music_player: AudioStreamPlayer
var _current_music_id: StringName = &""


func _ready() -> void:
	_sfx_streams = _scan_audio_dir(SFX_DIR)
	_music_streams = _scan_audio_dir(MUSIC_DIR)

	for i: int in range(SFX_POOL_SIZE):
		var player := AudioStreamPlayer.new()
		player.bus = "Master"
		add_child(player)
		_sfx_pool.append(player)

	_music_player = AudioStreamPlayer.new()
	_music_player.bus = "Master"
	_music_player.finished.connect(_on_music_finished)
	add_child(_music_player)

	print("Audio: loaded %d sfx, %d music tracks" % [_sfx_streams.size(), _music_streams.size()])

	# Every Button anywhere in the project gets a click sound for free, with
	# no per-panel wiring - node_added fires for every node added to the
	# tree, which already covers every button every panel builds (and
	# rebuilds, repeatedly - see MainScreen's refresh cadence) since they're
	# all plain Button.new() + add_child() calls.
	get_tree().node_added.connect(_on_node_added)


func _on_node_added(node: Node) -> void:
	if node is BaseButton:
		(node as BaseButton).pressed.connect(func() -> void: play_sfx(&"click"))


## Safe no-op if `id` has no matching file yet (see the class doc) or SFX is
## disabled.
func play_sfx(id: StringName) -> void:
	if not Game.meta.sfx_enabled:
		return
	var stream: AudioStream = _sfx_streams.get(id)
	if stream == null:
		return
	var player: AudioStreamPlayer = _next_free_sfx_player()
	player.stream = stream
	player.play()


## Loops `id` - safe no-op if there's no matching file yet or music is
## disabled (does not remember `id` in that case; turning music on later
## won't retroactively start it - call play_music() again once it's on).
func play_music(id: StringName) -> void:
	if _current_music_id == id and _music_player.playing:
		return
	_current_music_id = id
	if not Game.meta.music_enabled:
		return
	var stream: AudioStream = _music_streams.get(id)
	if stream == null:
		return
	_music_player.stream = stream
	_music_player.play()


func stop_music() -> void:
	_current_music_id = &""
	_music_player.stop()


## Called by the Menu popup's toggles. Stopping/resuming music happens
## immediately here rather than waiting for the next play_music() call, so
## flipping the toggle mid-track has an audible effect right away.
func set_music_enabled(enabled: bool) -> void:
	Game.meta.music_enabled = enabled
	if not enabled:
		_music_player.stop()
	elif _current_music_id != &"":
		play_music(_current_music_id)


func set_sfx_enabled(enabled: bool) -> void:
	Game.meta.sfx_enabled = enabled


func _on_music_finished() -> void:
	# AudioStreamPlayer has no built-in "loop forever" toggle that works
	# uniformly across every stream type (ogg/wav/mp3) - replaying on
	# `finished` is the one approach that works regardless of format.
	if _current_music_id != &"" and Game.meta.music_enabled:
		_music_player.play()


func _next_free_sfx_player() -> AudioStreamPlayer:
	for player: AudioStreamPlayer in _sfx_pool:
		if not player.playing:
			return player
	# Pool exhausted (SFX_POOL_SIZE simultaneous sounds at once) - steal the
	# first one rather than dropping the new sound silently.
	return _sfx_pool[0]


## Scans `dir_path` for supported audio files and returns id -> AudioStream,
## id being the filename without its extension (mirrors Db's
## filename-is-the-id convention for every other content type).
func _scan_audio_dir(dir_path: String) -> Dictionary:
	var out: Dictionary = {}
	var dir: DirAccess = DirAccess.open(dir_path)
	if dir == null:
		return out

	dir.list_dir_begin()
	var filename: String = dir.get_next()
	while filename != "":
		if not dir.current_is_dir():
			var ext: String = filename.get_extension().to_lower()
			if SUPPORTED_EXTENSIONS.has(ext):
				var stream: Resource = load(dir_path + filename)
				if stream is AudioStream:
					out[StringName(filename.get_basename())] = stream
				else:
					push_error("Audio: %s did not load as an AudioStream" % (dir_path + filename))
		filename = dir.get_next()
	dir.list_dir_end()

	return out
