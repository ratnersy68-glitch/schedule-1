class_name Interactable
extends Area3D
## Base class for everything the player can look at and use.
##
## Interactables live on physics layer 4 and are found by the player's
## Interactor shape-cast. Subclasses override `prompt()`, `can_use()` and
## `use()`. Keeping the contract this small means a door, a bench, a person
## and a parked van are all the same thing to the player controller.

signal used(by: Node3D)

@export var display_name: String = "Object"
@export var verb: String = "Use"
@export var enabled: bool = true
@export var one_shot: bool = false
@export var hold_seconds: float = 0.0     ## >0 requires a press-and-hold
@export var highlight: bool = true

var _consumed := false


func _ready() -> void:
	collision_layer = 1 << 3        # layer 4: interactable
	collision_mask = 0
	monitoring = false
	monitorable = true
	add_to_group("interactable")


## Short verb+noun shown on the interaction button.
func prompt() -> String:
	return "%s %s" % [verb, display_name]


## Optional second line with context (price, status, contents).
func subtitle() -> String:
	return ""


func can_use(_player: Node3D) -> bool:
	return enabled and not (_consumed and one_shot)


## Reason shown when can_use() is false, so the UI can explain itself.
func blocked_reason() -> String:
	return ""


func use(player: Node3D) -> void:
	if not can_use(player):
		return
	if one_shot:
		_consumed = true
	used.emit(player)
	_on_use(player)


## Subclass hook.
func _on_use(_player: Node3D) -> void:
	pass


## Where the world-space marker floats. Defaults to the node origin.
func focus_point() -> Vector3:
	return global_position


## Icon glyph for the interaction button.
func icon() -> String:
	return "use"
