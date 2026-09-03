class_name PropertyBoardInteractable
extends Interactable
## The "for sale" sign / management panel on the front of a property.

@export var property_id: String = ""


func _ready() -> void:
	super._ready()
	display_name = "Property"


func prompt() -> String:
	if GameState.owns_property(property_id):
		return "Manage " + String(GameData.property(property_id).get("name", "property"))
	return "View " + String(GameData.property(property_id).get("name", "property"))


func subtitle() -> String:
	if GameState.owns_property(property_id):
		var p: PropertyState = GameState.get_property(property_id)
		return "%d staff, %d stations, upkeep %s/day" % [
			GameState.employees_at(property_id).size(), p.stations.size(),
			GameConfig.format_money(p.daily_upkeep())]
	var price := int(GameData.property(property_id).get("price", 0))
	if not BusinessService.unlock_met(property_id):
		return BusinessService.unlock_hint(property_id)
	return "For sale: " + GameConfig.format_money(price)


func icon() -> String:
	return "⌂"


func _on_use(_player: Node3D) -> void:
	EventBus.screen_requested.emit("property", {"property": property_id})
