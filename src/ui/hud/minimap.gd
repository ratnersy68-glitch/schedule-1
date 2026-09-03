class_name Minimap
extends Control
## Rotating minimap drawn directly from the city layout.
##
## No render target and no second camera: the city is a known grid, so the map
## is a handful of draw calls. That matters on mobile, where a second 3D
## viewport for a minimap is one of the easiest ways to halve your frame rate.

@export var view_radius: float = 62.0
@export var rotate_with_player: bool = true

var player: Node3D = null
var objective_pos: Vector3 = Vector3.ZERO
var has_objective: bool = false

var _npc_dots: Array[Dictionary] = []
var _refresh := 0.0


func _ready() -> void:
	custom_minimum_size = Vector2(132, 132)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_process(true)


func _process(delta: float) -> void:
	_refresh -= delta
	if _refresh <= 0.0:
		_refresh = 0.2
		_collect_dots()
	queue_redraw()


func _collect_dots() -> void:
	_npc_dots.clear()
	if player == null or not is_instance_valid(player):
		return
	var origin := player.global_position
	for node in get_tree().get_nodes_in_group("npc"):
		var agent := node as NpcAgent
		if agent == null or not agent.visible:
			continue
		var d := agent.global_position.distance_to(origin)
		if d > view_radius * 1.2:
			continue
		var color := UIKit.TEXT_FAINT
		if agent.role == NpcDB.ROLE_OFFICER:
			color = UIKit.BAD if agent.sees_player else Color(0.45, 0.65, 1.0)
		elif agent.customer != null:
			color = UIKit.MONEY
		elif agent.is_named:
			color = UIKit.WARN
		_npc_dots.append({"pos": agent.global_position, "color": color,
			"size": 3.5 if agent.is_named else 2.6})


func _world_to_map(world: Vector3, center: Vector2, yaw: float) -> Vector2:
	var origin := player.global_position
	var rel := Vector2(world.x - origin.x, world.z - origin.z)
	if rotate_with_player:
		rel = rel.rotated(yaw)
	var scale := (size.x * 0.5 - 6.0) / view_radius
	return center + rel * scale


func _draw() -> void:
	var center := size * 0.5
	var radius := size.x * 0.5

	draw_circle(center, radius, Color(UIKit.BG.r, UIKit.BG.g, UIKit.BG.b, 0.82))
	if player == null or not is_instance_valid(player):
		draw_arc(center, radius - 1.0, 0.0, TAU, 48, UIKit.LINE, 2.0, true)
		return

	var yaw := player.rotation.y if rotate_with_player else 0.0

	# District tint underneath, so you can feel where you are.
	for did in DistrictDB.CELL_MAP:
		var cell := DistrictDB.cell_of(did)
		var c0 := Vector3(cell.x * DistrictDB.CELL_SIZE, 0, cell.y * DistrictDB.CELL_SIZE)
		var c1 := c0 + Vector3(DistrictDB.CELL_SIZE, 0, DistrictDB.CELL_SIZE)
		var pts := PackedVector2Array([
			_world_to_map(c0, center, yaw),
			_world_to_map(Vector3(c1.x, 0, c0.z), center, yaw),
			_world_to_map(c1, center, yaw),
			_world_to_map(Vector3(c0.x, 0, c1.z), center, yaw)])
		var col: Color = GameData.district(did).get("palette", [UIKit.BG_PANEL])[0]
		if not GameState.district_unlocked(did):
			col = col.darkened(0.6)
		draw_colored_polygon(pts, Color(col.r, col.g, col.b, 0.5))

	# Roads.
	var road_col := Color(0.22, 0.24, 0.28, 0.9)
	for z in CityBuilder.ROAD_Z:
		draw_line(_world_to_map(Vector3(-20, 0, z), center, yaw),
			_world_to_map(Vector3(400, 0, z), center, yaw), road_col, 2.0)
	for x in CityBuilder.ROAD_X:
		draw_line(_world_to_map(Vector3(x, 0, -20), center, yaw),
			_world_to_map(Vector3(x, 0, 260), center, yaw), road_col, 2.0)

	# Owned properties.
	for prop in GameState.all_owned_properties():
		var p: Vector3 = GameData.property(prop.id).get("position", Vector3.ZERO)
		var mp := _world_to_map(p, center, yaw)
		if mp.distance_to(center) < radius - 4.0:
			draw_rect(Rect2(mp - Vector2(3, 3), Vector2(6, 6)), UIKit.GOOD)

	# People.
	for dot in _npc_dots:
		var mp2 := _world_to_map(dot["pos"], center, yaw)
		if mp2.distance_to(center) < radius - 4.0:
			draw_circle(mp2, float(dot["size"]), dot["color"])

	# Objective.
	if has_objective:
		var mo := _world_to_map(objective_pos, center, yaw)
		var clamped := mo
		if mo.distance_to(center) > radius - 8.0:
			clamped = center + (mo - center).normalized() * (radius - 8.0)
		draw_circle(clamped, 5.0, UIKit.WARN)
		draw_arc(clamped, 8.0, 0.0, TAU, 20, UIKit.WARN, 1.5, true)

	# The player, always a triangle pointing up.
	var tri := PackedVector2Array([
		center + Vector2(0, -7), center + Vector2(-5, 5), center + Vector2(5, 5)])
	draw_colored_polygon(tri, UIKit.ACCENT)

	draw_arc(center, radius - 1.0, 0.0, TAU, 48, UIKit.LINE, 2.0, true)

	# North marker.
	var north := Vector2(0, -1).rotated(yaw) * (radius - 12.0)
	var font := ThemeDB.fallback_font
	draw_string(font, center + north - Vector2(4, -4), "N",
		HORIZONTAL_ALIGNMENT_CENTER, -1, 12, UIKit.TEXT_DIM)
