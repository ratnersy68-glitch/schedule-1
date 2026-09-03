class_name DistrictDB
extends RefCounted
## The six districts of Cobalt Bay.
##
## Districts drive the economy (wealth, demand), enforcement (patrol density,
## heat), city generation (grid cell, palette, block style) and progression
## (unlock gates). The city is a 3x2 grid of 120m cells; the bay is to the
## north (negative Z), so the top row is waterfront.

const CELL_SIZE := 120.0
const GRID_COLS := 3
const GRID_ROWS := 2


static func data() -> Dictionary:
	return {
		"dockside": {
			"name": "Dockside",
			"tagline": "Containers, gull noise, and nobody asking questions.",
			"cell": Vector2i(0, 0),
			"wealth": 0.25,          # affects how much customers will pay
			"footfall": 0.55,        # how many customers spawn
			"patrol": 0.35,          # police density multiplier
			"heat_gain": 0.8,        # how fast heat accrues here
			"heat_decay": 1.35,      # how fast it bleeds off
			"style": "industrial_port",
			"palette": [Color(0.20, 0.24, 0.29), Color(0.26, 0.31, 0.34), Color(0.16, 0.30, 0.34)],
			"accent": Color(0.30, 0.75, 0.85),
			"demand": {"pale_shard": 1.25, "cobalt_bloom": 0.85, "aurora_prism": 0.45,
				"solar_halo": 0.2, "midnight_veil": 0.1},
			"unlocked": true,
			"unlock_note": "",
		},
		"ironworks": {
			"name": "Ironworks Flats",
			"tagline": "Three shifts a day and a skyline of vent stacks.",
			"cell": Vector2i(1, 0),
			"wealth": 0.38,
			"footfall": 0.7,
			"patrol": 0.5,
			"heat_gain": 1.0,
			"heat_decay": 1.1,
			"style": "industrial",
			"palette": [Color(0.28, 0.24, 0.22), Color(0.34, 0.30, 0.26), Color(0.40, 0.26, 0.20)],
			"accent": Color(0.95, 0.55, 0.22),
			"demand": {"pale_shard": 1.1, "cobalt_bloom": 1.15, "aurora_prism": 0.7,
				"solar_halo": 0.35, "midnight_veil": 0.15},
			"unlocked": true,
			"unlock_note": "",
		},
		"old_town": {
			"name": "Old Town Rows",
			"tagline": "Terraces, washing lines, and long memories.",
			"cell": Vector2i(2, 0),
			"wealth": 0.45,
			"footfall": 0.85,
			"patrol": 0.6,
			"heat_gain": 1.05,
			"heat_decay": 1.0,
			"style": "residential_old",
			"palette": [Color(0.36, 0.28, 0.26), Color(0.44, 0.34, 0.30), Color(0.30, 0.26, 0.30)],
			"accent": Color(0.95, 0.75, 0.45),
			"demand": {"pale_shard": 1.0, "cobalt_bloom": 1.25, "aurora_prism": 0.9,
				"solar_halo": 0.5, "midnight_veil": 0.2},
			"unlocked": false,
			"unlock_note": "Reach Dockside standing 25.",
		},
		"market_row": {
			"name": "Market Row",
			"tagline": "Awnings, hard bargains, and a stall for everything.",
			"cell": Vector2i(0, 1),
			"wealth": 0.55,
			"footfall": 1.15,
			"patrol": 0.75,
			"heat_gain": 1.15,
			"heat_decay": 1.0,
			"style": "shopping",
			"palette": [Color(0.32, 0.30, 0.36), Color(0.42, 0.36, 0.42), Color(0.28, 0.34, 0.40)],
			"accent": Color(0.98, 0.35, 0.55),
			"demand": {"pale_shard": 0.95, "cobalt_bloom": 1.2, "aurora_prism": 1.15,
				"solar_halo": 0.75, "midnight_veil": 0.35},
			"unlocked": false,
			"unlock_note": "Complete 'Rows and Whispers'.",
		},
		"meridian": {
			"name": "Meridian Core",
			"tagline": "Glass towers, private security, and the Bureau's front door.",
			"cell": Vector2i(1, 1),
			"wealth": 0.85,
			"footfall": 1.3,
			"patrol": 1.35,
			"heat_gain": 1.5,
			"heat_decay": 0.75,
			"style": "downtown",
			"palette": [Color(0.20, 0.24, 0.34), Color(0.26, 0.31, 0.44), Color(0.18, 0.22, 0.30)],
			"accent": Color(0.35, 0.65, 1.0),
			"demand": {"pale_shard": 0.6, "cobalt_bloom": 1.0, "aurora_prism": 1.35,
				"solar_halo": 1.3, "midnight_veil": 0.9},
			"unlocked": false,
			"unlock_note": "Own two properties and reach level 8.",
		},
		"hillcrest": {
			"name": "Hillcrest",
			"tagline": "Hedges, motion lights, and money that pretends it is quiet.",
			"cell": Vector2i(2, 1),
			"wealth": 1.0,
			"footfall": 0.6,
			"patrol": 1.1,
			"heat_gain": 1.35,
			"heat_decay": 0.85,
			"style": "suburb",
			"palette": [Color(0.26, 0.34, 0.28), Color(0.34, 0.42, 0.34), Color(0.40, 0.40, 0.36)],
			"accent": Color(0.70, 0.95, 0.60),
			"demand": {"pale_shard": 0.45, "cobalt_bloom": 0.8, "aurora_prism": 1.3,
				"solar_halo": 1.45, "midnight_veil": 1.2},
			"unlocked": false,
			"unlock_note": "Complete 'The Quiet Side of the Hill'.",
		},
	}


static func ids() -> PackedStringArray:
	return PackedStringArray(["dockside", "ironworks", "old_town", "market_row", "meridian", "hillcrest"])


## Row-major grid lookup: index = cell.y * GRID_COLS + cell.x.
## Kept as a const so the per-frame district test never rebuilds the table.
const CELL_MAP := ["dockside", "ironworks", "old_town", "market_row", "meridian", "hillcrest"]


static func cell_of(district_id: String) -> Vector2i:
	var idx := CELL_MAP.find(district_id)
	if idx < 0:
		return Vector2i.ZERO
	return Vector2i(idx % GRID_COLS, idx / GRID_COLS)


## World-space centre of a district cell.
static func center_of(district_id: String) -> Vector3:
	var c := cell_of(district_id)
	return Vector3((c.x + 0.5) * CELL_SIZE, 0.0, (c.y + 0.5) * CELL_SIZE)


## Which district contains a world position (clamped to the grid).
static func district_at(pos: Vector3) -> String:
	var cx := clampi(int(floor(pos.x / CELL_SIZE)), 0, GRID_COLS - 1)
	var cz := clampi(int(floor(pos.z / CELL_SIZE)), 0, GRID_ROWS - 1)
	return CELL_MAP[cz * GRID_COLS + cx]


static func world_bounds() -> AABB:
	return AABB(Vector3.ZERO, Vector3(GRID_COLS * CELL_SIZE, 40.0, GRID_ROWS * CELL_SIZE))
