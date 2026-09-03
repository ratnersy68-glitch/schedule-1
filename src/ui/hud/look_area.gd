class_name LookArea
extends Control
## The right-hand region that turns a thumb drag into camera movement.
##
## Also detects a quick tap with no drag, which acts as "interact" - a small
## affordance that saves reaching for the button when something is already
## centred on screen.

signal tapped()

const TAP_TIME := 0.22
const TAP_SLOP := 14.0

var _touch_index := -1
var _last_pos := Vector2.ZERO
var _down_pos := Vector2.ZERO
var _down_time := 0.0
var _moved := 0.0


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP


func _gui_input(event: InputEvent) -> void:
	if event is InputEventScreenTouch:
		var t := event as InputEventScreenTouch
		if t.pressed and _touch_index < 0:
			_touch_index = t.index
			_last_pos = t.position
			_down_pos = t.position
			_down_time = Time.get_ticks_msec() / 1000.0
			_moved = 0.0
			accept_event()
		elif not t.pressed and t.index == _touch_index:
			var held := Time.get_ticks_msec() / 1000.0 - _down_time
			if held < TAP_TIME and _moved < TAP_SLOP:
				tapped.emit()
				PlayerInput.press("interact")
			_touch_index = -1
			accept_event()
	elif event is InputEventScreenDrag:
		var d := event as InputEventScreenDrag
		if d.index == _touch_index:
			var delta := d.position - _last_pos
			_last_pos = d.position
			_moved += delta.length()
			PlayerInput.add_touch_look(delta)
			accept_event()


func _input(event: InputEvent) -> void:
	if _touch_index < 0:
		return
	if event is InputEventScreenTouch:
		var t := event as InputEventScreenTouch
		if not t.pressed and t.index == _touch_index:
			_touch_index = -1
