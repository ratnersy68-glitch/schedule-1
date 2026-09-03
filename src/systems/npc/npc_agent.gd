class_name NpcAgent
extends CharacterBody3D
## A person in Cobalt Bay.
##
## One script covers every role because they share 90% of their behaviour:
## follow a schedule, walk the pavement graph, react to the player. Role
## specifics (an officer's vision cone, a customer's deal offer, a shopkeeper
## standing behind a counter) branch off `role`.
##
## Agents are pooled. `configure()` sets them up, `release()` returns them to
## an inert state so the pool can reuse the node without reallocating meshes.

enum State { IDLE, WALKING, WORKING, TALKING, PATROL, CHASE, FLEE, SLEEP }

const LAYER_NPC := 1 << 2
const MASK := 1 | (1 << 1) | (1 << 4)
const ARRIVE_DIST := 1.2
const WALK_SPEED := 1.5
const RUN_SPEED := 4.6
const VISION_RANGE := 17.0
const VISION_ANGLE_DEG := 62.0

var npc_id: String = ""
var display_name: String = "Someone"
var role: String = NpcDB.ROLE_CIVILIAN
var district: String = "dockside"
var faction: String = ""
var tint: Color = Color(0.6, 0.65, 0.72)
var body_height: float = 1.75

var schedule: NpcSchedule = null
var customer: CustomerProfile = null
var employee_id: String = ""

var state: State = State.IDLE
var sees_player: bool = false
var is_named: bool = false

var _graph: CityGraph = null
var _path: PackedVector3Array = PackedVector3Array()
var _path_index := 0
var _target_pos: Vector3 = Vector3.ZERO
var _repath_timer := 0.0
var _idle_timer := 0.0
var _think_timer := 0.0
var _walk_phase := 0.0
var _speak_cooldown := 0.0
var _player: Node3D = null
var _last_hour := -1
var _alerted := false

# Visual parts
var _root_visual: Node3D
var _torso: MeshInstance3D
var _head: MeshInstance3D
var _leg_l: MeshInstance3D
var _leg_r: MeshInstance3D
var _arm_l: MeshInstance3D
var _arm_r: MeshInstance3D
var _label: Label3D
var _interactable: NpcInteractable
var _collider: CollisionShape3D


func _ready() -> void:
	add_to_group("npc")
	collision_layer = LAYER_NPC
	collision_mask = MASK
	_build_visual()
	_build_collider()
	_build_interactable()
	_think_timer = randf() * (1.0 / GameConfig.AI_TICKS_PER_SECOND)


# ===========================================================================
# CONSTRUCTION
# ===========================================================================

func _build_collider() -> void:
	_collider = CollisionShape3D.new()
	var capsule := CapsuleShape3D.new()
	capsule.radius = 0.3
	capsule.height = 1.7
	_collider.shape = capsule
	_collider.position = Vector3(0, 0.85, 0)
	add_child(_collider)


func _build_visual() -> void:
	_root_visual = Node3D.new()
	add_child(_root_visual)

	_torso = _part(Vector3(0.44, 0.62, 0.26), Vector3(0, 1.08, 0), tint)
	_head = _part(Vector3(0.24, 0.26, 0.24), Vector3(0, 1.52, 0), Color(0.68, 0.53, 0.43))
	_leg_l = _part(Vector3(0.16, 0.72, 0.18), Vector3(-0.12, 0.4, 0), Color(0.18, 0.20, 0.24))
	_leg_r = _part(Vector3(0.16, 0.72, 0.18), Vector3(0.12, 0.4, 0), Color(0.18, 0.20, 0.24))
	_arm_l = _part(Vector3(0.13, 0.56, 0.15), Vector3(-0.29, 1.1, 0), tint.darkened(0.15))
	_arm_r = _part(Vector3(0.13, 0.56, 0.15), Vector3(0.29, 1.1, 0), tint.darkened(0.15))

	_label = Label3D.new()
	_label.font_size = 34
	_label.pixel_size = 0.0035
	_label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	_label.no_depth_test = true
	_label.outline_size = 8
	_label.outline_modulate = Color(0.02, 0.03, 0.05, 0.85)
	_label.position = Vector3(0, 1.95, 0)
	_label.visibility_range_end = 22.0
	_root_visual.add_child(_label)


func _part(size: Vector3, pos: Vector3, color: Color) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = size
	mi.mesh = bm
	mi.material_override = MeshFactory.solid(color, 0.85)
	mi.position = pos
	_root_visual.add_child(mi)
	return mi


func _build_interactable() -> void:
	_interactable = NpcInteractable.new()
	_interactable.brain = self
	var cs := CollisionShape3D.new()
	var shape := CapsuleShape3D.new()
	shape.radius = 0.65
	shape.height = 2.0
	cs.shape = shape
	cs.position = Vector3(0, 1.0, 0)
	_interactable.add_child(cs)
	add_child(_interactable)


# ===========================================================================
# LIFECYCLE
# ===========================================================================

func configure(data: Dictionary, graph: CityGraph, player: Node3D) -> void:
	_graph = graph
	_player = player
	npc_id = String(data.get("id", ""))
	display_name = String(data.get("name", "Someone"))
	role = String(data.get("role", NpcDB.ROLE_CIVILIAN))
	district = String(data.get("district", "dockside"))
	faction = String(data.get("faction", ""))
	tint = data.get("color", Color(0.6, 0.65, 0.72))
	body_height = float(data.get("height", 1.75))
	is_named = bool(data.get("named", false))
	employee_id = String(data.get("employee_id", ""))
	customer = data.get("customer", null)
	_interactable.npc_id = npc_id
	_interactable.display_name = display_name
	_alerted = false
	sees_player = false

	var sched: Array = data.get("schedule", [])
	schedule = NpcSchedule.new(sched)

	_apply_look()
	visible = true
	set_physics_process(true)
	_interactable.enabled = true
	state = State.IDLE
	_idle_timer = randf_range(0.5, 2.5)
	_last_hour = -1


func release() -> void:
	visible = false
	set_physics_process(false)
	_interactable.enabled = false
	_path = PackedVector3Array()
	_path_index = 0
	sees_player = false
	state = State.IDLE
	npc_id = ""
	customer = null
	employee_id = ""


func _apply_look() -> void:
	_torso.material_override = MeshFactory.solid(tint, 0.85)
	_arm_l.material_override = MeshFactory.solid(tint.darkened(0.15), 0.85)
	_arm_r.material_override = MeshFactory.solid(tint.darkened(0.15), 0.85)
	var scale := body_height / 1.75
	_root_visual.scale = Vector3.ONE * scale
	_label.text = display_name
	_label.modulate = tint.lightened(0.35)
	_label.visible = is_named or role == NpcDB.ROLE_OFFICER

	# Officers wear a high-visibility band so they read instantly at distance.
	if role == NpcDB.ROLE_OFFICER:
		_torso.material_override = MeshFactory.solid(Color(0.16, 0.24, 0.42), 0.7)
		var band := MeshFactory.solid(Color(0.95, 0.85, 0.25), 0.5)
		_arm_l.material_override = band
		_arm_r.material_override = band


# ===========================================================================
# TICK
# ===========================================================================

func _physics_process(delta: float) -> void:
	_think_timer -= delta
	if _think_timer <= 0.0:
		_think_timer = 1.0 / GameConfig.AI_TICKS_PER_SECOND
		_think()

	_move(delta)
	_animate(delta)
	_speak_cooldown = maxf(0.0, _speak_cooldown - delta)


func _think() -> void:
	if role == NpcDB.ROLE_OFFICER:
		_think_officer()
	match state:
		State.IDLE:
			_idle_timer -= 1.0 / GameConfig.AI_TICKS_PER_SECOND
			if _idle_timer <= 0.0:
				_choose_destination()
		State.WALKING, State.PATROL, State.CHASE, State.FLEE:
			if _path_index >= _path.size():
				_on_arrived()
		State.WORKING, State.SLEEP:
			if int(GameState.hour) != _last_hour:
				_last_hour = int(GameState.hour)
				_choose_destination()
		State.TALKING:
			pass


func _choose_destination() -> void:
	if _graph == null:
		return
	_last_hour = int(GameState.hour)
	var action := "wander"
	var poi := ""
	if schedule != null and not schedule.is_empty():
		var entry := schedule.current(GameState.hour)
		action = String(entry.get("action", "wander"))
		poi = String(entry.get("poi", ""))

	var target := Vector3.ZERO
	if poi != "" and GameData.has_poi(poi):
		target = GameData.poi_position(poi)
	else:
		var node_id := _graph.random_node_in(district)
		if node_id < 0:
			node_id = _graph.nearest(global_position, "walk")
		target = _graph.position_of(node_id)

	# Working and sleeping mean "stand at the place", not "orbit it".
	if action == "work" or action == "sleep":
		_walk_to(target, State.WORKING if action == "work" else State.SLEEP)
	elif action == "patrol":
		_walk_to(target + Vector3(randf_range(-8, 8), 0, randf_range(-8, 8)), State.PATROL)
	else:
		_walk_to(target + Vector3(randf_range(-4, 4), 0, randf_range(-4, 4)), State.WALKING)


func _walk_to(target: Vector3, next_state: State) -> void:
	if _graph == null:
		return
	_target_pos = target
	_path = _graph.find_path(global_position, target, "walk")
	_path_index = 0
	state = next_state if not _path.is_empty() else State.IDLE
	if _path.is_empty():
		_idle_timer = randf_range(2.0, 5.0)


func _on_arrived() -> void:
	match state:
		State.CHASE:
			_try_bust()
			state = State.PATROL
			_idle_timer = 1.0
		State.WORKING, State.SLEEP:
			pass
		_:
			state = State.IDLE
			_idle_timer = randf_range(2.5, 8.0)


# ===========================================================================
# MOVEMENT
# ===========================================================================

func _move(delta: float) -> void:
	if not is_on_floor():
		velocity.y -= 22.0 * delta
	else:
		velocity.y = 0.0

	var speed := 0.0
	match state:
		State.WALKING:
			speed = WALK_SPEED
		State.PATROL:
			speed = WALK_SPEED * 1.1
		State.CHASE:
			speed = RUN_SPEED
		State.FLEE:
			speed = RUN_SPEED * 0.85
		_:
			speed = 0.0

	if speed > 0.0 and _path_index < _path.size():
		var target: Vector3 = _path[_path_index]
		target.y = global_position.y
		var to := target - global_position
		if to.length() < ARRIVE_DIST:
			_path_index += 1
		else:
			var dir := to.normalized()
			velocity.x = dir.x * speed
			velocity.z = dir.z * speed
			var want_yaw := atan2(-dir.x, -dir.z)
			rotation.y = lerp_angle(rotation.y, want_yaw, delta * 7.0)
	else:
		velocity.x = move_toward(velocity.x, 0.0, 12.0 * delta)
		velocity.z = move_toward(velocity.z, 0.0, 12.0 * delta)

	move_and_slide()

	# Chasers re-path frequently because the target moves.
	if state == State.CHASE:
		_repath_timer -= delta
		if _repath_timer <= 0.0 and _player != null:
			_repath_timer = 0.7
			_path = _graph.find_path(global_position, _player.global_position, "walk")
			_path_index = 0


func _animate(delta: float) -> void:
	var moving := Vector2(velocity.x, velocity.z).length()
	_walk_phase += delta * (2.0 + moving * 2.6)
	var swing := sin(_walk_phase * 2.4) * clampf(moving / 3.0, 0.0, 1.0) * 0.55
	_leg_l.rotation.x = swing
	_leg_r.rotation.x = -swing
	_arm_l.rotation.x = -swing * 0.8
	_arm_r.rotation.x = swing * 0.8
	var bob := absf(sin(_walk_phase * 2.4)) * 0.035 * clampf(moving / 3.0, 0.0, 1.0)
	_root_visual.position.y = bob
	if state == State.SLEEP:
		_root_visual.rotation.x = lerpf(_root_visual.rotation.x, -0.15, delta * 3.0)
	else:
		_root_visual.rotation.x = lerpf(_root_visual.rotation.x, 0.0, delta * 3.0)


# ===========================================================================
# OFFICER BEHAVIOUR
# ===========================================================================

func _think_officer() -> void:
	sees_player = _can_see_player()
	var wanted := EnforcementService.wanted_level

	if sees_player and wanted > 0:
		if state != State.CHASE:
			state = State.CHASE
			_repath_timer = 0.0
			_say("Stop right there.")
			AudioDirector.play_at("alert", global_position, -6.0)
		if _player != null and global_position.distance_to(_player.global_position) < 2.0:
			_try_bust()
	elif state == State.CHASE and wanted == 0:
		state = State.PATROL
		_choose_destination()


func _can_see_player() -> bool:
	if _player == null or not is_instance_valid(_player):
		return false
	var to := _player.global_position - global_position
	var dist := to.length()
	var range_m := VISION_RANGE
	# Crouching, darkness and rain all shorten the line.
	if _player.has_method("is_crouching") and _player.is_crouching():
		range_m *= 0.55
	if GameState.is_night():
		range_m *= 0.75
	if GameState.weather == "fog":
		range_m *= 0.6
	if dist > range_m:
		return false
	var facing := -global_transform.basis.z
	var angle := rad_to_deg(facing.angle_to(to.normalized()))
	if angle > VISION_ANGLE_DEG:
		return false
	var space := get_world_3d().direct_space_state
	if space == null:
		return false
	var q := PhysicsRayQueryParameters3D.create(
		global_position + Vector3.UP * 1.5,
		_player.global_position + Vector3.UP * 1.0)
	q.collision_mask = 1
	q.exclude = [get_rid()]
	return space.intersect_ray(q).is_empty()


func _try_bust() -> void:
	if _player == null or EnforcementService.wanted_level == 0:
		return
	if global_position.distance_to(_player.global_position) > 2.6:
		return
	EnforcementService.bust()
	AudioDirector.play("bust", -4.0)
	state = State.PATROL


# ===========================================================================
# INTERACTION
# ===========================================================================

func can_talk() -> bool:
	if state == State.CHASE:
		return false
	if role == NpcDB.ROLE_OFFICER and EnforcementService.wanted_level > 0:
		return false
	return true


func talk_blocked_reason() -> String:
	if role == NpcDB.ROLE_OFFICER and EnforcementService.wanted_level > 0:
		return "Not while they are looking for you."
	return ""


func interaction_prompt() -> String:
	if customer != null:
		return "Offer to " + display_name
	if is_named:
		return "Talk to " + display_name
	return "Talk to " + display_name


func interaction_subtitle() -> String:
	if customer != null:
		var want: Array[String] = []
		for p in customer.prefers:
			want.append(GameData.item_name(p))
		return "%s - wants %s" % [customer.archetype_label(), " or ".join(want)]
	if is_named:
		var n: Dictionary = GameData.npc(npc_id)
		if n.has("blurb"):
			return String(n["blurb"])
	if role == NpcDB.ROLE_OFFICER:
		return "Civic Standards Bureau"
	return ""


func on_interacted(player: Node3D) -> void:
	face_towards(player.global_position)
	state = State.TALKING
	GameState.meet_npc(npc_id)
	if customer != null:
		EventBus.screen_requested.emit("deal", {"npc": self})
	elif is_named:
		EventBus.screen_requested.emit("dialogue", {"npc_id": npc_id, "npc": self})
	else:
		_say(_smalltalk())
		state = State.IDLE
	AudioDirector.play_ui("ui_tap")


func end_conversation() -> void:
	if state == State.TALKING:
		state = State.IDLE
		_idle_timer = randf_range(1.0, 3.0)


func face_towards(pos: Vector3) -> void:
	var to := pos - global_position
	to.y = 0.0
	if to.length() < 0.05:
		return
	rotation.y = atan2(-to.x, -to.z)


func _smalltalk() -> String:
	var lines := [
		"Rain again. It is always rain.",
		"You want the Row if you are buying anything.",
		"Bureau were on this street yesterday. Just so you know.",
		"Mind yourself after dark.",
		"Everything is more expensive than last month.",
		"I have not seen you around here before.",
	]
	return lines[randi() % lines.size()]


func _say(text: String) -> void:
	if _speak_cooldown > 0.0:
		return
	_speak_cooldown = 3.0
	var bubble := Label3D.new()
	bubble.text = text
	bubble.font_size = 30
	bubble.pixel_size = 0.0035
	bubble.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	bubble.no_depth_test = true
	bubble.outline_size = 8
	bubble.outline_modulate = Color(0.02, 0.03, 0.05, 0.9)
	bubble.modulate = Color(0.95, 0.95, 0.95)
	bubble.position = Vector3(0, 2.2, 0)
	bubble.visibility_range_end = 26.0
	add_child(bubble)
	var t := create_tween()
	t.tween_interval(2.4)
	t.tween_property(bubble, "modulate:a", 0.0, 0.6)
	t.tween_callback(bubble.queue_free)


## Reacts to the player sprinting past or drawing attention nearby.
func react_to_player(distance: float) -> void:
	if distance > 6.0 or _speak_cooldown > 0.0:
		return
	if _player == null or not is_instance_valid(_player):
		return
	if role == NpcDB.ROLE_CIVILIAN and EnforcementService.wanted_level >= 2:
		state = State.FLEE
		var away := (global_position - _player.global_position).normalized() * 18.0
		_walk_to(global_position + away, State.FLEE)
		_say("Not my business!")
