class_name ScreenManager
extends CanvasLayer
## Routes EventBus.screen_requested to the right screen and owns the stack.
##
## While any screen is open, gameplay input is disabled and the touch controls
## hide, so a thumb on a menu never also steers the player.

const SCREENS := {
	"production": "res://src/ui/screens/production_screen.gd",
	"storage": "res://src/ui/screens/storage_screen.gd",
	"property": "res://src/ui/screens/property_screen.gd",
	"dialogue": "res://src/ui/screens/dialogue_screen.gd",
	"deal": "res://src/ui/screens/deal_screen.gd",
	"inventory": "res://src/ui/screens/inventory_screen.gd",
	"shop": "res://src/ui/screens/shop_screen.gd",
	"bulk": "res://src/ui/screens/bulk_screen.gd",
	"hire": "res://src/ui/screens/hire_screen.gd",
	"vehicles": "res://src/ui/screens/vehicle_shop_screen.gd",
	"teach": "res://src/ui/screens/teach_screen.gd",
	"skills": "res://src/ui/screens/skills_screen.gd",
	"pause": "res://src/ui/screens/pause_screen.gd",
	"settings": "res://src/ui/screens/settings_screen.gd",
	"bust": "res://src/ui/screens/bust_screen.gd",
}

var stack: Array[GameScreen] = []
var touch_controls: TouchControls = null

var _cache: Dictionary = {}


func _ready() -> void:
	layer = 60
	process_mode = Node.PROCESS_MODE_ALWAYS
	EventBus.screen_requested.connect(_on_screen_requested)
	EventBus.player_busted.connect(func(penalty): open("bust", {"penalty": penalty}))


func _on_screen_requested(screen_id: String, payload: Dictionary) -> void:
	if SCREENS.has(screen_id):
		open(screen_id, payload)


func open(screen_id: String, payload: Dictionary = {}) -> GameScreen:
	var path: String = SCREENS.get(screen_id, "")
	if path == "":
		return null
	var script: Script = _cache.get(path)
	if script == null:
		if not ResourceLoader.exists(path):
			push_error("Screen script missing: " + path)
			return null
		script = load(path)
		_cache[path] = script
	var screen: GameScreen = (script as GDScript).new()
	screen.open_with(payload)
	screen.closed.connect(_on_screen_closed.bind(screen))
	add_child(screen)
	stack.append(screen)
	_update_gate()
	AudioDirector.play_ui("ui_tap")
	return screen


func _on_screen_closed(screen: GameScreen) -> void:
	stack.erase(screen)
	_update_gate()


func close_all() -> void:
	for screen in stack.duplicate():
		screen.close()
	stack.clear()
	_update_gate()


func is_open() -> bool:
	return not stack.is_empty()


func _update_gate() -> void:
	var blocked := not stack.is_empty()
	PlayerInput.set_gameplay_enabled(not blocked)
	EventBus.ui_input_blocked.emit(blocked)
	if touch_controls != null:
		touch_controls.set_visible_controls(not blocked)
