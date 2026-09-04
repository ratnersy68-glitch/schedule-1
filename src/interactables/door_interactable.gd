class_name DoorInteractable
extends Interactable
## A hinged door that swings open and shut.
##
## The visual leaf and its collider are rotated together by a tween, so the
## player can walk through an open door and is blocked by a closed one.

@export var open_angle_deg: float = 95.0
@export var swing_time: float = 0.45
@export var locked: bool = false
@export var lock_message: String = "Locked."
@export var requires_property: String = ""   ## must own this property to open

var is_open := false
var _leaf: Node3D = null
var _tween: Tween = null


func _ready() -> void:
	super._ready()
	display_name = "Door"
	verb = "Open"
	_leaf = get_parent() if get_parent() is Node3D else null


## The city builder passes the pivot node that should rotate.
func bind_leaf(leaf: Node3D) -> void:
	_leaf = leaf


func can_use(player: Node3D) -> bool:
	if not super.can_use(player):
		return false
	return true


func blocked_reason() -> String:
	if locked:
		return lock_message
	if requires_property != "" and not GameState.owns_property(requires_property):
		return "You do not have a key."
	return ""


func prompt() -> String:
	return ("Close " if is_open else "Open ") + display_name


func icon() -> String:
	return "door"


func _on_use(_player: Node3D) -> void:
	if locked:
		EventBus.toast_requested.emit(lock_message, "warn")
		AudioDirector.play_ui("ui_error")
		return
	if requires_property != "" and not GameState.owns_property(requires_property):
		EventBus.toast_requested.emit("You do not have a key.", "warn")
		AudioDirector.play_ui("ui_error")
		return
	toggle()


func toggle() -> void:
	if _leaf == null:
		return
	is_open = not is_open
	var target := deg_to_rad(open_angle_deg) if is_open else 0.0
	if _tween != null and _tween.is_running():
		_tween.kill()
	_tween = create_tween()
	_tween.set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_CUBIC)
	_tween.tween_property(_leaf, "rotation:y", target, swing_time)
	AudioDirector.play_at("door", global_position, -6.0, randf_range(0.95, 1.08))
