class_name LodManager
extends RefCounted
## Applies the player's view-distance setting to the generated city.
##
## The city is drawn from a handful of MultiMeshInstance3D nodes, which Godot
## can range-cull as a unit. Street furniture disappears first, then window
## glow, and buildings last, because losing a building silhouette is far more
## noticeable than losing a bin.

const PROP_BASE := 110.0
const WINDOW_BASE := 170.0
const BUILDING_BASE := 320.0
const LABEL_BASE := 70.0

var _props: Array[MultiMeshInstance3D] = []
var _windows: Array[MultiMeshInstance3D] = []
var _buildings: Array[MultiMeshInstance3D] = []
var _labels: Array[Label3D] = []


## Walks the built city once and sorts its renderables into LOD buckets.
func collect(root: Node) -> void:
	_props.clear()
	_windows.clear()
	_buildings.clear()
	_labels.clear()
	_walk(root)


func _walk(node: Node) -> void:
	for child in node.get_children():
		if child is MultiMeshInstance3D:
			var name := child.name
			if name.begins_with("Props_"):
				_props.append(child)
			elif name.begins_with("Windows_"):
				_windows.append(child)
			elif name.begins_with("Buildings_"):
				_buildings.append(child)
		elif child is Label3D:
			_labels.append(child)
		if child.get_child_count() > 0:
			_walk(child)


func apply(view_distance: float, shadows_enabled: bool) -> void:
	var d := clampf(view_distance, 0.4, 2.0)
	_set_range(_props, PROP_BASE * d, 14.0)
	_set_range(_windows, WINDOW_BASE * d, 20.0)
	_set_range(_buildings, BUILDING_BASE * d, 30.0)
	for label in _labels:
		if is_instance_valid(label):
			label.visibility_range_end = LABEL_BASE * d

	var shadow_mode := GeometryInstance3D.SHADOW_CASTING_SETTING_ON if shadows_enabled \
		else GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	for node in _buildings:
		if is_instance_valid(node):
			node.cast_shadow = shadow_mode
	# Props never cast shadows: hundreds of tiny shadow casters cost far more
	# than they add.
	for node in _props:
		if is_instance_valid(node):
			node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF


func _set_range(nodes: Array[MultiMeshInstance3D], distance: float, margin: float) -> void:
	for node in nodes:
		if not is_instance_valid(node):
			continue
		node.visibility_range_end = distance
		node.visibility_range_end_margin = margin


func stats() -> Dictionary:
	return {"buildings": _buildings.size(), "windows": _windows.size(),
		"props": _props.size(), "labels": _labels.size()}
