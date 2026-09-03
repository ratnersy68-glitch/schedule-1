class_name StorageInteractable
extends Interactable
## The stock shelves of a property. Opens a two-panel transfer screen.

@export var property_id: String = ""


func _ready() -> void:
	super._ready()
	verb = "Open"
	display_name = "Storage"


func prompt() -> String:
	return "Open storage"


func subtitle() -> String:
	var p: PropertyState = GameState.get_property(property_id)
	if p == null:
		return ""
	return "%d / %d units" % [p.stored_units(), p.storage_capacity()]


func icon() -> String:
	return "▤"


func can_use(_player: Node3D) -> bool:
	return enabled and GameState.owns_property(property_id)


func _on_use(_player: Node3D) -> void:
	EventBus.screen_requested.emit("storage", {"property": property_id})
