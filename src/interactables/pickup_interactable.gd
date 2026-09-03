class_name PickupInteractable
extends Interactable
## A loose item lying in the world.
##
## Used for scavenged materials, event drops and mission items. Returns itself
## to the object pool rather than freeing, because scavenging spawns a lot of
## these across a session.

@export var item_id: String = "scrap_bundle"
@export var amount: int = 1
@export var quality: int = 0
@export var respawn_hours: float = -1.0   ## <0 never respawns

var _next_available: float = -1.0
var _visual: Node3D = null


func _ready() -> void:
	super._ready()
	verb = "Take"
	one_shot = false
	_refresh_name()


func configure(new_item: String, new_amount: int, new_quality: int = 0) -> void:
	item_id = new_item
	amount = new_amount
	quality = new_quality
	_refresh_name()


func bind_visual(node: Node3D) -> void:
	_visual = node


func _refresh_name() -> void:
	display_name = "%s x%d" % [GameData.item_name(item_id), amount]


func icon() -> String:
	return GameData.item_icon(item_id)


func subtitle() -> String:
	if GameData.item(item_id).get("category", "") == ItemDB.CAT_PRODUCT:
		return GameConfig.quality_name(quality)
	return ""


func can_use(player: Node3D) -> bool:
	if _next_available > 0.0 and GameState.absolute_hours() < _next_available:
		return false
	return super.can_use(player)


func _on_use(_player: Node3D) -> void:
	var added := GameState.inventory.add(item_id, amount, quality)
	if added <= 0:
		EventBus.toast_requested.emit("Your pockets are full", "warn")
		AudioDirector.play_ui("ui_error")
		return
	AudioDirector.play_at("pickup", global_position, -4.0)
	EventBus.toast_requested.emit("+%d %s" % [added, GameData.item_name(item_id)], "good")
	if added < amount:
		amount -= added
		_refresh_name()
		return
	_hide_until_respawn()


func _hide_until_respawn() -> void:
	if respawn_hours > 0.0:
		_next_available = GameState.absolute_hours() + respawn_hours
		_set_visible(false)
		var timer := get_tree().create_timer(respawn_hours * GameConfig.SECONDS_PER_GAME_HOUR)
		timer.timeout.connect(func():
			if is_instance_valid(self):
				_set_visible(true))
	else:
		queue_free()


func _set_visible(v: bool) -> void:
	if _visual != null and is_instance_valid(_visual):
		_visual.visible = v
	enabled = v
