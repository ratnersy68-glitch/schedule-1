class_name SkillDB
extends RefCounted
## Four progression trees. Ranks are bought with skill points from levelling.
##
## Effects are read by the systems that care about them via
## GameState.skill_effect(effect_key), which sums every purchased rank.

const TREES := ["hustle", "craft", "nerve", "empire"]

const TREE_LABELS := {
	"hustle": "Hustle",
	"craft": "Craft",
	"nerve": "Nerve",
	"empire": "Empire",
}

const TREE_BLURBS := {
	"hustle": "Selling, pricing and the people who buy from you.",
	"craft": "Yield, quality and the speed of a bench.",
	"nerve": "Staying out of a Bureau file.",
	"empire": "Property, payroll and everything that runs without you.",
}


static func data() -> Dictionary:
	return {
		# --- HUSTLE ----------------------------------------------------
		"silver_tongue": {
			"tree": "hustle", "name": "Silver Tongue", "ranks": 4, "cost": [1, 1, 2, 3],
			"desc": "Every unit sells for more.",
			"effect": "sale_price_mult", "per_rank": 0.05, "requires": {},
		},
		"regulars": {
			"tree": "hustle", "name": "Regulars", "ranks": 3, "cost": [1, 2, 3],
			"desc": "Customers remember you and come back sooner.",
			"effect": "loyalty_gain", "per_rank": 0.2, "requires": {},
		},
		"streetwise": {
			"tree": "hustle", "name": "Streetwise", "ranks": 3, "cost": [1, 2, 2],
			"desc": "More buyers are out looking for you at any hour.",
			"effect": "customer_density", "per_rank": 0.18, "requires": {"silver_tongue": 1},
		},
		"bulk_talk": {
			"tree": "hustle", "name": "Bulk Talk", "ranks": 3, "cost": [2, 2, 3],
			"desc": "Resellers take larger lots and pay closer to list.",
			"effect": "bulk_bonus", "per_rank": 0.06, "requires": {"regulars": 1},
		},
		"market_reader": {
			"tree": "hustle", "name": "Market Reader", "ranks": 1, "cost": [3],
			"desc": "The phone shows live demand and price trends per district.",
			"effect": "see_market", "per_rank": 1.0, "requires": {"streetwise": 2},
		},

		# --- CRAFT -----------------------------------------------------
		"steady_hands": {
			"tree": "craft", "name": "Steady Hands", "ranks": 4, "cost": [1, 1, 2, 3],
			"desc": "Higher base quality on everything you make yourself.",
			"effect": "quality_bonus", "per_rank": 0.045, "requires": {},
		},
		"batching": {
			"tree": "craft", "name": "Batching", "ranks": 3, "cost": [1, 2, 3],
			"desc": "A chance of one extra unit per job.",
			"effect": "extra_yield_chance", "per_rank": 0.14, "requires": {},
		},
		"frugal": {
			"tree": "craft", "name": "Frugal Lattice", "ranks": 3, "cost": [1, 2, 3],
			"desc": "A chance to consume one fewer input per job.",
			"effect": "input_save_chance", "per_rank": 0.12, "requires": {"steady_hands": 1},
		},
		"fast_cure": {
			"tree": "craft", "name": "Fast Cure", "ranks": 3, "cost": [2, 2, 3],
			"desc": "Production jobs finish faster.",
			"effect": "craft_speed", "per_rank": 0.12, "requires": {"batching": 1},
		},
		"third_slot": {
			"tree": "craft", "name": "Third Slot", "ranks": 1, "cost": [4],
			"desc": "A third additive slot on every station.",
			"effect": "additive_slots", "per_rank": 1.0, "requires": {"fast_cure": 2},
		},

		# --- NERVE -----------------------------------------------------
		"low_profile": {
			"tree": "nerve", "name": "Low Profile", "ranks": 4, "cost": [1, 1, 2, 3],
			"desc": "Suspicion builds slower and fades faster.",
			"effect": "suspicion_resist", "per_rank": 0.12, "requires": {},
		},
		"pocket_liner": {
			"tree": "nerve", "name": "Pocket Liner", "ranks": 3, "cost": [1, 2, 3],
			"desc": "Carried contraband radiates less heat.",
			"effect": "carry_heat_reduction", "per_rank": 0.15, "requires": {},
		},
		"cool_head": {
			"tree": "nerve", "name": "Cool Head", "ranks": 3, "cost": [2, 2, 3],
			"desc": "Wanted level decays much faster once you break line of sight.",
			"effect": "wanted_decay", "per_rank": 0.25, "requires": {"low_profile": 1},
		},
		"alibi": {
			"tree": "nerve", "name": "Alibi", "ranks": 3, "cost": [2, 3, 4],
			"desc": "Fines and seizures hurt less when you are caught.",
			"effect": "bust_mitigation", "per_rank": 0.14, "requires": {"cool_head": 1},
		},
		"ghost": {
			"tree": "nerve", "name": "Ghost", "ranks": 1, "cost": [5],
			"desc": "Crouch-walking makes you effectively invisible to patrols.",
			"effect": "crouch_invisible", "per_rank": 1.0, "requires": {"low_profile": 3},
		},

		# --- EMPIRE ----------------------------------------------------
		"landlord": {
			"tree": "empire", "name": "Landlord", "ranks": 3, "cost": [1, 2, 3],
			"desc": "Daily property upkeep costs less.",
			"effect": "upkeep_reduction", "per_rank": 0.12, "requires": {},
		},
		"foreman": {
			"tree": "empire", "name": "Foreman", "ranks": 4, "cost": [1, 2, 2, 3],
			"desc": "Employees work faster and make fewer mistakes.",
			"effect": "employee_output", "per_rank": 0.15, "requires": {},
		},
		"payroll": {
			"tree": "empire", "name": "Payroll Discipline", "ranks": 3, "cost": [1, 2, 3],
			"desc": "Wages cost less and loyalty falls slower.",
			"effect": "wage_reduction", "per_rank": 0.1, "requires": {"foreman": 1},
		},
		"logistics": {
			"tree": "empire", "name": "Logistics", "ranks": 3, "cost": [2, 2, 3],
			"desc": "More personal carry slots and more storage everywhere.",
			"effect": "storage_bonus", "per_rank": 0.15, "requires": {"landlord": 1},
		},
		"franchise": {
			"tree": "empire", "name": "Franchise", "ranks": 2, "cost": [4, 5],
			"desc": "Retail fronts sell noticeably more while you are away.",
			"effect": "front_rate", "per_rank": 0.35, "requires": {"payroll": 2, "logistics": 1},
		},
	}


static func skills_in_tree(tree: String) -> Array[String]:
	var out: Array[String] = []
	for id in data():
		if data()[id]["tree"] == tree:
			out.append(id)
	return out


static func cost_for_rank(skill_id: String, rank: int) -> int:
	var s: Dictionary = data().get(skill_id, {})
	var costs: Array = s.get("cost", [])
	if rank <= 0 or rank > costs.size():
		return -1
	return int(costs[rank - 1])
