class_name MissionDB
extends RefCounted
## Missions: main story chapters, side jobs, and random events.
##
## Objective types understood by MissionService:
##   talk        {npc}                       - speak to a character
##   goto        {poi} or {pos, radius}      - reach a place
##   collect     {item, count}               - hold N of an item
##   craft       {item, count}               - produce N of an item
##   sell        {item|"any", count, district?, min_quality?}
##   earn        {amount}                    - cumulative cash earned
##   deliver     {item, count, npc}          - hand items to a character
##   buy_property{property}                  - own a property
##   upgrade     {property, track, level}
##   hire        {count}                     - employees on payroll
##   level       {value}
##   rep         {district, value}
##   evade       {seconds}                   - stay clear of the Bureau
##   avoid_wanted{seconds}                   - keep wanted at 0 for N seconds
##   flag        {flag}                      - a story flag set elsewhere

const KIND_MAIN := "main"
const KIND_SIDE := "side"
const KIND_EVENT := "event"
const KIND_RIVAL := "rival"
const KIND_LAW := "law"


static func data() -> Dictionary:
	return {
		# =================================================================
		# MAIN STORY - "Underlight"
		# =================================================================
		"ch1_keys": {
			"title": "Salt and Static",
			"kind": KIND_MAIN, "chapter": 1, "giver": "mira_vance",
			"brief": "Mira Vance says there is a container on Pier 3 with your name chalked on it. She did not say why.",
			"objectives": [
				{"type": "talk", "npc": "mira_vance", "label": "Meet Mira at the Gull Cafe"},
				{"type": "goto", "poi": "pier3", "radius": 6.0, "label": "Find the Pier 3 lockup"},
			],
			"rewards": {"cash": 60, "xp": 40, "items": {"lockup_key": 1},
				"unlock_property": "dockside_lockup", "flags": ["has_lockup"]},
			"next": "ch1_first_lattice",
			"auto_offer": true,
		},
		"ch1_first_lattice": {
			"title": "First Light",
			"kind": KIND_MAIN, "chapter": 1, "giver": "mira_vance",
			"brief": "A bench, a bag of silt and a culture tray. Make something that glows.",
			"objectives": [
				{"type": "collect", "item": "ferro_silt", "count": 2, "label": "Get Ferro-Silt from Dez"},
				{"type": "collect", "item": "bloomspore", "count": 1, "label": "Get a Bloomspore Culture"},
				{"type": "collect", "item": "binder_resin", "count": 1, "label": "Get Binder Resin"},
				{"type": "craft", "item": "pale_shard", "count": 2, "label": "Lattice two Pale Shards"},
			],
			"rewards": {"cash": 40, "xp": 70, "flags": ["crafted_first"]},
			"next": "ch1_first_sale",
		},
		"ch1_first_sale": {
			"title": "Somebody's Buying",
			"kind": KIND_MAIN, "chapter": 1, "giver": "mira_vance",
			"brief": "Dockside is full of people who want a light that does not appear on a bill. Find two of them.",
			"objectives": [
				{"type": "sell", "item": "pale_shard", "count": 2, "district": "dockside",
					"label": "Sell 2 Pale Shards in Dockside"},
			],
			"rewards": {"cash": 120, "xp": 90, "rep": {"dockside": 6.0}, "flags": ["first_sale"]},
			"next": "ch2_rows",
		},
		"ch2_rows": {
			"title": "Rows and Whispers",
			"kind": KIND_MAIN, "chapter": 2, "giver": "mira_vance",
			"brief": "Word travels up the hill from the water. Old Town will take your shards if Dockside vouches for you.",
			"objectives": [
				{"type": "rep", "district": "dockside", "value": 25.0, "label": "Reach Dockside standing 25"},
				{"type": "earn", "amount": 900, "label": "Bank $900 in total earnings"},
			],
			"rewards": {"cash": 250, "xp": 180, "unlock_district": "old_town",
				"flags": ["old_town_open"]},
			"next": "ch3_blue_line",
		},
		"ch3_blue_line": {
			"title": "The Blue Line",
			"kind": KIND_MAIN, "chapter": 3, "giver": "odette_sang",
			"brief": "Odette Sang wrote the papers on chromatic lattices before the Bureau classified them. She will teach you, for a price paid in materials.",
			"objectives": [
				{"type": "talk", "npc": "odette_sang", "label": "Find Odette in Ironworks Flats"},
				{"type": "deliver", "item": "chromatic_salt", "count": 4, "npc": "odette_sang",
					"label": "Bring Odette 4 Chromatic Salt"},
				{"type": "craft", "item": "cobalt_bloom", "count": 3, "label": "Lattice 3 Cobalt Blooms"},
			],
			"rewards": {"cash": 300, "xp": 320, "unlock_recipe": "cobalt_bloom",
				"unlock_district": "market_row", "flags": ["knows_bloom"]},
			"next": "ch4_toll",
		},
		"ch4_toll": {
			"title": "Grip's Toll",
			"kind": KIND_MAIN, "chapter": 4, "giver": "grip_halloran",
			"brief": "Grip Halloran collects a percentage for the Tidewell Syndicate. He has decided you are a percentage.",
			"objectives": [
				{"type": "talk", "npc": "grip_halloran", "label": "Hear Grip out at the dock gate"},
				{"type": "sell", "item": "any", "count": 12, "label": "Move 12 units to prove you are worth taxing"},
				{"type": "avoid_wanted", "seconds": 180.0, "label": "Stay clean for three minutes"},
			],
			"rewards": {"cash": 700, "xp": 450, "rep": {"dockside": 10.0},
				"flags": ["tidewell_aware"]},
			"next": "ch5_paper",
		},
		"ch5_paper": {
			"title": "Paper Trail",
			"kind": KIND_MAIN, "chapter": 5, "giver": "saoirse_lam",
			"brief": "Cash you cannot explain is cash you cannot spend. Saoirse says a legitimate stall fixes that.",
			"objectives": [
				{"type": "buy_property", "property": "market_stall", "label": "Buy Stall 9 on Market Row"},
				{"type": "hire", "count": 1, "label": "Put one employee on the payroll"},
			],
			"rewards": {"cash": 0, "xp": 600, "flags": ["has_front"], "influence": 0.05},
			"next": "ch6_hill",
		},
		"ch6_hill": {
			"title": "The Quiet Side of the Hill",
			"kind": KIND_MAIN, "chapter": 6, "giver": "nadia_quill",
			"brief": "Nadia Quill collects light. If you can put a Radiant prism in her hand she will open Hillcrest to you.",
			"objectives": [
				{"type": "craft", "item": "aurora_prism", "count": 2, "label": "Fire 2 Aurora Prisms"},
				{"type": "deliver", "item": "aurora_prism", "count": 1, "npc": "nadia_quill",
					"min_quality": 3, "label": "Deliver a Radiant Aurora Prism to Nadia"},
			],
			"rewards": {"cash": 1800, "xp": 900, "unlock_district": "hillcrest",
				"unlock_recipe": "aurora_prism", "rep": {"hillcrest": 15.0}},
			"next": "ch7_bureau",
		},
		"ch7_bureau": {
			"title": "Bureau Business",
			"kind": KIND_MAIN, "chapter": 7, "giver": "row_calder",
			"brief": "Inspector Calder wants a conversation. Mira says go. Mira is usually right and occasionally wrong.",
			"objectives": [
				{"type": "talk", "npc": "row_calder", "label": "Meet Inspector Calder"},
				{"type": "evade", "seconds": 150.0, "label": "Lose the tail Calder puts on you"},
				{"type": "collect", "item": "survey_slate", "count": 1, "label": "Recover the Survey Slate"},
			],
			"rewards": {"cash": 2500, "xp": 1400, "flags": ["calder_watching"]},
			"spawns": [{"item": "survey_slate", "poi": "csb_hq", "offset": [6.0, 0.0, 9.0],
				"after_objective": 1}],
			"next": "ch8_meridian",
		},
		"ch8_meridian": {
			"title": "Meridian",
			"kind": KIND_MAIN, "chapter": 8, "giver": "mira_vance",
			"brief": "The Core is where the money actually lives. You need standing, an address, and nerve.",
			"objectives": [
				{"type": "level", "value": 12, "label": "Reach level 12"},
				{"type": "earn", "amount": 60000, "label": "Earn $60,000 lifetime"},
				{"type": "deliver", "item": "survey_slate", "count": 1, "npc": "odette_sang",
					"label": "Give Odette the Survey Slate"},
			],
			"rewards": {"cash": 5000, "xp": 2600, "unlock_district": "meridian",
				"unlock_recipe": "solar_halo", "influence": 0.1},
			"next": "ch9_ledger",
		},
		"ch9_ledger": {
			"title": "The Ledger",
			"kind": KIND_MAIN, "chapter": 9, "giver": "mira_vance",
			"brief": "Ivo Brandt writes down every inspector he has ever bought. Mira wants that book more than she wants you safe.",
			"objectives": [
				{"type": "talk", "npc": "ivo_brandt", "label": "Get into a room with Ivo Brandt"},
				{"type": "collect", "item": "tidewell_ledger", "count": 1, "label": "Take the Tidewell Ledger"},
				{"type": "deliver", "item": "tidewell_ledger", "count": 1, "npc": "mira_vance",
					"label": "Get the ledger to Mira"},
			],
			"rewards": {"cash": 12000, "xp": 5200, "influence": 0.25,
				"unlock_recipe": "midnight_veil", "flags": ["tidewell_broken"]},
			"spawns": [{"item": "tidewell_ledger", "poi": "meridian_bank", "offset": [-5.0, 0.0, 8.0],
				"after_objective": 0}],
			"next": "ch10_underlight",
		},
		"ch10_underlight": {
			"title": "Underlight",
			"kind": KIND_MAIN, "chapter": 10, "giver": "mira_vance",
			"brief": "Cobalt Bay is going to belong to somebody by the end of the year. Decide what kind of somebody you are.",
			"objectives": [
				{"type": "flag", "flag": "endgame_reached",
					"label": "Complete any endgame path (see Phone > Empire)"},
			],
			"rewards": {"cash": 0, "xp": 10000, "flags": ["finale"]},
			"next": "",
		},

		# =================================================================
		# SIDE JOBS
		# =================================================================
		"side_scrap_run": {
			"title": "Scrap Run",
			"kind": KIND_SIDE, "giver": "dez_okonkwo", "repeatable": true, "cooldown_days": 1,
			"brief": "Dez needs scrap and does not want to bend down for it himself.",
			"objectives": [
				{"type": "deliver", "item": "scrap_bundle", "count": 6, "npc": "dez_okonkwo",
					"label": "Bring Dez 6 Scrap Bundles"},
			],
			"rewards": {"cash": 90, "xp": 45, "rep": {"dockside": 2.0}},
			"requires": {"flag": "has_lockup"},
		},
		"side_night_shift": {
			"title": "Night Shift",
			"kind": KIND_SIDE, "giver": "mira_vance", "repeatable": true, "cooldown_days": 2,
			"brief": "Anything sold between midnight and four is worth more and costs more.",
			"objectives": [
				{"type": "sell", "item": "any", "count": 6, "label": "Sell 6 units after dark"},
			],
			"rewards": {"cash": 260, "xp": 140, "rep": {"dockside": 3.0}},
			"requires": {"flag": "first_sale"},
		},
		"side_quality_control": {
			"title": "Quality Control",
			"kind": KIND_SIDE, "giver": "odette_sang", "repeatable": true, "cooldown_days": 3,
			"brief": "Odette wants proof you can hit Radiant on purpose rather than by luck.",
			"objectives": [
				{"type": "craft", "item": "cobalt_bloom", "count": 2, "min_quality": 3,
					"label": "Lattice 2 Radiant Cobalt Blooms"},
			],
			"rewards": {"cash": 480, "xp": 300, "items": {"cryo_gel": 3}},
			"requires": {"flag": "knows_bloom"},
		},
		"side_clean_books": {
			"title": "Clean Books",
			"kind": KIND_SIDE, "giver": "saoirse_lam", "repeatable": true, "cooldown_days": 3,
			"brief": "Saoirse will take a bulk lot off you at a discount and ask nothing at all.",
			"objectives": [
				{"type": "deliver", "item": "any", "count": 10, "npc": "saoirse_lam",
					"label": "Move a lot of 10 through Saoirse"},
			],
			"rewards": {"cash": 900, "xp": 260, "rep": {"market_row": 5.0}},
			"requires": {"district": "market_row"},
		},
		"side_hedge_money": {
			"title": "Hedge Money",
			"kind": KIND_SIDE, "giver": "nadia_quill", "repeatable": true, "cooldown_days": 4,
			"brief": "Nadia's friends want what Nadia has, and they want it discreetly.",
			"objectives": [
				{"type": "sell", "item": "any", "count": 4, "district": "hillcrest", "min_quality": 3,
					"label": "Sell 4 Radiant-or-better units in Hillcrest"},
			],
			"rewards": {"cash": 3200, "xp": 900, "rep": {"hillcrest": 8.0}},
			"requires": {"district": "hillcrest"},
		},
		"side_open_shop": {
			"title": "Somewhere to Sleep",
			"kind": KIND_SIDE, "giver": "wendell_pike",
			"brief": "Wendell knows a terrace on Kestrel Row going cheap because of what happened in it.",
			"objectives": [
				{"type": "buy_property", "property": "rowhouse_12", "label": "Buy 12 Kestrel Row"},
				{"type": "upgrade", "property": "rowhouse_12", "track": "production", "level": 1,
					"label": "Install a second bench"},
			],
			"rewards": {"cash": 0, "xp": 700, "items": {"shell_case": 5}},
			"requires": {"level": 3},
		},
		"side_wheels": {
			"title": "Wheels",
			"kind": KIND_SIDE, "giver": "teo_marchetti",
			"brief": "Teo has a van with clean plates. Carrying stock on foot is how people get caught.",
			"objectives": [
				{"type": "talk", "npc": "teo_marchetti", "label": "See Teo at the Ironworks fuel stop"},
				{"type": "flag", "flag": "owns_vehicle", "label": "Own any vehicle"},
			],
			"rewards": {"cash": 0, "xp": 400, "rep": {"ironworks": 5.0}},
			"requires": {"level": 4},
		},

		# =================================================================
		# RIVAL / LAW PRESSURE (spawned by services, not offered by NPCs)
		# =================================================================
		"rival_squeeze": {
			"title": "Tidewell Squeeze",
			"kind": KIND_RIVAL, "repeatable": true, "cooldown_days": 3,
			"brief": "Tidewell runners are undercutting you on your own street. Take the district back.",
			"objectives": [
				{"type": "sell", "item": "any", "count": 8, "label": "Out-sell them: move 8 units"},
			],
			"rewards": {"cash": 600, "xp": 350, "rep": {"dockside": 6.0}},
			"fail_after_days": 3,
			"fail_penalty": {"rep": {"dockside": -8.0}},
		},
		"law_audit": {
			"title": "Bureau Audit",
			"kind": KIND_LAW, "repeatable": true, "cooldown_days": 4,
			"brief": "An inspector has your address on a clipboard. Keep the heat down or lose stock.",
			"objectives": [
				{"type": "avoid_wanted", "seconds": 240.0, "label": "Keep a clean record for four minutes"},
			],
			"rewards": {"cash": 0, "xp": 400, "flags": ["audit_passed"]},
			"fail_after_days": 2,
			"fail_penalty": {"seize_fraction": 0.3},
		},
	}


## Lightweight random world events. Fired by MissionService on a timer.
static func random_events() -> Array:
	return [
		{"id": "ev_shipment", "title": "Shipment In",
			"body": "A container split open on Pier 3. Free materials for whoever gets there first.",
			"effect": "spawn_pickups", "district": "dockside", "weight": 12},
		{"id": "ev_price_spike", "title": "Price Spike",
			"body": "A Bureau raid across the water dried up supply. Prices are up citywide for a while.",
			"effect": "price_up", "power": 1.35, "hours": 6, "weight": 10},
		{"id": "ev_glut", "title": "Market Glut",
			"body": "Somebody dumped a pallet of shards on Market Row. Prices are down.",
			"effect": "price_down", "power": 0.7, "hours": 5, "weight": 9},
		{"id": "ev_crackdown", "title": "Crackdown",
			"body": "Extra Bureau patrols tonight. Heat builds faster until morning.",
			"effect": "patrol_up", "power": 1.7, "hours": 8, "weight": 8},
		{"id": "ev_blackout", "title": "Grid Fault",
			"body": "Half the Core is dark. Nobody is watching the cameras, and everybody wants light.",
			"effect": "demand_up", "district": "meridian", "power": 1.6, "hours": 4, "weight": 6},
		{"id": "ev_rival_move", "title": "Tidewell Move",
			"body": "Tidewell runners are working one of your districts.",
			"effect": "rival_pressure", "weight": 7},
		{"id": "ev_tipoff", "title": "Tip-off",
			"body": "A friendly voice says an inspector is asking about your address.",
			"effect": "warn_raid", "weight": 5},
	]


## Endgame paths. Each is checked continuously; achieving one flags the finale.
static func endgames() -> Dictionary:
	return {
		"wealth": {
			"name": "The Quiet Fortune",
			"desc": "Two million clean, banked, and untouchable.",
			"check": {"bank": 2000000},
			"epilogue": "You stop counting in units and start counting in years. The Bay never learns your name, which was always the point.",
		},
		"influence": {
			"name": "The Long Table",
			"desc": "Enough leverage in the Core that the Bureau consults you before it moves.",
			"check": {"influence": 1.0},
			"epilogue": "Calder still files reports. They just come to you first now, as a courtesy.",
		},
		"domination": {
			"name": "Total Market",
			"desc": "Control every district's trade and break the Tidewell Syndicate.",
			"check": {"districts_controlled": 6, "flag": "tidewell_broken"},
			"epilogue": "Every glowing window from Pier 3 to Hillcrest runs on your lattice. Brandt sells cars in a town you have never heard of.",
		},
		"reputation": {
			"name": "The Bay's Own",
			"desc": "Maximum standing in every district. They would hide you from the Bureau themselves.",
			"check": {"min_rep_all": 90.0},
			"epilogue": "You walk Dockside at four in the morning and three separate people offer you a coat.",
		},
		"estate": {
			"name": "Landlord",
			"desc": "Own every property in Cobalt Bay.",
			"check": {"properties": 7},
			"epilogue": "The map of the city and the map of your holdings are the same map, and it is framed above the bench where you made your first shard.",
		},
	}
