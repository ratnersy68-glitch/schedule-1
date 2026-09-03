class_name CityBuilder
extends RefCounted
## Procedural generator for Cobalt Bay.
##
## The city is a 3x2 grid of 120m districts sitting on a bay to the north.
## Roads run every 60m; the space between them is divided into blocks that are
## filled with district-appropriate buildings. Named landmarks and player
## properties are reserved first so generated filler never covers them.
##
## Rendering strategy: repeated geometry (buildings, windows, props, road
## markings) goes into per-district MultiMeshInstance3D nodes so the whole city
## draws in a handful of calls. Collision is a small number of StaticBody3D
## nodes holding many box shapes. Interiors, doors and interactables are real
## nodes because the player touches them.

const CELL := DistrictDB.CELL_SIZE
const ROAD_WIDTH := 9.0
const PAVEMENT := 3.0
const BLOCK_MARGIN := 2.5

## Road centre lines.
const ROAD_X := [10.0, 60.0, 120.0, 180.0, 240.0, 300.0, 350.0]
const ROAD_Z := [10.0, 60.0, 120.0, 180.0, 230.0]

var root: Node3D
var graph: CityGraph
var rng := RandomNumberGenerator.new()

var _reserved: Array[Rect2] = []
var _building_boxes: Array = []      ## per district: [{xform, color}]
var _window_boxes: Array = []
var _prop_boxes: Array = []
var _colliders: Dictionary = {}      ## district -> StaticBody3D
var _emissive_nodes: Array[MultiMeshInstance3D] = []
var _interiors: Dictionary = {}      ## property_id -> Node3D
var _occluders: Node3D = null
var _occluder_count := 0

## Occlusion culling only pays for itself when the occluders are large and few.
## Small props would cost more to rasterise than they save.
const OCCLUDER_MIN_HEIGHT := 11.0
const OCCLUDER_MIN_FOOTPRINT := 55.0
const OCCLUDER_BUDGET := 70

## Named places placed before filler. Position is the building centre.
const LANDMARKS := [
	{"id": "pier3", "name": "Pier 3", "district": "dockside",
		"pos": Vector3(20, 0, 12), "size": Vector3(16, 3, 10), "kind": "pier"},
	{"id": "dock_gate", "name": "Dock Gate", "district": "dockside",
		"pos": Vector3(78, 0, 24), "size": Vector3(10, 5, 4), "kind": "gate"},
	{"id": "pell_store", "name": "Pell's Corner Supply", "district": "dockside",
		"pos": Vector3(100, 0, 42), "size": Vector3(14, 5, 12), "kind": "shop"},
	{"id": "gull_cafe", "name": "The Gull", "district": "dockside",
		"pos": Vector3(32, 0, 92), "size": Vector3(13, 4.5, 11), "kind": "cafe"},
	{"id": "scrapyard", "name": "Halloran Scrap", "district": "dockside",
		"pos": Vector3(94, 0, 96), "size": Vector3(20, 4, 18), "kind": "yard"},
	{"id": "foundry_gate", "name": "Foundry Gate", "district": "ironworks",
		"pos": Vector3(138, 0, 92), "size": Vector3(12, 6, 6), "kind": "gate"},
	{"id": "unit_row", "name": "Sang Repairs", "district": "ironworks",
		"pos": Vector3(212, 0, 40), "size": Vector3(15, 5.5, 13), "kind": "shop"},
	{"id": "fuel_stop", "name": "Marchetti Fuel & Motors", "district": "ironworks",
		"pos": Vector3(206, 0, 96), "size": Vector3(20, 5, 14), "kind": "fuel"},
	{"id": "old_town_square", "name": "Kestrel Square", "district": "old_town",
		"pos": Vector3(325, 0, 33), "size": Vector3(18, 1, 18), "kind": "plaza"},
	{"id": "laundry", "name": "Rows Laundry", "district": "old_town",
		"pos": Vector3(328, 0, 94), "size": Vector3(12, 5, 11), "kind": "shop"},
	{"id": "market_arcade", "name": "Row Arcade", "district": "market_row",
		"pos": Vector3(92, 0, 150), "size": Vector3(22, 7, 16), "kind": "arcade"},
	{"id": "row_diner", "name": "Nine Bells Diner", "district": "market_row",
		"pos": Vector3(33, 0, 208), "size": Vector3(14, 5, 12), "kind": "cafe"},
	{"id": "csb_hq", "name": "Civic Standards Bureau", "district": "meridian",
		"pos": Vector3(150, 0, 206), "size": Vector3(24, 14, 18), "kind": "police"},
	{"id": "tower_plaza", "name": "Meridian Plaza", "district": "meridian",
		"pos": Vector3(210, 0, 150), "size": Vector3(20, 1, 20), "kind": "plaza"},
	{"id": "meridian_bank", "name": "Bay Mutual", "district": "meridian",
		"pos": Vector3(150, 0, 150), "size": Vector3(18, 22, 16), "kind": "bank"},
	{"id": "hill_park", "name": "Hillcrest Green", "district": "hillcrest",
		"pos": Vector3(268, 0, 150), "size": Vector3(26, 1, 22), "kind": "park"},
	{"id": "country_club", "name": "The Hill Club", "district": "hillcrest",
		"pos": Vector3(328, 0, 214), "size": Vector3(20, 7, 16), "kind": "club"},
]


## Interiors keyed by property id, so the world manager can show and hide
## station fittings as a property is upgraded.
func interiors() -> Dictionary:
	return _interiors


func build(parent: Node3D, seed_value: int) -> Dictionary:
	root = parent
	rng.seed = seed_value
	graph = CityGraph.new()
	_reserved.clear()
	_interiors.clear()
	_emissive_nodes.clear()

	_reset_buffers()
	_occluder_count = 0
	_occluders = Node3D.new()
	_occluders.name = "Occluders"
	root.add_child(_occluders)
	_build_ground()
	_build_roads()
	_build_graph()
	_reserve_all()
	_place_landmarks()
	_place_properties()
	_fill_blocks()
	_place_street_props()
	_flush_multimeshes()
	_build_scavenge_points()

	return {"graph": graph, "interiors": _interiors, "emissive": _emissive_nodes}


func _reset_buffers() -> void:
	_building_boxes = []
	_window_boxes = []
	_prop_boxes = []
	for i in DistrictDB.ids().size():
		_building_boxes.append([])
		_window_boxes.append([])
		_prop_boxes.append([])


func _district_index(district_id: String) -> int:
	return DistrictDB.CELL_MAP.find(district_id)


func _collider_for(district_id: String) -> StaticBody3D:
	if _colliders.has(district_id):
		return _colliders[district_id]
	var body := StaticBody3D.new()
	body.name = "Collision_" + district_id
	body.collision_layer = 1
	body.collision_mask = 0
	root.add_child(body)
	_colliders[district_id] = body
	return body


# ===========================================================================
# GROUND, WATER, ROADS
# ===========================================================================

func _build_ground() -> void:
	var w := DistrictDB.GRID_COLS * CELL
	var d := DistrictDB.GRID_ROWS * CELL

	var ground := MeshFactory.box_node(Vector3(w + 120.0, 2.0, d + 120.0), Color(0.14, 0.15, 0.16))
	ground.position = Vector3(w * 0.5, -1.0, d * 0.5)
	ground.name = "Ground"
	root.add_child(ground)

	var body := StaticBody3D.new()
	body.name = "GroundCollision"
	body.collision_layer = 1
	MeshFactory.add_box_collider(body, Vector3(w * 0.5, -1.0, d * 0.5),
		Vector3(w + 120.0, 2.0, d + 120.0))
	root.add_child(body)

	# The bay, north of z = 0.
	var water := MeshFactory.box_node(Vector3(w + 200.0, 1.0, 160.0), Color(0.05, 0.13, 0.19))
	water.material_override = MeshFactory.water()
	water.position = Vector3(w * 0.5, -0.9, -82.0)
	water.name = "Bay"
	root.add_child(water)

	# Quay wall so the player cannot walk into the bay.
	var wall := StaticBody3D.new()
	wall.collision_layer = 1
	MeshFactory.add_box_collider(wall, Vector3(w * 0.5, 1.0, -1.5), Vector3(w + 200.0, 6.0, 3.0))
	# Outer city limits.
	MeshFactory.add_box_collider(wall, Vector3(-2.0, 6.0, d * 0.5), Vector3(4.0, 14.0, d + 20.0))
	MeshFactory.add_box_collider(wall, Vector3(w + 2.0, 6.0, d * 0.5), Vector3(4.0, 14.0, d + 20.0))
	MeshFactory.add_box_collider(wall, Vector3(w * 0.5, 6.0, d + 2.0), Vector3(w + 20.0, 14.0, 4.0))
	root.add_child(wall)

	# A low seawall you can see.
	var seawall := MeshFactory.box_node(Vector3(w + 40.0, 1.4, 2.0), Color(0.28, 0.29, 0.30))
	seawall.position = Vector3(w * 0.5, 0.7, -1.4)
	root.add_child(seawall)

	# Far hills so the skyline is not empty.
	for i in 14:
		var hx := rng.randf_range(-80.0, w + 80.0)
		var hz := d + rng.randf_range(60.0, 190.0)
		var hh := rng.randf_range(18.0, 52.0)
		var hill := MeshFactory.box_node(
			Vector3(rng.randf_range(40.0, 90.0), hh, rng.randf_range(40.0, 80.0)),
			Color(0.10, 0.13, 0.16).lerp(Color(0.16, 0.19, 0.23), rng.randf()))
		hill.position = Vector3(hx, hh * 0.5 - 4.0, hz)
		hill.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		root.add_child(hill)


func _build_roads() -> void:
	var w := DistrictDB.GRID_COLS * CELL
	var d := DistrictDB.GRID_ROWS * CELL
	var asphalt := Color(0.10, 0.105, 0.115)
	var kerb := Color(0.30, 0.31, 0.32)

	var roads := Node3D.new()
	roads.name = "Roads"
	root.add_child(roads)

	for z in ROAD_Z:
		var strip := MeshFactory.box_node(Vector3(w + 20.0, 0.12, ROAD_WIDTH), asphalt, 0.95)
		strip.position = Vector3(w * 0.5, 0.06, z)
		strip.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		roads.add_child(strip)
		for side: float in [-1.0, 1.0]:
			var pave := MeshFactory.box_node(Vector3(w + 20.0, 0.22, PAVEMENT), kerb, 0.95)
			pave.position = Vector3(w * 0.5, 0.11, z + side * (ROAD_WIDTH * 0.5 + PAVEMENT * 0.5))
			pave.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			roads.add_child(pave)

	for x in ROAD_X:
		var strip2 := MeshFactory.box_node(Vector3(ROAD_WIDTH, 0.12, d + 20.0), asphalt, 0.95)
		strip2.position = Vector3(x, 0.06, d * 0.5)
		strip2.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		roads.add_child(strip2)
		for side2: float in [-1.0, 1.0]:
			var pave2 := MeshFactory.box_node(Vector3(PAVEMENT, 0.22, d + 20.0), kerb, 0.95)
			pave2.position = Vector3(x + side2 * (ROAD_WIDTH * 0.5 + PAVEMENT * 0.5), 0.11, d * 0.5)
			pave2.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			roads.add_child(pave2)

	_build_lane_markings(roads, w, d)


func _build_lane_markings(parent: Node3D, w: float, d: float) -> void:
	var marks: Array = []
	for z in ROAD_Z:
		var x := 4.0
		while x < w:
			marks.append(Transform3D(Basis().scaled(Vector3(2.4, 0.02, 0.22)),
				Vector3(x, 0.14, z)))
			x += 8.0
	for x2 in ROAD_X:
		var z2 := 4.0
		while z2 < d:
			marks.append(Transform3D(Basis().scaled(Vector3(0.22, 0.02, 2.4)),
				Vector3(x2, 0.14, z2)))
			z2 += 8.0
	var node := MeshFactory.multimesh_node("LaneMarkings", MeshFactory.unit_box(),
		MeshFactory.vertex_colored(0.85), marks.size(), false)
	for i in marks.size():
		node.multimesh.set_instance_transform(i, marks[i])
		node.multimesh.set_instance_color(i, Color(0.62, 0.60, 0.52))
	parent.add_child(node)


# ===========================================================================
# NAVIGATION GRAPH
# ===========================================================================

func _build_graph() -> void:
	var pavement_offset := ROAD_WIDTH * 0.5 + PAVEMENT * 0.5
	var walk_rows := {}     # z -> {x -> node_id}

	# Pedestrian nodes: both pavements of every road, every 10 metres.
	for z in ROAD_Z:
		for side: float in [-1.0, 1.0]:
			var pz: float = z + side * pavement_offset
			var row := {}
			var x := 6.0
			var prev := -1
			while x <= DistrictDB.GRID_COLS * CELL - 6.0:
				var pos := Vector3(x, 0.25, pz)
				var id := graph.add_node(pos, DistrictDB.district_at(pos), "walk")
				row[x] = id
				if prev >= 0:
					graph.link(prev, id)
				prev = id
				x += 10.0
			walk_rows[pz] = row

	for x2 in ROAD_X:
		for side2: float in [-1.0, 1.0]:
			var px: float = x2 + side2 * pavement_offset
			var prev2 := -1
			var z2 := 6.0
			while z2 <= DistrictDB.GRID_ROWS * CELL - 6.0:
				var pos2 := Vector3(px, 0.25, z2)
				var id2 := graph.add_node(pos2, DistrictDB.district_at(pos2), "walk")
				if prev2 >= 0:
					graph.link(prev2, id2)
				prev2 = id2
				# Stitch this column into any pavement row it crosses.
				for pz2 in walk_rows.keys():
					if absf(float(pz2) - z2) < 5.5:
						var row2: Dictionary = walk_rows[pz2]
						var best_x := -1.0
						for rx in row2.keys():
							if absf(float(rx) - px) < 6.0:
								best_x = float(rx)
								break
						if best_x >= 0.0:
							graph.link(id2, int(row2[best_x]))
				z2 += 10.0

	# Vehicle nodes: road centre lines, every 12 metres, linked into a grid.
	var road_rows := {}
	for z3 in ROAD_Z:
		var prev3 := -1
		var x3 := 4.0
		var row3 := {}
		while x3 <= DistrictDB.GRID_COLS * CELL - 4.0:
			var pos3 := Vector3(x3, 0.35, z3)
			var id3 := graph.add_node(pos3, DistrictDB.district_at(pos3), "road")
			row3[x3] = id3
			if prev3 >= 0:
				graph.link(prev3, id3)
			prev3 = id3
			x3 += 12.0
		road_rows[z3] = row3

	for x4 in ROAD_X:
		var prev4 := -1
		var z4 := 4.0
		while z4 <= DistrictDB.GRID_ROWS * CELL - 4.0:
			var pos4 := Vector3(x4, 0.35, z4)
			var id4 := graph.add_node(pos4, DistrictDB.district_at(pos4), "road")
			if prev4 >= 0:
				graph.link(prev4, id4)
			prev4 = id4
			for rz in road_rows.keys():
				if absf(float(rz) - z4) < 6.5:
					var row4: Dictionary = road_rows[rz]
					for rx4 in row4.keys():
						if absf(float(rx4) - x4) < 7.0:
							graph.link(id4, int(row4[rx4]))
							break
			z4 += 12.0


# ===========================================================================
# RESERVATIONS, LANDMARKS AND PROPERTIES
# ===========================================================================

func _reserve(center: Vector3, size: Vector3) -> void:
	_reserved.append(Rect2(
		center.x - size.x * 0.5 - BLOCK_MARGIN,
		center.z - size.z * 0.5 - BLOCK_MARGIN,
		size.x + BLOCK_MARGIN * 2.0,
		size.z + BLOCK_MARGIN * 2.0))


func _is_reserved(center: Vector3, size: Vector3) -> bool:
	var r := Rect2(center.x - size.x * 0.5, center.z - size.z * 0.5, size.x, size.z)
	for other in _reserved:
		if other.intersects(r):
			return true
	return false


func _reserve_all() -> void:
	for lm in LANDMARKS:
		_reserve(lm["pos"], lm["size"])
	for pid in GameData.properties:
		var p: Dictionary = GameData.property(pid)
		var fp: Vector2 = p["footprint"]
		_reserve(p["position"], Vector3(fp.x, 4.0, fp.y))
	# Keep roads clear.
	for z in ROAD_Z:
		_reserved.append(Rect2(-20.0, z - ROAD_WIDTH * 0.5 - PAVEMENT - 1.0,
			DistrictDB.GRID_COLS * CELL + 40.0, ROAD_WIDTH + PAVEMENT * 2.0 + 2.0))
	for x in ROAD_X:
		_reserved.append(Rect2(x - ROAD_WIDTH * 0.5 - PAVEMENT - 1.0, -20.0,
			ROAD_WIDTH + PAVEMENT * 2.0 + 2.0, DistrictDB.GRID_ROWS * CELL + 40.0))


func _place_landmarks() -> void:
	for lm in LANDMARKS:
		var district: String = lm["district"]
		var pos: Vector3 = lm["pos"]
		var size: Vector3 = lm["size"]
		var kind: String = lm["kind"]
		GameData.register_poi(lm["id"], lm["name"], pos + Vector3(0, 0.2, size.z * 0.5 + 2.5),
			district, kind)
		match kind:
			"plaza", "park":
				_build_open_space(district, pos, size, kind)
			"pier":
				_build_pier(district, pos, size)
			"gate":
				_build_gate(district, pos, size)
			"fuel":
				_build_fuel_station(district, pos, size)
			"yard":
				_build_scrapyard(district, pos, size)
			_:
				_build_landmark_building(district, pos, size, kind, String(lm["name"]))
		_add_sign(pos + Vector3(0, size.y + 0.9, size.z * 0.5 + 0.2), String(lm["name"]),
			Color(GameData.district(district).get("accent", Color.WHITE)))


func _build_landmark_building(district: String, pos: Vector3, size: Vector3,
		kind: String, _label: String) -> void:
	var palette: Array = GameData.district(district).get("palette", [Color(0.3, 0.3, 0.3)])
	var color: Color = palette[rng.randi() % palette.size()]
	if kind == "police":
		color = Color(0.20, 0.26, 0.40)
	elif kind == "bank":
		color = Color(0.24, 0.26, 0.32)
	_push_building(district, pos + Vector3(0, size.y * 0.5, 0), size, color)
	_add_windows(district, pos, size, color)
	MeshFactory.add_box_collider(_collider_for(district), pos + Vector3(0, size.y * 0.5, 0), size)

	# A visible entrance porch so the player can find the door.
	var porch := MeshFactory.box_node(Vector3(minf(size.x * 0.5, 5.0), 0.35, 2.4),
		Color(0.32, 0.33, 0.35))
	porch.position = pos + Vector3(0, 0.18, size.z * 0.5 + 1.2)
	root.add_child(porch)


func _build_open_space(district: String, pos: Vector3, size: Vector3, kind: String) -> void:
	var color := Color(0.22, 0.30, 0.22) if kind == "park" else Color(0.34, 0.34, 0.36)
	var slab := MeshFactory.box_node(Vector3(size.x, 0.2, size.z), color)
	slab.position = pos + Vector3(0, 0.1, 0)
	slab.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	root.add_child(slab)
	if kind == "park":
		for i in 7:
			var tx := pos.x + rng.randf_range(-size.x * 0.4, size.x * 0.4)
			var tz := pos.z + rng.randf_range(-size.z * 0.4, size.z * 0.4)
			_add_tree(district, Vector3(tx, 0.0, tz))
	else:
		# A civic sculpture: three stacked, slowly glowing prisms.
		for i in 3:
			var h := 2.4 - i * 0.5
			_push_prop(district, Vector3(pos.x, 1.0 + i * 1.6, pos.z),
				Vector3(1.6 - i * 0.35, h, 1.6 - i * 0.35),
				Color(0.35, 0.7, 0.95), rng.randf() * TAU)
		_push_window(district, Vector3(pos.x, 5.4, pos.z), Vector3(0.7, 0.7, 0.7),
			Color(0.4, 0.85, 1.0))


func _build_pier(district: String, pos: Vector3, size: Vector3) -> void:
	var deck := MeshFactory.box_node(Vector3(size.x, 0.5, size.z + 16.0), Color(0.31, 0.26, 0.21))
	deck.position = pos + Vector3(0, 0.25, -8.0)
	root.add_child(deck)
	MeshFactory.add_box_collider(_collider_for(district), pos + Vector3(0, 0.25, -8.0),
		Vector3(size.x, 0.5, size.z + 16.0))
	for i in 6:
		var px := pos.x - size.x * 0.4 + i * (size.x * 0.8 / 5.0)
		_push_prop(district, Vector3(px, 0.6, pos.z - 15.0), Vector3(0.5, 1.2, 0.5),
			Color(0.24, 0.20, 0.16), 0.0)
	# Stacked containers, the visual signature of Dockside.
	var container_colors := [Color(0.55, 0.24, 0.20), Color(0.20, 0.42, 0.48),
		Color(0.50, 0.45, 0.18), Color(0.28, 0.40, 0.28)]
	for i in 9:
		var cx := pos.x + rng.randf_range(-4.0, 26.0)
		var cz := pos.z + rng.randf_range(4.0, 22.0)
		var stack := rng.randi_range(1, 2)
		for s in stack:
			var csize := Vector3(6.0, 2.6, 2.6)
			var center := Vector3(cx, 1.3 + s * 2.6, cz)
			if _is_reserved(center, csize):
				continue
			_push_building(district, center, csize,
				container_colors[rng.randi() % container_colors.size()])
			MeshFactory.add_box_collider(_collider_for(district), center, csize)


func _build_gate(district: String, pos: Vector3, size: Vector3) -> void:
	for side: float in [-1.0, 1.0]:
		var post_pos := pos + Vector3(side * size.x * 0.5, size.y * 0.5, 0)
		_push_building(district, post_pos, Vector3(0.9, size.y, 0.9), Color(0.28, 0.29, 0.30))
		MeshFactory.add_box_collider(_collider_for(district), post_pos, Vector3(0.9, size.y, 0.9))
	_push_building(district, pos + Vector3(0, size.y - 0.4, 0),
		Vector3(size.x, 0.8, 0.7), Color(0.24, 0.25, 0.26))


func _build_fuel_station(district: String, pos: Vector3, size: Vector3) -> void:
	var canopy := MeshFactory.box_node(Vector3(size.x, 0.6, size.z), Color(0.72, 0.66, 0.30))
	canopy.position = pos + Vector3(0, 5.0, 0)
	root.add_child(canopy)
	MeshFactory.add_box_collider(_collider_for(district), pos + Vector3(0, 5.0, 0),
		Vector3(size.x, 0.6, size.z))
	for side: float in [-1.0, 1.0]:
		var col := Vector3(pos.x + side * (size.x * 0.5 - 1.0), 2.5, pos.z)
		_push_building(district, col, Vector3(0.6, 5.0, 0.6), Color(0.5, 0.5, 0.52))
		MeshFactory.add_box_collider(_collider_for(district), col, Vector3(0.6, 5.0, 0.6))
	for i in 2:
		var pump := Vector3(pos.x - 3.0 + i * 6.0, 0.9, pos.z)
		_push_prop(district, pump, Vector3(0.8, 1.8, 1.2), Color(0.8, 0.3, 0.22), 0.0)
		MeshFactory.add_box_collider(_collider_for(district), pump, Vector3(0.8, 1.8, 1.2))
	var kiosk := pos + Vector3(0, 1.8, -size.z * 0.5 - 3.0)
	_push_building(district, kiosk, Vector3(7.0, 3.6, 5.0), Color(0.36, 0.38, 0.40))
	MeshFactory.add_box_collider(_collider_for(district), kiosk, Vector3(7.0, 3.6, 5.0))


func _build_scrapyard(district: String, pos: Vector3, size: Vector3) -> void:
	# Fence.
	for side: float in [-1.0, 1.0]:
		var fz := pos + Vector3(0, 1.4, side * size.z * 0.5)
		_push_prop(district, fz, Vector3(size.x, 2.8, 0.15), Color(0.30, 0.28, 0.24), 0.0)
		MeshFactory.add_box_collider(_collider_for(district), fz, Vector3(size.x, 2.8, 0.15))
		var fx := pos + Vector3(side * size.x * 0.5, 1.4, 0)
		_push_prop(district, fx, Vector3(0.15, 2.8, size.z), Color(0.30, 0.28, 0.24), 0.0)
		MeshFactory.add_box_collider(_collider_for(district), fx, Vector3(0.15, 2.8, size.z))
	for i in 12:
		var p := pos + Vector3(rng.randf_range(-7.0, 7.0), rng.randf_range(0.4, 2.2),
			rng.randf_range(-6.0, 6.0))
		_push_prop(district, p, Vector3(rng.randf_range(1.0, 2.6), rng.randf_range(0.6, 1.6),
			rng.randf_range(1.0, 2.4)), Color(0.34, 0.30, 0.26).lerp(Color(0.5, 0.32, 0.2),
			rng.randf()), rng.randf() * TAU)


func _place_properties() -> void:
	for pid in PropertyDB.ids():
		var def: Dictionary = GameData.property(pid)
		_build_property(pid, def)


func _build_property(pid: String, def: Dictionary) -> void:
	var district: String = def["district"]
	var pos: Vector3 = def["position"]
	var fp: Vector2 = def["footprint"]
	var height: float = def["interior_height"]
	var yaw := deg_to_rad(float(def.get("rotation_deg", 0.0)))

	var holder := Node3D.new()
	holder.name = "Property_" + pid
	holder.position = pos
	holder.rotation.y = yaw
	root.add_child(holder)

	var palette: Array = GameData.district(district).get("palette", [Color(0.3, 0.3, 0.3)])
	var shell_color: Color = (palette[0] as Color).lightened(0.06)
	_build_hollow_shell(holder, Vector3(fp.x, height, fp.y), shell_color, pid)

	# Facade glazing is batched in world space, so it has to use the rotated
	# footprint rather than the local one.
	var quarter := int(round(float(def.get("rotation_deg", 0.0)) / 90.0)) % 4
	var world_size := Vector3(fp.x, height, fp.y)
	if quarter == 1 or quarter == 3:
		world_size = Vector3(fp.y, height, fp.x)
	_add_windows(district, pos, world_size, shell_color)
	_build_interior_fittings(holder, pid, Vector3(fp.x, height, fp.y))
	_interiors[pid] = holder

	# Exterior board / for-sale sign beside the door.
	var board := PropertyBoardInteractable.new()
	board.property_id = pid
	board.display_name = String(def.get("name", pid))
	var board_shape := CollisionShape3D.new()
	var bs := BoxShape3D.new()
	bs.size = Vector3(1.4, 1.6, 0.4)
	board_shape.shape = bs
	board.add_child(board_shape)
	board.position = Vector3(fp.x * 0.5 - 1.2, 1.4, fp.y * 0.5 + 0.6)
	holder.add_child(board)

	var board_mesh := MeshFactory.box_node(Vector3(1.3, 1.5, 0.12),
		Color(0.85, 0.82, 0.72) if not GameState.owns_property(pid) else Color(0.3, 0.55, 0.45))
	board_mesh.position = board.position + Vector3(0, 0, 0.1)
	holder.add_child(board_mesh)

	GameData.register_poi(pid, String(def.get("name", pid)),
		pos + Vector3(0, 0.2, fp.y * 0.5 + 3.0), district, "property")


## A walk-in box: floor, ceiling, four walls with a doorway gap in the front.
func _build_hollow_shell(holder: Node3D, size: Vector3, color: Color,
		owner_property: String = "") -> void:
	var t := 0.35              # wall thickness
	var door_w := 2.2
	var body := StaticBody3D.new()
	body.collision_layer = 1
	holder.add_child(body)

	var floor_mesh := MeshFactory.box_node(Vector3(size.x, t, size.z), color.darkened(0.35))
	floor_mesh.position = Vector3(0, t * 0.5, 0)
	holder.add_child(floor_mesh)
	MeshFactory.add_box_collider(body, Vector3(0, t * 0.5, 0), Vector3(size.x, t, size.z))

	var roof := MeshFactory.box_node(Vector3(size.x + 0.6, t, size.z + 0.6), color.darkened(0.15))
	roof.position = Vector3(0, size.y, 0)
	holder.add_child(roof)
	MeshFactory.add_box_collider(body, Vector3(0, size.y, 0),
		Vector3(size.x + 0.6, t, size.z + 0.6))

	# Back and side walls.
	_wall(holder, body, Vector3(0, size.y * 0.5, -size.z * 0.5), Vector3(size.x, size.y, t), color)
	_wall(holder, body, Vector3(-size.x * 0.5, size.y * 0.5, 0), Vector3(t, size.y, size.z), color)
	_wall(holder, body, Vector3(size.x * 0.5, size.y * 0.5, 0), Vector3(t, size.y, size.z), color)

	# Front wall in two pieces with a doorway between them.
	var side_w := (size.x - door_w) * 0.5
	for side: float in [-1.0, 1.0]:
		var cx := side * (door_w * 0.5 + side_w * 0.5)
		_wall(holder, body, Vector3(cx, size.y * 0.5, size.z * 0.5),
			Vector3(side_w, size.y, t), color)
	# Lintel above the door.
	_wall(holder, body, Vector3(0, size.y - 0.6, size.z * 0.5),
		Vector3(door_w, 1.2, t), color)

	_add_door(holder, Vector3(-door_w * 0.5 + 0.05, 0, size.z * 0.5), door_w, size.y - 1.2,
		owner_property)

	# Interior light so the inside is readable at any hour.
	var lamp := OmniLight3D.new()
	lamp.position = Vector3(0, size.y - 0.6, 0)
	lamp.light_color = Color(1.0, 0.93, 0.82)
	lamp.light_energy = 1.5
	lamp.omni_range = maxf(size.x, size.z) * 1.3
	lamp.shadow_enabled = false
	holder.add_child(lamp)


func _wall(holder: Node3D, body: StaticBody3D, center: Vector3, size: Vector3, color: Color) -> void:
	var mesh := MeshFactory.box_node(size, color)
	mesh.position = center
	holder.add_child(mesh)
	MeshFactory.add_box_collider(body, center, size)


func _add_door(holder: Node3D, hinge_local: Vector3, width: float, height: float,
		owner_property: String = "") -> void:
	var pivot := Node3D.new()
	pivot.name = "DoorPivot"
	pivot.position = hinge_local
	holder.add_child(pivot)

	var leaf := MeshFactory.box_node(Vector3(width - 0.1, height, 0.1), Color(0.36, 0.28, 0.22))
	leaf.position = Vector3((width - 0.1) * 0.5, height * 0.5, 0)
	pivot.add_child(leaf)

	var door_body := StaticBody3D.new()
	door_body.collision_layer = 1
	MeshFactory.add_box_collider(door_body, Vector3((width - 0.1) * 0.5, height * 0.5, 0),
		Vector3(width - 0.1, height, 0.12))
	pivot.add_child(door_body)

	var interact := DoorInteractable.new()
	interact.bind_leaf(pivot)
	if owner_property != "":
		# A property you have not bought is somebody else's locked front door.
		interact.requires_property = owner_property
		interact.lock_message = "Locked. You do not own this yet."
	var cs := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = Vector3(width, height, 1.2)
	cs.shape = shape
	interact.add_child(cs)
	interact.position = Vector3(width * 0.5, height * 0.5, 0.1)
	pivot.add_child(interact)


func _build_interior_fittings(holder: Node3D, pid: String, size: Vector3) -> void:
	var fittings := Node3D.new()
	fittings.name = "Fittings"
	holder.add_child(fittings)

	# Up to five benches along the back wall; the property state decides how
	# many are actually active, refreshed whenever it is upgraded.
	for i in 5:
		var slot := Node3D.new()
		slot.name = "Station%d" % i
		var span := size.x - 3.0
		var x := -span * 0.5 + span * (float(i) + 0.5) / 5.0
		slot.position = Vector3(x, 0.0, -size.z * 0.5 + 1.6)
		fittings.add_child(slot)

		var bench := MeshFactory.box_node(Vector3(1.7, 0.95, 1.0), Color(0.33, 0.35, 0.38), 0.7)
		bench.position = Vector3(0, 0.48, 0)
		slot.add_child(bench)
		var rig := MeshFactory.box_node(Vector3(0.9, 0.7, 0.5), Color(0.22, 0.35, 0.42), 0.5)
		rig.position = Vector3(0, 1.28, -0.15)
		slot.add_child(rig)
		var glow := MeshFactory.box_node(Vector3(0.5, 0.12, 0.3), Color(0.4, 0.85, 1.0))
		var gm := StandardMaterial3D.new()
		gm.albedo_color = Color(0.4, 0.85, 1.0)
		gm.emission_enabled = true
		gm.emission = Color(0.4, 0.85, 1.0)
		gm.emission_energy_multiplier = 2.2
		glow.material_override = gm
		glow.position = Vector3(0, 1.66, -0.15)
		slot.add_child(glow)

		var ws := WorkstationInteractable.new()
		ws.property_id = pid
		ws.station_index = i
		var cs := CollisionShape3D.new()
		var shape := BoxShape3D.new()
		shape.size = Vector3(1.9, 1.9, 1.4)
		cs.shape = shape
		ws.add_child(cs)
		ws.position = Vector3(0, 1.0, 0.3)
		slot.add_child(ws)

		var sbody := StaticBody3D.new()
		sbody.collision_layer = 1
		MeshFactory.add_box_collider(sbody, Vector3(0, 0.48, 0), Vector3(1.7, 0.95, 1.0))
		slot.add_child(sbody)

	# Storage shelving on the left wall.
	var shelf_root := Node3D.new()
	shelf_root.position = Vector3(-size.x * 0.5 + 1.0, 0, size.z * 0.25)
	fittings.add_child(shelf_root)
	var shelf := MeshFactory.box_node(Vector3(1.1, 2.1, 3.2), Color(0.30, 0.28, 0.26), 0.85)
	shelf.position = Vector3(0, 1.05, 0)
	shelf_root.add_child(shelf)
	var shelf_body := StaticBody3D.new()
	shelf_body.collision_layer = 1
	MeshFactory.add_box_collider(shelf_body, Vector3(0, 1.05, 0), Vector3(1.1, 2.1, 3.2))
	shelf_root.add_child(shelf_body)

	var store := StorageInteractable.new()
	store.property_id = pid
	var scs := CollisionShape3D.new()
	var sshape := BoxShape3D.new()
	sshape.size = Vector3(1.8, 2.2, 3.4)
	scs.shape = sshape
	store.add_child(scs)
	store.position = Vector3(0.6, 1.1, 0)
	shelf_root.add_child(store)

	# A bed in anything you could plausibly sleep in.
	if size.x >= 10.0:
		var bed_root := Node3D.new()
		bed_root.position = Vector3(size.x * 0.5 - 1.8, 0, -size.z * 0.25)
		fittings.add_child(bed_root)
		var bed := MeshFactory.box_node(Vector3(1.5, 0.5, 2.4), Color(0.35, 0.31, 0.34), 0.9)
		bed.position = Vector3(0, 0.3, 0)
		bed_root.add_child(bed)
		var bed_body := StaticBody3D.new()
		bed_body.collision_layer = 1
		MeshFactory.add_box_collider(bed_body, Vector3(0, 0.3, 0), Vector3(1.5, 0.5, 2.4))
		bed_root.add_child(bed_body)
		var bi := BedInteractable.new()
		bi.property_id = pid
		var bcs := CollisionShape3D.new()
		var bshape := BoxShape3D.new()
		bshape.size = Vector3(1.8, 1.4, 2.6)
		bcs.shape = bshape
		bi.add_child(bcs)
		bi.position = Vector3(0, 0.7, 0)
		bed_root.add_child(bi)


# ===========================================================================
# GENERATED FILLER
# ===========================================================================

func _fill_blocks() -> void:
	for i in range(ROAD_X.size() - 1):
		for j in range(ROAD_Z.size() - 1):
			var x0: float = ROAD_X[i] + ROAD_WIDTH * 0.5 + PAVEMENT
			var x1: float = ROAD_X[i + 1] - ROAD_WIDTH * 0.5 - PAVEMENT
			var z0: float = ROAD_Z[j] + ROAD_WIDTH * 0.5 + PAVEMENT
			var z1: float = ROAD_Z[j + 1] - ROAD_WIDTH * 0.5 - PAVEMENT
			if x1 - x0 < 8.0 or z1 - z0 < 8.0:
				continue
			var center := Vector3((x0 + x1) * 0.5, 0.0, (z0 + z1) * 0.5)
			var district := DistrictDB.district_at(center)
			_fill_block(district, x0, x1, z0, z1)


func _fill_block(district: String, x0: float, x1: float, z0: float, z1: float) -> void:
	var style := String(GameData.district(district).get("style", "downtown"))
	var palette: Array = GameData.district(district).get("palette", [Color(0.3, 0.3, 0.3)])
	var cols := 2
	var rows := 2
	match style:
		"residential_old":
			cols = 4
			rows = 2
		"suburb":
			cols = 2
			rows = 2
		"downtown":
			cols = 2
			rows = 2
		"industrial", "industrial_port":
			cols = 2
			rows = 1
		"shopping":
			cols = 3
			rows = 2

	var cw := (x1 - x0) / float(cols)
	var ch := (z1 - z0) / float(rows)
	for i in cols:
		for j in rows:
			var pad := 1.6
			var w := cw - pad * 2.0
			var d := ch - pad * 2.0
			if w < 4.0 or d < 4.0:
				continue
			var cx := x0 + cw * (i + 0.5)
			var cz := z0 + ch * (j + 0.5)
			var height := _height_for(style)
			if style == "suburb":
				w *= 0.62
				d *= 0.62
			var center := Vector3(cx, 0.0, cz)
			var size := Vector3(w, height, d)
			if _is_reserved(center, size):
				continue
			var color: Color = (palette[rng.randi() % palette.size()] as Color).lerp(
				Color(0.5, 0.5, 0.52), rng.randf() * 0.25)
			_push_building(district, center + Vector3(0, height * 0.5, 0), size, color)
			MeshFactory.add_box_collider(_collider_for(district),
				center + Vector3(0, height * 0.5, 0), size)
			_add_windows(district, center, size, color)
			_add_roof_detail(district, center, size, style)
			if style == "suburb":
				_add_garden(district, center, Vector3(cw - 2.0, 0.2, ch - 2.0))


func _height_for(style: String) -> float:
	match style:
		"downtown":
			return rng.randf_range(22.0, 48.0)
		"residential_old":
			return rng.randf_range(9.0, 13.0)
		"suburb":
			return rng.randf_range(5.5, 8.0)
		"industrial":
			return rng.randf_range(8.0, 16.0)
		"industrial_port":
			return rng.randf_range(6.0, 12.0)
		"shopping":
			return rng.randf_range(8.0, 14.0)
		_:
			return rng.randf_range(9.0, 18.0)


func _add_roof_detail(district: String, center: Vector3, size: Vector3, style: String) -> void:
	match style:
		"downtown":
			_push_building(district, center + Vector3(0, size.y + 1.2, 0),
				Vector3(size.x * 0.35, 2.4, size.z * 0.35), Color(0.18, 0.20, 0.24))
			# Aircraft warning light.
			_push_window(district, center + Vector3(0, size.y + 2.8, 0),
				Vector3(0.5, 0.5, 0.5), Color(1.0, 0.25, 0.2))
		"industrial", "industrial_port":
			for i in 2:
				var vx := center.x + rng.randf_range(-size.x * 0.3, size.x * 0.3)
				var vz := center.z + rng.randf_range(-size.z * 0.3, size.z * 0.3)
				_push_building(district, Vector3(vx, size.y + 1.6, vz),
					Vector3(1.0, 3.2, 1.0), Color(0.30, 0.28, 0.26))
		"residential_old":
			_push_building(district, center + Vector3(0, size.y + 0.4, 0),
				Vector3(size.x + 0.7, 0.8, size.z + 0.7), Color(0.22, 0.19, 0.20))
		"suburb":
			_push_building(district, center + Vector3(0, size.y + 0.9, 0),
				Vector3(size.x + 0.8, 1.8, size.z + 0.8), Color(0.28, 0.22, 0.21))


func _add_garden(district: String, center: Vector3, size: Vector3) -> void:
	var lawn := MeshFactory.box_node(Vector3(size.x, 0.16, size.z), Color(0.20, 0.30, 0.20))
	lawn.position = center + Vector3(0, 0.08, 0)
	lawn.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	root.add_child(lawn)
	if rng.randf() < 0.7:
		_add_tree(district, center + Vector3(rng.randf_range(-size.x * 0.35, size.x * 0.35), 0,
			size.z * 0.38))


func _add_tree(district: String, pos: Vector3) -> void:
	_push_prop(district, pos + Vector3(0, 1.1, 0), Vector3(0.35, 2.2, 0.35),
		Color(0.26, 0.20, 0.15), 0.0)
	_push_prop(district, pos + Vector3(0, 3.0, 0), Vector3(2.6, 2.4, 2.6),
		Color(0.18, 0.34, 0.20).lerp(Color(0.26, 0.42, 0.22), rng.randf()), rng.randf() * TAU)


## Facade windows as instanced quads-in-boxes, coloured warm so they read as
## occupied at night.
func _add_windows(district: String, base: Vector3, size: Vector3, wall_color: Color) -> void:
	var floors := int(size.y / 3.2)
	if floors <= 0:
		return
	var per_side := clampi(int(size.x / 3.0), 1, 6)
	for f in floors:
		var y := 2.0 + f * 3.2
		if y > size.y - 1.0:
			break
		for i in per_side:
			var lit := rng.randf() < 0.55
			var tint := Color(1.0, 0.86, 0.62) if lit else wall_color.darkened(0.55)
			var wx := base.x - size.x * 0.4 + size.x * 0.8 * (float(i) + 0.5) / float(per_side)
			_push_window(district, Vector3(wx, y, base.z + size.z * 0.5 + 0.06),
				Vector3(1.2, 1.5, 0.08), tint)
			_push_window(district, Vector3(wx, y, base.z - size.z * 0.5 - 0.06),
				Vector3(1.2, 1.5, 0.08), tint)
		var per_end := clampi(int(size.z / 3.5), 1, 4)
		for k in per_end:
			var lit2 := rng.randf() < 0.45
			var tint2 := Color(0.95, 0.84, 0.66) if lit2 else wall_color.darkened(0.55)
			var wz := base.z - size.z * 0.4 + size.z * 0.8 * (float(k) + 0.5) / float(per_end)
			_push_window(district, Vector3(base.x + size.x * 0.5 + 0.06, y, wz),
				Vector3(0.08, 1.5, 1.2), tint2)
			_push_window(district, Vector3(base.x - size.x * 0.5 - 0.06, y, wz),
				Vector3(0.08, 1.5, 1.2), tint2)


func _add_sign(pos: Vector3, text: String, color: Color) -> void:
	var label := Label3D.new()
	label.text = text
	label.font_size = 48
	label.pixel_size = 0.006
	label.modulate = color
	label.outline_size = 10
	label.outline_modulate = Color(0.02, 0.03, 0.05, 0.9)
	label.billboard = BaseMaterial3D.BILLBOARD_DISABLED
	label.double_sided = true
	label.position = pos
	label.no_depth_test = false
	label.visibility_range_end = 70.0
	root.add_child(label)


# ===========================================================================
# STREET FURNITURE
# ===========================================================================

func _place_street_props() -> void:
	var offset := ROAD_WIDTH * 0.5 + PAVEMENT * 0.5
	for z in ROAD_Z:
		for side: float in [-1.0, 1.0]:
			var pz: float = z + side * offset
			var x := 14.0
			while x < DistrictDB.GRID_COLS * CELL - 10.0:
				var pos := Vector3(x, 0.0, pz)
				_street_lamp(DistrictDB.district_at(pos), pos)
				if rng.randf() < 0.28:
					_small_prop(DistrictDB.district_at(pos), pos + Vector3(rng.randf_range(-3, 3), 0, 0))
				x += 24.0
	for x2 in ROAD_X:
		for side2: float in [-1.0, 1.0]:
			var px: float = x2 + side2 * offset
			var z2 := 20.0
			while z2 < DistrictDB.GRID_ROWS * CELL - 10.0:
				var pos2 := Vector3(px, 0.0, z2)
				_street_lamp(DistrictDB.district_at(pos2), pos2)
				if rng.randf() < 0.24:
					_small_prop(DistrictDB.district_at(pos2), pos2 + Vector3(0, 0, rng.randf_range(-3, 3)))
				z2 += 26.0


func _street_lamp(district: String, pos: Vector3) -> void:
	_push_prop(district, pos + Vector3(0, 2.4, 0), Vector3(0.18, 4.8, 0.18),
		Color(0.22, 0.23, 0.25), 0.0)
	var accent: Color = GameData.district(district).get("accent", Color(1.0, 0.85, 0.6))
	_push_window(district, pos + Vector3(0, 4.85, 0), Vector3(0.55, 0.28, 0.55),
		accent.lerp(Color(1.0, 0.92, 0.75), 0.55))


func _small_prop(district: String, pos: Vector3) -> void:
	var roll := rng.randf()
	if roll < 0.4:
		_push_prop(district, pos + Vector3(0, 0.55, 0), Vector3(0.7, 1.1, 0.7),
			Color(0.24, 0.28, 0.26), rng.randf() * TAU)     # litter bin
	elif roll < 0.7:
		_push_prop(district, pos + Vector3(0, 0.45, 0), Vector3(1.9, 0.15, 0.6),
			Color(0.34, 0.27, 0.20), rng.randf() * TAU)     # bench seat
		_push_prop(district, pos + Vector3(0, 0.22, 0), Vector3(1.7, 0.45, 0.12),
			Color(0.25, 0.26, 0.27), rng.randf() * TAU)
	else:
		_push_prop(district, pos + Vector3(0, 0.9, 0), Vector3(0.14, 1.8, 0.14),
			Color(0.3, 0.31, 0.33), 0.0)                    # sign post
		_push_prop(district, pos + Vector3(0, 1.85, 0), Vector3(0.8, 0.35, 0.06),
			Color(0.55, 0.58, 0.62), 0.0)


## Free materials scattered in service alleys: the earliest source of income.
func _build_scavenge_points() -> void:
	var spots := [
		Vector3(70, 0, 46), Vector3(46, 0, 78), Vector3(104, 0, 78), Vector3(24, 0, 46),
		Vector3(148, 0, 34), Vector3(196, 0, 74), Vector3(232, 0, 46),
		Vector3(268, 0, 82), Vector3(312, 0, 70), Vector3(346, 0, 44),
		Vector3(88, 0, 194), Vector3(36, 0, 146), Vector3(142, 0, 178),
		Vector3(226, 0, 196), Vector3(292, 0, 168), Vector3(340, 0, 148),
	]
	var pool := ["scrap_bundle", "scrap_bundle", "ferro_silt", "tide_ash", "binder_resin"]
	for spot in spots:
		var item: String = pool[rng.randi() % pool.size()]
		spawn_pickup(spot, item, rng.randi_range(1, 3), 8.0)


## Drops a loose item in the world. Public so missions and world events can
## place things the player has to physically go and collect.
func spawn_pickup(pos: Vector3, item_id: String, amount: int, respawn_hours: float) -> void:
	var holder := Node3D.new()
	holder.position = pos + Vector3(0, 0.35, 0)
	root.add_child(holder)

	var mesh := MeshFactory.box_node(Vector3(0.55, 0.45, 0.55), GameData.item_color(item_id), 0.8)
	holder.add_child(mesh)

	var pickup := PickupInteractable.new()
	pickup.configure(item_id, amount)
	pickup.respawn_hours = respawn_hours
	pickup.bind_visual(mesh)
	var cs := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = Vector3(1.1, 1.1, 1.1)
	cs.shape = shape
	pickup.add_child(cs)
	holder.add_child(pickup)


## Public entry point used by the "shipment in" world event.
func spawn_event_pickups(district_id: String, count: int) -> void:
	var pool := ["ferro_silt", "bloomspore", "chromatic_salt", "binder_resin",
		"cryo_gel", "harbor_solvent"]
	for i in count:
		var node_id := graph.random_node_in(district_id)
		if node_id < 0:
			continue
		var pos := graph.position_of(node_id) + Vector3(rng.randf_range(-2, 2), 0,
			rng.randf_range(-2, 2))
		spawn_pickup(Vector3(pos.x, 0.0, pos.z), pool[rng.randi() % pool.size()],
			rng.randi_range(1, 3), -1.0)


# ===========================================================================
# MULTIMESH BUFFERS
# ===========================================================================

func _push_building(district: String, center: Vector3, size: Vector3, color: Color) -> void:
	var idx := _district_index(district)
	if idx < 0:
		return
	_building_boxes[idx].append({
		"xform": Transform3D(Basis().scaled(size), center), "color": color})
	_maybe_add_occluder(center, size)


## Big solid volumes become occluders so the renderer can skip whatever stands
## behind them - the single biggest win in a dense district.
func _maybe_add_occluder(center: Vector3, size: Vector3) -> void:
	if _occluder_count >= OCCLUDER_BUDGET:
		return
	if size.y < OCCLUDER_MIN_HEIGHT or size.x * size.z < OCCLUDER_MIN_FOOTPRINT:
		return
	var shape := BoxOccluder3D.new()
	# Shrink slightly so an occluder never pokes through its own facade.
	shape.size = Vector3(maxf(size.x - 0.6, 0.5), maxf(size.y - 0.6, 0.5),
		maxf(size.z - 0.6, 0.5))
	var node := OccluderInstance3D.new()
	node.occluder = shape
	node.position = center
	_occluders.add_child(node)
	_occluder_count += 1


func occluder_count() -> int:
	return _occluder_count


func _push_window(district: String, center: Vector3, size: Vector3, color: Color) -> void:
	var idx := _district_index(district)
	if idx < 0:
		return
	_window_boxes[idx].append({
		"xform": Transform3D(Basis().scaled(size), center), "color": color})


func _push_prop(district: String, center: Vector3, size: Vector3, color: Color, yaw: float) -> void:
	var idx := _district_index(district)
	if idx < 0:
		return
	_prop_boxes[idx].append({
		"xform": Transform3D(Basis(Vector3.UP, yaw).scaled(size), center), "color": color})


func _flush_multimeshes() -> void:
	var ids := DistrictDB.ids()
	for i in ids.size():
		var district: String = ids[i]
		_flush_group("Buildings_" + district, _building_boxes[i],
			MeshFactory.vertex_colored(0.92), true, 0.0)
		var glow_node := _flush_group("Windows_" + district, _window_boxes[i],
			MeshFactory.emissive(1.6, "windows"), false, 0.0)
		if glow_node != null:
			_emissive_nodes.append(glow_node)
		_flush_group("Props_" + district, _prop_boxes[i],
			MeshFactory.vertex_colored(0.9), true, 110.0)


func _flush_group(node_name: String, entries: Array, material: Material,
		shadows: bool, cull_distance: float) -> MultiMeshInstance3D:
	if entries.is_empty():
		return null
	var node := MeshFactory.multimesh_node(node_name, MeshFactory.unit_box(), material,
		entries.size(), shadows)
	for i in entries.size():
		node.multimesh.set_instance_transform(i, entries[i]["xform"])
		node.multimesh.set_instance_color(i, entries[i]["color"])
	if cull_distance > 0.0:
		node.visibility_range_end = cull_distance
		node.visibility_range_end_margin = 12.0
	root.add_child(node)
	return node
