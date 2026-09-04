class_name ItemDB
extends RefCounted
## Static item catalogue for Underlight.
##
## Every item is a plain Dictionary so it serialises trivially and can be
## extended by content packs later. Keys:
##   name, desc, category, base_value, stack, weight, contraband, heat,
##   tier, color, icon (glyph), tags
##
## Categories: "material", "product", "packaging", "consumable", "tool", "misc"

const CAT_MATERIAL := "material"
const CAT_PRODUCT := "product"
const CAT_PACKAGING := "packaging"
const CAT_CONSUMABLE := "consumable"
const CAT_TOOL := "tool"
const CAT_MISC := "misc"


static func data() -> Dictionary:
	return {
		# ---------------------------------------------------------------
		# RAW MATERIALS - bought from suppliers, scavenged, or farmed
		# ---------------------------------------------------------------
		"ferro_silt": {
			"name": "Ferro-Silt",
			"desc": "Grey harbour sediment, heavy with iron. The cheap skeleton of every Lumen lattice.",
			"category": CAT_MATERIAL, "base_value": 6, "stack": 40, "weight": 0.5,
			"contraband": false, "heat": 0.0, "tier": 1,
			"color": Color(0.44, 0.46, 0.48), "icon": "mineral", "tags": ["base"],
		},
		"tide_ash": {
			"name": "Tide Ash",
			"desc": "Fine grey ash raked off the tideline. Bulks out a lattice without adding shine.",
			"category": CAT_MATERIAL, "base_value": 9, "stack": 40, "weight": 0.3,
			"contraband": false, "heat": 0.0, "tier": 1,
			"color": Color(0.58, 0.57, 0.53), "icon": "mineral", "tags": ["base", "filler"],
		},
		"bloomspore": {
			"name": "Bloomspore Culture",
			"desc": "A living culture that threads light through mineral. Warm to the touch. Dies if it dries.",
			"category": CAT_MATERIAL, "base_value": 14, "stack": 30, "weight": 0.2,
			"contraband": false, "heat": 0.0, "tier": 1,
			"color": Color(0.4, 0.85, 0.6), "icon": "culture", "tags": ["culture"],
		},
		"binder_resin": {
			"name": "Binder Resin",
			"desc": "Clear industrial resin. Holds a lattice together while it sets.",
			"category": CAT_MATERIAL, "base_value": 11, "stack": 30, "weight": 0.4,
			"contraband": false, "heat": 0.0, "tier": 1,
			"color": Color(0.85, 0.83, 0.7), "icon": "resin", "tags": ["binder"],
		},
		"chromatic_salt": {
			"name": "Chromatic Salt",
			"desc": "Refinery salt that bends the glow toward blue. Restricted, but nobody counts the barrels.",
			"category": CAT_MATERIAL, "base_value": 22, "stack": 25, "weight": 0.3,
			"contraband": false, "heat": 0.05, "tier": 2,
			"color": Color(0.4, 0.7, 1.0), "icon": "mineral", "tags": ["additive", "colour"],
		},
		"cryo_gel": {
			"name": "Cryo-Gel",
			"desc": "Keeps a curing lattice from cracking. Stabiliser of choice for anyone who wants clean edges.",
			"category": CAT_MATERIAL, "base_value": 27, "stack": 20, "weight": 0.6,
			"contraband": false, "heat": 0.0, "tier": 2,
			"color": Color(0.7, 0.92, 0.96), "icon": "frost", "tags": ["additive", "stabiliser"],
		},
		"voltaic_dust": {
			"name": "Voltaic Dust",
			"desc": "Charged particulate scraped from transformer housings. Makes a shard sing.",
			"category": CAT_MATERIAL, "base_value": 38, "stack": 20, "weight": 0.2,
			"contraband": true, "heat": 0.15, "tier": 3,
			"color": Color(1.0, 0.82, 0.3), "icon": "spark", "tags": ["additive", "potency"],
		},
		"prism_flake": {
			"name": "Prism Flake",
			"desc": "Shaved from a natural seam under the Meridian bedrock. Nobody sells this legally.",
			"category": CAT_MATERIAL, "base_value": 64, "stack": 15, "weight": 0.1,
			"contraband": true, "heat": 0.25, "tier": 4,
			"color": Color(0.8, 0.5, 1.0), "icon": "crystal", "tags": ["additive", "rare"],
		},
		"harbor_solvent": {
			"name": "Harbour Solvent",
			"desc": "Strips impurity out of raw silt. Smells like a bad decision.",
			"category": CAT_MATERIAL, "base_value": 19, "stack": 25, "weight": 0.5,
			"contraband": false, "heat": 0.0, "tier": 2,
			"color": Color(0.75, 0.9, 0.55), "icon": "flask", "tags": ["additive", "purity"],
		},

		# ---------------------------------------------------------------
		# PRODUCTS - the things you sell. All contraband.
		# ---------------------------------------------------------------
		"pale_shard": {
			"name": "Pale Shard",
			"desc": "Entry-grade Lumen. A soft white glow that lasts a fortnight. Every Cobalt Bay bedsit has one.",
			"category": CAT_PRODUCT, "base_value": 34, "stack": 20, "weight": 0.3,
			"contraband": true, "heat": 0.6, "tier": 1,
			"color": Color(0.85, 0.9, 0.95), "icon": "crystal", "tags": ["lumen"],
		},
		"cobalt_bloom": {
			"name": "Cobalt Bloom",
			"desc": "Deep blue and slow-burning. The signature of the Bay's underground, and the reason the Bureau cares.",
			"category": CAT_PRODUCT, "base_value": 72, "stack": 20, "weight": 0.3,
			"contraband": true, "heat": 0.9, "tier": 2,
			"color": Color(0.25, 0.55, 1.0), "icon": "crystal", "tags": ["lumen"],
		},
		"aurora_prism": {
			"name": "Aurora Prism",
			"desc": "Shifts colour as it burns. Collectors on Hillcrest pay silly money for a clean one.",
			"category": CAT_PRODUCT, "base_value": 145, "stack": 15, "weight": 0.4,
			"contraband": true, "heat": 1.2, "tier": 3,
			"color": Color(0.5, 0.85, 0.8), "icon": "crystal", "tags": ["lumen", "premium"],
		},
		"solar_halo": {
			"name": "Solar Halo",
			"desc": "Burns gold for a month straight. Lighting a room with one is a statement about who you are.",
			"category": CAT_PRODUCT, "base_value": 290, "stack": 12, "weight": 0.5,
			"contraband": true, "heat": 1.6, "tier": 4,
			"color": Color(1.0, 0.75, 0.25), "icon": "crystal", "tags": ["lumen", "premium"],
		},
		"midnight_veil": {
			"name": "Midnight Veil",
			"desc": "Light that reads as shadow. Only four people in the Bay know the lattice. You are trying to be the fifth.",
			"category": CAT_PRODUCT, "base_value": 520, "stack": 10, "weight": 0.4,
			"contraband": true, "heat": 2.2, "tier": 5,
			"color": Color(0.45, 0.3, 0.75), "icon": "crystal", "tags": ["lumen", "legendary"],
		},

		# ---------------------------------------------------------------
		# PACKAGING - raises value, lowers the heat a unit radiates
		# ---------------------------------------------------------------
		"paper_wrap": {
			"name": "Waxed Paper",
			"desc": "Barely a wrapper. Better than a bare hand.",
			"category": CAT_PACKAGING, "base_value": 2, "stack": 60, "weight": 0.05,
			"contraband": false, "heat": 0.0, "tier": 1,
			"color": Color(0.82, 0.76, 0.6), "icon": "package",
			"tags": ["packaging"], "value_bonus": 0.0, "heat_reduction": 0.05, "capacity": 1,
		},
		"vac_pouch": {
			"name": "Vac Pouch",
			"desc": "Sealed, opaque, and quiet in a pocket.",
			"category": CAT_PACKAGING, "base_value": 6, "stack": 50, "weight": 0.05,
			"contraband": false, "heat": 0.0, "tier": 2,
			"color": Color(0.35, 0.4, 0.45), "icon": "package",
			"tags": ["packaging"], "value_bonus": 0.08, "heat_reduction": 0.2, "capacity": 2,
		},
		"shell_case": {
			"name": "Shell Case",
			"desc": "Moulded case with a foam bed. Buyers read it as professional and pay accordingly.",
			"category": CAT_PACKAGING, "base_value": 18, "stack": 30, "weight": 0.15,
			"contraband": false, "heat": 0.0, "tier": 3,
			"color": Color(0.2, 0.55, 0.6), "icon": "package",
			"tags": ["packaging"], "value_bonus": 0.18, "heat_reduction": 0.35, "capacity": 4,
		},
		"courier_box": {
			"name": "Courier Crate",
			"desc": "Bonded freight crate with a forged manifest window. Reads as legal cargo at a glance.",
			"category": CAT_PACKAGING, "base_value": 40, "stack": 20, "weight": 0.4,
			"contraband": false, "heat": 0.0, "tier": 4,
			"color": Color(0.55, 0.45, 0.3), "icon": "package",
			"tags": ["packaging"], "value_bonus": 0.3, "heat_reduction": 0.55, "capacity": 8,
		},

		# ---------------------------------------------------------------
		# CONSUMABLES
		# ---------------------------------------------------------------
		"volt_tin": {
			"name": "Volt Tin",
			"desc": "Cold, metallic, deeply unpleasant. Restores stamina.",
			"category": CAT_CONSUMABLE, "base_value": 12, "stack": 10, "weight": 0.2,
			"contraband": false, "heat": 0.0, "tier": 1,
			"color": Color(0.9, 0.5, 0.2), "icon": "tin",
			"tags": ["consumable"], "effect": "stamina", "power": 60.0,
		},
		"field_patch": {
			"name": "Field Patch",
			"desc": "Adhesive wound dressing from a dockside vending machine.",
			"category": CAT_CONSUMABLE, "base_value": 30, "stack": 8, "weight": 0.2,
			"contraband": false, "heat": 0.0, "tier": 1,
			"color": Color(0.9, 0.3, 0.35), "icon": "patch",
			"tags": ["consumable"], "effect": "health", "power": 45.0,
		},
		"burner_sim": {
			"name": "Burner SIM",
			"desc": "Swap it in and the Bureau loses the thread. Clears most of your wanted level.",
			"category": CAT_CONSUMABLE, "base_value": 95, "stack": 5, "weight": 0.02,
			"contraband": true, "heat": 0.1, "tier": 2,
			"color": Color(0.4, 0.85, 0.9), "icon": "sim",
			"tags": ["consumable"], "effect": "clear_wanted", "power": 1.0,
		},
		"ledger_scrub": {
			"name": "Ledger Scrub",
			"desc": "A quiet accountant's afternoon in an envelope. Drops district heat.",
			"category": CAT_CONSUMABLE, "base_value": 160, "stack": 5, "weight": 0.05,
			"contraband": true, "heat": 0.1, "tier": 3,
			"color": Color(0.6, 0.9, 0.5), "icon": "news",
			"tags": ["consumable"], "effect": "clear_heat", "power": 45.0,
		},

		# ---------------------------------------------------------------
		# TOOLS / KEYS / QUEST ITEMS
		# ---------------------------------------------------------------
		"lockup_key": {
			"name": "Lockup Key",
			"desc": "A stamped brass key to a shipping container on Pier 3. Your first address.",
			"category": CAT_TOOL, "base_value": 0, "stack": 1, "weight": 0.05,
			"contraband": false, "heat": 0.0, "tier": 1,
			"color": Color(0.85, 0.7, 0.35), "icon": "key", "tags": ["key", "quest"],
		},
		"survey_slate": {
			"name": "Survey Slate",
			"desc": "A stolen Bureau tablet showing seam maps under the Core. Odette wants it badly.",
			"category": CAT_TOOL, "base_value": 0, "stack": 1, "weight": 0.4,
			"contraband": true, "heat": 0.8, "tier": 4,
			"color": Color(0.35, 0.65, 0.8), "icon": "slate", "tags": ["quest"],
		},
		"tidewell_ledger": {
			"name": "Tidewell Ledger",
			"desc": "Every payment Brandt ever made to a Bureau inspector, in his own handwriting.",
			"category": CAT_TOOL, "base_value": 0, "stack": 1, "weight": 0.3,
			"contraband": true, "heat": 1.0, "tier": 5,
			"color": Color(0.75, 0.3, 0.3), "icon": "news", "tags": ["quest"],
		},
		"scrap_bundle": {
			"name": "Scrap Bundle",
			"desc": "Wire, plate offcuts, a dead battery. Dez pays a little for these.",
			"category": CAT_MISC, "base_value": 8, "stack": 30, "weight": 0.8,
			"contraband": false, "heat": 0.0, "tier": 1,
			"color": Color(0.5, 0.45, 0.4), "icon": "scrap", "tags": ["junk"],
		},
	}


## Ordered product list, cheapest first. Used by market + UI.
static func product_ids() -> PackedStringArray:
	return PackedStringArray([
		"pale_shard", "cobalt_bloom", "aurora_prism", "solar_halo", "midnight_veil",
	])


static func packaging_ids() -> PackedStringArray:
	return PackedStringArray(["paper_wrap", "vac_pouch", "shell_case", "courier_box"])
