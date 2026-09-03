class_name MapView
extends Control
## Static top-down city map drawn from the same data the world is built from.


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_process(true)


func _process(_delta: float) -> void:
	queue_redraw()


func _to_map(world: Vector3) -> Vector2:
	var w := DistrictDB.GRID_COLS * DistrictDB.CELL_SIZE
	var d := DistrictDB.GRID_ROWS * DistrictDB.CELL_SIZE
	var scale := minf(size.x / w, size.y / d)
	var offset := Vector2((size.x - w * scale) * 0.5, (size.y - d * scale) * 0.5)
	return offset + Vector2(world.x, world.z) * scale


func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, size), UIKit.BG)

	for did in DistrictDB.CELL_MAP:
		var cell := DistrictDB.cell_of(String(did))
		var p0 := _to_map(Vector3(cell.x * DistrictDB.CELL_SIZE, 0, cell.y * DistrictDB.CELL_SIZE))
		var p1 := _to_map(Vector3((cell.x + 1) * DistrictDB.CELL_SIZE, 0,
			(cell.y + 1) * DistrictDB.CELL_SIZE))
		var col: Color = GameData.district(String(did)).get("palette", [UIKit.BG_PANEL])[0]
		if not GameState.district_unlocked(String(did)):
			col = col.darkened(0.65)
		draw_rect(Rect2(p0, p1 - p0), Color(col.r, col.g, col.b, 0.85))
		draw_rect(Rect2(p0, p1 - p0), UIKit.LINE, false, 1.0)
		var font := ThemeDB.fallback_font
		draw_string(font, p0 + Vector2(8, 18), String(GameData.district_name(String(did))),
			HORIZONTAL_ALIGNMENT_LEFT, -1, 12,
			UIKit.TEXT if GameState.district_unlocked(String(did)) else UIKit.TEXT_FAINT)

	var road_col := Color(0.20, 0.22, 0.26, 0.9)
	for z in CityBuilder.ROAD_Z:
		draw_line(_to_map(Vector3(0, 0, z)),
			_to_map(Vector3(DistrictDB.GRID_COLS * DistrictDB.CELL_SIZE, 0, z)), road_col, 1.5)
	for x in CityBuilder.ROAD_X:
		draw_line(_to_map(Vector3(x, 0, 0)),
			_to_map(Vector3(x, 0, DistrictDB.GRID_ROWS * DistrictDB.CELL_SIZE)), road_col, 1.5)

	# Points of interest.
	for poi_id in GameData.pois:
		var poi: Dictionary = GameData.pois[poi_id]
		if not GameState.district_unlocked(String(poi["district"])):
			continue
		var p := _to_map(poi["pos"])
		var kind := String(poi.get("kind", "poi"))
		var col2 := UIKit.TEXT_FAINT
		if kind == "property":
			col2 = UIKit.GOOD if GameState.owns_property(String(poi_id)) else UIKit.WARN
		elif kind == "police":
			col2 = UIKit.BAD
		elif kind == "shop" or kind == "fuel":
			col2 = UIKit.ACCENT
		draw_circle(p, 3.5, col2)

	# The player.
	var player := get_tree().get_first_node_in_group("player") if is_inside_tree() else null
	if player != null:
		var pp := _to_map(player.global_position)
		draw_circle(pp, 5.0, UIKit.ACCENT)
		draw_arc(pp, 8.0, 0.0, TAU, 20, UIKit.ACCENT, 1.5, true)
