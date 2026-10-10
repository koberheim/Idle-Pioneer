## Sound effects and music. A file at assets/audio/sfx/<id>.(ogg|wav|mp3) or
## assets/audio/music/<id>.* is used for that id; ids without a file fall back to
## a small synthesised tone, so the game works without any audio files. Extra
## takes <id>_2 ... <id>_9 are variants: play() picks one, never twice in a row. See
## assets/audio/README.md for the id list and the loudness each file should have.
##
## Music follows a context (set_music_context): it crossfades between contexts
## and resumes each one where it left off. Playlist contexts (theme, europe,
## congress) play <id>, <id>_2, <id>_3 ... shuffled, with a pause between
## tracks; any other context loops, and one-shots (independence) play once and
## hand back. Under the music,
## an ambience bed (assets/audio/ambience/<id>.*) loops per context and keeps
## going through the gaps between playlist tracks; it follows the Music setting.
extends Node

const RATE := 22050
const SFX_DIR := "res://assets/audio/sfx/"
const MUSIC_DIR := "res://assets/audio/music/"
const AMBIENCE_DIR := "res://assets/audio/ambience/"
## Sound files are loudness-normalised per id in the file itself
## (tools/music/sfx_tools.py), so they all play at this level.
const SFX_DB := 0.0
## Optional per-id fine trims in dB on top of SFX_DB, for quick listening
## tweaks. Prefer re-normalising the file so the README targets stay true.
const TRIM_DB: Dictionary = {}
## Level of the synthesised fallback tones (only used for ids without a file).
const SYNTH_DB := -8.0
## Music files are normalised to -16 LUFS integrated, so in game they sit at
## about -23 LUFS: under the UI sounds (-24 LUFS momentary peaks, which cut
## through) and well under the rewards (-20) and ceremonies (-18).
const MUSIC_DB := -7.0
## Ambience files are normalised to -26 LUFS integrated, so in game they sit at
## about -34 LUFS, roughly 10 LU under the music.
const AMBIENCE_DB := -8.0
## Ambience bed per music context; a one-shot context keeps whatever bed is on.
const AMBIENCE: Dictionary = {"theme": "amb_newworld", "europe": "amb_europe", "congress": "amb_congress"}
const FADE_SECONDS := 1.5
## Fade used instead of a hard stop, so a cut-off never clicks.
const QUICK_FADE := 0.05
## Silence between playlist tracks, in seconds (min, max), per context; the
## ambience bed keeps playing through it. The map gets long rests; the tabs a
## short breath, since a visit there is brief.
const PLAYLIST_GAP: Dictionary = {"theme": Vector2(20.0, 40.0), "europe": Vector2(5.0, 10.0), "congress": Vector2(5.0, 10.0)}
const PLAYLIST_MAX := 9
## Music contexts that play once and then return to the previous context.
const ONE_SHOT_MUSIC: Array[String] = ["independence"]
## Music contexts that are playlists of <id>, <id>_2 ... <id>_9.
const PLAYLIST_MUSIC: Array[String] = ["theme", "europe", "congress"]
## Played on their own players so a burst of UI sounds can't cut them off.
const CEREMONIAL: Array[String] = ["liberty", "fanfare", "purchase", "salute"]
## Played with a little random pitch so repeats don't sound mechanical.
const VARIED_PITCH: Array[String] = ["click", "tab", "buy", "coin", "deny", "quill"]

## id -> Array of streams (the file and its variants, or the synth fallback).
var _sfx: Dictionary = {}
var _last_variant: Dictionary = {}
var _sfx_db: Dictionary = {}
var _players: Array[AudioStreamPlayer] = []
var _next: int = 0
var _ceremony: Array[AudioStreamPlayer] = []
var _last_play: Dictionary = {}
var _warned: Dictionary = {}

## Every music player alive: the current one and any still fading out.
var _music_players: Array[AudioStreamPlayer] = []
var _music: AudioStreamPlayer
var _music_files: Dictionary = {}
var _synth_theme: AudioStream
var _context: String = "theme"
var _return_context: String = "theme"
## context -> {"stream": AudioStream, "pos": float}, where to pick up again.
var _resume: Dictionary = {}
## context -> remaining shuffled track ids; and the last id played per context.
var _bag: Dictionary = {}
var _last_track: Dictionary = {}
var _gap: Timer
var _started: bool = false
var _paused: bool = false
var _headless: bool = false
var _music_task: int = -1
var _amb: AudioStreamPlayer
var _amb_id: String = ""


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	for i in 8:
		var p := AudioStreamPlayer.new()
		add_child(p)
		_players.append(p)
	for i in 2:
		var c := AudioStreamPlayer.new()
		add_child(c)
		_ceremony.append(c)
	_gap = Timer.new()
	_gap.one_shot = true
	_gap.timeout.connect(_on_gap_timeout)
	add_child(_gap)
	_headless = DisplayServer.get_name() == "headless"
	if _headless:
		return
	_load_sfx()
	if _music_file("theme") == null:
		# Synthesising the theme takes long enough to stall a phone's first
		# frame, so it's built off the main thread and starts when ready.
		_music_task = WorkerThreadPool.add_task(func() -> void:
			var stream: AudioStreamWAV = _build_music()
			_set_synth_music.call_deferred(stream))


func _exit_tree() -> void:
	if _music_task >= 0:
		WorkerThreadPool.wait_for_task_completion(_music_task)
		_music_task = -1


func _set_synth_music(stream: AudioStream) -> void:
	if _music_task >= 0:
		WorkerThreadPool.wait_for_task_completion(_music_task)
		_music_task = -1
	_synth_theme = stream
	if _started and _music == null:
		sync_music()


# --- Sound effects ------------------------------------------------------------------

## Plays a sound by id. Unknown ids, and every call while sound is off or
## paused for an ad, are ignored.
func play(id: String) -> void:
	if _paused or not Game.meta.sfx_on:
		return
	var takes: Array = _sfx.get(id, [])
	if takes.is_empty():
		if not _headless and OS.is_debug_build() and not _warned.has(id):
			_warned[id] = true
			push_warning("Sfx.play: unknown sound id '%s'" % id)
		return
	var now: int = Time.get_ticks_msec()
	if now - int(_last_play.get(id, -1000)) < 60:
		return
	_last_play[id] = now
	var k: int = randi() % takes.size()
	if takes.size() > 1 and k == int(_last_variant.get(id, -1)):
		k = (k + 1) % takes.size()
	_last_variant[id] = k
	var stream: AudioStream = takes[k]
	var p: AudioStreamPlayer
	if id in CEREMONIAL:
		p = _ceremony[0] if not _ceremony[0].playing else _ceremony[1]
	else:
		p = _players[_next]
		_next = (_next + 1) % _players.size()
	p.stream = stream
	p.volume_db = float(_sfx_db[id])
	p.pitch_scale = randf_range(0.97, 1.03) if id in VARIED_PITCH else 1.0
	p.play()


## True if `id` has a sound (a file or a synthesised fallback).
func has_sound(id: String) -> bool:
	return _sfx.has(id)


## Silences everything while an ad plays: music pauses where it is, sound
## effects stop, and play() is ignored until resume_all().
func pause_all() -> void:
	_paused = true
	_gap.paused = true
	for m: AudioStreamPlayer in _music_players:
		m.stream_paused = true
	if _amb != null:
		_amb.stream_paused = true
	for p: AudioStreamPlayer in _players + _ceremony:
		p.stop()


## Undoes pause_all(): music continues from where it was.
func resume_all() -> void:
	if not _paused:
		return
	_paused = false
	_gap.paused = false
	for m: AudioStreamPlayer in _music_players:
		m.stream_paused = false
	if _amb != null:
		_amb.stream_paused = false
	if _headless or not _started:
		return
	_sync_ambience()
	if not Game.meta.music_on:
		_stop_music()
	elif _music == null or String(_music.get_meta("context", "")) != _context:
		# The context or the Music setting changed while paused.
		if _music != null or _gap.is_stopped():
			_switch_music()


func is_paused() -> bool:
	return _paused


# --- Music --------------------------------------------------------------------------

## Starts or stops the music to match the Music setting.
func sync_music() -> void:
	_started = true
	if _headless:
		return
	_sync_ambience()
	if not Game.meta.music_on:
		_stop_music()
		return
	if _paused:
		return
	if _music == null and _gap.is_stopped():
		_switch_music()


## Switches the music to the context `id` with a crossfade: assets/audio/music/
## <id>.* (a playlist for PLAYLIST_MUSIC), falling back to the theme. A context
## left earlier resumes where it was. One-shot contexts (ONE_SHOT_MUSIC) play
## once, then return to whatever context was active before them.
func set_music_context(id: String) -> void:
	if _headless or id == _context:
		return
	if id in ONE_SHOT_MUSIC:
		# A one-shot only makes sense heard; with music off it's skipped.
		if _music_file(id) == null or not _started or not Game.meta.music_on:
			return
		if _context not in ONE_SHOT_MUSIC:
			_return_context = _context
	_context = id
	if _started and Game.meta.music_on and not _paused:
		_switch_music()
		_sync_ambience()


func music_context() -> String:
	return _context


## Crossfades from whatever is playing to the current context.
func _switch_music() -> void:
	_gap.stop()
	var old: AudioStreamPlayer = _music
	_music = null
	if old != null:
		_remember(old)
		_fade_out(old, FADE_SECONDS)
	var pick: Array = _pick(_context)
	var stream: AudioStream = pick[0]
	if stream == null:
		return
	# A one-shot (a fanfare) comes in at full volume; its opening matters. So
	# does a playlist track starting from the top after silence.
	var instant: bool = _context in ONE_SHOT_MUSIC or (old == null and float(pick[1]) == 0.0)
	_music = _start_player(stream, float(pick[1]), instant)


## The stream to play for `context` and where to start it.
func _pick(context: String) -> Array:
	if _resume.has(context):
		var r: Dictionary = _resume[context]
		_resume.erase(context)
		return [r["stream"], r["pos"]]
	if context in PLAYLIST_MUSIC:
		return [_next_track(context), 0.0]
	return [_resolve_music(context), 0.0]


func _remember(p: AudioStreamPlayer) -> void:
	var context: String = p.get_meta("context", "")
	if context == "" or context in ONE_SHOT_MUSIC or not p.playing:
		return
	_resume[context] = {"stream": p.stream, "pos": p.get_playback_position()}


func _start_player(stream: AudioStream, pos: float, instant: bool) -> AudioStreamPlayer:
	var p := AudioStreamPlayer.new()
	p.set_meta("context", _context)
	p.stream = stream
	p.set_meta("base_db", MUSIC_DB)
	p.volume_db = MUSIC_DB if instant else -80.0
	p.finished.connect(_on_music_finished.bind(p))
	add_child(p)
	_music_players.append(p)
	p.play(pos)
	if not instant:
		# Equal-power fade so a crossfade doesn't dip in the middle.
		_tween_gain(p, 0.0, 1.0, FADE_SECONDS, false)
	return p


## Fades `p` from its current level to silence, then frees it. Safe to call
## on a player that's still fading in: it fades out from where it got to.
func _fade_out(p: AudioStreamPlayer, seconds: float) -> void:
	if not p.playing or p.stream_paused:
		_free_player(p)
		return
	var g0: float = clampf(db_to_linear(p.volume_db - float(p.get_meta("base_db", MUSIC_DB))), 0.0, 1.0)
	_tween_gain(p, g0, 0.0, seconds, true)


func _tween_gain(p: AudioStreamPlayer, from: float, to: float, seconds: float, free_after: bool) -> void:
	var old: Tween = (p.get_meta("tween") if p.has_meta("tween") else null)
	if old != null:
		old.kill()
	var tw: Tween = create_tween()
	p.set_meta("tween", tw)
	var rising: bool = to > from
	var base: float = float(p.get_meta("base_db", MUSIC_DB))
	tw.tween_method(func(f: float) -> void:
		var curve: float = sin(f * PI * 0.5) if rising else cos(f * PI * 0.5)
		var g: float = to * curve if rising else from * curve
		p.volume_db = base + linear_to_db(maxf(g, 0.0001)),
		0.0, 1.0, seconds)
	if free_after:
		tw.tween_callback(_on_faded_out.bind(p))


func _on_faded_out(p: AudioStreamPlayer) -> void:
	if is_instance_valid(p):
		p.set_meta("tween", null)
	_free_player(p)


func _free_player(p: AudioStreamPlayer) -> void:
	if not is_instance_valid(p):
		return
	var tw: Tween = (p.get_meta("tween") if p.has_meta("tween") else null)
	if tw != null:
		tw.kill()
	_music_players.erase(p)
	if p == _music:
		_music = null
	p.stop()
	p.queue_free()


## Stops all music (Music switched off), remembering where the context was.
func _stop_music() -> void:
	_gap.stop()
	if _music != null:
		_remember(_music)
	for m: AudioStreamPlayer in _music_players.duplicate():
		_fade_out(m, QUICK_FADE)
	_music = null
	if _context in ONE_SHOT_MUSIC:
		# Don't replay a one-shot from the top when music is switched back on.
		_context = _return_context


## Crossfades the ambience bed to the current context's (or to silence when
## music is off, paused for an ad, or the context has no bed file).
func _sync_ambience() -> void:
	if _headless or _paused:
		return
	var want: String = ""
	if _started and Game.meta.music_on:
		want = _amb_id if _context in ONE_SHOT_MUSIC else str(AMBIENCE.get(_context, ""))
	var stream: AudioStream = _file_or(AMBIENCE_DIR, want, null) if want != "" else null
	if stream == null:
		want = ""
	if want == _amb_id:
		return
	if _amb != null:
		_fade_out(_amb, FADE_SECONDS)
		_amb = null
	_amb_id = want
	if stream == null:
		return
	if stream is AudioStreamOggVorbis:
		(stream as AudioStreamOggVorbis).loop = true
	elif stream is AudioStreamMP3:
		(stream as AudioStreamMP3).loop = true
	elif stream is AudioStreamWAV and (stream as AudioStreamWAV).loop_mode == AudioStreamWAV.LOOP_DISABLED:
		var w := stream as AudioStreamWAV
		w.loop_mode = AudioStreamWAV.LOOP_FORWARD
		w.loop_begin = 0
		w.loop_end = int(w.get_length() * w.mix_rate)
	_amb = AudioStreamPlayer.new()
	_amb.stream = stream
	_amb.set_meta("base_db", AMBIENCE_DB)
	_amb.volume_db = -80.0
	add_child(_amb)
	# A random start, so the bed doesn't open on the same waves every time.
	_amb.play(randf() * stream.get_length())
	_tween_gain(_amb, 0.0, 1.0, FADE_SECONDS * 2.0, false)


func _on_music_finished(p: AudioStreamPlayer) -> void:
	if p != _music:
		_free_player(p)
		return
	if _context in ONE_SHOT_MUSIC:
		set_music_context(_return_context)
	elif _context in PLAYLIST_MUSIC:
		_free_player(p)
		var gap: Vector2 = PLAYLIST_GAP.get(_context, Vector2(20.0, 40.0))
		_gap.start(randf_range(gap.x, gap.y))
	else:
		# Looping tracks don't finish; if a replacement file can't loop, restart it.
		p.play()


func _on_gap_timeout() -> void:
	if _context in PLAYLIST_MUSIC and _music == null and _started and not _paused and Game.meta.music_on:
		_switch_music()


## Next track of a playlist context: a shuffled pass through all its tracks,
## never the same track twice in a row.
func _next_track(context: String) -> AudioStream:
	var tracks: Array[String] = _playlist(context)
	if tracks.is_empty():
		return _resolve_music(context)
	var bag: Array = _bag.get(context, [])
	if bag.is_empty():
		bag = tracks.duplicate()
		bag.shuffle()
		if bag.size() > 1 and bag[0] == _last_track.get(context, ""):
			bag.push_back(bag.pop_front())
	var id: String = bag.pop_front()
	_bag[context] = bag
	_last_track[context] = id
	return _music_file(id)


func _playlist(context: String) -> Array[String]:
	var out: Array[String] = []
	for i in range(1, PLAYLIST_MAX + 1):
		var id: String = context if i == 1 else "%s_%d" % [context, i]
		if _music_file(id) != null:
			out.append(id)
	return out


func _music_file(id: String) -> AudioStream:
	if not _music_files.has(id):
		var s: AudioStream = _file_or(MUSIC_DIR, id, null)
		var loop: bool = id not in ONE_SHOT_MUSIC and _playlist_of(id) == ""
		if s is AudioStreamOggVorbis:
			(s as AudioStreamOggVorbis).loop = loop
		elif s is AudioStreamMP3:
			(s as AudioStreamMP3).loop = loop
		elif s is AudioStreamWAV:
			var w := s as AudioStreamWAV
			if loop and w.loop_mode == AudioStreamWAV.LOOP_DISABLED:
				w.loop_mode = AudioStreamWAV.LOOP_FORWARD
				w.loop_begin = 0
				w.loop_end = int(w.get_length() * w.mix_rate)
			elif not loop:
				w.loop_mode = AudioStreamWAV.LOOP_DISABLED
		_music_files[id] = s
	return _music_files[id]


## The playlist context a track id belongs to ("theme_3" -> "theme"), or "".
func _playlist_of(id: String) -> String:
	for context: String in PLAYLIST_MUSIC:
		if id == context:
			return context
		if id.begins_with(context + "_") and id.substr(context.length() + 1).is_valid_int():
			return context
	return ""


func _resolve_music(id: String) -> AudioStream:
	var s: AudioStream = _music_file(id)
	if s == null and id not in PLAYLIST_MUSIC:
		s = _music_file("theme")
	if s == null:
		s = _synth_theme
	return s


func _file_or(dir: String, id: String, fallback: AudioStream) -> AudioStream:
	for ext: String in ["ogg", "wav", "mp3"]:
		var path: String = dir + id + "." + ext
		if ResourceLoader.exists(path):
			return load(path) as AudioStream
	return fallback


# --- Synthesis ----------------------------------------------------------------

## Loads every sound id: its file if there is one, otherwise a synthesised
## fallback (only built for ids that have no file).
func _load_sfx() -> void:
	var synth: Dictionary = {
		"click": func() -> AudioStream: return _tone([[1400.0, 0.025]], "square", 0.18),
		"quill": func() -> AudioStream: return _tone([[2600.0, 0.02], [2200.0, 0.03]], "pulse", 0.08),
		"tab": func() -> AudioStream: return _tone([[900.0, 0.03], [1350.0, 0.04]], "square", 0.16),
		"buy": func() -> AudioStream: return _tone([[1318.5, 0.05], [1975.5, 0.09]], "square", 0.22),
		"coin": func() -> AudioStream: return _tone([[1760.0, 0.04], [2637.0, 0.08]], "triangle", 0.3),
		"deny": func() -> AudioStream: return _tone([[180.0, 0.08], [140.0, 0.1]], "square", 0.2),
		"market": func() -> AudioStream: return _bell(784.0, 0.9),
		"found": func() -> AudioStream: return _tone([[523.25, 0.1], [659.25, 0.1], [783.99, 0.1], [1046.5, 0.3]], "square", 0.22),
		"father": func() -> AudioStream: return _tone([[392.0, 0.12], [523.25, 0.12], [659.25, 0.12], [783.99, 0.35]], "triangle", 0.35),
		"discover": func() -> AudioStream: return _tone([[880.0, 0.06], [1108.7, 0.06], [1318.5, 0.14]], "triangle", 0.3),
		"milestone": func() -> AudioStream: return _tone([[1174.7, 0.06], [1480.0, 0.06], [1760.0, 0.06], [2349.3, 0.25]], "triangle", 0.28),
		"relic": func() -> AudioStream: return _tone([[587.33, 0.05], [739.99, 0.05], [880.0, 0.05], [1174.7, 0.3]], "triangle", 0.3),
		"research": func() -> AudioStream: return _tone([[587.33, 0.08], [880.0, 0.18]], "triangle", 0.28),
		"charter": func() -> AudioStream: return _tone([[110.0, 0.05], [82.41, 0.12]], "square", 0.25),
		"unlock": func() -> AudioStream: return _tone([[659.25, 0.06], [783.99, 0.06], [987.77, 0.06], [1318.5, 0.22]], "triangle", 0.3),
		"consult": func() -> AudioStream: return _tone([[880.0, 0.05], [1174.7, 0.22]], "triangle", 0.25),
		"liberty": func() -> AudioStream: return _bell(523.25, 2.2),
		"fanfare": func() -> AudioStream: return _tone([[392.0, 0.15], [392.0, 0.08], [523.25, 0.2], [659.25, 0.2], [783.99, 0.2], [659.25, 0.12], [783.99, 0.5]], "square", 0.22),
		"purchase": func() -> AudioStream: return _tone([[587.33, 0.1], [739.99, 0.1], [880.0, 0.1], [1174.7, 0.4]], "square", 0.2),
		"treasure": func() -> AudioStream: return _tone([[1760.0, 0.04], [2093.0, 0.04], [2637.0, 0.12]], "triangle", 0.3),
		"page": func() -> AudioStream: return _tone([[1318.5, 0.05], [1760.0, 0.12]], "triangle", 0.25),
		"workshop": func() -> AudioStream: return _tone([[220.0, 0.08], [196.0, 0.1]], "square", 0.2),
		"sheet_up": func() -> AudioStream: return _tone([[700.0, 0.03], [900.0, 0.03]], "triangle", 0.12),
		"sheet_down": func() -> AudioStream: return _tone([[900.0, 0.03], [700.0, 0.03]], "triangle", 0.12),
		"governor": func() -> AudioStream: return _tone([[392.0, 0.1], [587.33, 0.25]], "triangle", 0.3),
		"salute": func() -> AudioStream: return _tone([[65.0, 0.4], [65.0, 0.4], [65.0, 0.6]], "square", 0.25),
		"welcome": func() -> AudioStream: return _tone([[523.25, 0.08], [659.25, 0.08], [783.99, 0.2]], "triangle", 0.28),
	}
	for id: String in synth.keys():
		var takes: Array = []
		for i in range(1, 10):
			var file: AudioStream = _file_or(SFX_DIR, id if i == 1 else "%s_%d" % [id, i], null)
			if file == null:
				break
			takes.append(file)
		if not takes.is_empty():
			_sfx[id] = takes
			_sfx_db[id] = SFX_DB + float(TRIM_DB.get(id, 0.0))
		else:
			_sfx[id] = [(synth[id] as Callable).call()]
			_sfx_db[id] = SYNTH_DB + float(TRIM_DB.get(id, 0.0))


func _wav(samples: PackedFloat32Array, loop: bool = false) -> AudioStreamWAV:
	var data := PackedByteArray()
	data.resize(samples.size() * 2)
	for i in samples.size():
		data.encode_s16(i * 2, int(clampf(samples[i], -1.0, 1.0) * 32000.0))
	var w := AudioStreamWAV.new()
	w.format = AudioStreamWAV.FORMAT_16_BITS
	w.mix_rate = RATE
	w.stereo = false
	w.data = data
	if loop:
		w.loop_mode = AudioStreamWAV.LOOP_FORWARD
		w.loop_end = samples.size()
	return w


func _osc(kind: String, phase: float) -> float:
	var p: float = phase - floor(phase)
	match kind:
		"square":
			return 1.0 if p < 0.5 else -1.0
		"pulse":
			return 1.0 if p < 0.25 else -1.0
		"triangle":
			return 4.0 * absf(p - 0.5) - 1.0
		_:
			return sin(p * TAU)


func _tone(notes: Array, kind: String, vol: float) -> AudioStreamWAV:
	var out := PackedFloat32Array()
	for n: Array in notes:
		var freq: float = n[0]
		var dur: float = n[1]
		var count: int = int(dur * RATE)
		var phase: float = 0.0
		for i in count:
			var t: float = float(i) / count
			var env: float = minf(1.0, t * 40.0) * pow(1.0 - t, 1.6)
			phase += freq / RATE
			out.append(_osc(kind, phase) * env * vol)
	return _wav(out)


func _bell(freq: float, dur: float) -> AudioStreamWAV:
	var out := PackedFloat32Array()
	var count: int = int(dur * RATE)
	for i in count:
		var t: float = float(i) / RATE
		var env: float = exp(-t * 3.2) * minf(1.0, t * 300.0)
		var s: float = sin(TAU * freq * t) * 0.6 + sin(TAU * freq * 2.76 * t) * 0.25 * exp(-t * 5.0) + sin(TAU * freq * 5.4 * t) * 0.12 * exp(-t * 8.0)
		out.append(s * env * 0.4)
	return _wav(out)


## An original, gentle folk-style loop: triangle-wave melody over a plucked
## square bass, 16 bars in D major at a walking pace.
func _build_music() -> AudioStreamWAV:
	var bpm: float = 96.0
	var beat: float = 60.0 / bpm
	# Scale degrees relative to D4; 0 = rest marker handled by -99.
	var melody: Array = [
		[0, 1], [2, 1], [4, 1], [7, 1], [4, 2], [2, 1], [0, 1],
		[2, 1], [4, 1], [5, 1], [4, 1], [2, 3], [-99, 1],
		[4, 1], [5, 1], [7, 1], [9, 1], [7, 2], [5, 1], [4, 1],
		[2, 1], [4, 1], [2, 1], [-1, 1], [0, 3], [-99, 1],
		[7, 1], [9, 1], [11, 1], [12, 1], [11, 2], [9, 1], [7, 1],
		[9, 1], [7, 1], [5, 1], [4, 1], [5, 3], [-99, 1],
		[4, 1], [2, 1], [4, 1], [5, 1], [7, 2], [4, 1], [2, 1],
		[0, 1], [2, 1], [-1, 1], [-3, 1], [0, 4],
	]
	var bass_roots: Array = [0, 0, -3, -3, 3, 3, -4, 0, 0, 3, -3, -4, 0, -3, -4, 0]
	var major: Array = [0, 2, 4, 5, 7, 9, 11]
	var total_beats: float = 0.0
	for n: Array in melody:
		total_beats += float(n[1])
	var count: int = int(total_beats * beat * RATE)
	var out := PackedFloat32Array()
	out.resize(count)
	# Melody.
	var pos: int = 0
	for n: Array in melody:
		var deg: int = n[0]
		var len_s: float = float(n[1]) * beat
		var samples: int = int(len_s * RATE)
		if deg != -99:
			var semis: int = _degree_to_semitones(deg, major)
			var freq: float = 293.66 * pow(2.0, semis / 12.0)
			var phase: float = 0.0
			for i in samples:
				if pos + i >= count:
					break
				var t: float = float(i) / samples
				var env: float = minf(1.0, t * 25.0) * (1.0 - t * 0.6)
				var vib: float = 1.0 + sin(float(i) / RATE * TAU * 5.0) * 0.004
				phase += freq * vib / RATE
				out[pos + i] += _osc("triangle", phase) * env * 0.22
		pos += samples
	# Bass: one plucked note per two beats.
	var bar_samples: int = int(beat * 2.0 * RATE)
	var bars: int = count / bar_samples
	for b in bars:
		var root: int = bass_roots[b % bass_roots.size()]
		var freq: float = 146.83 * pow(2.0, float(_degree_to_semitones(root, major)) / 12.0) / 2.0
		var phase: float = 0.0
		for i in bar_samples:
			var idx: int = b * bar_samples + i
			if idx >= count:
				break
			var t: float = float(i) / RATE
			var env: float = exp(-t * 3.0)
			phase += freq / RATE
			out[idx] += _osc("pulse", phase) * env * 0.07
	# Soft fade at the loop seam.
	for i in 800:
		var f: float = float(i) / 800.0
		out[i] *= f
		out[count - 1 - i] *= f
	return _wav(out, true)


func _degree_to_semitones(deg: int, scale: Array) -> int:
	var octave: int = int(floor(float(deg) / 7.0))
	var idx: int = deg - octave * 7
	return octave * 12 + int(scale[idx])
