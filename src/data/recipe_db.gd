class_name RecipeDB
extends RefCounted
## Crafting recipes and the quality model.
##
## A recipe declares required inputs, the station family that can run it, a
## base quality score and a duration. Optional *additives* can be slotted into
## a job at run time to push quality higher at extra material cost - that is
## the core risk/reward decision of the production loop.

## Station families. A station's tier gates which recipes it can run.
const STATION_CULTIVATOR := "cultivator"
const STATION_BENCH := "lattice_bench"
const STATION_KILN := "kiln"
const STATION_PRESS := "press"

const STATION_NAMES := {
	STATION_CULTIVATOR: "Spore Cultivator",
	STATION_BENCH: "Lattice Bench",
	STATION_KILN: "Resonance Kiln",
	STATION_PRESS: "Packing Press",
}


static func data() -> Dictionary:
	return {
		"cultivate_spore": {
			"name": "Culture Bloomspore",
			"desc": "Feed ash and resin into a tray and let it thread overnight.",
			"station": STATION_CULTIVATOR, "station_tier": 1,
			"inputs": {"tide_ash": 2, "binder_resin": 1},
			"output": "bloomspore", "output_amount": 3,
			"seconds": 40.0, "base_quality": 0.30, "xp": 8,
			"unlocked_by_default": true,
		},
		"pale_shard": {
			"name": "Pale Shard Lattice",
			"desc": "The first lattice anyone in the Bay learns. Cheap, forgiving, sells itself.",
			"station": STATION_BENCH, "station_tier": 1,
			"inputs": {"ferro_silt": 2, "bloomspore": 1, "binder_resin": 1},
			"output": "pale_shard", "output_amount": 2,
			"seconds": 28.0, "base_quality": 0.34, "xp": 14,
			"unlocked_by_default": true,
		},
		"cobalt_bloom": {
			"name": "Cobalt Bloom Lattice",
			"desc": "Chromatic salt bends the glow into the blue the Bay is named for.",
			"station": STATION_BENCH, "station_tier": 2,
			"inputs": {"ferro_silt": 2, "bloomspore": 2, "chromatic_salt": 1},
			"output": "cobalt_bloom", "output_amount": 2,
			"seconds": 55.0, "base_quality": 0.42, "xp": 30,
			"unlocked_by_default": false,
		},
		"aurora_prism": {
			"name": "Aurora Prism Firing",
			"desc": "Two blooms fused under pressure until the colour will not settle.",
			"station": STATION_KILN, "station_tier": 1,
			"inputs": {"cobalt_bloom": 2, "cryo_gel": 1, "voltaic_dust": 1},
			"output": "aurora_prism", "output_amount": 2,
			"seconds": 95.0, "base_quality": 0.46, "xp": 60,
			"unlocked_by_default": false,
		},
		"solar_halo": {
			"name": "Solar Halo Firing",
			"desc": "A month of gold light out of a kiln that has to hold temperature perfectly.",
			"station": STATION_KILN, "station_tier": 2,
			"inputs": {"aurora_prism": 2, "voltaic_dust": 2, "prism_flake": 1},
			"output": "solar_halo", "output_amount": 2,
			"seconds": 150.0, "base_quality": 0.5, "xp": 120,
			"unlocked_by_default": false,
		},
		"midnight_veil": {
			"name": "Midnight Veil Lattice",
			"desc": "Odette's lattice. Light folded back on itself until a room reads as empty.",
			"station": STATION_KILN, "station_tier": 3,
			"inputs": {"solar_halo": 2, "prism_flake": 2, "cryo_gel": 2},
			"output": "midnight_veil", "output_amount": 1,
			"seconds": 240.0, "base_quality": 0.54, "xp": 260,
			"unlocked_by_default": false,
		},
		"reclaim_scrap": {
			"name": "Reclaim Scrap",
			"desc": "Cook a scrap bundle down into usable silt. Slow money, but it is money.",
			"station": STATION_CULTIVATOR, "station_tier": 1,
			"inputs": {"scrap_bundle": 3},
			"output": "ferro_silt", "output_amount": 4,
			"seconds": 30.0, "base_quality": 0.2, "xp": 5,
			"unlocked_by_default": true,
		},
	}


## Additives may be slotted into any bench/kiln job. Each entry gives a quality
## bonus and, for some, a side effect. Two slots by default; skills add more.
static func additives() -> Dictionary:
	return {
		"harbor_solvent": {"quality": 0.08, "speed": 0.0, "heat": 0.0,
			"note": "Strips impurities. Small, reliable lift."},
		"chromatic_salt": {"quality": 0.11, "speed": 0.0, "heat": 0.0,
			"note": "Deepens colour saturation."},
		"cryo_gel": {"quality": 0.13, "speed": -0.15, "heat": 0.0,
			"note": "Fewer cracks, slower cure."},
		"voltaic_dust": {"quality": 0.19, "speed": 0.2, "heat": 0.1,
			"note": "Faster and brighter. Detectable."},
		"prism_flake": {"quality": 0.29, "speed": 0.0, "heat": 0.2,
			"note": "The real thing. Expensive and loud."},
	}


static func additive_ids() -> PackedStringArray:
	return PackedStringArray([
		"harbor_solvent", "chromatic_salt", "cryo_gel", "voltaic_dust", "prism_flake",
	])


## Maps a continuous 0..1 quality score onto the 5 discrete quality tiers.
static func score_to_quality(score: float) -> int:
	var s := clampf(score, 0.0, 1.0)
	if s < 0.25:
		return 0
	if s < 0.45:
		return 1
	if s < 0.66:
		return 2
	if s < 0.85:
		return 3
	return 4


## Recipes that a given station (family + tier) is able to run.
static func recipes_for_station(family: String, tier: int) -> Array[String]:
	var out: Array[String] = []
	for id in data():
		var r: Dictionary = data()[id]
		if r["station"] == family and int(r["station_tier"]) <= tier:
			out.append(id)
	return out
