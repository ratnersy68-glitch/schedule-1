class_name FirstPersonHands
extends Node3D
## Procedural first-person hands.
##
## No rigged model ships with the project, so the hands are built from boxes at
## runtime and animated with additive offsets: a walk sway, a breathing idle, a
## use punch, and a hold pose when carrying something. Cheap, readable, and it
## sells the first-person camera far better than an empty screen.

@export var sway_amount: float = 0.018
@export var bob_amount: float = 0.012

var _left: Node3D
var _right: Node3D
var _held_anchor: Node3D
var _held_visual: MeshInstance3D = null

var _bob_phase := 0.0
var _sway := Vector2.ZERO
var _use_punch := 0.0
var _hold_blend := 0.0
var _hidden := false

const SKIN := Color(0.68, 0.52, 0.42)
const SLEEVE := Color(0.19, 0.22, 0.28)


func _ready() -> void:
	_left = _build_arm(-1.0)
	_right = _build_arm(1.0)
	add_child(_left)
	add_child(_right)
	_held_anchor = Node3D.new()
	_held_anchor.position = Vector3(0.16, -0.2, -0.42)
	add_child(_held_anchor)


func _build_arm(side: float) -> Node3D:
	var root := Node3D.new()
	root.position = Vector3(0.23 * side, -0.28, -0.36)
	root.rotation = Vector3(deg_to_rad(-8.0), deg_to_rad(-12.0 * side), deg_to_rad(6.0 * side))

	var forearm := MeshInstance3D.new()
	var fm := BoxMesh.new()
	fm.size = Vector3(0.075, 0.075, 0.30)
	forearm.mesh = fm
	forearm.material_override = _mat(SLEEVE)
	forearm.position = Vector3(0.0, 0.0, 0.12)
	root.add_child(forearm)

	var hand := MeshInstance3D.new()
	var hm := BoxMesh.new()
	hm.size = Vector3(0.085, 0.055, 0.11)
	hand.mesh = hm
	hand.material_override = _mat(SKIN)
	hand.position = Vector3(0.0, 0.0, -0.07)
	root.add_child(hand)

	# Four stubby fingers read as a hand at this scale.
	for i in 4:
		var finger := MeshInstance3D.new()
		var gm := BoxMesh.new()
		gm.size = Vector3(0.017, 0.032, 0.055)
		finger.mesh = gm
		finger.material_override = _mat(SKIN.darkened(0.05))
		finger.position = Vector3(-0.03 + i * 0.02, -0.005, -0.15)
		root.add_child(finger)

	var thumb := MeshInstance3D.new()
	var tm := BoxMesh.new()
	tm.size = Vector3(0.026, 0.03, 0.05)
	thumb.mesh = tm
	thumb.material_override = _mat(SKIN.darkened(0.05))
	thumb.position = Vector3(0.045 * side, 0.005, -0.11)
	root.add_child(thumb)
	return root


func _mat(c: Color) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = c
	m.roughness = 0.85
	m.metallic_specular = 0.15
	# Hands should never be clipped by geometry the camera is pressed against.
	m.no_depth_test = false
	return m


func _process(delta: float) -> void:
	_bob_phase += delta
	_use_punch = maxf(0.0, _use_punch - delta * 4.0)
	_hold_blend = lerpf(_hold_blend, 1.0 if _held_visual != null else 0.0, delta * 8.0)
	_apply_pose(delta)


## Called by the player each frame with its planar speed and look delta.
func drive(speed_ratio: float, look_delta: Vector2, crouching: bool, delta: float) -> void:
	_sway = _sway.lerp(-look_delta * 6.0, clampf(delta * 9.0, 0.0, 1.0))
	_sway = _sway.limit_length(1.0)
	_bob_phase += speed_ratio * delta * 9.0
	var target_y := -0.06 if crouching else 0.0
	position.y = lerpf(position.y, target_y, delta * 8.0)
	_speed_ratio = speed_ratio


var _speed_ratio := 0.0


func _apply_pose(delta: float) -> void:
	var bob_x := sin(_bob_phase * 2.0) * bob_amount * _speed_ratio
	var bob_y: float = absf(cos(_bob_phase * 4.0)) * bob_amount * _speed_ratio
	var breathe := sin(_bob_phase * 1.2) * 0.004

	var sway_offset := Vector3(_sway.x * sway_amount, _sway.y * sway_amount, 0.0)
	var punch := Vector3(0.0, -0.03 * _use_punch, 0.06 * _use_punch)

	var base_left := Vector3(-0.0, 0.0, 0.0)
	var target_left := base_left + sway_offset + punch \
		+ Vector3(bob_x, bob_y + breathe, 0.0)
	var target_right := base_left + sway_offset + punch * 1.4 \
		+ Vector3(-bob_x, bob_y * 0.8 + breathe, 0.0)

	_left.position = _left.position.lerp(Vector3(-0.23, -0.28, -0.36) + target_left, delta * 12.0)
	_right.position = _right.position.lerp(Vector3(0.23, -0.28, -0.36) + target_right
		+ Vector3(-0.05, 0.06, 0.08) * _hold_blend, delta * 12.0)
	_right.rotation.x = lerpf(_right.rotation.x, deg_to_rad(-8.0 - 18.0 * _hold_blend), delta * 10.0)


func play_use() -> void:
	_use_punch = 1.0


## Shows a small coloured block in the right hand representing an item.
func hold_item(item_id: String) -> void:
	clear_held()
	if item_id == "":
		return
	var mi := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = Vector3(0.09, 0.09, 0.13)
	mi.mesh = bm
	var m := StandardMaterial3D.new()
	var c := GameData.item_color(item_id)
	m.albedo_color = c
	if GameData.item(item_id).get("category", "") == ItemDB.CAT_PRODUCT:
		m.emission_enabled = true
		m.emission = c
		m.emission_energy_multiplier = 1.4
	mi.mesh.surface_set_material(0, m)
	_held_anchor.add_child(mi)
	_held_visual = mi


func clear_held() -> void:
	if _held_visual != null and is_instance_valid(_held_visual):
		_held_visual.queue_free()
	_held_visual = null


func set_hidden(hidden: bool) -> void:
	_hidden = hidden
	visible = not hidden
