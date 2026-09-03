class_name NpcDB
extends RefCounted
## Named characters, procedural civilian pools and employee archetypes.
##
## A "schedule" is an ordered list of {hour, poi, action}. The NPC brain picks
## the latest entry whose hour has passed and walks to that point of interest.
## Actions: "idle", "work", "wander", "patrol", "shop", "sleep", "sell".

const ROLE_FIXER := "fixer"
const ROLE_SUPPLIER := "supplier"
const ROLE_BROKER := "broker"
const ROLE_CUSTOMER := "customer"
const ROLE_CIVILIAN := "civilian"
const ROLE_OFFICER := "officer"
const ROLE_RIVAL := "rival"
const ROLE_MECHANIC := "mechanic"
const ROLE_RECRUITER := "recruiter"
const ROLE_ENGINEER := "engineer"


static func named() -> Dictionary:
	return {
		"mira_vance": {
			"name": "Mira Vance",
			"role": ROLE_FIXER,
			"blurb": "Runs half the favours on the waterfront and never writes anything down.",
			"district": "dockside",
			"color": Color(0.35, 0.78, 0.85),
			"initials": "MV",
			"height": 1.72,
			"personality": {"warmth": 0.6, "patience": 0.8, "greed": 0.3, "nerve": 0.9},
			"schedule": [
				{"hour": 7, "poi": "gull_cafe", "action": "idle"},
				{"hour": 11, "poi": "pier3", "action": "work"},
				{"hour": 16, "poi": "dock_gate", "action": "wander"},
				{"hour": 22, "poi": "gull_cafe", "action": "idle"},
			],
			"gives_missions": true,
			"trades": false,
		},
		"dez_okonkwo": {
			"name": "Dez Okonkwo",
			"role": ROLE_SUPPLIER,
			"blurb": "Pell's Corner Supply. Sells you everything except a straight answer.",
			"district": "dockside",
			"color": Color(0.95, 0.66, 0.28),
			"initials": "DO",
			"height": 1.8,
			"personality": {"warmth": 0.7, "patience": 0.6, "greed": 0.6, "nerve": 0.4},
			"schedule": [
				{"hour": 6, "poi": "pell_store", "action": "work"},
				{"hour": 21, "poi": "pell_store", "action": "idle"},
			],
			"gives_missions": true,
			"trades": true,
			"shop": {
				"markup": 1.0,
				"stock": ["ferro_silt", "tide_ash", "binder_resin", "bloomspore",
					"harbor_solvent", "paper_wrap", "vac_pouch", "volt_tin", "field_patch"],
				"buys": ["scrap_bundle"],
			},
		},
		"saoirse_lam": {
			"name": "Saoirse Lam",
			"role": ROLE_BROKER,
			"blurb": "Moves volume through Market Row. Pays less per unit and never haggles twice.",
			"district": "market_row",
			"color": Color(0.98, 0.4, 0.6),
			"initials": "SL",
			"height": 1.65,
			"personality": {"warmth": 0.35, "patience": 0.4, "greed": 0.85, "nerve": 0.7},
			"schedule": [
				{"hour": 9, "poi": "market_arcade", "action": "work"},
				{"hour": 14, "poi": "stall_9", "action": "idle"},
				{"hour": 19, "poi": "row_diner", "action": "idle"},
			],
			"gives_missions": true,
			"trades": true,
			"bulk_buyer": true,
			"bulk_discount": 0.82,     # pays 82% of unit price but takes big lots
			"bulk_min": 5,
		},
		"odette_sang": {
			"name": "Odette Sang",
			"role": ROLE_ENGINEER,
			"blurb": "Wrote the lattice papers the Bureau later classified. Now she fixes kettles.",
			"district": "ironworks",
			"color": Color(0.6, 0.85, 0.5),
			"initials": "OS",
			"height": 1.6,
			"personality": {"warmth": 0.45, "patience": 0.95, "greed": 0.2, "nerve": 0.6},
			"schedule": [
				{"hour": 8, "poi": "unit_row", "action": "work"},
				{"hour": 18, "poi": "foundry_gate", "action": "wander"},
				{"hour": 23, "poi": "unit_row", "action": "sleep"},
			],
			"gives_missions": true,
			"trades": true,
			"shop": {
				"markup": 1.15,
				"stock": ["chromatic_salt", "cryo_gel", "shell_case", "voltaic_dust"],
				"buys": [],
			},
			"teaches_recipes": ["cobalt_bloom", "aurora_prism", "solar_halo", "midnight_veil"],
		},
		"teo_marchetti": {
			"name": "Teo Marchetti",
			"role": ROLE_MECHANIC,
			"blurb": "Sells vans with clean plates and a philosophical view of mileage.",
			"district": "ironworks",
			"color": Color(0.85, 0.35, 0.28),
			"initials": "TM",
			"height": 1.86,
			"personality": {"warmth": 0.8, "patience": 0.5, "greed": 0.5, "nerve": 0.5},
			"schedule": [
				{"hour": 7, "poi": "fuel_stop", "action": "work"},
				{"hour": 20, "poi": "fuel_stop", "action": "idle"},
			],
			"gives_missions": true,
			"trades": true,
			"sells_vehicles": true,
		},
		"wendell_pike": {
			"name": "Wendell Pike",
			"role": ROLE_RECRUITER,
			"blurb": "Knows who needs work and who can keep their mouth shut. Charges for the second part.",
			"district": "old_town",
			"color": Color(0.7, 0.6, 0.9),
			"initials": "WP",
			"height": 1.75,
			"personality": {"warmth": 0.55, "patience": 0.7, "greed": 0.7, "nerve": 0.3},
			"schedule": [
				{"hour": 9, "poi": "old_town_square", "action": "idle"},
				{"hour": 15, "poi": "laundry", "action": "work"},
				{"hour": 21, "poi": "old_town_square", "action": "wander"},
			],
			"gives_missions": true,
			"trades": false,
			"hires_staff": true,
		},
		"grip_halloran": {
			"name": "\"Grip\" Halloran",
			"role": ROLE_RIVAL,
			"blurb": "Tidewell's man on the docks. Built like a bollard, twice as immovable.",
			"district": "dockside",
			"color": Color(0.55, 0.3, 0.3),
			"initials": "GH",
			"height": 1.92,
			"personality": {"warmth": 0.1, "patience": 0.2, "greed": 0.6, "nerve": 0.95},
			"schedule": [
				{"hour": 10, "poi": "dock_gate", "action": "patrol"},
				{"hour": 18, "poi": "scrapyard", "action": "idle"},
			],
			"gives_missions": true,
			"hostile": true,
			"faction": "tidewell",
		},
		"ivo_brandt": {
			"name": "Ivo Brandt",
			"role": ROLE_RIVAL,
			"blurb": "Owns the Tidewell Syndicate and, on a good week, three inspectors.",
			"district": "meridian",
			"color": Color(0.75, 0.2, 0.25),
			"initials": "IB",
			"height": 1.82,
			"personality": {"warmth": 0.3, "patience": 0.9, "greed": 0.95, "nerve": 1.0},
			"schedule": [
				{"hour": 11, "poi": "tower_plaza", "action": "idle"},
				{"hour": 20, "poi": "meridian_bank", "action": "work"},
			],
			"gives_missions": true,
			"hostile": true,
			"faction": "tidewell",
		},
		"row_calder": {
			"name": "Inspector Row Calder",
			"role": ROLE_OFFICER,
			"blurb": "Civic Standards Bureau. Polite, tireless, and entirely unbribable, which is the problem.",
			"district": "meridian",
			"color": Color(0.4, 0.6, 0.95),
			"initials": "RC",
			"height": 1.78,
			"personality": {"warmth": 0.4, "patience": 1.0, "greed": 0.0, "nerve": 0.85},
			"schedule": [
				{"hour": 8, "poi": "csb_hq", "action": "work"},
				{"hour": 13, "poi": "tower_plaza", "action": "patrol"},
				{"hour": 19, "poi": "csb_hq", "action": "work"},
			],
			"gives_missions": true,
			"is_law": true,
		},
		"nadia_quill": {
			"name": "Nadia Quill",
			"role": ROLE_CUSTOMER,
			"blurb": "Collects light the way other people collect wine. Pays for provenance.",
			"district": "hillcrest",
			"color": Color(0.9, 0.85, 0.5),
			"initials": "NQ",
			"height": 1.68,
			"personality": {"warmth": 0.75, "patience": 0.3, "greed": 0.2, "nerve": 0.4},
			"schedule": [
				{"hour": 10, "poi": "country_club", "action": "idle"},
				{"hour": 15, "poi": "hill_park", "action": "wander"},
				{"hour": 21, "poi": "villa_gate", "action": "sleep"},
			],
			"gives_missions": true,
			"is_customer": true,
			"prefers": ["aurora_prism", "solar_halo", "midnight_veil"],
			"price_bias": 1.35,
			"min_quality": 2,
		},
	}


# --- Procedural civilian generation ---------------------------------------

static func first_names() -> PackedStringArray:
	return PackedStringArray([
		"Aster", "Bex", "Cato", "Delia", "Emre", "Fen", "Greer", "Halcy", "Ines",
		"Jory", "Kestrel", "Liesl", "Marek", "Nils", "Orla", "Perrin", "Quill",
		"Rafe", "Sable", "Tam", "Uma", "Vesper", "Wren", "Yara", "Zeke", "Noor",
		"Idris", "Sena", "Bram", "Calla", "Dov", "Elin", "Ferro", "Gita", "Hobb",
	])


static func last_names() -> PackedStringArray:
	return PackedStringArray([
		"Adeyemi", "Barlow", "Castellan", "Doyle", "Ehrlich", "Fontaine", "Gower",
		"Haslet", "Ibori", "Jankowski", "Kilbride", "Lyszkiewicz", "Moreau",
		"Nakamura", "Obi", "Pelletier", "Quintero", "Rask", "Sandoval", "Thorne",
		"Ubaldi", "Vasquez", "Whitlock", "Yusuf", "Zabala", "Croft", "Meldrum",
	])


## Customer personality archetypes. These drive haggling, loyalty and risk.
static func customer_archetypes() -> Dictionary:
	return {
		"cautious": {
			"label": "Cautious",
			"price_bias": 0.92, "quality_bias": 1.1, "loyalty_gain": 1.2,
			"public_risk": 0.5, "quantity": [1, 2], "min_quality": 1,
			"line": "Not out here. Somewhere with fewer windows.",
		},
		"eager": {
			"label": "Eager",
			"price_bias": 1.12, "quality_bias": 0.85, "loyalty_gain": 0.9,
			"public_risk": 1.4, "quantity": [1, 3], "min_quality": 0,
			"line": "I've been looking for you all day.",
		},
		"collector": {
			"label": "Collector",
			"price_bias": 1.45, "quality_bias": 1.6, "loyalty_gain": 1.35,
			"public_risk": 0.7, "quantity": [1, 2], "min_quality": 2,
			"line": "I only want a clean one. I'll know if it isn't.",
		},
		"reseller": {
			"label": "Reseller",
			"price_bias": 0.78, "quality_bias": 0.7, "loyalty_gain": 1.0,
			"public_risk": 1.0, "quantity": [3, 7], "min_quality": 0,
			"line": "Bulk or nothing. I've got my own people to feed.",
		},
		"tourist": {
			"label": "Out-of-towner",
			"price_bias": 1.3, "quality_bias": 0.6, "loyalty_gain": 0.4,
			"public_risk": 1.6, "quantity": [1, 2], "min_quality": 0,
			"line": "Is this the blue one people talk about?",
		},
	}


## Employee archetypes hired through Wendell Pike.
static func employee_archetypes() -> Dictionary:
	return {
		"hand": {
			"label": "Yard Hand",
			"wage": 45, "skill": 0.35, "loyalty": 0.5, "discretion": 0.4,
			"jobs": ["production", "haul"],
			"hire_cost": 250,
			"blurb": "Willing, unskilled, and cheap. Will break one thing a week.",
		},
		"latticer": {
			"label": "Latticer",
			"wage": 110, "skill": 0.7, "loyalty": 0.55, "discretion": 0.55,
			"jobs": ["production"],
			"hire_cost": 900,
			"blurb": "Knows a bench. Output quality climbs noticeably.",
		},
		"runner": {
			"label": "Runner",
			"wage": 95, "skill": 0.5, "loyalty": 0.45, "discretion": 0.75,
			"jobs": ["sell", "haul"],
			"hire_cost": 700,
			"blurb": "Moves product to customers while you are elsewhere.",
		},
		"minder": {
			"label": "Minder",
			"wage": 130, "skill": 0.4, "loyalty": 0.8, "discretion": 0.85,
			"jobs": ["security"],
			"hire_cost": 1200,
			"blurb": "Stands near the door. Raids go a lot worse for the Bureau.",
		},
		"fixer": {
			"label": "Site Fixer",
			"wage": 260, "skill": 0.85, "loyalty": 0.7, "discretion": 0.9,
			"jobs": ["production", "sell", "security", "haul"],
			"hire_cost": 3400,
			"blurb": "Runs a whole site unsupervised. Expensive for a reason.",
		},
	}
