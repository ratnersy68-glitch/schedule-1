class_name PropertyDB
extends RefCounted
## Purchasable properties and their upgrade tracks.
##
## Each property is a real building in the world with an interior. Upgrade
## tracks are independent ladders so the player chooses whether to grow
## storage, throughput, staff or security first.
##
## Track effects:
##   storage    -> +slots of on-site storage
##   production -> +station slots and +station tier
##   staff      -> +employee slots
##   security   -> raid resistance and slower on-site heat gain

const TRACKS := ["storage", "production", "staff", "security"]

const TRACK_LABELS := {
	"storage": "Storage",
	"production": "Production",
	"staff": "Staff Quarters",
	"security": "Security",
}


static func data() -> Dictionary:
	return {
		"dockside_lockup": {
			"name": "Pier 3 Lockup",
			"desc": "A rusted forty-foot container with a work light and a door that sticks. It is yours, and that matters.",
			"district": "dockside",
			"price": 0,                       # granted by the prologue
			"position": Vector3(20.0, 0.0, 26.0),
			"rotation_deg": 0.0,
			"footprint": Vector2(12.0, 7.0),
			"interior_height": 3.2,
			"daily_upkeep": 8,
			"base_storage": 30,
			"base_stations": 1,
			"base_station_tier": 1,
			"base_employees": 0,
			"base_security": 0.05,
			"sale_front": false,
			"unlock": {"type": "story", "value": "ch1_keys"},
			"upgrades": {
				"storage":    {"levels": 3, "costs": [600, 2200, 7000],    "storage": [20, 45, 90]},
				"production": {"levels": 3, "costs": [900, 3400, 11000],   "stations": [1, 2, 2], "tier": [1, 2, 2]},
				"staff":      {"levels": 2, "costs": [1500, 5200],         "employees": [1, 2]},
				"security":   {"levels": 3, "costs": [800, 2900, 8600],    "security": [0.18, 0.36, 0.55]},
			},
		},
		"rowhouse_12": {
			"name": "12 Kestrel Row",
			"desc": "A narrow terrace on Old Town's quietest street. Thin walls, deep cellar.",
			"district": "old_town",
			"price": 4800,
			"position": Vector3(272.0, 0.0, 62.0),
			"rotation_deg": 90.0,
			"footprint": Vector2(11.0, 9.0),
			"interior_height": 3.4,
			"daily_upkeep": 26,
			"base_storage": 55,
			"base_stations": 2,
			"base_station_tier": 2,
			"base_employees": 1,
			"base_security": 0.15,
			"sale_front": false,
			"unlock": {"type": "level", "value": 3},
			"upgrades": {
				"storage":    {"levels": 3, "costs": [1400, 4800, 14000],  "storage": [35, 80, 160]},
				"production": {"levels": 3, "costs": [2200, 7600, 21000],  "stations": [1, 2, 3], "tier": [2, 2, 3]},
				"staff":      {"levels": 3, "costs": [2600, 8200, 19000],  "employees": [1, 2, 3]},
				"security":   {"levels": 3, "costs": [1800, 5400, 15000],  "security": [0.2, 0.4, 0.62]},
			},
		},
		"market_stall": {
			"name": "Stall 9, Market Row",
			"desc": "A legitimate lamp-and-curio stall. Foot traffic all day and a very useful paper trail.",
			"district": "market_row",
			"price": 9600,
			"position": Vector3(44.0, 0.0, 168.0),
			"rotation_deg": 0.0,
			"footprint": Vector2(9.0, 8.0),
			"interior_height": 3.0,
			"daily_upkeep": 55,
			"base_storage": 40,
			"base_stations": 1,
			"base_station_tier": 2,
			"base_employees": 2,
			"base_security": 0.25,
			"sale_front": true,                # can sell passively through staff
			"front_rate": 0.35,                # units/hour per staffed slot
			"launder_bonus": 0.05,             # reduces launder fee
			"unlock": {"type": "district", "value": "market_row"},
			"upgrades": {
				"storage":    {"levels": 2, "costs": [2600, 8800],         "storage": [30, 70]},
				"production": {"levels": 2, "costs": [4200, 13000],        "stations": [1, 2], "tier": [2, 3]},
				"staff":      {"levels": 3, "costs": [3800, 11000, 26000], "employees": [1, 2, 4]},
				"security":   {"levels": 3, "costs": [3000, 9000, 22000],  "security": [0.2, 0.38, 0.6]},
			},
		},
		"ironworks_unit": {
			"name": "Ironworks Unit 4B",
			"desc": "A leased industrial bay. Nobody notices another humming machine on this street.",
			"district": "ironworks",
			"price": 27500,
			"position": Vector3(170.0, 0.0, 40.0),
			"rotation_deg": 0.0,
			"footprint": Vector2(18.0, 13.0),
			"interior_height": 5.0,
			"daily_upkeep": 140,
			"base_storage": 120,
			"base_stations": 3,
			"base_station_tier": 2,
			"base_employees": 3,
			"base_security": 0.2,
			"sale_front": false,
			"unlock": {"type": "level", "value": 8},
			"upgrades": {
				"storage":    {"levels": 3, "costs": [7000, 19000, 48000],  "storage": [80, 190, 380]},
				"production": {"levels": 3, "costs": [11000, 29000, 72000], "stations": [1, 2, 3], "tier": [2, 3, 3]},
				"staff":      {"levels": 3, "costs": [9000, 24000, 56000],  "employees": [2, 4, 6]},
				"security":   {"levels": 3, "costs": [8000, 21000, 51000],  "security": [0.22, 0.42, 0.68]},
			},
		},
		"hillcrest_villa": {
			"name": "Hillcrest Villa",
			"desc": "Six bedrooms, a hedge you cannot see over, and neighbours who are professionally incurious.",
			"district": "hillcrest",
			"price": 82000,
			"position": Vector3(300.0, 0.0, 186.0),
			"rotation_deg": 180.0,
			"footprint": Vector2(20.0, 15.0),
			"interior_height": 3.8,
			"daily_upkeep": 420,
			"base_storage": 150,
			"base_stations": 3,
			"base_station_tier": 3,
			"base_employees": 4,
			"base_security": 0.45,
			"sale_front": false,
			"rep_bonus": 0.15,                 # prestige: better prices citywide
			"unlock": {"type": "district", "value": "hillcrest"},
			"upgrades": {
				"storage":    {"levels": 3, "costs": [18000, 46000, 105000], "storage": [100, 240, 480]},
				"production": {"levels": 3, "costs": [26000, 64000, 148000], "stations": [1, 2, 3], "tier": [3, 3, 4]},
				"staff":      {"levels": 3, "costs": [22000, 55000, 126000], "employees": [2, 4, 8]},
				"security":   {"levels": 3, "costs": [20000, 52000, 118000], "security": [0.2, 0.38, 0.55]},
			},
		},
		"meridian_loft": {
			"name": "Meridian Sky Loft",
			"desc": "Twenty-eighth floor, floor-to-ceiling glass, and a private lift the Bureau needs a warrant to use.",
			"district": "meridian",
			"price": 168000,
			"position": Vector3(176.0, 0.0, 178.0),
			"rotation_deg": 0.0,
			"footprint": Vector2(16.0, 14.0),
			"interior_height": 4.0,
			"daily_upkeep": 780,
			"base_storage": 160,
			"base_stations": 4,
			"base_station_tier": 3,
			"base_employees": 5,
			"base_security": 0.55,
			"sale_front": false,
			"rep_bonus": 0.25,
			"influence": 0.3,                  # counts toward the City Influence ending
			"unlock": {"type": "district", "value": "meridian"},
			"upgrades": {
				"storage":    {"levels": 3, "costs": [34000, 82000, 190000], "storage": [120, 280, 560]},
				"production": {"levels": 3, "costs": [46000, 110000, 260000],"stations": [1, 2, 3], "tier": [3, 4, 4]},
				"staff":      {"levels": 3, "costs": [40000, 96000, 220000], "employees": [3, 6, 10]},
				"security":   {"levels": 3, "costs": [38000, 92000, 210000], "security": [0.18, 0.32, 0.45]},
			},
		},
		"harbor_warehouse": {
			"name": "Pier 7 Warehouse",
			"desc": "Twelve thousand square feet of bonded storage with its own crane and its own rules.",
			"district": "dockside",
			"price": 245000,
			"position": Vector3(86.0, 0.0, 34.0),
			"rotation_deg": 0.0,
			"footprint": Vector2(26.0, 18.0),
			"interior_height": 7.0,
			"daily_upkeep": 900,
			"base_storage": 400,
			"base_stations": 5,
			"base_station_tier": 3,
			"base_employees": 8,
			"base_security": 0.35,
			"sale_front": false,
			"influence": 0.35,
			"unlock": {"type": "level", "value": 18},
			"upgrades": {
				"storage":    {"levels": 3, "costs": [52000, 124000, 280000],"storage": [300, 700, 1400]},
				"production": {"levels": 3, "costs": [64000, 150000, 340000],"stations": [2, 3, 4], "tier": [3, 4, 4]},
				"staff":      {"levels": 3, "costs": [58000, 138000, 310000],"employees": [4, 8, 14]},
				"security":   {"levels": 3, "costs": [50000, 120000, 275000],"security": [0.22, 0.4, 0.6]},
			},
		},
	}


static func ids() -> PackedStringArray:
	return PackedStringArray([
		"dockside_lockup", "rowhouse_12", "market_stall", "ironworks_unit",
		"hillcrest_villa", "meridian_loft", "harbor_warehouse",
	])


## Total value of a track at a given level (levels are cumulative arrays).
static func track_value(prop_id: String, track: String, level: int, key: String, base: float) -> float:
	var p: Dictionary = data().get(prop_id, {})
	if p.is_empty():
		return base
	var up: Dictionary = p.get("upgrades", {})
	var t: Dictionary = up.get(track, {})
	var arr: Array = t.get(key, [])
	if level <= 0 or arr.is_empty():
		return base
	var idx := clampi(level - 1, 0, arr.size() - 1)
	return base + float(arr[idx])


static func track_cost(prop_id: String, track: String, next_level: int) -> int:
	var p: Dictionary = data().get(prop_id, {})
	var t: Dictionary = p.get("upgrades", {}).get(track, {})
	var costs: Array = t.get("costs", [])
	if next_level <= 0 or next_level > costs.size():
		return -1
	return int(costs[next_level - 1])


static func track_max(prop_id: String, track: String) -> int:
	var p: Dictionary = data().get(prop_id, {})
	var t: Dictionary = p.get("upgrades", {}).get(track, {})
	return int(t.get("levels", 0))
