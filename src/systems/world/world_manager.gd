class_name WorldManager
extends Node3D
## Owns the running world: generation, lighting, weather, population and the
## hourly economy ticks.
##
## Everything expensive is budgeted. NPCs come from a fixed pool and are
## recycled by distance, the AI runs at 6Hz staggered across agents, and the
## sky/weather update on a slow timer rather than per frame.

signal world_built()

const PLAYER_SCENE := preload("res://scenes/player/player.tscn")
const SPAWN_POINT := Vector3(16.0, 0.4, 44.0)

@onready var sun: DirectionalLight3D = $Sun
@onready var world_env: WorldEnvironment = $WorldEnvironment

var city: CityBuilder = null
var graph: CityGraph = null
var player: Player = null

var npc_pool: ObjectPool = null
var lod: LodManager = null
var _named_spawned: Dictionary = {}       ## npc_id -> NpcAgent
var _customers: Dictionary = {}           ## district -> Array[CustomerProfile]
var _vehicles: Array[Vehicle] = []
var _emissive_nodes: Array[MultiMeshInstance3D] = []
var _rain: CPUParticles3D = null
var _population_timer := 0.0
var _env_timer := 0.0
var _observer_timer := 0.0
var _customer_counter := 0
var _sky_material: ProceduralSkyMaterial = null
var _built := false
var _diag := false
var _diag_timer := 0.0
var _active_radius := GameConfig.NPC_ACTIVE_RADIUS
var _cull_radius := GameConfig.NPC_CULL_RADIUS
var _sim_radius := GameConfig.NPC_SIM_RADIUS


func _ready() -> void:
	_diag = OS.get_cmdline_user_args().has("--diag")
	_build_environment()
	call_deferred("_build_world")


# ===========================================================================
# BUILD
# ===========================================================================

func _build_world() -> void:
	var t0 := Time.get_ticks_msec()
	GameData.clear_pois()

	city = CityBuilder.new()
	var result := city.build(self, GameState.seed_value)
	graph = result["graph"]
	_emissive_nodes = result["emissive"]

	_spawn_player()
	_build_npc_pool()
	lod = LodManager.new()
	lod.collect(self)
	_apply_view_settings()
	_restore_world_state()
	_spawn_owned_vehicles()
	_spawn_dealer_vehicles()

	SaveService.register_world(self)
	GameState.set_clock_running(true)
	AudioDirector.start_world_audio()

	_connect_signals()
	_refresh_property_stations()
	_update_environment(true)

	_built = true
	world_built.emit()
	EventBus.world_ready.emit()
	_announce_start()
	print("[World] Cobalt Bay built in %d ms, %d nav nodes" %
		[Time.get_ticks_msec() - t0, graph.node_count()])


## A short orientation on a new save, so the first minute is not a shrug.
func _announce_start() -> void:
	if GameState.day > 1 or GameState.lifetime_earned > 0:
		EventBus.toast_requested.emit("Welcome back to Cobalt Bay", "info")
		return
	EventBus.toast_requested.emit("Cobalt Bay, Dockside. Find Mira Vance at the Gull.", "info")
	EventBus.phone_notification.emit("messages", "Mira Vance",
		"Gull Cafe, top of the pier road. Come alone, come now, and bring nothing " +
		"you would mind losing. - M")
	EventBus.phone_notification.emit("news", "Getting started",
		"Left stick moves, drag the right side of the screen to look, and the big " +
		"button uses whatever you are pointing at. The phone button opens everything else.")


## True once the city, player and population exist.
func is_built() -> bool:
	return _built


func _connect_signals() -> void:
	EventBus.hour_passed.connect(_on_hour_passed)
	EventBus.day_passed.connect(_on_day_passed)
	EventBus.weather_changed.connect(_on_weather_changed)
	EventBus.property_upgraded.connect(func(_p, _t, _l): _refresh_property_stations())
	EventBus.property_purchased.connect(func(_p): _refresh_property_stations())
	EventBus.screen_requested.connect(_on_screen_requested)
	EventBus.settings_changed.connect(func(section):
		if section == "graphics":
			_apply_view_settings())


func _spawn_player() -> void:
	player = PLAYER_SCENE.instantiate()
	add_child(player)
	var pos := SPAWN_POINT
	var yaw := 0.0
	if GameState.player_position.length_squared() > 1.0:
		pos = GameState.player_position + Vector3.UP * 0.2
		yaw = GameState.player_yaw
	else:
		# Snap a fresh start onto the pavement so nobody wakes up in a wall.
		var node_id := graph.nearest(SPAWN_POINT, "walk")
		if node_id >= 0:
			pos = graph.position_of(node_id) + Vector3.UP * 0.3
	player.teleport(pos, yaw)
	GameState.current_district = DistrictDB.district_at(pos)


func _build_npc_pool() -> void:
	# One allocation up front; from here on people are recycled, never spawned.
	npc_pool = ObjectPool.new(func(): return NpcAgent.new(), self,
		GameConfig.MAX_ACTIVE_NPCS)


# ===========================================================================
# ENVIRONMENT
# ===========================================================================

func _build_environment() -> void:
	var env := Environment.new()
	_sky_material = ProceduralSkyMaterial.new()
	_sky_material.sky_top_color = Color(0.11, 0.17, 0.29)
	_sky_material.sky_horizon_color = Color(0.32, 0.36, 0.42)
	_sky_material.ground_bottom_color = Color(0.06, 0.07, 0.09)
	_sky_material.ground_horizon_color = Color(0.18, 0.19, 0.22)
	_sky_material.sun_angle_max = 12.0
	var sky := Sky.new()
	sky.sky_material = _sky_material
	env.sky = sky
	env.background_mode = Environment.BG_SKY
	env.ambient_light_source = Environment.AMBIENT_SOURCE_SKY
	env.ambient_light_sky_contribution = 0.75
	env.ambient_light_energy = 1.0
	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	env.tonemap_white = 4.0
	env.fog_enabled = true
	env.fog_light_color = Color(0.30, 0.36, 0.44)
	env.fog_density = 0.006
	env.fog_sky_affect = 0.3
	env.glow_enabled = bool(SettingsService.get_value("graphics", "bloom", true))
	env.glow_intensity = 0.55
	env.glow_bloom = 0.12
	env.glow_hdr_threshold = 1.0

	world_env.environment = env


func _update_environment(force: bool = false) -> void:
	var hour := GameState.hour
	# Sun travels from east at 06:00 to west at 18:00.
	var t := clampf((hour - 5.0) / 14.0, -0.2, 1.2)
	var elevation := lerpf(-12.0, 62.0, sin(clampf(t, 0.0, 1.0) * PI))
	sun.rotation_degrees = Vector3(-elevation, lerpf(-40.0, 220.0, clampf(t, 0.0, 1.0)), 0.0)

	var day_amount := clampf(sin(clampf(t, 0.0, 1.0) * PI) * 1.4, 0.0, 1.0)
	var weather := GameState.weather
	var overcast := 1.0
	match weather:
		"overcast":
			overcast = 0.62
		"rain":
			overcast = 0.45
		"storm":
			overcast = 0.32
		"fog":
			overcast = 0.55
		_:
			overcast = 1.0

	sun.light_energy = lerpf(0.05, 1.15, day_amount) * overcast
	sun.light_color = Color(1.0, 0.93, 0.82).lerp(Color(1.0, 0.62, 0.42),
		clampf(1.0 - day_amount, 0.0, 1.0) * 0.8)
	sun.shadow_enabled = bool(SettingsService.get_value("graphics", "shadows", true)) and day_amount > 0.12

	var env := world_env.environment
	if env != null:
		var night := 1.0 - day_amount
		env.ambient_light_energy = lerpf(0.35, 1.0, day_amount)
		env.fog_density = lerpf(0.004, 0.02, night) * (1.0 if weather != "fog" else 3.2)
		env.fog_light_color = Color(0.30, 0.36, 0.44).lerp(Color(0.06, 0.08, 0.14), night)
		_sky_material.sky_top_color = Color(0.14, 0.32, 0.58).lerp(Color(0.03, 0.04, 0.09), night)
		_sky_material.sky_horizon_color = Color(0.55, 0.60, 0.66).lerp(Color(0.09, 0.11, 0.18), night)
		_sky_material.ground_horizon_color = Color(0.22, 0.24, 0.28).lerp(Color(0.05, 0.06, 0.09), night)

	# Windows and street lamps brighten as the light goes.
	var glow := lerpf(2.6, 0.25, day_amount)
	var mat := MeshFactory.emissive(1.0, "windows")
	mat.emission_energy_multiplier = glow
	if force:
		for node in _emissive_nodes:
			node.visible = true


func _on_weather_changed(weather_id: String) -> void:
	_update_environment()
	var wants_rain := weather_id == "rain" or weather_id == "storm"
	if not bool(SettingsService.get_value("graphics", "weather_effects", true)):
		wants_rain = false
	if wants_rain and _rain == null:
		_rain = _make_rain()
		add_child(_rain)
	elif not wants_rain and _rain != null:
		_rain.emitting = false
		_rain.queue_free()
		_rain = null
	if _rain != null:
		_rain.amount = 900 if weather_id == "storm" else 420
		_rain.emitting = true


func _make_rain() -> CPUParticles3D:
	var p := CPUParticles3D.new()
	p.amount = 420
	p.lifetime = 1.1
	p.emission_shape = CPUParticles3D.EMISSION_SHAPE_BOX
	p.emission_box_extents = Vector3(16.0, 0.4, 16.0)
	p.direction = Vector3(0.15, -1.0, 0.05)
	p.spread = 3.0
	p.gravity = Vector3(0, -34.0, 0)
	p.initial_velocity_min = 12.0
	p.initial_velocity_max = 18.0
	p.scale_amount_min = 0.03
	p.scale_amount_max = 0.06
	var mesh := BoxMesh.new()
	mesh.size = Vector3(0.02, 0.5, 0.02)
	p.mesh = mesh
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.7, 0.82, 0.95, 0.55)
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	p.material_override = mat
	p.local_coords = false
	return p


# ===========================================================================
# POPULATION
# ===========================================================================

func _process(delta: float) -> void:
	if not _built or player == null:
		return

	_env_timer += delta
	if _env_timer >= 1.0:
		_env_timer = 0.0
		_update_environment()
		if _rain != null:
			_rain.global_position = player.global_position + Vector3(0, 14.0, 0)

	_population_timer += delta
	if _population_timer >= 1.2:
		_population_timer = 0.0
		_update_population()

	_observer_timer += delta
	if _observer_timer >= 0.25:
		_observer_timer = 0.0
		_report_observers()

	if _diag:
		_diag_timer += delta
		if _diag_timer >= 10.0:
			_diag_timer = 0.0
			_print_diagnostics()


## Console read-out for QA soaks: "godot -- --autostart --diag".
func _print_diagnostics() -> void:
	var active := 0
	var officers := 0
	var customers := 0
	for a: NpcAgent in _agents():
		if not a.visible:
			continue
		active += 1
		if a.role == NpcDB.ROLE_OFFICER:
			officers += 1
		elif a.customer != null:
			customers += 1
	print("[Diag] D%d %s | %s | npcs %d (%d law, %d buyers) | cash %s | susp %.0f | wanted %d | jobs %d | fps %d" % [
		GameState.day, GameConfig.format_clock(GameState.hour),
		GameData.district_name(GameState.current_district), active, officers, customers,
		GameConfig.format_money(GameState.cash), EnforcementService.suspicion,
		EnforcementService.wanted_level, MissionService.active.size(),
		Engine.get_frames_per_second()])


## Pushes the graphics settings into the world: LOD ranges, shadows and the
## radii the population budget uses.
func _apply_view_settings() -> void:
	var view := float(SettingsService.get_value("graphics", "view_distance", 1.0))
	var shadows := bool(SettingsService.get_value("graphics", "shadows", true))
	if lod != null:
		lod.apply(view, shadows)
	sun.shadow_enabled = shadows
	sun.directional_shadow_max_distance = clampf(90.0 * view, 40.0, 180.0)
	_active_radius = GameConfig.NPC_ACTIVE_RADIUS * view
	_cull_radius = GameConfig.NPC_CULL_RADIUS * view
	_sim_radius = GameConfig.NPC_SIM_RADIUS * view


func _report_observers() -> void:
	var observers := 0
	var nearby := 0
	var ppos := player.global_position
	for agent: NpcAgent in _agents():
		if not agent.visible:
			continue
		var d := agent.global_position.distance_to(ppos)
		if d < 14.0:
			nearby += 1
		if agent.role == NpcDB.ROLE_OFFICER and agent.sees_player:
			observers += 1
		if d < 8.0:
			agent.react_to_player(d)
	EnforcementService.report_observation(observers)
	player.set_nearby_npc_count(nearby)


func _update_population() -> void:
	var ppos := player.global_position

	# Recycle anyone too far away.
	for agent: NpcAgent in _agents():
		if not agent.visible:
			continue
		if agent.global_position.distance_to(ppos) > _cull_radius:
			if agent.is_named:
				_named_spawned.erase(agent.npc_id)
			agent.release()

	# Named characters near their scheduled place.
	for npc_id in GameData.npcs:
		if _named_spawned.has(npc_id):
			continue
		var data: Dictionary = GameData.npc(npc_id)
		var sched := NpcSchedule.new(data.get("schedule", []))
		var poi := sched.current_poi(GameState.hour)
		var target := GameData.poi_position(poi, DistrictDB.center_of(String(data["district"])))
		if target.distance_to(ppos) > _sim_radius:
			continue
		var agent := _take_from_pool()
		if agent == null:
			break
		var spawn := _safe_spawn_near(target)
		agent.global_position = spawn
		agent.configure({
			"id": npc_id, "name": data.get("name", npc_id), "role": data.get("role", "civilian"),
			"district": data["district"], "color": data.get("color", Color.WHITE),
			"height": data.get("height", 1.75), "named": true,
			"faction": data.get("faction", ""), "schedule": data.get("schedule", []),
		}, graph, player)
		_named_spawned[npc_id] = agent

	# Fill the remainder with civilians, customers and patrols.
	var district_id := GameState.current_district
	var district: Dictionary = GameData.district(district_id)
	var want_customers := int(round(3.0 * float(district.get("footfall", 0.6))
		* (1.0 + GameState.skill_effect("customer_density"))))
	var want_officers := int(round(2.0 * float(district.get("patrol", 0.5))
		* EconomyService.patrol_multiplier(district_id)))
	if GameState.is_night():
		want_customers = maxi(1, want_customers - 1)
		want_officers = maxi(1, want_officers)

	var have_customers := 0
	var have_officers := 0
	var have_civilians := 0
	for agent: NpcAgent in _agents():
		if not agent.visible or agent.is_named:
			continue
		if agent.customer != null:
			have_customers += 1
		elif agent.role == NpcDB.ROLE_OFFICER:
			have_officers += 1
		else:
			have_civilians += 1

	for i in maxi(0, want_customers - have_customers):
		_spawn_customer(district_id)
	for i in maxi(0, want_officers - have_officers):
		_spawn_officer(district_id)
	var want_civilians := int(round(5.0 * float(district.get("footfall", 0.6))))
	for i in maxi(0, want_civilians - have_civilians):
		_spawn_civilian(district_id)


## Typed view over the pool so call sites keep their autocomplete.
func _agents() -> Array:
	return npc_pool.members if npc_pool != null else []


func _take_from_pool() -> NpcAgent:
	return npc_pool.acquire() as NpcAgent if npc_pool != null else null


func _safe_spawn_near(target: Vector3) -> Vector3:
	var node_id := graph.nearest(target, "walk")
	var pos := graph.position_of(node_id) if node_id >= 0 else target
	return Vector3(pos.x, 0.1, pos.z)


func _spawn_point_away_from_player(district_id: String) -> Vector3:
	for attempt in 8:
		var node_id := graph.random_node_in(district_id)
		if node_id < 0:
			return Vector3.ZERO
		var pos := graph.position_of(node_id)
		var d := pos.distance_to(player.global_position)
		if d > 16.0 and d < _active_radius:
			return Vector3(pos.x, 0.1, pos.z)
	return Vector3.ZERO


func _spawn_customer(district_id: String) -> void:
	var agent := _take_from_pool()
	if agent == null:
		return
	var pos := _spawn_point_away_from_player(district_id)
	if pos == Vector3.ZERO:
		return
	_customer_counter += 1
	var profile := CustomerProfile.generate(district_id, "cust_%d" % _customer_counter)
	# Returning customers: reuse a remembered profile from this district.
	var pool: Array = _customers.get(district_id, [])
	if not pool.is_empty() and randf() < 0.45:
		profile = pool[randi() % pool.size()]
	else:
		pool.append(profile)
		if pool.size() > 12:
			pool.pop_front()
		_customers[district_id] = pool

	agent.global_position = pos
	agent.configure({
		"id": profile.id, "name": profile.display_name, "role": NpcDB.ROLE_CUSTOMER,
		"district": district_id, "color": profile.color, "height": randf_range(1.6, 1.9),
		"named": false, "customer": profile,
		"schedule": [{"hour": 0, "poi": "", "action": "wander"}],
	}, graph, player)


func _spawn_officer(district_id: String) -> void:
	var agent := _take_from_pool()
	if agent == null:
		return
	var pos := _spawn_point_away_from_player(district_id)
	if pos == Vector3.ZERO:
		return
	agent.global_position = pos
	agent.configure({
		"id": "officer_%d" % randi(), "name": "Bureau Officer", "role": NpcDB.ROLE_OFFICER,
		"district": district_id, "color": Color(0.30, 0.42, 0.68), "height": 1.8,
		"named": false,
		"schedule": [{"hour": 0, "poi": "", "action": "patrol"}],
	}, graph, player)


func _spawn_civilian(district_id: String) -> void:
	var agent := _take_from_pool()
	if agent == null:
		return
	var pos := _spawn_point_away_from_player(district_id)
	if pos == Vector3.ZERO:
		return
	var first := NpcDB.first_names()
	var last := NpcDB.last_names()
	agent.global_position = pos
	agent.configure({
		"id": "civ_%d" % randi(),
		"name": "%s %s" % [first[randi() % first.size()], last[randi() % last.size()]],
		"role": NpcDB.ROLE_CIVILIAN, "district": district_id,
		"color": Color.from_hsv(randf(), 0.22, 0.7), "height": randf_range(1.6, 1.92),
		"named": false,
		"schedule": [{"hour": 0, "poi": "", "action": "wander"}],
	}, graph, player)


# ===========================================================================
# VEHICLES
# ===========================================================================

func _spawn_owned_vehicles() -> void:
	for record in GameState.owned_vehicles:
		var v := Vehicle.new()
		add_child(v)
		v.setup(String(record.get("type", "kestrel_van")), String(record.get("id", "v0")), true)
		var pos_arr: Array = record.get("pos", [30.0, 0.6, 40.0])
		v.global_position = Vector3(pos_arr[0], maxf(pos_arr[1], 0.6), pos_arr[2])
		v.rotation.y = float(record.get("yaw", 0.0))
		if record.has("storage"):
			v.storage.from_dict(record["storage"])
		_vehicles.append(v)


## Teo's forecourt always has stock so the shop has something to look at.
func _spawn_dealer_vehicles() -> void:
	var forecourt := GameData.poi_position("fuel_stop", Vector3(206, 0, 96))
	var types := VehicleDB.ids()
	for i in mini(3, types.size()):
		var v := Vehicle.new()
		add_child(v)
		v.setup(String(types[i]), "dealer_%d" % i, false)
		v.global_position = forecourt + Vector3(-8.0 + i * 6.0, 0.6, 10.0)
		v.rotation.y = deg_to_rad(90.0)
		_vehicles.append(v)


## Called after buying: places the new vehicle on the forecourt and marks it
## owned so the player can drive it away.
func deliver_vehicle(type_id: String) -> Vehicle:
	var forecourt := GameData.poi_position("fuel_stop", Vector3(206, 0, 96))
	var unique := "veh_%d" % (GameState.owned_vehicles.size() + 1)
	var v := Vehicle.new()
	add_child(v)
	v.setup(type_id, unique, true)
	v.global_position = forecourt + Vector3(randf_range(-4.0, 4.0), 0.6, 16.0)
	_vehicles.append(v)
	GameState.owned_vehicles.append({
		"id": unique, "type": type_id,
		"pos": [v.global_position.x, v.global_position.y, v.global_position.z],
		"yaw": 0.0, "storage": {},
	})
	GameState.set_flag("owns_vehicle")
	return v


func nearest_owned_vehicle() -> Vehicle:
	var best: Vehicle = null
	var best_d := INF
	for v in _vehicles:
		if not v.owned:
			continue
		var d := v.global_position.distance_to(player.global_position)
		if d < best_d:
			best_d = d
			best = v
	return best


# ===========================================================================
# TICKS
# ===========================================================================

func _on_hour_passed(_day: int, _hour: int) -> void:
	BusinessService.tick_hour()
	_update_environment()


func _on_day_passed(_day: int) -> void:
	BusinessService.settle_day()


func _refresh_property_stations() -> void:
	if city == null:
		return
	for pid in city.interiors():
		var holder: Node3D = city.interiors()[pid]
		var fittings := holder.get_node_or_null("Fittings")
		if fittings == null:
			continue
		var prop: PropertyState = GameState.get_property(pid)
		var active := 0
		if prop != null and prop.owned:
			prop.sync_stations()
			active = prop.stations.size()
		for i in 5:
			var slot := fittings.get_node_or_null("Station%d" % i)
			if slot != null:
				slot.visible = i < active
				for child in slot.get_children():
					if child is WorkstationInteractable:
						(child as WorkstationInteractable).enabled = i < active


func _on_screen_requested(screen_id: String, payload: Dictionary) -> void:
	match screen_id:
		"spawn_pickups":
			if city != null:
				city.spawn_event_pickups(String(payload.get("district", "dockside")), 5)
		"spawn_quest_item":
			_spawn_quest_item(payload)
		"sleep":
			_sleep_until_morning()
		"respawn":
			_respawn_player()


## Places a story item in the world so a "recover the X" objective has an X.
func _spawn_quest_item(payload: Dictionary) -> void:
	if city == null:
		return
	var item_id := String(payload.get("item", ""))
	if item_id == "" or not GameData.items.has(item_id):
		return
	var poi := String(payload.get("poi", ""))
	var base := GameData.poi_position(poi, DistrictDB.center_of(GameState.current_district))
	var off: Array = payload.get("offset", [0.0, 0.0, 0.0])
	var pos := base + Vector3(float(off[0]), 0.0, float(off[2]))
	city.spawn_pickup(Vector3(pos.x, 0.0, pos.z), item_id, 1, -1.0)


func _sleep_until_morning() -> void:
	var hours := 0.0
	if GameState.hour < 7.0:
		hours = 7.0 - GameState.hour
	else:
		hours = 24.0 - GameState.hour + 7.0
	# Run the world forward an hour at a time so production and wages resolve.
	for i in int(ceil(hours)):
		GameState.hour += 1.0
		if GameState.hour >= 24.0:
			GameState.hour -= 24.0
			GameState.day += 1
			EventBus.day_passed.emit(GameState.day)
		EventBus.hour_passed.emit(GameState.day, int(GameState.hour))
	GameState.hour = 7.0
	player.heal(GameConfig.HEALTH_MAX)
	player.restore_stamina(GameConfig.STAMINA_MAX)
	EnforcementService.clear_wanted(0.6)
	EventBus.toast_requested.emit("You slept until morning", "good")
	SaveService.save_game(GameConfig.AUTOSAVE_SLOT, true)


func _respawn_player() -> void:
	var target := SPAWN_POINT
	for p in GameState.all_owned_properties():
		target = GameData.property(p.id)["position"] + Vector3(0, 1.2, 4.0)
		break
	player.teleport(target)
	EventBus.toast_requested.emit("You woke up somewhere safe", "warn")


# ===========================================================================
# SAVE / LOAD
# ===========================================================================

func to_dict() -> Dictionary:
	var vehicles: Array = []
	for v in _vehicles:
		if v.owned:
			vehicles.append(v.to_dict())
	var customers := {}
	for did in _customers:
		var arr: Array = []
		for c in _customers[did]:
			arr.append((c as CustomerProfile).to_dict())
		customers[did] = arr
	return {
		"vehicles": vehicles,
		"customers": customers,
		"customer_counter": _customer_counter,
	}


func _restore_world_state() -> void:
	var data := SaveService.take_pending_world()
	if data.is_empty():
		return
	_customer_counter = int(data.get("customer_counter", 0))
	var customers: Dictionary = data.get("customers", {})
	for did in customers:
		var arr: Array[CustomerProfile] = []
		for raw in customers[did]:
			arr.append(CustomerProfile.from_dict(raw))
		_customers[did] = arr
	# Owned vehicle positions come back through GameState.owned_vehicles, which
	# _spawn_owned_vehicles reads immediately after this call.
	var saved_vehicles: Array = data.get("vehicles", [])
	for sv in saved_vehicles:
		for record in GameState.owned_vehicles:
			if String(record.get("id", "")) == String(sv.get("instance_id", "")):
				record["pos"] = sv.get("pos", record.get("pos"))
				record["yaw"] = sv.get("yaw", 0.0)
				record["storage"] = sv.get("storage", {})


func _exit_tree() -> void:
	SaveService.unregister_world()
