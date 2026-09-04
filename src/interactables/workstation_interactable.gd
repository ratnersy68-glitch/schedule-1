class_name WorkstationInteractable
extends Interactable
## A production station inside one of your properties.
##
## Opens the production screen for its StationState. Also shows live progress
## in its subtitle so you can read a bench without opening anything.

@export var property_id: String = ""
@export var station_index: int = 0

var _hum: AudioStreamPlayer3D = null


func _ready() -> void:
	super._ready()
	verb = "Use"
	display_name = "Workstation"
	set_process(true)


func station() -> StationState:
	var p: PropertyState = GameState.get_property(property_id)
	if p == null or station_index >= p.stations.size():
		return null
	return p.stations[station_index]


func _process(_delta: float) -> void:
	# A running station hums. Cheap enough to poll; only owned interiors exist.
	var s := station()
	if s == null:
		return
	var busy := s.is_busy(GameState.absolute_hours())
	if busy and _hum == null:
		_hum = AudioStreamPlayer3D.new()
		_hum.stream = AudioDirector.stream_for("station_hum")
		_hum.bus = "SFX"
		_hum.volume_db = -18.0
		_hum.max_distance = 14.0
		add_child(_hum)
		_hum.play()
	elif not busy and _hum != null:
		_hum.queue_free()
		_hum = null


func prompt() -> String:
	var s := station()
	if s == null:
		return "Workstation"
	var now := GameState.absolute_hours()
	if s.is_ready(now):
		return "Collect from " + s.display_name()
	return "Use " + s.display_name()


func subtitle() -> String:
	var s := station()
	if s == null:
		return ""
	var now := GameState.absolute_hours()
	if s.is_ready(now):
		return "%d x %s ready" % [s.output_amount,
			GameData.item_name(String(GameData.recipe(s.recipe_id).get("output", "")))]
	if s.is_busy(now):
		return "%d%% - %s" % [int(s.progress(now) * 100.0),
			String(GameData.recipe(s.recipe_id).get("name", ""))]
	return "Idle"


func icon() -> String:
	return "WK"


func can_use(player: Node3D) -> bool:
	if not super.can_use(player):
		return false
	return GameState.owns_property(property_id)


func blocked_reason() -> String:
	var p: PropertyState = GameState.get_property(property_id)
	if p != null and p.is_shutdown(GameState.absolute_hours()):
		return "Shut down by the Bureau."
	return ""


func _on_use(_player: Node3D) -> void:
	var s := station()
	if s == null:
		return
	var p: PropertyState = GameState.get_property(property_id)
	if p != null and p.is_shutdown(GameState.absolute_hours()):
		EventBus.toast_requested.emit("This site is shut down.", "warn")
		return
	if s.is_ready(GameState.absolute_hours()):
		ProductionService.collect(p, s)
		AudioDirector.play("craft_done", -4.0)
		return
	EventBus.screen_requested.emit("production",
		{"property": property_id, "station": station_index})
