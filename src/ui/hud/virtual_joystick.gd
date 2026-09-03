class_name VirtualJoystick
extends Control
## Left-thumb movement stick.
##
## Supports both a fixed stick and a dynamic one that springs to wherever the
## thumb first lands inside its region, which is what most players actually
## prefer on a phone. Draws itself so there are no texture assets to ship.

signal value_changed(value: Vector2)

@export var dynamic: bool = true
@export var base_radius: float = 62.0
@export var knob_radius: float = 28.0
@export var dead_zone: float = 0.14

var value: Vector2 = Vector2.ZERO
var _touch_index: int = -1
var _origin: Vector2 = Vector2.ZERO
var _knob: Vector2 = Vector2.ZERO
var _active := false
var _opacity := 0.85


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	set_process_input(true)
	_refresh_settings()
	EventBus.settings_changed.connect(func(section):
		if section == "controls":
			_refresh_settings())


func _refresh_settings() -> void:
	var scale := float(SettingsService.get_value("controls", "joystick_size", 1.0))
	base_radius = 62.0 * scale
	knob_radius = 28.0 * scale
	dynamic = bool(SettingsService.get_value("controls", "dynamic_joystick", true))
	_opacity = float(SettingsService.get_value("controls", "ui_opacity", 0.85))
	custom_minimum_size = Vector2(base_radius * 2.6, base_radius * 2.6)
	if not _active:
		_origin = size * 0.5
		_knob = _origin
	queue_redraw()


func _gui_input(event: InputEvent) -> void:
	if event is InputEventScreenTouch:
		var touch := event as InputEventScreenTouch
		if touch.pressed and _touch_index < 0:
			_touch_index = touch.index
			_active = true
			_origin = touch.position if dynamic else size * 0.5
			_knob = touch.position
			_update_value()
			accept_event()
		elif not touch.pressed and touch.index == _touch_index:
			_release()
			accept_event()
	elif event is InputEventScreenDrag:
		var drag := event as InputEventScreenDrag
		if drag.index == _touch_index:
			_knob = drag.position
			_update_value()
			accept_event()


func _input(event: InputEvent) -> void:
	# A drag that leaves the control still belongs to this stick.
	if _touch_index < 0:
		return
	if event is InputEventScreenDrag and (event as InputEventScreenDrag).index == _touch_index:
		_knob = (event as InputEventScreenDrag).position - global_position
		_update_value()
	elif event is InputEventScreenTouch:
		var t := event as InputEventScreenTouch
		if not t.pressed and t.index == _touch_index:
			_release()


func _release() -> void:
	_touch_index = -1
	_active = false
	value = Vector2.ZERO
	_origin = size * 0.5
	_knob = _origin
	value_changed.emit(value)
	PlayerInput.set_touch_move(Vector2.ZERO)
	queue_redraw()


func _update_value() -> void:
	var offset := _knob - _origin
	var length := offset.length()
	if length > base_radius:
		offset = offset.normalized() * base_radius
		_knob = _origin + offset
	var raw := offset / base_radius
	if raw.length() < dead_zone:
		raw = Vector2.ZERO
	else:
		# Rescale past the dead zone so the first responsive pixel is smooth.
		raw = raw.normalized() * ((raw.length() - dead_zone) / (1.0 - dead_zone))
	# Screen Y is down; forward is up.
	value = Vector2(raw.x, -raw.y)
	value_changed.emit(value)
	PlayerInput.set_touch_move(value)
	queue_redraw()


func _draw() -> void:
	var center := _origin if _active else size * 0.5
	var alpha := _opacity * (1.0 if _active else 0.55)
	draw_circle(center, base_radius, Color(UIKit.BG_PANEL.r, UIKit.BG_PANEL.g,
		UIKit.BG_PANEL.b, 0.35 * alpha))
	draw_arc(center, base_radius, 0.0, TAU, 48,
		Color(UIKit.ACCENT.r, UIKit.ACCENT.g, UIKit.ACCENT.b, 0.5 * alpha), 2.0, true)
	var knob := _knob if _active else center
	draw_circle(knob, knob_radius, Color(UIKit.ACCENT.r, UIKit.ACCENT.g,
		UIKit.ACCENT.b, 0.32 * alpha))
	draw_arc(knob, knob_radius, 0.0, TAU, 32,
		Color(UIKit.TEXT.r, UIKit.TEXT.g, UIKit.TEXT.b, 0.75 * alpha), 2.0, true)
