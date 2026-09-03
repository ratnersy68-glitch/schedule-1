extends Node
## Read-only content registry.
##
## Loads every static database once at boot and exposes cached dictionaries.
## Gameplay code should always read content through GameData rather than
## calling the *_DB static functions repeatedly - those rebuild their tables
## on every call, which is fine at boot and wasteful in a frame loop.

var items: Dictionary = {}
var recipes: Dictionary = {}
var additives: Dictionary = {}
var districts: Dictionary = {}
var properties: Dictionary = {}
var npcs: Dictionary = {}
var missions: Dictionary = {}
var skills: Dictionary = {}
var vehicles: Dictionary = {}
var dialogue: Dictionary = {}
var customer_archetypes: Dictionary = {}
var employee_archetypes: Dictionary = {}
var random_events: Array = []
var endgames: Dictionary = {}

var product_ids: PackedStringArray = PackedStringArray()
var packaging_ids: PackedStringArray = PackedStringArray()
var district_ids: PackedStringArray = PackedStringArray()

## Points of interest are registered by the city builder at world load so that
## schedules, missions and the map can all refer to places by id.
var pois: Dictionary = {}       # poi_id -> {name, pos: Vector3, district, kind}


func _ready() -> void:
	items = ItemDB.data()
	recipes = RecipeDB.data()
	additives = RecipeDB.additives()
	districts = DistrictDB.data()
	properties = PropertyDB.data()
	npcs = NpcDB.named()
	missions = MissionDB.data()
	skills = SkillDB.data()
	vehicles = VehicleDB.data()
	dialogue = DialogueDB.trees()
	customer_archetypes = NpcDB.customer_archetypes()
	employee_archetypes = NpcDB.employee_archetypes()
	random_events = MissionDB.random_events()
	endgames = MissionDB.endgames()
	product_ids = ItemDB.product_ids()
	packaging_ids = ItemDB.packaging_ids()
	district_ids = DistrictDB.ids()
	_validate()


## Cheap integrity pass so a content typo fails loudly at boot instead of
## silently producing an empty shop or an unreachable mission.
func _validate() -> void:
	for rid in recipes:
		var r: Dictionary = recipes[rid]
		if not items.has(r["output"]):
			push_error("Recipe '%s' outputs unknown item '%s'" % [rid, r["output"]])
		for input_id in r["inputs"]:
			if not items.has(input_id):
				push_error("Recipe '%s' needs unknown item '%s'" % [rid, input_id])
	for pid in properties:
		var p: Dictionary = properties[pid]
		if not districts.has(p["district"]):
			push_error("Property '%s' in unknown district '%s'" % [pid, p["district"]])
	for mid in missions:
		var m: Dictionary = missions[mid]
		var nxt: String = m.get("next", "")
		if nxt != "" and not missions.has(nxt):
			push_error("Mission '%s' chains to unknown mission '%s'" % [mid, nxt])
		for obj in m.get("objectives", []):
			var it: String = obj.get("item", "")
			if it != "" and it != "any" and not items.has(it):
				push_error("Mission '%s' references unknown item '%s'" % [mid, it])
	for nid in npcs:
		var n: Dictionary = npcs[nid]
		if not districts.has(n["district"]):
			push_error("NPC '%s' in unknown district '%s'" % [nid, n["district"]])


# --- Lookup helpers --------------------------------------------------------

func item(id: String) -> Dictionary:
	return items.get(id, {})


func item_name(id: String) -> String:
	return items.get(id, {}).get("name", id)


func item_color(id: String) -> Color:
	return items.get(id, {}).get("color", Color.WHITE)


func item_icon(id: String) -> String:
	return items.get(id, {}).get("icon", "?")


func item_value(id: String) -> int:
	return int(items.get(id, {}).get("base_value", 0))


func is_contraband(id: String) -> bool:
	return bool(items.get(id, {}).get("contraband", false))


func item_heat(id: String) -> float:
	return float(items.get(id, {}).get("heat", 0.0))


func recipe(id: String) -> Dictionary:
	return recipes.get(id, {})


func district(id: String) -> Dictionary:
	return districts.get(id, {})


func district_name(id: String) -> String:
	return districts.get(id, {}).get("name", id)


func property(id: String) -> Dictionary:
	return properties.get(id, {})


func npc(id: String) -> Dictionary:
	return npcs.get(id, {})


func npc_name(id: String) -> String:
	return npcs.get(id, {}).get("name", id)


func mission(id: String) -> Dictionary:
	return missions.get(id, {})


func skill(id: String) -> Dictionary:
	return skills.get(id, {})


func vehicle(id: String) -> Dictionary:
	return vehicles.get(id, {})


# --- Points of interest ----------------------------------------------------

func register_poi(id: String, display_name: String, pos: Vector3, district_id: String,
		kind: String = "poi") -> void:
	pois[id] = {"name": display_name, "pos": pos, "district": district_id, "kind": kind}


func poi_position(id: String, fallback: Vector3 = Vector3.ZERO) -> Vector3:
	if pois.has(id):
		return pois[id]["pos"]
	return fallback


func has_poi(id: String) -> bool:
	return pois.has(id)


func pois_in_district(district_id: String) -> Array:
	var out: Array = []
	for id in pois:
		if pois[id]["district"] == district_id:
			out.append(id)
	return out


func clear_pois() -> void:
	pois.clear()
