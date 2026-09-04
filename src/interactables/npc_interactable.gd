class_name NpcInteractable
extends Interactable
## Attached to an NPC body. Routes to dialogue, trade or a customer deal.

@export var npc_id: String = ""

var brain: Node = null      ## NpcBrain, set at spawn


func _ready() -> void:
	super._ready()
	verb = "Talk to"


func prompt() -> String:
	if brain != null and brain.has_method("interaction_prompt"):
		return brain.interaction_prompt()
	return "Talk to " + display_name


func subtitle() -> String:
	if brain != null and brain.has_method("interaction_subtitle"):
		return brain.interaction_subtitle()
	return ""


func icon() -> String:
	return "person"


func can_use(player: Node3D) -> bool:
	if not super.can_use(player):
		return false
	if brain != null and brain.has_method("can_talk"):
		return brain.can_talk()
	return true


func blocked_reason() -> String:
	if brain != null and brain.has_method("talk_blocked_reason"):
		return brain.talk_blocked_reason()
	return ""


func _on_use(player: Node3D) -> void:
	if brain != null and brain.has_method("on_interacted"):
		brain.on_interacted(player)
