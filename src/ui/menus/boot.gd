extends Control
## Title splash. Gives the autoloads a frame to warm up and sets the mood.

var _elapsed := 0.0
var _moved := false


func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	theme = UITheme.get_theme()
	var bg := ColorRect.new()
	bg.color = UIKit.BG
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(bg)

	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(center)

	var v := UIKit.vbox(6)
	center.add_child(v)

	var title := UIKit.label(GameConfig.GAME_TITLE, 58, UIKit.ACCENT, HORIZONTAL_ALIGNMENT_CENTER)
	title.add_theme_constant_override("outline_size", 0)
	v.add_child(title)
	v.add_child(UIKit.label(GameConfig.GAME_SUBTITLE.to_upper(), 18, UIKit.TEXT_DIM,
		HORIZONTAL_ALIGNMENT_CENTER))
	v.add_child(UIKit.spacer(18))
	v.add_child(UIKit.label("Tap to begin", 14, UIKit.TEXT_FAINT, HORIZONTAL_ALIGNMENT_CENTER))

	modulate.a = 0.0
	create_tween().tween_property(self, "modulate:a", 1.0, 0.6)
	set_process(true)
	set_process_unhandled_input(true)

	# CI / smoke-test entry point: "godot -- --autostart" drops straight into a
	# fresh game so the whole stack can be exercised without a human tapping.
	# On desktop the flag arrives after "--"; the web shell passes it as a
	# plain engine argument. Check both so smoke tests work everywhere.
	var args := OS.get_cmdline_user_args() + OS.get_cmdline_args()
	if args.has("--autostart"):
		_moved = true
		call_deferred("_autostart")


func _autostart() -> void:
	SceneRouter.start_new_game()


func _process(delta: float) -> void:
	_elapsed += delta
	if _elapsed > 2.4:
		_go()


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventScreenTouch and (event as InputEventScreenTouch).pressed:
		_go()
	elif event is InputEventKey and (event as InputEventKey).pressed:
		_go()


func _go() -> void:
	if _moved:
		return
	_moved = true
	SceneRouter.go_to_menu()
