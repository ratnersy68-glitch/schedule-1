class_name Player
extends CharacterBody3D
## First-person player controller.
##
## Handles locomotion (walk / sprint / crouch / jump), the camera rig, stamina
## and health, footsteps, interaction dispatch, vehicle possession and the
## "how exposed am I right now" value that the trade and enforcement systems
## use to price risk.

signal interaction_target_changed(target: Interactable)

const LAYER_PLAYER := 1 << 1
const MASK_WORLD := 1 | (1 << 2) | (1 << 4)   # world, npc, vehicle

@onready var head: Node3D = $Head
@onready var camera: Camera3D = $Head/Camera3D
@onready var hands: FirstPersonHands = $Head/Camera3D/Hands
@onready var interactor: Interactor = $Head/Camera3D/Interactor
@onready var collider: CollisionShape3D = $Collider
@onready var ceiling_probe: RayCast3D = $CeilingProbe

var health: float = GameConfig.HEALTH_MAX
var stamina: float = GameConfig.STAMINA_MAX

var _crouching := false
var _crouch_blend := 0.0
var _sprinting := false
var _stamina_delay := 0.0
var _health_delay := 0.0
var _step_distance := 0.0
var _last_y_velocity := 0.0
var _bob_time := 0.0
var _base_fov := 74.0
var _target_roll := 0.0

var driving: Node3D = null          ## Vehicle being driven, or null
var _capsule: CapsuleShape3D = null
var _indoors := false
var _indoor_probe_accum := 0.0
var _district_accum := 0.0
var _nearby_npcs := 0
var _control_locked := false


func _ready() -> void:
	add_to_group("player")
	collision_layer = LAYER_PLAYER
	collision_mask = MASK_WORLD
	_capsule = collider.shape as CapsuleShape3D
	if _capsule != null:
		# Duplicate so two players (or a reload) never share one resource.
		_capsule = _capsule.duplicate()
		collider.shape = _capsule
		_capsule.height = GameConfig.STAND_HEIGHT
	_base_fov = camera.fov
	interactor.target_changed.connect(_on_interactor_target_changed)
	EventBus.player_spawned.emit(self)
	EventBus.player_health_changed.emit(health, GameConfig.HEALTH_MAX)
	EventBus.player_stamina_changed.emit(stamina, GameConfig.STAMINA_MAX)


func _physics_process(delta: float) -> void:
	if driving != null:
		# The vehicle drives the body; we only own the head and the buttons.
		if driving.has_method("driver_seat_position"):
			global_position = driving.driver_seat_position()
		else:
			global_position = driving.global_position + Vector3.UP * 0.6
		_update_look(delta)
		if PlayerInput.consume("vehicle_exit"):
			exit_vehicle()
		_update_context(delta)
		return

	_update_look(delta)
	_update_crouch(delta)
	_update_movement(delta)
	_update_stamina(delta)
	_update_health(delta)
	_update_footsteps(delta)
	_update_camera_effects(delta)
	_poll_actions()
	_update_context(delta)


# ===========================================================================
# LOOK
# ===========================================================================

func _update_look(delta: float) -> void:
	if _control_locked:
		return
	var look := PlayerInput.look
	if look == Vector2.ZERO:
		hands.drive(_speed_ratio(), Vector2.ZERO, _crouching, delta)
		return
	rotate_y(-look.x)
	head.rotate_x(-look.y)
	head.rotation.x = clampf(head.rotation.x,
		-deg_to_rad(GameConfig.MAX_PITCH_DEG), deg_to_rad(GameConfig.MAX_PITCH_DEG))
	hands.drive(_speed_ratio(), look, _crouching, delta)


func _speed_ratio() -> float:
	var planar := Vector2(velocity.x, velocity.z).length()
	return clampf(planar / GameConfig.SPRINT_SPEED, 0.0, 1.0)


# ===========================================================================
# MOVEMENT
# ===========================================================================

func _update_crouch(delta: float) -> void:
	var want_crouch := PlayerInput.crouch_held
	if bool(SettingsService.get_value("controls", "toggle_crouch", true)):
		if PlayerInput.consume("crouch_toggle"):
			want_crouch = not _crouching
		else:
			want_crouch = _crouching or PlayerInput.crouch_held
	if _crouching and not want_crouch and ceiling_probe.is_colliding():
		want_crouch = true          # cannot stand up under a shelf
	_crouching = want_crouch

	var target := 1.0 if _crouching else 0.0
	_crouch_blend = move_toward(_crouch_blend, target, delta * 7.0)
	var height := lerpf(GameConfig.STAND_HEIGHT, GameConfig.CROUCH_HEIGHT, _crouch_blend)
	if _capsule != null:
		_capsule.height = height
		collider.position.y = height * 0.5
	head.position.y = height - GameConfig.CAMERA_EYE_OFFSET


func _update_movement(delta: float) -> void:
	if not is_on_floor():
		velocity.y -= ProjectSettings.get_setting("physics/3d/default_gravity", 22.0) * delta
	else:
		if _last_y_velocity < -GameConfig.FALL_DAMAGE_THRESHOLD:
			_apply_fall_damage(-_last_y_velocity)
		velocity.y = minf(velocity.y, 0.0)

	var input := PlayerInput.move if not _control_locked else Vector2.ZERO
	var direction := (transform.basis * Vector3(input.x, 0.0, -input.y))
	direction.y = 0.0
	if direction.length() > 1.0:
		direction = direction.normalized()

	var target_speed := GameConfig.WALK_SPEED
	_sprinting = false
	if _crouching:
		target_speed = GameConfig.CROUCH_SPEED
	elif PlayerInput.sprint_held and stamina > GameConfig.STAMINA_SPRINT_MIN and input.y > 0.1:
		target_speed = GameConfig.SPRINT_SPEED
		_sprinting = true

	var accel := GameConfig.ACCELERATION if is_on_floor() else GameConfig.AIR_ACCELERATION
	var desired := direction * target_speed
	var planar := Vector3(velocity.x, 0.0, velocity.z)
	if direction.length() > 0.01:
		planar = planar.move_toward(desired, accel * delta)
	else:
		var friction := GameConfig.FRICTION if is_on_floor() else 1.0
		planar = planar.move_toward(Vector3.ZERO, friction * delta)
	velocity.x = planar.x
	velocity.z = planar.z

	if is_on_floor() and PlayerInput.consume("jump") and not _crouching \
			and stamina > GameConfig.STAMINA_JUMP_COST:
		velocity.y = GameConfig.JUMP_VELOCITY
		stamina -= GameConfig.STAMINA_JUMP_COST
		_stamina_delay = GameConfig.STAMINA_REGEN_DELAY
		EventBus.player_stamina_changed.emit(stamina, GameConfig.STAMINA_MAX)

	_last_y_velocity = velocity.y
	move_and_slide()


func _apply_fall_damage(impact: float) -> void:
	var over := impact - GameConfig.FALL_DAMAGE_THRESHOLD
	if over <= 0.0:
		return
	take_damage(over * GameConfig.FALL_DAMAGE_SCALE)
	AudioDirector.play_at("land", global_position, -2.0)


# ===========================================================================
# STAMINA / HEALTH
# ===========================================================================

func _update_stamina(delta: float) -> void:
	var before := stamina
	if _sprinting and Vector2(velocity.x, velocity.z).length() > 0.5:
		stamina = maxf(0.0, stamina - GameConfig.STAMINA_SPRINT_DRAIN * delta)
		_stamina_delay = GameConfig.STAMINA_REGEN_DELAY
	else:
		_stamina_delay = maxf(0.0, _stamina_delay - delta)
		if _stamina_delay <= 0.0:
			stamina = minf(GameConfig.STAMINA_MAX, stamina + GameConfig.STAMINA_REGEN * delta)
	if absf(stamina - before) > 0.05:
		EventBus.player_stamina_changed.emit(stamina, GameConfig.STAMINA_MAX)


func _update_health(delta: float) -> void:
	_health_delay = maxf(0.0, _health_delay - delta)
	if _health_delay <= 0.0 and health < GameConfig.HEALTH_MAX:
		var before := health
		health = minf(GameConfig.HEALTH_MAX, health + GameConfig.HEALTH_REGEN * delta)
		if absf(health - before) > 0.05:
			EventBus.player_health_changed.emit(health, GameConfig.HEALTH_MAX)


func take_damage(amount: float) -> void:
	if amount <= 0.0:
		return
	health = maxf(0.0, health - amount)
	_health_delay = GameConfig.HEALTH_REGEN_DELAY
	EventBus.player_health_changed.emit(health, GameConfig.HEALTH_MAX)
	if health <= 0.0:
		_on_incapacitated()


func heal(amount: float) -> void:
	health = minf(GameConfig.HEALTH_MAX, health + amount)
	EventBus.player_health_changed.emit(health, GameConfig.HEALTH_MAX)


func restore_stamina(amount: float) -> void:
	stamina = minf(GameConfig.STAMINA_MAX, stamina + amount)
	EventBus.player_stamina_changed.emit(stamina, GameConfig.STAMINA_MAX)


## Being knocked out is a setback, never a game over: you wake up in the
## nearest owned property, lighter by a fine.
func _on_incapacitated() -> void:
	health = GameConfig.HEALTH_MAX * 0.5
	EventBus.player_health_changed.emit(health, GameConfig.HEALTH_MAX)
	EnforcementService.bust()
	EventBus.screen_requested.emit("respawn", {})


# ===========================================================================
# FOOTSTEPS AND CAMERA FEEL
# ===========================================================================

func _update_footsteps(delta: float) -> void:
	if not is_on_floor():
		return
	var planar := Vector2(velocity.x, velocity.z).length()
	if planar < 0.4:
		_step_distance = 0.0
		return
	_step_distance += planar * delta
	var stride := 2.4 if _sprinting else (1.6 if not _crouching else 2.0)
	if _step_distance >= stride:
		_step_distance = 0.0
		AudioDirector.footstep(_indoors_surface(), global_position, _sprinting)
		# Sprinting past an officer is exactly the kind of thing they notice.
		if _sprinting and EnforcementService.is_observed:
			EnforcementService.report_incident("sprint_near_officer", 0.35)


func _indoors_surface() -> String:
	return "metal" if _indoors else "concrete"


func _update_camera_effects(delta: float) -> void:
	var ratio := _speed_ratio()
	_bob_time += delta * (6.0 + ratio * 7.0)
	var bob := sin(_bob_time) * 0.022 * ratio
	var sway := cos(_bob_time * 0.5) * 0.012 * ratio
	camera.position.y = lerpf(camera.position.y, bob, delta * 12.0)
	camera.position.x = lerpf(camera.position.x, sway, delta * 12.0)

	# Slight roll when strafing, and a FOV kick while sprinting.
	_target_roll = -PlayerInput.move.x * 0.022
	camera.rotation.z = lerpf(camera.rotation.z, _target_roll, delta * 6.0)
	var target_fov := _base_fov + (7.0 if _sprinting else 0.0)
	camera.fov = lerpf(camera.fov, target_fov, delta * 6.0)


# ===========================================================================
# ACTIONS AND CONTEXT
# ===========================================================================

func _poll_actions() -> void:
	if PlayerInput.consume("interact"):
		try_interact()


func try_interact() -> void:
	var target := interactor.current
	if target == null:
		return
	if not target.can_use(self):
		var reason := target.blocked_reason()
		if reason != "":
			EventBus.toast_requested.emit(reason, "warn")
			AudioDirector.play_ui("ui_error")
		return
	hands.play_use()
	target.use(self)


func _on_interactor_target_changed(target: Interactable) -> void:
	interaction_target_changed.emit(target)
	if target == null:
		EventBus.interaction_target_changed.emit({})
	else:
		EventBus.interaction_target_changed.emit({
			"prompt": target.prompt(),
			"subtitle": target.subtitle(),
			"icon": target.icon(),
			"enabled": target.can_use(self),
			"reason": target.blocked_reason(),
			"hold": target.hold_seconds,
		})


func refresh_prompt() -> void:
	_on_interactor_target_changed(interactor.current)


func _update_context(delta: float) -> void:
	_district_accum += delta
	if _district_accum >= 0.5:
		_district_accum = 0.0
		var d := DistrictDB.district_at(global_position)
		if d != GameState.current_district:
			GameState.current_district = d
			EventBus.player_entered_district.emit(d)
		GameState.player_position = global_position
		GameState.player_yaw = rotation.y

	_indoor_probe_accum += delta
	if _indoor_probe_accum >= 0.35:
		_indoor_probe_accum = 0.0
		_indoors = _probe_indoors()


func _probe_indoors() -> bool:
	var space := get_world_3d().direct_space_state
	if space == null:
		return false
	var q := PhysicsRayQueryParameters3D.create(
		global_position + Vector3.UP * 1.2, global_position + Vector3.UP * 7.0)
	q.collision_mask = 1
	q.exclude = [get_rid()]
	return not space.intersect_ray(q).is_empty()


func is_crouching() -> bool:
	return _crouching


func is_sprinting() -> bool:
	return _sprinting


func is_indoors() -> bool:
	return _indoors


func set_nearby_npc_count(n: int) -> void:
	_nearby_npcs = n


## 0 = a locked room at 3am, 1 = the middle of Market Row at lunchtime.
## Drives how much suspicion a deal generates.
func exposure() -> float:
	var e := 0.32
	e += float(GameData.district(GameState.current_district).get("footfall", 0.6)) * 0.22
	e += clampf(float(_nearby_npcs) / 6.0, 0.0, 1.0) * 0.3
	if not GameState.is_night():
		e += 0.14
	if _crouching:
		e -= 0.18
	if _indoors:
		e -= 0.3
	return clampf(e, 0.05, 1.0)


func set_control_locked(locked: bool) -> void:
	_control_locked = locked


# ===========================================================================
# VEHICLES
# ===========================================================================

func enter_vehicle(vehicle: Node3D) -> void:
	if driving != null:
		return
	driving = vehicle
	collider.disabled = true
	hands.set_hidden(true)
	velocity = Vector3.ZERO
	PlayerInput.set_vehicle_mode(true)
	if vehicle.has_method("set_driver"):
		vehicle.set_driver(self)
	EventBus.player_entered_vehicle.emit(vehicle)


func exit_vehicle() -> void:
	if driving == null:
		return
	var vehicle := driving
	driving = null
	collider.disabled = false
	hands.set_hidden(false)
	PlayerInput.set_vehicle_mode(false)
	if vehicle.has_method("set_driver"):
		vehicle.set_driver(null)
	if vehicle.has_method("exit_point"):
		global_position = vehicle.exit_point()
	else:
		global_position = vehicle.global_position + vehicle.global_transform.basis.x * 2.2
	velocity = Vector3.ZERO
	EventBus.player_exited_vehicle.emit(vehicle)


## Camera used by the vehicle so the driver's view sits behind the wheel.
func camera_node() -> Camera3D:
	return camera


func teleport(pos: Vector3, yaw: float = INF) -> void:
	global_position = pos
	if yaw != INF:
		rotation.y = yaw
	velocity = Vector3.ZERO
