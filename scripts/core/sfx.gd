## Sound effects and music. Every sound has a synthesised fallback built at
## startup, so the game works without any audio files; a .ogg/.wav/.mp3 at
## assets/audio/sfx/<id>.* or assets/audio/music/<id>.* replaces the synthesised
## version of that id. Music follows a context (see set_music_context) and
## crossfades between tracks.
extends Node

const RATE := 22050
const SFX_DIR := "res://assets/audio/sfx/"
const MUSIC_DIR := "res://assets/audio/music/"
const SFX_DB := -8.0
## Recorded samples are normalised hotter than the synthesised tones.
const FILE_SFX_DB := -5.0
const MUSIC_DB := -14.0
const FADE_SECONDS := 1.5
## Music contexts that play once and then return to the previous context.
const ONE_SHOT_MUSIC: Array[String] = ["independence"]

var _sfx: Dictionary = {}
var _sfx_db: Dictionary = {}
var _players: Array[AudioStreamPlayer] = []
var _next: int = 0
var _music_players: Array[AudioStreamPlayer] = []
var _music: AudioStreamPlayer
var _music_files: Dictionary = {}
var _synth_theme: AudioStream
var _context: String = "theme"
var _return_context: String = "theme"
var _fade: Tween
var _started: bool = false
var _headless: bool = false
var _last_play: Dictionary = {}
var _music_task: int = -1


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	for i in 8:
		var p := AudioStreamPlayer.new()
		p.volume_db = SFX_DB
		add_child(p)
		_players.append(p)
	for i in 2:
		var m := AudioStreamPlayer.new()
		m.volume_db = MUSIC_DB
		m.finished.connect(_on_music_finished.bind(m))
		add_child(m)
		_music_players.append(m)
	_music = _music_players[0]
	_headless = DisplayServer.get_name() == "headless"
	if _headless:
		return
	_build_sfx()
	if _music_file("theme") == null:
		# Synthesising the theme takes long enough to stall a phone's first
		# frame, so it's built off the main thread and starts when ready.
		_music_task = WorkerThreadPool.add_task(func() -> void:
			var stream: AudioStreamWAV = _build_music()
			_set_music.call_deferred(stream))
	_music.stream = _resolve_music(_context)


func _exit_tree() -> void:
	if _music_task >= 0:
		WorkerThreadPool.wait_for_task_completion(_music_task)
		_music_task = -1


func _set_music(stream: AudioStream) -> void:
	if _music_task >= 0:
		WorkerThreadPool.wait_for_task_completion(_music_task)
		_music_task = -1
	_synth_theme = stream
	if _music.stream == null:
		_music.stream = _resolve_music(_context)
		_music.volume_db = MUSIC_DB
		if _started:
			sync_music()


func play(id: String) -> void:
	if not Game.meta.sfx_on or not _sfx.has(id):
		return
	var now: int = Time.get_ticks_msec()
	if now - int(_last_play.get(id, 0)) < 60:
		return
	_last_play[id] = now
	var p: AudioStreamPlayer = _players[_next]
	_next = (_next + 1) % _players.size()
	p.stream = _sfx[id]
	p.volume_db = SFX_DB + float(_sfx_db.get(id, 0.0))
	p.pitch_scale = randf_range(0.97, 1.03) if id in ["click", "buy", "coin"] else 1.0
	p.play()


## Starts or stops the music to match the Music setting.
func sync_music() -> void:
	_started = true
	if _headless or _music.stream == null:
		return
	if Game.meta.music_on and not _music.playing:
		_music.volume_db = MUSIC_DB
		_music.play()
	elif not Game.meta.music_on and _music.playing:
		if _fade != null:
			_fade.kill()
		for m: AudioStreamPlayer in _music_players:
			m.stop()
		if _context in ONE_SHOT_MUSIC:
			# Don't replay a one-shot from the top when music is switched back on.
			_context = _return_context
			_music.stream = _resolve_music(_context)


## Switches the music to assets/audio/music/<id>.* with a crossfade, falling back
## to the theme. One-shot contexts (ONE_SHOT_MUSIC) play once, then return to
## whatever context was active before them.
func set_music_context(id: String) -> void:
	if _headless or id == _context:
		return
	if id in ONE_SHOT_MUSIC:
		if _music_file(id) == null:
			return
		if _context not in ONE_SHOT_MUSIC:
			_return_context = _context
	_context = id
	var stream: AudioStream = _resolve_music(id)
	if stream == null or stream == _music.stream:
		return
	if not _music.playing or not Game.meta.music_on:
		if _fade != null:
			_fade.kill()
		for m: AudioStreamPlayer in _music_players:
			m.stop()
		_music.stream = stream
		_music.volume_db = MUSIC_DB
		if _started and Game.meta.music_on:
			_music.volume_db = -80.0
			_music.play()
			_fade = create_tween()
			_fade.tween_property(_music, "volume_db", MUSIC_DB, FADE_SECONDS).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
		return
	# A one-shot (a fanfare) comes in at full volume; its opening matters.
	_crossfade_to(stream, id in ONE_SHOT_MUSIC)


func music_context() -> String:
	return _context


func _crossfade_to(stream: AudioStream, instant_in: bool = false) -> void:
	if _fade != null:
		_fade.kill()
	var old: AudioStreamPlayer = _music
	var nxt: AudioStreamPlayer = _music_players[1] if old == _music_players[0] else _music_players[0]
	var old_gain: float = clampf(db_to_linear(old.volume_db - MUSIC_DB), 0.0, 1.0)
	_music = nxt
	nxt.stop()
	nxt.stream = stream
	nxt.volume_db = MUSIC_DB if instant_in else -80.0
	nxt.play()
	# Equal-power crossfade so the overall level doesn't dip mid-fade.
	_fade = create_tween()
	_fade.tween_method(func(f: float) -> void:
		if not instant_in:
			nxt.volume_db = MUSIC_DB + linear_to_db(maxf(sin(f * PI * 0.5), 0.0001))
		old.volume_db = MUSIC_DB + linear_to_db(maxf(old_gain * cos(f * PI * 0.5), 0.0001)),
		0.0, 1.0, FADE_SECONDS)
	_fade.tween_callback(old.stop)


func _on_music_finished(player: AudioStreamPlayer) -> void:
	if player == _music and _context in ONE_SHOT_MUSIC:
		set_music_context(_return_context)


func _music_file(id: String) -> AudioStream:
	if not _music_files.has(id):
		var s: AudioStream = _file_or(MUSIC_DIR, id, null)
		var loop: bool = id not in ONE_SHOT_MUSIC
		if s is AudioStreamOggVorbis:
			(s as AudioStreamOggVorbis).loop = loop
		elif s is AudioStreamMP3:
			(s as AudioStreamMP3).loop = loop
		elif s is AudioStreamWAV and loop:
			var w := s as AudioStreamWAV
			if w.loop_mode == AudioStreamWAV.LOOP_DISABLED:
				w.loop_mode = AudioStreamWAV.LOOP_FORWARD
				w.loop_begin = 0
				w.loop_end = int(w.get_length() * w.mix_rate)
		_music_files[id] = s
	return _music_files[id]


func _resolve_music(id: String) -> AudioStream:
	var s: AudioStream = _music_file(id)
	if s == null:
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

func _build_sfx() -> void:
	var defs: Dictionary = {
		"click": _tone([[1400.0, 0.025]], "square", 0.18),
		"tab": _tone([[900.0, 0.03], [1350.0, 0.04]], "square", 0.16),
		"buy": _tone([[1318.5, 0.05], [1975.5, 0.09]], "square", 0.22),
		"coin": _tone([[1760.0, 0.04], [2637.0, 0.08]], "triangle", 0.3),
		"deny": _tone([[180.0, 0.08], [140.0, 0.1]], "square", 0.2),
		"ship": _bell(784.0, 0.9),
		"found": _tone([[523.25, 0.1], [659.25, 0.1], [783.99, 0.1], [1046.5, 0.3]], "square", 0.22),
		"father": _tone([[392.0, 0.12], [523.25, 0.12], [659.25, 0.12], [783.99, 0.35]], "triangle", 0.35),
		"discover": _tone([[880.0, 0.06], [1108.7, 0.06], [1318.5, 0.14]], "triangle", 0.3),
		"liberty": _bell(523.25, 2.2),
		"fanfare": _tone([[392.0, 0.15], [392.0, 0.08], [523.25, 0.2], [659.25, 0.2], [783.99, 0.2], [659.25, 0.12], [783.99, 0.5]], "square", 0.22),
	}
	for id: String in defs.keys():
		var file: AudioStream = _file_or(SFX_DIR, id, null)
		_sfx[id] = file if file != null else defs[id]
		_sfx_db[id] = FILE_SFX_DB if file != null else 0.0


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
