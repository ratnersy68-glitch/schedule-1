extends Node
## Unified input layer: touch, keyboard and gamepad all write here.
##
## The player controller never reads raw input devices. The on-screen touch
## controls push their values in, physical devices are polled, and both are
## merged into the same fields. That makes the whole control scheme
## remappable, testable, and identical for the player and vehicles.

# --- Merged output ---------------------------------------------------------
var move: Vector2 = Vector2.ZERO          ## x = strafe, y = forward (+1 forward)
var look: Vector2 = Vector2.ZERO          ## consumed each frame, in radians
var sprint_held: bool = false
var crouch_held: bool = false

# --- Touch contributions (written by the HUD) ------------------------------
var touch_move: Vector2 = Vector2.ZERO
var touch_look: Vector2 = Vector2.ZERO    ## raw pixels since last frame
var touch_sprint: bool = false
var touch_crouch: bool = false

# --- Vehicle ---------------------------------------------------------------
## While driving, the same movement input becomes throttle and steering, so
## touch, keyboard and gamepad all control a car without a second code path.
var vehicle_mode: bool = false
var throttle: float = 0.0
var steer: float = 0.0
var handbrake: bool = false

# --- Gating ----------------------------------------------------------------
## When false the player ignores movement and looking: a menu, the phone or a
## dialogue is open. Buttons already pressed are released cleanly.
var gameplay_enabled: bool = true

var _one_shots: Dictionary = {}           ## action -> true for one frame
var _mouse_captured: bool = false


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS


func _process(_delta: float) -> void:
	_poll_devices()
	_one_shots.clear()


func _unhandled_input(event: InputEvent) -> void:
	# Desktop testing convenience: right-drag or captured mouse to look.
	if event is InputEventMouseMotion and _mouse_captured and gameplay_enabled:
		var sens := float(SettingsService.get_value("controls", "look_sensitivity", 1.0))
		touch_look += (event as InputEventMouseMotion).relative * sens * 0.6

	if event is InputEventMouseButton and (event as InputEventMouseButton).pressed:
		if (event as InputEventMouseButton).button_index == MOUSE_BUTTON_RIGHT:
			set_mouse_captured(not _mouse_captured)

	if event.is_action_pressed("interact"):
		_one_shots["interact"] = true
	if event.is_action_pressed("jump"):
		_one_shots["jump"] = true
	if event.is_action_pressed("toggle_phone"):
		_one_shots["toggle_phone"] = true
	if event.is_action_pressed("toggle_inventory"):
		_one_shots["toggle_inventory"] = true
	if event.is_action_pressed("pause_menu"):
		_one_shots["pause_menu"] = true
	if event.is_action_pressed("vehicle_exit"):
		_one_shots["vehicle_exit"] = true
	if event.is_action_pressed("crouch"):
		_one_shots["crouch"] = true
		_one_shots["crouch_toggle"] = true


func _poll_devices() -> void:
	if not gameplay_enabled:
		move = Vector2.ZERO
		look = Vector2.ZERO
		sprint_held = false
		crouch_held = false
		touch_look = Vector2.ZERO
		throttle = 0.0
		steer = 0.0
		return

	var gamepad := bool(SettingsService.get_value("controls", "gamepad_enabled", true))
	var kb := Vector2.ZERO
	if gamepad:
		kb = Input.get_vector("move_left", "move_right", "move_back", "move_forward")
	else:
		# Keyboard-only fallback still needs the same actions.
		kb = Vector2(
			Input.get_action_strength("move_right") - Input.get_action_strength("move_left"),
			Input.get_action_strength("move_forward") - Input.get_action_strength("move_back"))

	move = touch_move + kb
	if move.length() > 1.0:
		move = move.normalized()

	# Look: touch drag pixels plus right stick.
	var sens := float(SettingsService.get_value("controls", "look_sensitivity", 1.0))
	var invert := bool(SettingsService.get_value("controls", "invert_y", false))
	var stick := Vector2.ZERO
	if gamepad:
		stick = Input.get_vector("look_left", "look_right", "look_up", "look_down")
		var dead := float(SettingsService.get_value("controls", "gamepad_deadzone", 0.18))
		if stick.length() < dead:
			stick = Vector2.ZERO
	look = touch_look * 0.0022 * sens + stick * 0.045 * sens
	if invert:
		look.y = -look.y
	touch_look = Vector2.ZERO

	sprint_held = touch_sprint or Input.is_action_pressed("sprint")
	if bool(SettingsService.get_value("controls", "auto_sprint", false)) and move.y > 0.85:
		sprint_held = true
	crouch_held = touch_crouch or Input.is_action_pressed("crouch")

	if vehicle_mode:
		throttle = move.y
		steer = move.x
		handbrake = touch_sprint or Input.is_action_pressed("sprint")
		# Looking around inside a car uses its own sensitivity.
		var vsens := float(SettingsService.get_value("controls", "look_sensitivity_vehicle", 0.8))
		look *= vsens / maxf(0.01, sens)


# --- Touch API (called by the on-screen controls) --------------------------

func set_touch_move(v: Vector2) -> void:
	touch_move = v.limit_length(1.0)


func add_touch_look(delta_pixels: Vector2) -> void:
	touch_look += delta_pixels


func set_touch_sprint(pressed: bool) -> void:
	touch_sprint = pressed


func set_touch_crouch(pressed: bool) -> void:
	touch_crouch = pressed


func press(action: String) -> void:
	_one_shots[action] = true


func consume(action: String) -> bool:
	if _one_shots.get(action, false):
		_one_shots.erase(action)
		return true
	return false


func peek(action: String) -> bool:
	return bool(_one_shots.get(action, false))


func set_vehicle_mode(enabled: bool) -> void:
	vehicle_mode = enabled
	throttle = 0.0
	steer = 0.0
	handbrake = false


func set_gameplay_enabled(enabled: bool) -> void:
	gameplay_enabled = enabled
	if not enabled:
		touch_move = Vector2.ZERO
		touch_look = Vector2.ZERO
		touch_sprint = false
		touch_crouch = false
		throttle = 0.0
		steer = 0.0
	if not enabled and _mouse_captured:
		set_mouse_captured(false)


func set_mouse_captured(captured: bool) -> void:
	_mouse_captured = captured
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED if captured else Input.MOUSE_MODE_VISIBLE


func is_mouse_captured() -> bool:
	return _mouse_captured


## True on touch devices: the HUD uses this to decide whether to show the
## virtual stick by default.
func is_touch_device() -> bool:
	return DisplayServer.is_touchscreen_available() or OS.has_feature("mobile")
