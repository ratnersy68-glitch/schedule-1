class_name BedInteractable
extends Interactable
## Sleep to skip to morning. Restores health and stamina and settles the day.

@export var property_id: String = ""


func _ready() -> void:
	super._ready()
	verb = "Sleep in"
	display_name = "Bed"


func prompt() -> String:
	return "Sleep until morning"


func subtitle() -> String:
	return "Restores you and advances to 7:00"


func icon() -> String:
	return "☾"


func can_use(_player: Node3D) -> bool:
	return enabled and (property_id == "" or GameState.owns_property(property_id))


func _on_use(player: Node3D) -> void:
	if EnforcementService.wanted_level > 0:
		EventBus.toast_requested.emit("Not while the Bureau is looking for you.", "warn")
		return
	EventBus.screen_requested.emit("sleep", {"player": player})
