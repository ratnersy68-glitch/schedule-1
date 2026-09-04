class_name GameUi
extends CanvasLayer
## Assembles and wires the in-game interface layer.
##
## Owns the HUD, the touch controls and the phone, and routes the global
## action buttons. Screens live on their own layer above this one so a modal
## always covers the HUD.

var hud: GameHud
var touch: TouchControls
var phone: Phone
var screens: ScreenManager = null

var _paused_by_menu := false


func _ready() -> void:
	layer = 50
	process_mode = Node.PROCESS_MODE_ALWAYS

	hud = GameHud.new()
	hud.name = "Hud"
	add_child(hud)

	touch = TouchControls.new()
	touch.name = "TouchControls"
	touch.add_to_group("touch_controls")
	add_child(touch)

	phone = Phone.new()
	phone.name = "Phone"
	add_child(phone)

	screens = get_parent().get_node_or_null("Screens")
	if screens != null:
		screens.touch_controls = touch

	EventBus.phone_toggled.connect(_on_phone_toggled)
	EventBus.interaction_target_changed.connect(_on_interaction_target)
	EventBus.ui_input_blocked.connect(_on_ui_blocked)
	EventBus.player_busted.connect(func(_p): AudioDirector.play("bust", -6.0))
	set_process(true)
	_maybe_start_ui_tour()


## Development hook: "--uidemo" walks the interface through its screens on a
## timer so they can be captured and reviewed without driving touch input.
## Inert unless the flag is passed.
func _maybe_start_ui_tour() -> void:
	var args := OS.get_cmdline_user_args() + OS.get_cmdline_args()
	if not args.has("--uidemo"):
		return
	await get_tree().create_timer(2.0).timeout
	var tour := ["inventory", "property", "production", "skills", "settings"]
	for screen_id in tour:
		if screens != null:
			screens.close_all()
			screens.open(screen_id, {"property": "dockside_lockup", "station": 0})
		await get_tree().create_timer(6.0).timeout
	if screens != null:
		screens.close_all()
	phone.open()
	await get_tree().create_timer(6.0).timeout
	phone.open_app("business")


func _process(_delta: float) -> void:
	if PlayerInput.consume("toggle_phone"):
		if screens != null and screens.is_open():
			screens.close_all()
		else:
			phone.toggle()
	if PlayerInput.consume("toggle_inventory"):
		if phone.is_open:
			phone.close()
		EventBus.screen_requested.emit("inventory", {})
	if PlayerInput.consume("pause_menu"):
		_handle_pause()


func _handle_pause() -> void:
	if phone.is_open:
		phone.close()
		return
	if screens != null and screens.is_open():
		screens.close_all()
		return
	if screens != null:
		screens.open("pause", {})


func _on_phone_toggled(open: bool) -> void:
	touch.set_visible_controls(not open)
	hud.visible = not open


func _on_ui_blocked(blocked: bool) -> void:
	hud.visible = not blocked and not phone.is_open


func _on_interaction_target(payload: Dictionary) -> void:
	touch.set_interact_available(not payload.is_empty() and bool(payload.get("enabled", true)))
