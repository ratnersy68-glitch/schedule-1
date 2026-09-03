class_name Vehicle
extends CharacterBody3D
## Arcade driving model.
##
## Deliberately not VehicleBody3D: a raycast/suspension simulation is heavy on
## a phone and hard to control with a thumb. This is a kinematic body with
## speed, grip and a steering curve that scales with velocity, which gives
## predictable, forgiving handling on a touchscreen while still feeling
## different between a scooter and a loaded van.

const LAYER_VEHICLE := 1 << 4
const MASK := 1 | (1 << 2)

@export var type_id: String = "kestrel_van"

var top_speed: float = 16.0
var accel: float = 6.5
var grip: float = 4.6
var brake_force: float = 11.0
var storage: Inventory = null
var heat_shield: float = 0.0
var owned: bool = false
var instance_id: String = ""

var driver: Node3D = null
var _speed: float = 0.0
var _steer_angle: float = 0.0
var _body_mesh: MeshInstance3D
var _engine: AudioStreamPlayer3D
var _interactable: Interactable
var _headlights: Array[MeshInstance3D] = []
var _light_l: SpotLight3D
var _light_r: SpotLight3D
var _size: Vector3 = Vector3(2.0, 1.6, 4.6)


func _ready() -> void:
	add_to_group("vehicle")
	collision_layer = LAYER_VEHICLE
	collision_mask = MASK
	motion_mode = CharacterBody3D.MOTION_MODE_GROUNDED
	floor_max_angle = deg_to_rad(50.0)


func setup(vehicle_type: String, unique_id: String, is_owned: bool) -> void:
	type_id = vehicle_type
	instance_id = unique_id
	owned = is_owned
	var def: Dictionary = GameData.vehicle(type_id)
	top_speed = float(def.get("top_speed", 16.0))
	accel = float(def.get("accel", 6.5))
	grip = float(def.get("grip", 4.6))
	brake_force = float(def.get("brake", 11.0))
	heat_shield = float(def.get("heat_shield", 0.0))
	_size = def.get("body", Vector3(2.0, 1.6, 4.6))

	storage = Inventory.new("veh_" + unique_id, 10)
	storage.allow_overflow = true

	_build_body(def)
	_build_interactable(def)
	_build_audio()


func _build_body(def: Dictionary) -> void:
	var color: Color = def.get("color", Color(0.8, 0.8, 0.8))
	_body_mesh = MeshFactory.box_node(Vector3(_size.x, _size.y * 0.62, _size.z), color, 0.35)
	_body_mesh.position = Vector3(0, _size.y * 0.45, 0)
	add_child(_body_mesh)

	var cabin := MeshFactory.box_node(
		Vector3(_size.x * 0.9, _size.y * 0.45, _size.z * 0.42), color.darkened(0.25), 0.2)
	cabin.material_override = MeshFactory.glass()
	cabin.position = Vector3(0, _size.y * 0.86, -_size.z * 0.06)
	add_child(cabin)

	for sx in [-1.0, 1.0]:
		for sz in [-1.0, 1.0]:
			var wheel := MeshInstance3D.new()
			var cm := CylinderMesh.new()
			cm.top_radius = _size.y * 0.24
			cm.bottom_radius = _size.y * 0.24
			cm.height = 0.22
			cm.radial_segments = 10
			wheel.mesh = cm
			wheel.material_override = MeshFactory.solid(Color(0.08, 0.08, 0.09), 0.95)
			wheel.rotation.z = deg_to_rad(90.0)
			wheel.position = Vector3(sx * _size.x * 0.48, _size.y * 0.24, sz * _size.z * 0.33)
			add_child(wheel)

	for sx2 in [-1.0, 1.0]:
		var lamp := MeshFactory.box_node(Vector3(0.28, 0.16, 0.1), Color(1.0, 0.95, 0.8))
		var lm := StandardMaterial3D.new()
		lm.albedo_color = Color(1.0, 0.95, 0.8)
		lm.emission_enabled = true
		lm.emission = Color(1.0, 0.95, 0.8)
		lm.emission_energy_multiplier = 2.5
		lamp.material_override = lm
		lamp.position = Vector3(sx2 * _size.x * 0.32, _size.y * 0.45, -_size.z * 0.5 - 0.04)
		add_child(lamp)
		_headlights.append(lamp)

	_light_l = _make_headlight(Vector3(-_size.x * 0.3, _size.y * 0.5, -_size.z * 0.5))
	_light_r = _make_headlight(Vector3(_size.x * 0.3, _size.y * 0.5, -_size.z * 0.5))

	var cs := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = Vector3(_size.x, _size.y, _size.z)
	cs.shape = shape
	cs.position = Vector3(0, _size.y * 0.5, 0)
	add_child(cs)


func _make_headlight(pos: Vector3) -> SpotLight3D:
	var l := SpotLight3D.new()
	l.position = pos
	l.rotation.y = PI
	l.spot_range = 26.0
	l.spot_angle = 34.0
	l.light_energy = 2.4
	l.light_color = Color(1.0, 0.95, 0.85)
	l.shadow_enabled = false
	l.visible = false
	add_child(l)
	return l


func _build_interactable(def: Dictionary) -> void:
	_interactable = Interactable.new()
	_interactable.display_name = String(def.get("name", "Vehicle"))
	_interactable.verb = "Drive"
	var cs := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = Vector3(_size.x + 1.6, _size.y + 1.0, _size.z + 1.2)
	cs.shape = shape
	cs.position = Vector3(0, _size.y * 0.5, 0)
	_interactable.add_child(cs)
	_interactable.used.connect(_on_interacted)
	add_child(_interactable)


func _build_audio() -> void:
	_engine = AudioStreamPlayer3D.new()
	_engine.stream = AudioDirector.stream_for("engine")
	_engine.bus = "SFX"
	_engine.volume_db = -60.0
	_engine.max_distance = 40.0
	_engine.position = Vector3(0, 0.5, 0)
	add_child(_engine)


func _on_interacted(by: Node3D) -> void:
	if driver != null:
		return
	if not owned:
		EventBus.toast_requested.emit("Not yours. Teo sells these.", "warn")
		return
	if by.has_method("enter_vehicle"):
		by.enter_vehicle(self)


func set_driver(node: Node3D) -> void:
	driver = node
	_interactable.enabled = node == null
	if node != null:
		_engine.play()
		_engine.volume_db = -18.0
	else:
		_engine.stop()
		_speed = move_toward(_speed, 0.0, 100.0)


func driver_seat_position() -> Vector3:
	return global_position + global_transform.basis.y * (_size.y * 0.72) \
		+ global_transform.basis.z * (-_size.z * 0.1)


func exit_point() -> Vector3:
	return global_position + global_transform.basis.x * (_size.x * 0.5 + 1.1) + Vector3.UP * 0.3


func _physics_process(delta: float) -> void:
	_update_lights()
	if driver == null:
		velocity.y -= 22.0 * delta
		velocity.x = move_toward(velocity.x, 0.0, 20.0 * delta)
		velocity.z = move_toward(velocity.z, 0.0, 20.0 * delta)
		move_and_slide()
		return

	var throttle := clampf(PlayerInput.throttle, -1.0, 1.0)
	var steer_input := clampf(PlayerInput.steer, -1.0, 1.0)

	if throttle > 0.0:
		_speed = move_toward(_speed, top_speed * throttle, accel * delta)
	elif throttle < 0.0:
		# Reverse is deliberately slow and unglamorous.
		if _speed > 0.5:
			_speed = move_toward(_speed, 0.0, brake_force * delta)
		else:
			_speed = move_toward(_speed, -top_speed * 0.35, accel * 0.6 * delta)
	else:
		_speed = move_toward(_speed, 0.0, accel * 0.7 * delta)

	if PlayerInput.handbrake:
		_speed = move_toward(_speed, 0.0, brake_force * 1.8 * delta)

	# Steering authority falls off at speed so the car does not spin out.
	var speed_ratio := clampf(absf(_speed) / maxf(top_speed, 0.1), 0.0, 1.0)
	var authority := lerpf(1.0, 0.35, speed_ratio)
	_steer_angle = lerpf(_steer_angle, steer_input * authority, delta * 7.0)
	if absf(_speed) > 0.3:
		rotate_y(-_steer_angle * (grip * 0.16) * delta * signf(_speed) * absf(_speed))

	var forward := -global_transform.basis.z
	velocity.x = forward.x * _speed
	velocity.z = forward.z * _speed
	if not is_on_floor():
		velocity.y -= 22.0 * delta
	else:
		velocity.y = -0.5

	var before := global_position
	move_and_slide()

	# A hard stop against geometry is a crash: lose speed, gain attention.
	if get_slide_collision_count() > 0 and absf(_speed) > 7.0:
		var travelled := global_position.distance_to(before)
		if travelled < absf(_speed) * delta * 0.4:
			_speed *= 0.25
			EnforcementService.report_incident("crash", 0.6)
			AudioDirector.play_at("land", global_position, 0.0, 0.7)
			if driver != null and driver.has_method("take_damage"):
				driver.take_damage(6.0)

	# Engine note follows speed.
	_engine.pitch_scale = clampf(0.65 + speed_ratio * 1.1, 0.6, 2.0)
	_engine.volume_db = lerpf(-24.0, -8.0, speed_ratio)

	if driver.has_method("teleport"):
		driver.global_position = driver_seat_position()


func _update_lights() -> void:
	var on := GameState.is_night() or GameState.weather == "storm" or GameState.weather == "fog"
	if _light_l.visible == on:
		return
	_light_l.visible = on
	_light_r.visible = on
	for lamp in _headlights:
		lamp.visible = true


func speed_kph() -> float:
	return absf(_speed) * 3.6


func display_name() -> String:
	return String(GameData.vehicle(type_id).get("name", "Vehicle"))


func to_dict() -> Dictionary:
	return {
		"instance_id": instance_id, "type": type_id, "owned": owned,
		"pos": [global_position.x, global_position.y, global_position.z],
		"yaw": rotation.y,
		"storage": storage.to_dict() if storage != null else {},
	}
