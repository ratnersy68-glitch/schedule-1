class_name TouchControls
extends Control
## The on-screen control layer.
##
## Layout is a set of default anchors that the player can override by dragging
## in edit mode; overrides are stored per button id in settings. The same
## widgets serve on foot and while driving, relabelled rather than replaced, so
## the player's muscle memory survives getting into a van.

const BUTTONS := ["interact", "sprint", "crouch", "jump", "inventory", "phone"]

var joystick: VirtualJoystick
var look_area: LookArea
var buttons: Dictionary = {}         ## id -> TouchButton
var edit_mode := false

var _driving := false
var _edit_bar: Control = null
var _joystick_holder: Control = null
var _left_handed := false


func _ready() -> void:
	UIKit.fill_viewport(self)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_build()
	_apply_layout()
	EventBus.settings_changed.connect(_on_settings_changed)
	EventBus.player_entered_vehicle.connect(func(_v): set_driving(true))
	EventBus.player_exited_vehicle.connect(func(_v): set_driving(false))


func _build() -> void:
	look_area = LookArea.new()
	look_area.name = "LookArea"
	add_child(look_area)

	_joystick_holder = Control.new()
	_joystick_holder.name = "JoystickHolder"
	_joystick_holder.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_joystick_holder)

	joystick = VirtualJoystick.new()
	joystick.name = "Joystick"
	_joystick_holder.add_child(joystick)

	_make_button("interact", "use", UIKit.ACCENT, "Use", 42.0)
	_make_button("sprint", "run", UIKit.GOOD, "Run", 32.0)
	_make_button("crouch", "crouch", UIKit.WARN, "Crouch", 32.0)
	_make_button("jump", "jump", UIKit.VIOLET, "Jump", 32.0)
	_make_button("inventory", "bag", UIKit.TEXT_DIM, "Bag", 28.0)
	_make_button("phone", "phone", UIKit.TEXT_DIM, "Phone", 28.0)

	buttons["interact"].pressed_down.connect(_on_primary_action)
	buttons["jump"].pressed_down.connect(func(): PlayerInput.press("jump"))
	buttons["sprint"].pressed_down.connect(func(): _on_sprint(true))
	buttons["sprint"].released.connect(func(): _on_sprint(false))
	buttons["crouch"].pressed_down.connect(_on_crouch)
	buttons["inventory"].pressed_down.connect(func(): PlayerInput.press("toggle_inventory"))
	buttons["phone"].pressed_down.connect(func(): PlayerInput.press("toggle_phone"))


func _make_button(id: String, kind: String, color: Color, caption: String,
		radius: float) -> TouchButton:
	var b := TouchButton.new()
	b.name = "Btn_" + id
	b.setup(id, kind, color, caption, radius)
	add_child(b)
	buttons[id] = b
	return b


func _on_primary_action() -> void:
	# The same big button uses things on foot and leaves the car when driving.
	PlayerInput.press("vehicle_exit" if _driving else "interact")


func _on_sprint(pressed: bool) -> void:
	PlayerInput.set_touch_sprint(pressed)


func _on_crouch() -> void:
	if _driving:
		return
	if bool(SettingsService.get_value("controls", "toggle_crouch", true)):
		PlayerInput.press("crouch_toggle")
		PlayerInput.set_touch_crouch(not PlayerInput.touch_crouch)
	else:
		PlayerInput.set_touch_crouch(true)


func _on_settings_changed(section: String) -> void:
	if section == "controls":
		_apply_layout()


# ===========================================================================
# LAYOUT
# ===========================================================================

func _apply_layout() -> void:
	_left_handed = bool(SettingsService.get_value("controls", "left_handed", false))
	await get_tree().process_frame
	var vp := size
	if vp.x <= 0.0:
		vp = get_viewport_rect().size

	var stick_side := 1.0 if _left_handed else 0.0    # 0 = left, 1 = right
	var margin := 26.0

	_joystick_holder.size = Vector2(joystick.custom_minimum_size)
	joystick.size = joystick.custom_minimum_size
	_joystick_holder.position = Vector2(
		lerpf(margin, vp.x - margin - _joystick_holder.size.x, stick_side),
		vp.y - margin - _joystick_holder.size.y)

	# The look region is everything the stick is not.
	if _left_handed:
		look_area.position = Vector2.ZERO
		look_area.size = Vector2(vp.x * 0.62, vp.y)
	else:
		look_area.position = Vector2(vp.x * 0.38, 0)
		look_area.size = Vector2(vp.x * 0.62, vp.y)

	var defaults := _default_positions(vp)
	for id in BUTTONS:
		var b: TouchButton = buttons[id]
		b.size = b.custom_minimum_size
		var custom = SettingsService.layout_for(id)
		if custom != null:
			b.position = Vector2(float(custom["x"]) * vp.x, float(custom["y"]) * vp.y)
		else:
			b.position = defaults.get(id, Vector2(vp.x - 120.0, vp.y - 120.0))


func _default_positions(vp: Vector2) -> Dictionary:
	var m := 26.0
	var right := vp.x - m
	var bottom := vp.y - m
	var mirror := func(pos: Vector2, w: float) -> Vector2:
		return Vector2(vp.x - pos.x - w, pos.y) if _left_handed else pos

	var interact: TouchButton = buttons["interact"]
	var sprint: TouchButton = buttons["sprint"]
	var crouch: TouchButton = buttons["crouch"]
	var jump: TouchButton = buttons["jump"]
	var inv: TouchButton = buttons["inventory"]
	var phone: TouchButton = buttons["phone"]

	var out := {}
	out["interact"] = mirror.call(Vector2(right - interact.size.x, bottom - interact.size.y),
		interact.size.x)
	out["jump"] = mirror.call(Vector2(right - interact.size.x - jump.size.x - 14.0,
		bottom - jump.size.y - 8.0), jump.size.x)
	out["sprint"] = mirror.call(Vector2(right - sprint.size.x,
		bottom - interact.size.y - sprint.size.y - 26.0), sprint.size.x)
	out["crouch"] = mirror.call(Vector2(right - sprint.size.x - crouch.size.x - 14.0,
		bottom - interact.size.y - crouch.size.y - 8.0), crouch.size.x)
	out["inventory"] = Vector2(m, m + 58.0)
	out["phone"] = Vector2(m, m + 58.0 + phone.size.y + 14.0)
	return out


func _notification(what: int) -> void:
	if what == NOTIFICATION_RESIZED and is_inside_tree():
		_apply_layout()


# ===========================================================================
# MODES
# ===========================================================================

func set_driving(driving: bool) -> void:
	_driving = driving
	if driving:
		buttons["interact"].setup("interact", "exit", UIKit.BAD, "Exit", 42.0)
	else:
		buttons["interact"].setup("interact", "use", UIKit.ACCENT, "Use", 42.0)
	buttons["sprint"].set_icon("brake" if driving else "run", "Brake" if driving else "Run")
	buttons["crouch"].visible = not driving
	buttons["jump"].visible = not driving
	if driving:
		PlayerInput.set_touch_crouch(false)
	PlayerInput.set_touch_sprint(false)
	_apply_layout()


func set_edit_mode(enabled: bool) -> void:
	edit_mode = enabled
	for id in buttons:
		(buttons[id] as TouchButton).edit_mode = enabled
		(buttons[id] as TouchButton).queue_redraw()
	joystick.visible = not enabled
	look_area.visible = not enabled
	if enabled and _edit_bar == null:
		_build_edit_bar()
	elif not enabled and _edit_bar != null:
		_edit_bar.queue_free()
		_edit_bar = null


func _build_edit_bar() -> void:
	_edit_bar = UIKit.panel(UIKit.BG_RAISED)
	UIKit.anchor_to(_edit_bar, "center", "top", Vector2(0, 20), Vector2(380, 0))
	var v := UIKit.vbox(8)
	_edit_bar.add_child(v)
	v.add_child(UIKit.label("Drag the buttons where you want them", 14,
		UIKit.TEXT, HORIZONTAL_ALIGNMENT_CENTER))
	var h := UIKit.hbox(8)
	v.add_child(h)
	var reset := UIKit.button("Reset")
	reset.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	reset.pressed.connect(func():
		SettingsService.clear_layout()
		_apply_layout())
	h.add_child(reset)
	var done := UIKit.button("Done", "primary")
	done.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	done.pressed.connect(func(): set_edit_mode(false))
	h.add_child(done)
	add_child(_edit_bar)


## Called by the HUD so the Use button greys out when there is nothing to use.
func set_interact_available(available: bool) -> void:
	if _driving:
		return
	(buttons["interact"] as TouchButton).set_enabled(available)


func set_visible_controls(v: bool) -> void:
	visible = v
	if not v:
		PlayerInput.set_touch_move(Vector2.ZERO)
		PlayerInput.set_touch_sprint(false)
