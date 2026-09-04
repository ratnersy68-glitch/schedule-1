class_name TouchButton
extends Control
## A round, self-drawn action button sized for thumbs.
##
## Held state is exposed so the same widget serves momentary actions (sprint)
## and one-shots (jump). In layout-edit mode it can be dragged and its position
## is persisted per button id.

signal pressed_down()
signal released()

var button_id: String = "action"
## Which vector icon to draw. The engine's built-in font is a Latin subset, so
## symbol characters render as tofu; every icon here is drawn, not typed.
var icon_kind: String = "use"
var caption: String = ""
var tint: Color = UIKit.ACCENT
var radius: float = 34.0
var held: bool = false
var edit_mode: bool = false

var _touch_index := -1
var _pulse := 0.0
var _opacity := 0.85
var _drag_offset := Vector2.ZERO
var _enabled := true


func setup(id: String, kind: String, color: Color, button_caption: String = "",
		button_radius: float = 34.0) -> void:
	button_id = id
	icon_kind = kind
	tint = color
	caption = button_caption
	radius = button_radius
	_apply_scale()


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	_apply_scale()
	set_process(true)
	EventBus.settings_changed.connect(func(section):
		if section == "controls":
			_apply_scale())


func _apply_scale() -> void:
	var s := float(SettingsService.get_value("controls", "button_scale", 1.0))
	_opacity = float(SettingsService.get_value("controls", "ui_opacity", 0.85))
	custom_minimum_size = Vector2(radius * 2.0 * s, radius * 2.0 * s)
	size = custom_minimum_size
	queue_redraw()


func set_enabled(enabled: bool) -> void:
	if _enabled == enabled:
		return
	_enabled = enabled
	queue_redraw()


func is_enabled() -> bool:
	return _enabled


func set_icon(kind: String, new_caption: String = "") -> void:
	icon_kind = kind
	if new_caption != "":
		caption = new_caption
	queue_redraw()


func _process(delta: float) -> void:
	if _pulse > 0.0:
		_pulse = maxf(0.0, _pulse - delta * 3.0)
		queue_redraw()


func _gui_input(event: InputEvent) -> void:
	if edit_mode:
		_handle_edit_input(event)
		return
	if not _enabled:
		return
	if event is InputEventScreenTouch:
		var t := event as InputEventScreenTouch
		if t.pressed and _touch_index < 0:
			_touch_index = t.index
			held = true
			_pulse = 1.0
			pressed_down.emit()
			AudioDirector.play_ui("ui_tap")
			queue_redraw()
			accept_event()
		elif not t.pressed and t.index == _touch_index:
			_touch_index = -1
			held = false
			released.emit()
			queue_redraw()
			accept_event()


func _input(event: InputEvent) -> void:
	if _touch_index < 0 or edit_mode:
		return
	if event is InputEventScreenTouch:
		var t := event as InputEventScreenTouch
		if not t.pressed and t.index == _touch_index:
			_touch_index = -1
			held = false
			released.emit()
			queue_redraw()


func _handle_edit_input(event: InputEvent) -> void:
	if event is InputEventScreenTouch:
		var t := event as InputEventScreenTouch
		if t.pressed:
			_touch_index = t.index
			_drag_offset = t.position
		elif t.index == _touch_index:
			_touch_index = -1
			_persist_position()
	elif event is InputEventScreenDrag and (event as InputEventScreenDrag).index == _touch_index:
		var parent_size := get_parent_area_size()
		var target := global_position + (event as InputEventScreenDrag).position - _drag_offset
		position = Vector2(
			clampf(target.x, 0.0, maxf(0.0, parent_size.x - size.x)),
			clampf(target.y, 0.0, maxf(0.0, parent_size.y - size.y)))
		queue_redraw()


func _persist_position() -> void:
	var parent_size := get_parent_area_size()
	if parent_size.x <= 0.0 or parent_size.y <= 0.0:
		return
	SettingsService.set_layout_for(button_id, Vector2(
		position.x / parent_size.x, position.y / parent_size.y))


func _draw() -> void:
	var center := size * 0.5
	var r := size.x * 0.5
	var alpha := _opacity * (1.0 if _enabled else 0.35)
	var fill := tint.darkened(0.55)
	if held:
		fill = tint.darkened(0.2)
	draw_circle(center, r, Color(fill.r, fill.g, fill.b, 0.55 * alpha))
	draw_arc(center, r - 1.0, 0.0, TAU, 40,
		Color(tint.r, tint.g, tint.b, (0.85 if held else 0.55) * alpha), 2.0, true)
	if _pulse > 0.0:
		draw_arc(center, r + 6.0 * (1.0 - _pulse), 0.0, TAU, 40,
			Color(tint.r, tint.g, tint.b, 0.4 * _pulse), 2.0, true)
	if edit_mode:
		draw_arc(center, r + 4.0, 0.0, TAU, 40, UIKit.WARN, 2.0, true)

	_draw_icon(center, r, Color(UIKit.TEXT.r, UIKit.TEXT.g, UIKit.TEXT.b, alpha))

	var font := ThemeDB.fallback_font
	if caption != "":
		var cap_size := font.get_string_size(caption, HORIZONTAL_ALIGNMENT_CENTER, -1, 12)
		draw_string(font, Vector2(center.x - cap_size.x * 0.5, size.y + 12.0), caption,
			HORIZONTAL_ALIGNMENT_CENTER, -1, 12,
			Color(UIKit.TEXT_DIM.r, UIKit.TEXT_DIM.g, UIKit.TEXT_DIM.b, alpha))


## Simple vector icons. Every shape is built from lines, arcs and polygons so
## nothing depends on a font that may not contain the character.
func _draw_icon(c: Vector2, r: float, col: Color) -> void:
	var w := maxf(2.0, r * 0.11)
	var s := r * 0.46
	match icon_kind:
		"use":
			# A press target: a filled dot inside a ring.
			draw_arc(c, s * 0.95, 0.0, TAU, 28, col, w, true)
			draw_circle(c, s * 0.42, col)
		"run":
			_chevrons(c, s, w, col, Vector2(1, 0), 2)
		"brake":
			# Octagon, read universally as "stop".
			var pts := PackedVector2Array()
			for i in 8:
				var a := TAU * (float(i) + 0.5) / 8.0
				pts.append(c + Vector2(cos(a), sin(a)) * s)
			pts.append(pts[0])
			draw_polyline(pts, col, w, true)
		"crouch":
			_chevrons(c, s, w, col, Vector2(0, 1), 1)
			draw_line(c + Vector2(-s, s * 0.95), c + Vector2(s, s * 0.95), col, w, true)
		"jump":
			_chevrons(c, s, w, col, Vector2(0, -1), 1)
			draw_line(c + Vector2(-s, s * 0.95), c + Vector2(s, s * 0.95), col, w, true)
		"bag":
			var body := Rect2(c + Vector2(-s * 0.9, -s * 0.35), Vector2(s * 1.8, s * 1.3))
			draw_rect(body, col, false, w)
			draw_arc(c + Vector2(0, -s * 0.35), s * 0.5, PI, TAU, 16, col, w, true)
		"phone":
			var frame := Rect2(c + Vector2(-s * 0.62, -s * 1.0), Vector2(s * 1.24, s * 2.0))
			draw_rect(frame, col, false, w)
			draw_line(c + Vector2(-s * 0.2, -s * 0.72), c + Vector2(s * 0.2, -s * 0.72), col, w, true)
			draw_circle(c + Vector2(0, s * 0.72), w * 0.9, col)
		"exit":
			# A door with an arrow leaving it.
			draw_rect(Rect2(c + Vector2(-s, -s), Vector2(s * 0.9, s * 2.0)), col, false, w)
			draw_line(c + Vector2(-s * 0.05, 0), c + Vector2(s * 0.95, 0), col, w, true)
			draw_line(c + Vector2(s * 0.95, 0), c + Vector2(s * 0.4, -s * 0.5), col, w, true)
			draw_line(c + Vector2(s * 0.95, 0), c + Vector2(s * 0.4, s * 0.5), col, w, true)
		_:
			draw_circle(c, s * 0.5, col)


## `count` chevrons pointing along `dir`.
func _chevrons(c: Vector2, s: float, w: float, col: Color, dir: Vector2, count: int) -> void:
	var perp := Vector2(-dir.y, dir.x)
	for i in count:
		var offset := dir * (s * (-0.35 + float(i) * 0.72))
		var tip := c + offset + dir * s * 0.55
		draw_line(tip, c + offset - dir * s * 0.15 + perp * s * 0.7, col, w, true)
		draw_line(tip, c + offset - dir * s * 0.15 - perp * s * 0.7, col, w, true)
