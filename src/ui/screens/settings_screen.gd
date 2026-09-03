class_name SettingsScreen
extends GameScreen
## Controls, graphics, audio and gameplay options.
##
## Control options come first because on a phone they are the ones that decide
## whether the game is playable at all.

var _tab: String = "controls"


func build_content() -> void:
	set_titles("Settings", "")
	refresh()


func refresh() -> void:
	if content == null:
		return
	clear_content()

	var tabs := UIKit.hbox(6)
	for t in ["controls", "graphics", "audio", "gameplay"]:
		var b := UIKit.button(t.capitalize(), "primary" if t == _tab else "default")
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		b.add_theme_font_size_override("font_size", 14)
		b.pressed.connect(func():
			_tab = t
			refresh())
		tabs.add_child(b)
	content.add_child(tabs)

	match _tab:
		"controls":
			_build_controls()
		"graphics":
			_build_graphics()
		"audio":
			_build_audio()
		_:
			_build_gameplay()

	content.add_child(UIKit.spacer(10))
	var reset := UIKit.button("Reset this section", "bad")
	reset.pressed.connect(func():
		SettingsService.reset_section(_tab)
		refresh())
	content.add_child(reset)


# --- Builders --------------------------------------------------------------

func _build_controls() -> void:
	section("Aiming")
	_slider("Look sensitivity", "controls", "look_sensitivity", 0.2, 3.0, 0.05)
	_slider("Look sensitivity (driving)", "controls", "look_sensitivity_vehicle", 0.2, 2.0, 0.05)
	_toggle("Invert vertical look", "controls", "invert_y")

	section("Touch layout")
	_slider("Stick size", "controls", "joystick_size", 0.7, 1.4, 0.05)
	_slider("Button size", "controls", "button_scale", 0.7, 1.5, 0.05)
	_slider("Control opacity", "controls", "ui_opacity", 0.3, 1.0, 0.05)
	_toggle("Left-handed layout", "controls", "left_handed")
	_toggle("Stick follows my thumb", "controls", "dynamic_joystick")

	var edit := UIKit.button("Move the buttons around", "primary")
	edit.pressed.connect(func():
		var hud := get_tree().get_first_node_in_group("touch_controls")
		if hud != null:
			hud.set_edit_mode(true)
		close())
	content.add_child(edit)

	section("Behaviour")
	_toggle("Crouch is a toggle", "controls", "toggle_crouch")
	_toggle("Sprint automatically at full stick", "controls", "auto_sprint")
	_toggle("Vibration", "controls", "vibration")

	section("Controller")
	_toggle("Enable gamepad", "controls", "gamepad_enabled")
	_slider("Stick dead zone", "controls", "gamepad_deadzone", 0.05, 0.4, 0.01)
	content.add_child(UIKit.body(
		"A connected controller works everywhere: left stick moves, right stick looks, " +
		"A jumps, X interacts, triggers sprint and crouch."))


func _build_graphics() -> void:
	section("Quality")
	var quality := int(SettingsService.get_value("graphics", "quality", 1))
	var row := UIKit.hbox(6)
	for i in 3:
		var names := ["Low", "Medium", "High"]
		var b := UIKit.button(names[i], "primary" if quality == i else "default")
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		b.pressed.connect(func():
			SettingsService.set_value("graphics", "quality", i)
			_apply_quality_preset(i)
			refresh())
		row.add_child(b)
	content.add_child(row)

	_slider("Render scale", "graphics", "render_scale", 0.5, 1.0, 0.05)
	_slider("View distance", "graphics", "view_distance", 0.5, 1.5, 0.05)
	_toggle("Shadows", "graphics", "shadows")
	_toggle("Bloom", "graphics", "bloom")
	_toggle("Weather effects", "graphics", "weather_effects")
	_toggle("Show frame rate", "graphics", "show_fps")

	section("Frame rate")
	var cap := int(SettingsService.get_value("graphics", "fps_cap", 60))
	var caps := UIKit.hbox(6)
	for value in [30, 60, 0]:
		var b := UIKit.button("Unlimited" if value == 0 else "%d fps" % value,
			"primary" if cap == value else "default")
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		b.pressed.connect(func():
			SettingsService.set_value("graphics", "fps_cap", value)
			refresh())
		caps.add_child(b)
	content.add_child(caps)
	content.add_child(UIKit.body(
		"On older phones, 30 fps with a 0.7 render scale is far smoother than a " +
		"stuttering 60. Battery lasts longer too."))


func _apply_quality_preset(quality: int) -> void:
	match quality:
		0:
			SettingsService.set_value("graphics", "render_scale", 0.65)
			SettingsService.set_value("graphics", "shadows", false)
			SettingsService.set_value("graphics", "bloom", false)
			SettingsService.set_value("graphics", "weather_effects", false)
			SettingsService.set_value("graphics", "view_distance", 0.7)
			SettingsService.set_value("graphics", "fps_cap", 30)
		1:
			SettingsService.set_value("graphics", "render_scale", 0.85)
			SettingsService.set_value("graphics", "shadows", true)
			SettingsService.set_value("graphics", "bloom", true)
			SettingsService.set_value("graphics", "weather_effects", true)
			SettingsService.set_value("graphics", "view_distance", 1.0)
			SettingsService.set_value("graphics", "fps_cap", 60)
		_:
			SettingsService.set_value("graphics", "render_scale", 1.0)
			SettingsService.set_value("graphics", "shadows", true)
			SettingsService.set_value("graphics", "bloom", true)
			SettingsService.set_value("graphics", "weather_effects", true)
			SettingsService.set_value("graphics", "view_distance", 1.3)
			SettingsService.set_value("graphics", "fps_cap", 60)


func _build_audio() -> void:
	_slider("Master", "audio", "master", 0.0, 1.0, 0.05)
	_slider("Music", "audio", "music", 0.0, 1.0, 0.05)
	_slider("Effects", "audio", "sfx", 0.0, 1.0, 0.05)
	_slider("Ambience", "audio", "ambience", 0.0, 1.0, 0.05)
	_slider("Interface", "audio", "ui", 0.0, 1.0, 0.05)


func _build_gameplay() -> void:
	_slider("Autosave every (minutes)", "gameplay", "autosave_minutes", 0.0, 15.0, 0.5)
	_toggle("Show minimap", "gameplay", "minimap")
	_toggle("Show objective marker", "gameplay", "objective_marker")
	_toggle("Show hints", "gameplay", "show_hints")
	content.add_child(UIKit.body("Set autosave to 0 to turn it off entirely."))


# --- Widgets ---------------------------------------------------------------

func _slider(label_text: String, sect: String, key: String,
		min_v: float, max_v: float, step: float) -> void:
	var value := float(SettingsService.get_value(sect, key, min_v))
	var box := UIKit.vbox(2)
	var head := UIKit.hbox(8)
	var l := UIKit.label(label_text, 14, UIKit.TEXT)
	l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(l)
	var value_label := UIKit.label(_format_value(value), 14, UIKit.ACCENT)
	head.add_child(value_label)
	box.add_child(head)
	var s := UIKit.slider(min_v, max_v, step, value)
	s.value_changed.connect(func(v):
		value_label.text = _format_value(v)
		SettingsService.set_value(sect, key, v))
	box.add_child(s)
	content.add_child(box)


func _format_value(v: float) -> String:
	if absf(v - roundf(v)) < 0.001:
		return "%d" % int(v)
	return "%.2f" % v


func _toggle(label_text: String, sect: String, key: String) -> void:
	var t := UIKit.toggle(label_text, bool(SettingsService.get_value(sect, key, false)))
	t.toggled.connect(func(pressed): SettingsService.set_value(sect, key, pressed))
	content.add_child(t)
