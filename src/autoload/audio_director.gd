extends Node
## Procedural audio.
##
## The project ships no binary audio assets, so every sound is synthesised into
## an AudioStreamWAV at boot: short one-shots for feedback, looping beds for
## ambience and engines, and slow evolving pads for music. This keeps the
## repository free of licensing baggage and the APK small, and it means the
## soundscape can react to state (weather, tension) by re-mixing layers rather
## than streaming files.

const SAMPLE_RATE := 22050
const SFX_VOICES := 12
const SFX3D_VOICES := 10

var _sfx: Dictionary = {}              ## id -> AudioStreamWAV
var _pool2d: Array[AudioStreamPlayer] = []
var _pool3d: Array[AudioStreamPlayer3D] = []
var _ambience: AudioStreamPlayer = null
var _weather_layer: AudioStreamPlayer = null
var _music_a: AudioStreamPlayer = null
var _music_b: AudioStreamPlayer = null
var _music_active_is_a := true
var _current_music := ""
var _tension := 0.0
var _rng := RandomNumberGenerator.new()


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_rng.seed = 20260903
	_ensure_buses()
	_build_library()
	_build_players()
	EventBus.weather_changed.connect(_on_weather_changed)
	EventBus.wanted_level_changed.connect(_on_wanted_changed)
	EventBus.player_entered_district.connect(func(_d): _refresh_ambience())
	EventBus.cash_changed.connect(func(_c, delta):
		if delta > 0:
			play("cash"))


# ===========================================================================
# BUSES
# ===========================================================================

func _ensure_buses() -> void:
	for bus_name in ["Music", "SFX", "Ambience", "UI"]:
		if AudioServer.get_bus_index(bus_name) >= 0:
			continue
		var idx := AudioServer.bus_count
		AudioServer.add_bus(idx)
		AudioServer.set_bus_name(idx, bus_name)
		AudioServer.set_bus_send(idx, "Master")


# ===========================================================================
# SYNTHESIS
# ===========================================================================

## Packs a float buffer (-1..1) into a 16-bit mono AudioStreamWAV.
func _make_stream(samples: PackedFloat32Array, loop: bool = false) -> AudioStreamWAV:
	var bytes := PackedByteArray()
	bytes.resize(samples.size() * 2)
	for i in samples.size():
		var v := int(clampf(samples[i], -1.0, 1.0) * 32767.0)
		bytes.encode_s16(i * 2, v)
	var s := AudioStreamWAV.new()
	s.format = AudioStreamWAV.FORMAT_16_BITS
	s.mix_rate = SAMPLE_RATE
	s.stereo = false
	s.data = bytes
	if loop:
		s.loop_mode = AudioStreamWAV.LOOP_FORWARD
		s.loop_begin = 0
		s.loop_end = samples.size()
	return s


func _buffer(seconds: float) -> PackedFloat32Array:
	var b := PackedFloat32Array()
	b.resize(int(seconds * SAMPLE_RATE))
	b.fill(0.0)
	return b


## Simple one-pole low-pass, used to turn white noise into wind, rain or thud.
func _lowpass(buf: PackedFloat32Array, cutoff: float) -> PackedFloat32Array:
	var a := clampf(cutoff, 0.001, 0.999)
	var prev := 0.0
	for i in buf.size():
		prev = prev + a * (buf[i] - prev)
		buf[i] = prev
	return buf


func _highpass(buf: PackedFloat32Array, cutoff: float) -> PackedFloat32Array:
	var a := clampf(cutoff, 0.001, 0.999)
	var prev_in := 0.0
	var prev_out := 0.0
	for i in buf.size():
		var x := buf[i]
		prev_out = a * (prev_out + x - prev_in)
		prev_in = x
		buf[i] = prev_out
	return buf


func _noise(seconds: float, amp: float = 1.0) -> PackedFloat32Array:
	var b := _buffer(seconds)
	for i in b.size():
		b[i] = _rng.randf_range(-amp, amp)
	return b


## Adds a tone with an exponential decay envelope.
func _tone(buf: PackedFloat32Array, freq: float, amp: float, decay: float,
		start: float = 0.0, freq_end: float = -1.0, wave: String = "sine") -> void:
	var start_i := int(start * SAMPLE_RATE)
	var phase := 0.0
	var n := buf.size()
	for i in range(start_i, n):
		var t := float(i - start_i) / SAMPLE_RATE
		var env: float = exp(-t * decay)
		if env < 0.0005:
			break
		var f := freq
		if freq_end > 0.0:
			var total := float(n - start_i) / SAMPLE_RATE
			f = lerpf(freq, freq_end, clampf(t / maxf(total, 0.0001), 0.0, 1.0))
		phase += TAU * f / SAMPLE_RATE
		var v := 0.0
		match wave:
			"square":
				v = 1.0 if sin(phase) >= 0.0 else -1.0
			"saw":
				v = fmod(phase, TAU) / PI - 1.0
			"tri":
				v = asin(sin(phase)) * (2.0 / PI)
			_:
				v = sin(phase)
		buf[i] = clampf(buf[i] + v * amp * env, -1.0, 1.0)


func _apply_fade(buf: PackedFloat32Array, fade_seconds: float) -> void:
	var n := mini(int(fade_seconds * SAMPLE_RATE), buf.size() / 2)
	for i in n:
		var g := float(i) / float(n)
		buf[i] *= g
		buf[buf.size() - 1 - i] *= g


func _build_library() -> void:
	# --- Footsteps -------------------------------------------------------
	for variant in 3:
		var b := _noise(0.14, 0.55)
		_lowpass(b, 0.09 + variant * 0.02)
		for i in b.size():
			b[i] *= exp(-float(i) / SAMPLE_RATE * 34.0)
		_tone(b, 90.0 + variant * 12.0, 0.22, 40.0)
		_sfx["step_%d" % variant] = _make_stream(b)
	var metal := _noise(0.16, 0.5)
	_highpass(metal, 0.5)
	for i in metal.size():
		metal[i] *= exp(-float(i) / SAMPLE_RATE * 22.0)
	_tone(metal, 420.0, 0.16, 26.0)
	_sfx["step_metal"] = _make_stream(metal)

	var land := _noise(0.25, 0.7)
	_lowpass(land, 0.06)
	for i in land.size():
		land[i] *= exp(-float(i) / SAMPLE_RATE * 16.0)
	_tone(land, 62.0, 0.4, 14.0)
	_sfx["land"] = _make_stream(land)

	# --- UI ---------------------------------------------------------------
	var tap := _buffer(0.09)
	_tone(tap, 1180.0, 0.30, 55.0)
	_tone(tap, 1760.0, 0.12, 70.0)
	_sfx["ui_tap"] = _make_stream(tap)

	var confirm := _buffer(0.34)
	_tone(confirm, 660.0, 0.26, 12.0)
	_tone(confirm, 990.0, 0.20, 10.0, 0.07)
	_tone(confirm, 1320.0, 0.14, 9.0, 0.14)
	_sfx["ui_confirm"] = _make_stream(confirm)

	var cancel := _buffer(0.26)
	_tone(cancel, 420.0, 0.26, 14.0)
	_tone(cancel, 280.0, 0.22, 13.0, 0.08)
	_sfx["ui_cancel"] = _make_stream(cancel)

	var err := _buffer(0.3)
	_tone(err, 200.0, 0.3, 9.0, 0.0, 140.0, "square")
	_sfx["ui_error"] = _make_stream(err)

	var cash := _buffer(0.5)
	_tone(cash, 1320.0, 0.2, 13.0)
	_tone(cash, 1760.0, 0.16, 11.0, 0.05)
	_tone(cash, 2640.0, 0.10, 15.0, 0.11)
	_sfx["cash"] = _make_stream(cash)

	var notify := _buffer(0.45)
	_tone(notify, 880.0, 0.2, 11.0)
	_tone(notify, 1174.0, 0.18, 10.0, 0.1)
	_sfx["notify"] = _make_stream(notify)

	var levelup := _buffer(0.9)
	for i in 4:
		_tone(levelup, 523.0 * pow(1.2599, i), 0.2, 6.0, i * 0.11)
	_sfx["levelup"] = _make_stream(levelup)

	# --- World ------------------------------------------------------------
	var door := _buffer(0.7)
	_tone(door, 150.0, 0.2, 6.0, 0.0, 90.0, "saw")
	var creak := _noise(0.7, 0.18)
	_highpass(creak, 0.35)
	for i in creak.size():
		door[i] = clampf(door[i] + creak[i] * exp(-float(i) / SAMPLE_RATE * 4.0), -1.0, 1.0)
	_sfx["door"] = _make_stream(door)

	var pickup := _buffer(0.22)
	_tone(pickup, 700.0, 0.24, 22.0, 0.0, 1500.0)
	_sfx["pickup"] = _make_stream(pickup)

	var craft_start := _buffer(0.6)
	_tone(craft_start, 110.0, 0.22, 4.0, 0.0, 220.0, "saw")
	_tone(craft_start, 330.0, 0.1, 6.0, 0.1)
	_sfx["craft_start"] = _make_stream(craft_start)

	var craft_done := _buffer(1.1)
	_tone(craft_done, 392.0, 0.2, 4.5)
	_tone(craft_done, 587.0, 0.18, 4.0, 0.13)
	_tone(craft_done, 784.0, 0.16, 3.6, 0.26)
	_tone(craft_done, 1175.0, 0.10, 3.2, 0.39)
	_sfx["craft_done"] = _make_stream(craft_done)

	var alert := _buffer(1.0)
	_tone(alert, 700.0, 0.24, 2.0, 0.0, 900.0)
	_tone(alert, 900.0, 0.24, 2.0, 0.5, 700.0)
	_sfx["alert"] = _make_stream(alert)

	var siren := _buffer(2.0)
	for k in 4:
		_tone(siren, 640.0, 0.18, 1.2, k * 0.5, 980.0)
	_sfx["siren"] = _make_stream(siren)

	var bust := _buffer(1.4)
	_tone(bust, 180.0, 0.3, 2.2, 0.0, 70.0, "square")
	_tone(bust, 90.0, 0.25, 1.8, 0.3)
	_sfx["bust"] = _make_stream(bust)

	# --- Loops ------------------------------------------------------------
	_sfx["amb_city"] = _make_stream(_build_city_bed(), true)
	_sfx["amb_industry"] = _make_stream(_build_industry_bed(), true)
	_sfx["amb_quiet"] = _make_stream(_build_quiet_bed(), true)
	_sfx["rain"] = _make_stream(_build_rain(), true)
	_sfx["wind"] = _make_stream(_build_wind(), true)
	_sfx["engine"] = _make_stream(_build_engine(), true)
	_sfx["station_hum"] = _make_stream(_build_hum(), true)

	# --- Music ------------------------------------------------------------
	_sfx["music_calm"] = _make_stream(_build_pad([55.0, 82.5, 110.0, 164.7], 0.0), true)
	_sfx["music_work"] = _make_stream(_build_pad([61.7, 92.5, 123.5, 185.0], 0.35), true)
	_sfx["music_tense"] = _make_stream(_build_pad([49.0, 73.4, 98.0, 138.6], 0.8), true)


func _build_city_bed() -> PackedFloat32Array:
	var b := _noise(4.0, 0.22)
	_lowpass(b, 0.02)
	# Distant traffic swells.
	for i in b.size():
		var t := float(i) / SAMPLE_RATE
		b[i] *= 0.7 + 0.3 * sin(t * 0.9) * sin(t * 0.31)
	_tone(b, 46.0, 0.05, 0.0)
	_apply_fade(b, 0.4)
	return b


func _build_industry_bed() -> PackedFloat32Array:
	var b := _noise(4.0, 0.18)
	_lowpass(b, 0.05)
	for i in b.size():
		var t := float(i) / SAMPLE_RATE
		b[i] += 0.06 * sin(TAU * 72.0 * t) * (0.6 + 0.4 * sin(t * 1.7))
		b[i] += 0.03 * sin(TAU * 143.0 * t)
	_apply_fade(b, 0.4)
	return b


func _build_quiet_bed() -> PackedFloat32Array:
	var b := _noise(4.0, 0.12)
	_lowpass(b, 0.012)
	for i in b.size():
		var t := float(i) / SAMPLE_RATE
		b[i] *= 0.6 + 0.4 * sin(t * 0.37)
	_apply_fade(b, 0.4)
	return b


func _build_rain() -> PackedFloat32Array:
	var b := _noise(3.0, 0.4)
	_highpass(b, 0.55)
	_lowpass(b, 0.65)
	for i in b.size():
		var t := float(i) / SAMPLE_RATE
		b[i] *= 0.75 + 0.25 * sin(t * 2.3)
	_apply_fade(b, 0.3)
	return b


func _build_wind() -> PackedFloat32Array:
	var b := _noise(4.0, 0.35)
	_lowpass(b, 0.008)
	for i in b.size():
		var t := float(i) / SAMPLE_RATE
		b[i] *= 0.5 + 0.5 * sin(t * 0.6 + sin(t * 0.17) * 2.0)
	_apply_fade(b, 0.5)
	return b


func _build_engine() -> PackedFloat32Array:
	var b := _buffer(1.0)
	for i in b.size():
		var t := float(i) / SAMPLE_RATE
		var v := 0.0
		v += 0.22 * sin(TAU * 58.0 * t)
		v += 0.14 * sin(TAU * 116.0 * t + 0.4)
		v += 0.07 * sin(TAU * 174.0 * t)
		v += _rng.randf_range(-0.05, 0.05)
		b[i] = v
	_lowpass(b, 0.25)
	_apply_fade(b, 0.02)
	return b


func _build_hum() -> PackedFloat32Array:
	var b := _buffer(2.0)
	for i in b.size():
		var t := float(i) / SAMPLE_RATE
		b[i] = 0.10 * sin(TAU * 120.0 * t) + 0.05 * sin(TAU * 241.0 * t) \
			+ 0.03 * sin(TAU * 61.0 * t) + _rng.randf_range(-0.012, 0.012)
	_apply_fade(b, 0.05)
	return b


## Slow four-note pad. `grit` adds a detuned saw layer for tension.
func _build_pad(freqs: Array, grit: float) -> PackedFloat32Array:
	var seconds := 12.0
	var b := _buffer(seconds)
	var n := b.size()
	for i in n:
		var t := float(i) / SAMPLE_RATE
		var v := 0.0
		for k in freqs.size():
			var f := float(freqs[k])
			var swell := 0.5 + 0.5 * sin(TAU * (t / seconds) * (1.0 + k * 0.5) - k)
			v += 0.075 * swell * sin(TAU * f * t)
			v += 0.045 * swell * sin(TAU * f * 2.0 * t + 0.7)
			if grit > 0.0:
				var saw := fmod(t * f * 1.005, 1.0) * 2.0 - 1.0
				v += 0.03 * grit * swell * saw
		b[i] = v * 0.8
	_lowpass(b, 0.35)
	_apply_fade(b, 1.5)
	return b


# ===========================================================================
# PLAYBACK
# ===========================================================================

func _build_players() -> void:
	for i in SFX_VOICES:
		var p := AudioStreamPlayer.new()
		p.bus = "SFX"
		p.process_mode = Node.PROCESS_MODE_ALWAYS
		add_child(p)
		_pool2d.append(p)
	for i in SFX3D_VOICES:
		var p3 := AudioStreamPlayer3D.new()
		p3.bus = "SFX"
		p3.unit_size = 6.0
		p3.max_distance = 45.0
		p3.attenuation_model = AudioStreamPlayer3D.ATTENUATION_INVERSE_DISTANCE
		add_child(p3)
		_pool3d.append(p3)

	_ambience = _make_looper("Ambience", -8.0)
	_weather_layer = _make_looper("Ambience", -60.0)
	_music_a = _make_looper("Music", -60.0)
	_music_b = _make_looper("Music", -60.0)


func _make_looper(bus: String, db: float) -> AudioStreamPlayer:
	var p := AudioStreamPlayer.new()
	p.bus = bus
	p.volume_db = db
	p.process_mode = Node.PROCESS_MODE_ALWAYS
	add_child(p)
	return p


## Fire a UI or world one-shot. `bus_override` lets UI sounds sit on their bus.
func play(id: String, volume_db: float = 0.0, pitch: float = 1.0,
		bus_override: String = "") -> void:
	var stream: AudioStreamWAV = _sfx.get(id)
	if stream == null:
		return
	for p in _pool2d:
		if p.playing:
			continue
		p.stream = stream
		p.volume_db = volume_db
		p.pitch_scale = pitch
		p.bus = bus_override if bus_override != "" else "SFX"
		p.play()
		return


func play_ui(id: String) -> void:
	play(id, -3.0, 1.0, "UI")


func play_at(id: String, pos: Vector3, volume_db: float = 0.0, pitch: float = 1.0) -> void:
	var stream: AudioStreamWAV = _sfx.get(id)
	if stream == null:
		return
	for p in _pool3d:
		if p.playing:
			continue
		p.global_position = pos
		p.stream = stream
		p.volume_db = volume_db
		p.pitch_scale = pitch
		p.play()
		return


func stream_for(id: String) -> AudioStreamWAV:
	return _sfx.get(id)


func footstep(surface: String, pos: Vector3, running: bool) -> void:
	var id := "step_metal" if surface == "metal" else "step_%d" % (randi() % 3)
	play_at(id, pos, -6.0 if not running else -3.0, randf_range(0.92, 1.1))


# ===========================================================================
# AMBIENCE AND MUSIC MIX
# ===========================================================================

func start_world_audio() -> void:
	_refresh_ambience()
	_on_weather_changed(GameState.weather)
	set_music("music_calm")


func stop_world_audio() -> void:
	_ambience.stop()
	_weather_layer.stop()
	_music_a.stop()
	_music_b.stop()
	_current_music = ""


func _refresh_ambience() -> void:
	var style := String(GameData.district(GameState.current_district).get("style", "downtown"))
	var bed := "amb_city"
	match style:
		"industrial", "industrial_port":
			bed = "amb_industry"
		"suburb":
			bed = "amb_quiet"
		_:
			bed = "amb_city"
	if _ambience.stream == _sfx.get(bed) and _ambience.playing:
		return
	_ambience.stream = _sfx.get(bed)
	_ambience.volume_db = -10.0
	_ambience.play()


func _on_weather_changed(weather_id: String) -> void:
	var target := ""
	var db := -60.0
	match weather_id:
		"rain":
			target = "rain"
			db = -12.0
		"storm":
			target = "rain"
			db = -7.0
		"fog", "overcast":
			target = "wind"
			db = -18.0
		_:
			target = "wind"
			db = -30.0
	if target != "" and _weather_layer.stream != _sfx.get(target):
		_weather_layer.stream = _sfx.get(target)
		_weather_layer.play()
	create_tween().tween_property(_weather_layer, "volume_db", db, 2.5)


func _on_wanted_changed(level: int) -> void:
	_tension = clampf(float(level) / 4.0, 0.0, 1.0)
	if level >= 2:
		set_music("music_tense")
		play("siren", -8.0)
	elif level >= 1:
		set_music("music_work")
	else:
		set_music("music_calm")


## Crossfades between the two music voices so layers never click.
func set_music(id: String, fade: float = 3.0) -> void:
	if id == _current_music:
		return
	var stream: AudioStreamWAV = _sfx.get(id)
	if stream == null:
		return
	_current_music = id
	var incoming := _music_b if _music_active_is_a else _music_a
	var outgoing := _music_a if _music_active_is_a else _music_b
	_music_active_is_a = not _music_active_is_a

	incoming.stream = stream
	incoming.volume_db = -60.0
	incoming.play()
	create_tween().tween_property(incoming, "volume_db", -14.0, fade)
	var t := create_tween()
	t.tween_property(outgoing, "volume_db", -60.0, fade)
	t.tween_callback(outgoing.stop)
