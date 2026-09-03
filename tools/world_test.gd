extends Node
## Headless integration test: boots the real game scene and inspects the world.
##
## Run with:
##   godot --headless --path . res://scenes/dev/world_test.tscn
## Complements smoke_test.gd, which only exercises the rules layer.

var _passed := 0
var _failed := 0
var _failures: Array[String] = []
var _game: Node = null
var _world: WorldManager = null


func _ready() -> void:
	print("\n=== UNDERLIGHT world test ===\n")
	GameState.reset()
	EconomyService.reset()
	MissionService.reset()
	EnforcementService.reset()
	GameState.grant_starter_kit()

	var scene: PackedScene = load("res://scenes/world/game.tscn")
	_game = scene.instantiate()
	# The root is mid-_ready, so the add has to wait for the end of the frame.
	get_tree().root.add_child.call_deferred(_game)
	await get_tree().process_frame
	await get_tree().process_frame
	_world = _game.get_node_or_null("World")
	if _world == null:
		print("  FAIL  game scene did not instantiate")
		get_tree().quit(1)
		return
	var guard := 0
	while not _world.is_built() and guard < 900:
		await get_tree().process_frame
		guard += 1
	if not _world.is_built():
		print("  FAIL  world never finished building")
		get_tree().quit(1)
		return
	# Let a few frames of population and AI run.
	for i in 120:
		await get_tree().process_frame
	_run_checks()
	_report()


func check(label: String, condition: bool, detail: String = "") -> void:
	if condition:
		_passed += 1
		print("  ok    %s" % label)
	else:
		_failed += 1
		_failures.append(label + ("  (" + detail + ")" if detail != "" else ""))
		print("  FAIL  %s%s" % [label, "  (" + detail + ")" if detail != "" else ""])


func _run_checks() -> void:
	print("\n-- World")
	check("world manager present", _world != null)
	check("player spawned", _world.player != null and is_instance_valid(_world.player))
	check("player is above ground", _world.player.global_position.y > -1.0,
		str(_world.player.global_position))
	check("player starts in Dockside", GameState.current_district == "dockside",
		GameState.current_district)
	check("navigation graph built", _world.graph.node_count() > 400,
		str(_world.graph.node_count()))
	check("clock running", GameState.clock_running)

	print("\n-- Points of interest")
	check("POIs registered", GameData.pois.size() >= 20, str(GameData.pois.size()))
	for required in ["pier3", "gull_cafe", "pell_store", "csb_hq", "fuel_stop"]:
		check("POI " + required, GameData.has_poi(required))
	for pid in PropertyDB.ids():
		check("property placed: " + String(pid), GameData.has_poi(String(pid)))

	print("\n-- Navigation")
	var from := GameData.poi_position("gull_cafe")
	var to := GameData.poi_position("pell_store")
	var path := _world.graph.find_path(from, to, "walk")
	check("pedestrian path found", path.size() > 3, "%d hops" % path.size())
	var road_path := _world.graph.find_path(Vector3(16, 0, 20), Vector3(300, 0, 200), "road")
	check("road path across the city", road_path.size() > 10, "%d hops" % road_path.size())

	print("\n-- Population")
	var agents := get_tree().get_nodes_in_group("npc")
	var live := 0
	var named := 0
	for a in agents:
		if (a as NpcAgent).visible:
			live += 1
			if (a as NpcAgent).is_named:
				named += 1
	check("NPC pool allocated", agents.size() == GameConfig.MAX_ACTIVE_NPCS, str(agents.size()))
	check("people are out", live >= 4, str(live))
	check("named characters spawn", named >= 1, str(named))

	print("\n-- Interactables")
	var interactables := get_tree().get_nodes_in_group("interactable")
	check("interactables exist", interactables.size() > 40, str(interactables.size()))
	var kinds := {"door": 0, "workstation": 0, "storage": 0, "board": 0, "pickup": 0, "npc": 0}
	for node in interactables:
		if node is DoorInteractable:
			kinds["door"] += 1
		elif node is WorkstationInteractable:
			kinds["workstation"] += 1
		elif node is StorageInteractable:
			kinds["storage"] += 1
		elif node is PropertyBoardInteractable:
			kinds["board"] += 1
		elif node is PickupInteractable:
			kinds["pickup"] += 1
		elif node is NpcInteractable:
			kinds["npc"] += 1
	check("doors placed", kinds["door"] >= 7, str(kinds["door"]))
	check("workstations placed", kinds["workstation"] >= 30, str(kinds["workstation"]))
	check("storage placed", kinds["storage"] >= 7, str(kinds["storage"]))
	check("property boards placed", kinds["board"] >= 7, str(kinds["board"]))
	check("scavenge pickups placed", kinds["pickup"] >= 10, str(kinds["pickup"]))

	print("\n-- Property doors")
	var locked := 0
	for node in interactables:
		if node is DoorInteractable and (node as DoorInteractable).requires_property != "":
			if (node as DoorInteractable).blocked_reason() != "":
				locked += 1
	check("unowned properties are locked", locked >= 6, str(locked))

	print("\n-- Performance")
	check("NPCs come from a pool", _world.npc_pool != null and
		_world.npc_pool.size() == GameConfig.MAX_ACTIVE_NPCS)
	check("pool reports active members", _world.npc_pool.active_count() > 0,
		str(_world.npc_pool.active_count()))
	var lod_stats: Dictionary = _world.lod.stats()
	check("LOD found the building layers", int(lod_stats["buildings"]) == 6, str(lod_stats))
	check("LOD found the window layers", int(lod_stats["windows"]) == 6)
	check("LOD found the prop layers", int(lod_stats["props"]) == 6)
	check("occluders generated", _world.city.occluder_count() > 10,
		str(_world.city.occluder_count()))
	var draw_groups := 0
	for child in _world.get_children():
		if child is MultiMeshInstance3D:
			draw_groups += 1
	check("city draws from few batches", draw_groups <= 24, str(draw_groups))

	print("\n-- Vehicles")
	var vehicles := get_tree().get_nodes_in_group("vehicle")
	check("dealer stock on the forecourt", vehicles.size() >= 3, str(vehicles.size()))

	print("\n-- UI")
	var ui := _game.get_node_or_null("GameUi")
	check("game UI built", ui != null)
	if ui != null:
		check("HUD present", ui.hud != null)
		check("touch controls present", ui.touch != null)
		check("phone present", ui.phone != null)
		check("all touch buttons built", ui.touch.buttons.size() == TouchControls.BUTTONS.size())
		check("screen manager wired", ui.screens != null)

	print("\n-- Screens open and close")
	var screens: ScreenManager = _game.get_node_or_null("Screens")
	if screens != null:
		GameState.grant_property("dockside_lockup")
		for screen_id in ["inventory", "property", "storage", "production", "skills",
				"settings", "hire", "vehicles"]:
			var payload := {"property": "dockside_lockup", "station": 0}
			var screen := screens.open(screen_id, payload)
			check("screen opens: " + screen_id, screen != null)
			if screen != null:
				check("gameplay input gated by " + screen_id, not PlayerInput.gameplay_enabled)
				screen.close()
		check("input restored after closing", PlayerInput.gameplay_enabled)

	print("\n-- Live save round trip")
	check("world serialises", _world.to_dict().has("customers"))
	check("save with a live world", SaveService.save_game(3, true))
	var meta := SaveService.slot_summary(3)
	check("live save metadata", int(meta.get("day", 0)) >= 1)
	SaveService.delete_slot(3)

	print("\n-- Time skip")
	var day_before := GameState.day
	GameState.hour = 22.0
	_world._sleep_until_morning()
	check("sleeping advances the day", GameState.day == day_before + 1,
		"%d -> %d" % [day_before, GameState.day])
	check("sleeping lands at 7am", absf(GameState.hour - 7.0) < 0.01, str(GameState.hour))
	SaveService.delete_slot(GameConfig.AUTOSAVE_SLOT)


func _report() -> void:
	print("\n=== %d passed, %d failed ===" % [_passed, _failed])
	if _failed > 0:
		print("Failures:")
		for f in _failures:
			print("  - " + f)
	get_tree().quit(0 if _failed == 0 else 1)
