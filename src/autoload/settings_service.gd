extends Node
## Persisted player settings: controls, graphics, audio, gameplay.
##
## Stored in user://settings.cfg with ConfigFile so a corrupt or partial file
## degrades to defaults rather than crashing. Every setter emits
## EventBus.settings_changed so live UI and the renderer can react immediately.

const PATH := "user://settings.cfg"

const QUALITY_LOW := 0
const QUALITY_MEDIUM := 1
const QUALITY_HIGH := 2

const DEFAULTS := {
	"controls": {
		"look_sensitivity": 1.0,        # 0.2 .. 3.0
		"look_sensitivity_vehicle": 0.8,
		"invert_y": false,
		"joystick_size": 1.0,           # 0.7 .. 1.4
		"button_scale": 1.0,            # 0.7 .. 1.5
		"ui_opacity": 0.85,
		"left_handed": false,           # mirrors the whole touch layout
		"dynamic_joystick": true,       # joystick springs to first touch
		"auto_sprint": false,
		"toggle_crouch": true,
		"gyro_aim": false,
		"vibration": true,
		"gamepad_enabled": true,
		"gamepad_deadzone": 0.18,
		"layout": {},                   # button_id -> {"x": float, "y": float} normalised
	},
	"graphics": {
		"quality": QUALITY_MEDIUM,
		"render_scale": 0.85,
		"shadows": true,
		"weather_effects": true,
		"fps_cap": 60,
		"show_fps": false,
		"bloom": true,
		"view_distance": 1.0,           # multiplier on LOD / cull radii
	},
	"audio": {
		"master": 0.9,
		"music": 0.55,
		"sfx": 0.9,
		"ambience": 0.7,
		"ui": 0.7,
	},
	"gameplay": {
		"autosave_minutes": 3.0,
		"show_hints": true,
		"minimap": true,
		"damage_numbers": true,
		"objective_marker": true,
		"language": "en",
	},
}

var _data: Dictionary = {}


func _ready() -> void:
	_data = _deep_copy(DEFAULTS)
	load_settings()
	_apply_graphics()
	_apply_audio()


# --- Public API ------------------------------------------------------------

func get_value(section: String, key: String, fallback: Variant = null) -> Variant:
	if _data.has(section) and _data[section].has(key):
		return _data[section][key]
	if DEFAULTS.has(section) and DEFAULTS[section].has(key):
		return DEFAULTS[section][key]
	return fallback


func set_value(section: String, key: String, value: Variant, save_now: bool = true) -> void:
	if not _data.has(section):
		_data[section] = {}
	if _data[section].get(key) == value:
		return
	_data[section][key] = value
	if section == "graphics":
		_apply_graphics()
	elif section == "audio":
		_apply_audio()
	EventBus.settings_changed.emit(section)
	if save_now:
		save_settings()


func section(name: String) -> Dictionary:
	return _data.get(name, {})


func reset_section(name: String) -> void:
	if DEFAULTS.has(name):
		_data[name] = _deep_copy(DEFAULTS[name])
		if name == "graphics":
			_apply_graphics()
		elif name == "audio":
			_apply_audio()
		EventBus.settings_changed.emit(name)
		save_settings()


func reset_all() -> void:
	_data = _deep_copy(DEFAULTS)
	_apply_graphics()
	_apply_audio()
	for s in DEFAULTS:
		EventBus.settings_changed.emit(s)
	save_settings()


## Custom touch button placement. Returns null when the button uses its
## default anchor.
func layout_for(button_id: String) -> Variant:
	var layout: Dictionary = get_value("controls", "layout", {})
	return layout.get(button_id, null)


func set_layout_for(button_id: String, normalised: Vector2) -> void:
	var layout: Dictionary = (get_value("controls", "layout", {}) as Dictionary).duplicate()
	layout[button_id] = {"x": normalised.x, "y": normalised.y}
	set_value("controls", "layout", layout)


func clear_layout() -> void:
	set_value("controls", "layout", {})


# --- Persistence -----------------------------------------------------------

func save_settings() -> void:
	var cfg := ConfigFile.new()
	for sec in _data:
		for key in _data[sec]:
			cfg.set_value(sec, key, _data[sec][key])
	var err := cfg.save(PATH)
	if err != OK:
		push_warning("Could not save settings (%d)" % err)


func load_settings() -> void:
	var cfg := ConfigFile.new()
	var err := cfg.load(PATH)
	if err != OK:
		return  # first run, or unreadable: defaults already in place
	for sec in cfg.get_sections():
		if not _data.has(sec):
			continue
		for key in cfg.get_section_keys(sec):
			# Only accept keys we know about so old files cannot inject junk.
			if DEFAULTS.get(sec, {}).has(key):
				_data[sec][key] = cfg.get_value(sec, key)


# --- Application -----------------------------------------------------------

func _apply_graphics() -> void:
	var g: Dictionary = _data.get("graphics", {})
	var cap := int(g.get("fps_cap", 60))
	Engine.max_fps = cap if cap > 0 else 0

	var vp := get_viewport()
	if vp is Window:
		var scale := clampf(float(g.get("render_scale", 0.85)), 0.5, 1.0)
		vp.scaling_3d_scale = scale
		vp.msaa_3d = Viewport.MSAA_2X if int(g.get("quality", 1)) >= QUALITY_HIGH else Viewport.MSAA_DISABLED

	var quality := int(g.get("quality", QUALITY_MEDIUM))
	var shadow_size := 1024
	match quality:
		QUALITY_LOW:
			shadow_size = 512
		QUALITY_MEDIUM:
			shadow_size = 1536
		_:
			shadow_size = 2560
	if not bool(g.get("shadows", true)):
		shadow_size = 256
	RenderingServer.directional_shadow_atlas_set_size(shadow_size, true)


func _apply_audio() -> void:
	var a: Dictionary = _data.get("audio", {})
	_set_bus("Master", float(a.get("master", 0.9)))
	_set_bus("Music", float(a.get("music", 0.55)))
	_set_bus("SFX", float(a.get("sfx", 0.9)))
	_set_bus("Ambience", float(a.get("ambience", 0.7)))
	_set_bus("UI", float(a.get("ui", 0.7)))


func _set_bus(bus_name: String, linear: float) -> void:
	var idx := AudioServer.get_bus_index(bus_name)
	if idx < 0:
		return
	AudioServer.set_bus_volume_db(idx, linear_to_db(clampf(linear, 0.0, 1.0)))
	AudioServer.set_bus_mute(idx, linear <= 0.001)


func _deep_copy(d: Dictionary) -> Dictionary:
	var out := {}
	for k in d:
		var v = d[k]
		if v is Dictionary:
			out[k] = _deep_copy(v)
		elif v is Array:
			out[k] = (v as Array).duplicate(true)
		else:
			out[k] = v
	return out
