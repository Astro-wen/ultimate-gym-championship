class_name Sfx
extends Node
## Chiptune sound effects and a looping BGM, synthesized at startup so the
## demo needs no audio files. Listens to Events; nothing calls it directly.

const RATE: int = 22050

@export var sfx_db: float = -8.0
@export var bgm_db: float = -20.0

var _sounds: Dictionary = {}   # StringName -> AudioStreamWAV
var _players: Array[AudioStreamPlayer] = []
var _bgm: AudioStreamPlayer
var _heartbeat_t: float = 0.0
var _alert: float = 0.0


static func attach(parent: Node) -> Sfx:
	var s := Sfx.new()
	s.name = "Sfx"
	s.process_mode = Node.PROCESS_MODE_ALWAYS
	parent.add_child(s)
	return s


func _ready() -> void:
	_sounds[&"good"] = _tone([[880.0, 0.05], [1320.0, 0.08]], 0.5, &"square")
	_sounds[&"miss"] = _tone([[160.0, 0.12]], 0.6, &"noise")
	_sounds[&"set"] = _tone([[523.0, 0.07], [659.0, 0.07], [784.0, 0.07], [1047.0, 0.16]], 0.45, &"square")
	_sounds[&"alarm"] = _tone([[988.0, 0.12], [740.0, 0.12], [988.0, 0.12], [740.0, 0.2]], 0.5, &"saw")
	_sounds[&"shove"] = _mix(_tone([[140.0, 0.05], [70.0, 0.14]], 0.9, &"square"), _tone([[300.0, 0.12]], 0.8, &"noise"))
	_sounds[&"clink"] = _tone([[1568.0, 0.04], [2093.0, 0.09]], 0.35, &"triangle")
	_sounds[&"queue"] = _tone([[660.0, 0.05], [880.0, 0.06]], 0.3, &"square")
	_sounds[&"beat"] = _tone([[70.0, 0.06], [0.0, 0.05], [60.0, 0.08]], 0.7, &"sine")
	_sounds[&"start"] = _tone([[392.0, 0.08], [523.0, 0.08], [659.0, 0.14]], 0.45, &"square")
	_sounds[&"win"] = _tone([[523.0, 0.1], [659.0, 0.1], [784.0, 0.1], [1047.0, 0.1], [784.0, 0.1], [1047.0, 0.3]], 0.45, &"square")
	_sounds[&"lose"] = _tone([[392.0, 0.18], [349.0, 0.18], [311.0, 0.18], [262.0, 0.4]], 0.45, &"triangle")
	for i: int in 6:
		var p := AudioStreamPlayer.new()
		p.volume_db = sfx_db
		add_child(p)
		_players.append(p)
	_bgm = AudioStreamPlayer.new()
	_bgm.stream = _make_bgm()
	_bgm.volume_db = bgm_db
	add_child(_bgm)
	Events.rep_completed.connect(func(_s: Node, who: Node, good: bool) -> void:
		if who.is_in_group(&"player"):
			play(&"good" if good else &"miss"))
	Events.station_use_finished.connect(func(_s: Node, who: Node) -> void:
		if who.is_in_group(&"player"):
			play(&"set"))
	Events.player_detected.connect(func(_by: Node) -> void: play(&"alarm"))
	Events.shoved.connect(func(_p: Node, _v: Node, _at: Vector2) -> void: play(&"shove"))
	Events.cup_moved.connect(func(_c: bool) -> void: play(&"clink"))
	Events.toast.connect(func(_t: String, kind: StringName) -> void:
		if kind == &"info":
			play(&"queue"))
	Events.alert_changed.connect(func(v: float) -> void: _alert = v)
	Events.run_started.connect(func() -> void:
		play(&"start")
		_bgm.play())
	Events.run_finished.connect(func(r: Dictionary) -> void:
		_bgm.stop()
		play(&"win" if r.get("state") == GameState.State.WON else &"lose"))


## Stop everything on the way out (a voice still playing at quit is reported
## as a leaked AudioStreamPlayback by the engine).
func _exit_tree() -> void:
	for p: AudioStreamPlayer in _players:
		p.stop()
		p.stream = null
	if _bgm != null:
		_bgm.stop()
		_bgm.stream = null


func play(id: StringName) -> void:
	var s: AudioStreamWAV = _sounds.get(id)
	if s == null:
		return
	for p: AudioStreamPlayer in _players:
		if not p.playing:
			p.stream = s
			p.play()
			return
	_players[0].stream = s
	_players[0].play()


func _process(delta: float) -> void:
	var paused: bool = get_tree().paused
	_bgm.stream_paused = paused
	# heartbeat speeds up as the alert rises
	if paused or not GameState.is_running() or _alert < 0.35:
		_heartbeat_t = 0.0
		return
	_heartbeat_t -= delta
	if _heartbeat_t <= 0.0:
		play(&"beat")
		_heartbeat_t = lerpf(0.9, 0.35, clampf((_alert - 0.35) / 0.65, 0.0, 1.0))


# --- synthesis -------------------------------------------------------------

static func _osc(kind: StringName, phase: float, rng: RandomNumberGenerator) -> float:
	match kind:
		&"square":
			return 1.0 if fmod(phase, 1.0) < 0.5 else -1.0
		&"saw":
			return fmod(phase, 1.0) * 2.0 - 1.0
		&"triangle":
			return absf(fmod(phase, 1.0) * 4.0 - 2.0) - 1.0
		&"noise":
			return rng.randf_range(-1.0, 1.0)
		_:
			return sin(phase * TAU)


## notes: [[freq, seconds], ...]; freq 0 = rest. Short attack/decay per note.
static func _tone(notes: Array, vol: float, kind: StringName) -> AudioStreamWAV:
	var data := PackedByteArray()
	var rng := RandomNumberGenerator.new()
	rng.seed = 7
	for n: Array in notes:
		var f: float = n[0]
		var count: int = int(float(n[1]) * RATE)
		var phase: float = 0.0
		for i: int in count:
			var env: float = minf(1.0, float(i) / 80.0) * (1.0 - float(i) / float(count))
			var v: float = 0.0
			if f > 0.0:
				phase += f / RATE
				v = _osc(kind, phase, rng)
				if kind == &"noise":
					# crude low-pass for thuds: lower freq = darker
					v *= clampf(f / 400.0, 0.2, 1.0)
			var s: int = clampi(int(v * env * vol * 32767.0), -32768, 32767)
			data.append(s & 0xFF)
			data.append((s >> 8) & 0xFF)
	return _wav(data)


static func _wav(data: PackedByteArray) -> AudioStreamWAV:
	var w := AudioStreamWAV.new()
	w.format = AudioStreamWAV.FORMAT_16_BITS
	w.mix_rate = RATE
	w.stereo = false
	w.data = data
	return w


## 8-bar loop: bass + lead, light and sneaky (A minor, 128 bpm).
static func _make_bgm() -> AudioStreamWAV:
	var bpm: float = 128.0
	var step: float = 60.0 / bpm / 2.0   # eighth notes
	var bass: Array[float] = [110.0, 0.0, 110.0, 0.0, 131.0, 0.0, 98.0, 0.0]
	var lead: Array[float] = [
		440.0, 0.0, 523.0, 0.0, 494.0, 440.0, 0.0, 392.0,
		440.0, 0.0, 0.0, 330.0, 392.0, 0.0, 440.0, 0.0,
		523.0, 0.0, 587.0, 523.0, 494.0, 0.0, 440.0, 0.0,
		392.0, 0.0, 330.0, 0.0, 294.0, 330.0, 0.0, 0.0,
	]
	var steps: int = 64
	var per: int = int(step * RATE)
	var data := PackedByteArray()
	var pb: float = 0.0
	var pl: float = 0.0
	for s: int in steps:
		var fb: float = bass[s % bass.size()] * (0.75 if (s / 16) % 2 == 1 else 1.0)
		var fl: float = lead[s % lead.size()]
		for i: int in per:
			var env: float = 1.0 - float(i) / float(per) * 0.7
			var v: float = 0.0
			if fb > 0.0:
				pb += fb / RATE
				v += (absf(fmod(pb, 1.0) * 4.0 - 2.0) - 1.0) * 0.5
			if fl > 0.0:
				pl += fl / RATE
				v += (1.0 if fmod(pl, 1.0) < 0.25 else -1.0) * 0.18 * env
			var smp: int = clampi(int(v * 0.6 * 32767.0), -32768, 32767)
			data.append(smp & 0xFF)
			data.append((smp >> 8) & 0xFF)
	var w: AudioStreamWAV = _wav(data)
	w.loop_mode = AudioStreamWAV.LOOP_FORWARD
	w.loop_begin = 0
	w.loop_end = steps * per
	return w


## Sums two mono 16-bit streams (for layered hits).
static func _mix(a: AudioStreamWAV, b: AudioStreamWAV) -> AudioStreamWAV:
	var da: PackedByteArray = a.data
	var db: PackedByteArray = b.data
	var n: int = maxi(da.size(), db.size())
	var out := PackedByteArray()
	out.resize(n)
	for i: int in range(0, n - 1, 2):
		var sa: int = da.decode_s16(i) if i + 1 < da.size() else 0
		var sb: int = db.decode_s16(i) if i + 1 < db.size() else 0
		out.encode_s16(i, clampi(sa + sb, -32768, 32767))
	return _wav(out)
