extends Node
## Scene transitions with a fade curtain and deferred loading.
##
## Keeps scene paths in one place and guarantees the curtain always lifts, even
## if a scene fails to instantiate, so the game can never soft-lock on black.

const SCENE_BOOT := "res://scenes/ui/boot.tscn"
const SCENE_MENU := "res://scenes/ui/main_menu.tscn"
const SCENE_GAME := "res://scenes/world/game.tscn"

signal transition_finished(scene_path: String)

var _curtain: ColorRect = null
var _layer: CanvasLayer = null
var _busy := false
## Slot to load once the game scene is ready; -1 means start a new game.
var pending_load_slot: int = -1


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_layer = CanvasLayer.new()
	_layer.layer = 200
	add_child(_layer)
	_curtain = ColorRect.new()
	_curtain.color = Color(0.02, 0.03, 0.05, 1.0)
	_curtain.set_anchors_preset(Control.PRESET_FULL_RECT)
	_curtain.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_curtain.modulate.a = 0.0
	_curtain.visible = false
	_layer.add_child(_curtain)


func go_to_menu() -> void:
	_transition(SCENE_MENU)


## Starts a fresh game. Any existing progress in memory is discarded.
func start_new_game() -> void:
	pending_load_slot = -1
	GameState.reset()
	EconomyService.reset()
	MissionService.reset()
	EnforcementService.reset()
	GameState.grant_starter_kit()
	AppMessages.inbox.clear()
	_transition(SCENE_GAME)


## Loads a slot into the services, then swaps to the game scene.
func load_game(slot: int) -> void:
	if not SaveService.load_into_state(slot):
		EventBus.toast_requested.emit("Could not load that save", "bad")
		return
	pending_load_slot = slot
	_transition(SCENE_GAME)


func quit_to_menu() -> void:
	GameState.set_clock_running(false)
	get_tree().paused = false
	AudioDirector.stop_world_audio()
	SaveService.unregister_world()
	go_to_menu()


func _transition(path: String) -> void:
	if _busy:
		return
	_busy = true
	await fade_out()
	var err := get_tree().change_scene_to_file(path)
	if err != OK:
		push_error("Failed to change scene to %s (%d)" % [path, err])
	# Wait one frame so the new scene's _ready has run before we lift the fade.
	await get_tree().process_frame
	await get_tree().process_frame
	await fade_in()
	_busy = false
	transition_finished.emit(path)


func fade_out(duration: float = 0.35) -> void:
	_curtain.visible = true
	_curtain.mouse_filter = Control.MOUSE_FILTER_STOP
	var t := create_tween()
	t.tween_property(_curtain, "modulate:a", 1.0, duration)
	await t.finished


func fade_in(duration: float = 0.45) -> void:
	var t := create_tween()
	t.tween_property(_curtain, "modulate:a", 0.0, duration)
	await t.finished
	_curtain.visible = false
	_curtain.mouse_filter = Control.MOUSE_FILTER_IGNORE
