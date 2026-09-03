extends Node
## The single source of truth for everything the player owns, knows and is.
##
## GameState deliberately contains no gameplay *logic* beyond bookkeeping:
## economy, production, missions and enforcement are separate services that
## read and mutate this state. It also drives the world clock, because the
## clock is a saved value and every other system needs to read it.

# --- Money -----------------------------------------------------------------
var cash: int = 0
var bank: int = 0
var lifetime_earned: int = 0
var lifetime_spent: int = 0
var transactions: Array[Dictionary] = []   ## newest first, capped
const MAX_TRANSACTIONS := 120

# --- Clock -----------------------------------------------------------------
var day: int = GameConfig.START_DAY
var hour: float = GameConfig.START_HOUR    ## 0..24
var clock_running: bool = false
## Multiplier on the passage of time. 1.0 in normal play; the "--fasttime"
## command-line flag raises it so a QA soak can cover days in minutes.
var time_scale: float = 1.0
var weather: String = "clear"
var _weather_timer: float = 0.0
var _last_hour_int: int = -1

# --- Progression -----------------------------------------------------------
var xp: int = 0
var level: int = 1
var skill_points: int = 0
var skills: Dictionary = {}                ## skill_id -> rank
var unlocked_recipes: Array[String] = []
var unlocked_districts: Array[String] = []
var flags: Dictionary = {}                 ## story flags -> true
var influence: float = 0.0                 ## 0..1 toward the City Influence ending
var endgame_paths: Array[String] = []      ## achieved endings

# --- Standing --------------------------------------------------------------
var reputation: Dictionary = {}            ## district_id -> -50..100
var district_heat: Dictionary = {}         ## district_id -> 0..100
var relationships: Dictionary = {}         ## npc_id -> -100..100
var met_npcs: Array[String] = []

# --- Possessions -----------------------------------------------------------
var inventory: Inventory = null
var properties: Dictionary = {}            ## property_id -> PropertyState
var employees: Dictionary = {}             ## employee_id -> Employee
var owned_vehicles: Array[Dictionary] = [] ## [{id, type, district, pos, storage}]
var _employee_counter: int = 0

# --- Session ---------------------------------------------------------------
var current_district: String = "dockside"
var player_position: Vector3 = Vector3.ZERO
var player_yaw: float = 0.0
var play_seconds: float = 0.0
var seed_value: int = 0


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_PAUSABLE
	if OS.get_cmdline_user_args().has("--fasttime"):
		time_scale = 20.0
	reset()


func _process(delta: float) -> void:
	if not clock_running:
		return
	play_seconds += delta
	_advance_clock(delta)


# ===========================================================================
# NEW GAME / RESET
# ===========================================================================

func reset() -> void:
	cash = GameConfig.STARTING_CASH
	bank = GameConfig.STARTING_BANK
	lifetime_earned = 0
	lifetime_spent = 0
	transactions.clear()

	day = GameConfig.START_DAY
	hour = GameConfig.START_HOUR
	_last_hour_int = int(hour)
	weather = "clear"
	clock_running = false

	xp = 0
	level = 1
	skill_points = 1
	skills.clear()
	influence = 0.0
	endgame_paths.clear()
	flags.clear()

	unlocked_recipes.clear()
	for rid in GameData.recipes:
		if bool(GameData.recipes[rid].get("unlocked_by_default", false)):
			unlocked_recipes.append(rid)

	unlocked_districts.clear()
	reputation.clear()
	district_heat.clear()
	for did in GameData.district_ids:
		reputation[did] = 0.0
		district_heat[did] = 0.0
		if bool(GameData.district(did).get("unlocked", false)):
			unlocked_districts.append(did)

	relationships.clear()
	met_npcs.clear()

	inventory = Inventory.new("player", GameConfig.BASE_INVENTORY_SLOTS)
	properties.clear()
	employees.clear()
	owned_vehicles.clear()
	_employee_counter = 0

	current_district = "dockside"
	player_position = Vector3.ZERO
	player_yaw = 0.0
	play_seconds = 0.0
	seed_value = randi()


## Grants the prologue kit so a brand new game is immediately playable.
func grant_starter_kit() -> void:
	inventory.add("ferro_silt", 4)
	inventory.add("bloomspore", 2)
	inventory.add("binder_resin", 2)
	inventory.add("paper_wrap", 6)
	inventory.add("scrap_bundle", 3)


# ===========================================================================
# CLOCK
# ===========================================================================

func absolute_hours() -> float:
	return float(day - 1) * 24.0 + hour


func is_night() -> bool:
	return hour < GameConfig.DAWN_HOUR or hour >= GameConfig.DUSK_HOUR


func day_phase() -> String:
	if hour < 5.0:
		return "night"
	if hour < 8.0:
		return "dawn"
	if hour < 17.0:
		return "day"
	if hour < 20.0:
		return "dusk"
	return "night"


func _advance_clock(delta: float) -> void:
	hour += delta * time_scale / GameConfig.SECONDS_PER_GAME_HOUR
	while hour >= 24.0:
		hour -= 24.0
		day += 1
		EventBus.day_passed.emit(day)
	var h := int(floor(hour))
	if h != _last_hour_int:
		_last_hour_int = h
		EventBus.hour_passed.emit(day, h)

	_weather_timer -= delta
	if _weather_timer <= 0.0:
		_roll_weather()


func _roll_weather() -> void:
	_weather_timer = randf_range(180.0, 420.0)
	var options := ["clear", "clear", "overcast", "rain", "fog", "storm"]
	var pick: String = options[randi() % options.size()]
	if pick == weather:
		return
	weather = pick
	EventBus.weather_changed.emit(weather)


func set_clock_running(running: bool) -> void:
	clock_running = running


# ===========================================================================
# MONEY
# ===========================================================================

func add_cash(amount: int, reason: String = "") -> void:
	if amount == 0:
		return
	cash += amount
	if amount > 0:
		lifetime_earned += amount
	else:
		lifetime_spent += -amount
	_log_transaction(amount, reason, "cash")
	EventBus.cash_changed.emit(cash, amount)


func can_afford(amount: int, allow_bank: bool = true) -> bool:
	return (cash + (bank if allow_bank else 0)) >= amount


## Spends from cash first, then the bank. Returns false if unaffordable.
func spend(amount: int, reason: String = "", allow_bank: bool = true) -> bool:
	if amount <= 0:
		return true
	if not can_afford(amount, allow_bank):
		return false
	var from_cash: int = mini(cash, amount)
	if from_cash > 0:
		cash -= from_cash
		EventBus.cash_changed.emit(cash, -from_cash)
	var rest := amount - from_cash
	if rest > 0:
		bank -= rest
		EventBus.bank_changed.emit(bank, -rest)
	lifetime_spent += amount
	_log_transaction(-amount, reason, "spend")
	return true


func deposit(amount: int) -> bool:
	if amount <= 0 or cash < amount:
		return false
	var fee_rate := GameConfig.LAUNDER_FEE - _front_launder_bonus()
	var fee := int(round(amount * maxf(0.0, fee_rate)))
	cash -= amount
	bank += amount - fee
	EventBus.cash_changed.emit(cash, -amount)
	EventBus.bank_changed.emit(bank, amount - fee)
	_log_transaction(-fee, "Laundering fee", "fee")
	return true


func withdraw(amount: int) -> bool:
	if amount <= 0 or bank < amount:
		return false
	bank -= amount
	cash += amount
	EventBus.bank_changed.emit(bank, -amount)
	EventBus.cash_changed.emit(cash, amount)
	return true


func net_worth() -> int:
	var total := cash + bank
	total += inventory.estimated_value()
	for pid in properties:
		var p: PropertyState = properties[pid]
		if not p.owned:
			continue
		total += int(GameData.property(pid).get("price", 0))
		total += p.storage.estimated_value()
	for v in owned_vehicles:
		total += int(GameData.vehicle(String(v.get("type", ""))).get("price", 0)) / 2
	return total


func _front_launder_bonus() -> float:
	var bonus := 0.0
	for pid in properties:
		var p: PropertyState = properties[pid]
		if p.owned:
			bonus += float(GameData.property(pid).get("launder_bonus", 0.0))
	return bonus


func _log_transaction(amount: int, reason: String, kind: String) -> void:
	if reason == "":
		return
	var entry := {"amount": amount, "reason": reason, "kind": kind,
		"day": day, "hour": hour}
	transactions.push_front(entry)
	if transactions.size() > MAX_TRANSACTIONS:
		transactions.resize(MAX_TRANSACTIONS)
	EventBus.transaction_logged.emit(entry)


# ===========================================================================
# PROGRESSION
# ===========================================================================

func add_xp(amount: int, source: String = "") -> void:
	if amount <= 0 or level >= GameConfig.MAX_LEVEL:
		return
	xp += amount
	EventBus.xp_gained.emit(amount, source)
	while level < GameConfig.MAX_LEVEL and xp >= GameConfig.xp_for_level(level + 1):
		level += 1
		skill_points += GameConfig.SKILL_POINTS_PER_LEVEL
		EventBus.level_up.emit(level, skill_points)
		EventBus.toast_requested.emit("Level %d - %d skill point%s available" %
			[level, skill_points, "" if skill_points == 1 else "s"], "good")


func xp_progress() -> float:
	if level >= GameConfig.MAX_LEVEL:
		return 1.0
	var lo := GameConfig.xp_for_level(level)
	var hi := GameConfig.xp_for_level(level + 1)
	if hi <= lo:
		return 1.0
	return clampf(float(xp - lo) / float(hi - lo), 0.0, 1.0)


func skill_rank(skill_id: String) -> int:
	return int(skills.get(skill_id, 0))


## Sum of every purchased rank's contribution to an effect key.
func skill_effect(effect_key: String) -> float:
	var total := 0.0
	for sid in skills:
		var s: Dictionary = GameData.skill(sid)
		if s.get("effect", "") == effect_key:
			total += float(s.get("per_rank", 0.0)) * int(skills[sid])
	return total


func can_purchase_skill(skill_id: String) -> bool:
	var s: Dictionary = GameData.skill(skill_id)
	if s.is_empty():
		return false
	var rank := skill_rank(skill_id)
	if rank >= int(s.get("ranks", 1)):
		return false
	var cost := SkillDB.cost_for_rank(skill_id, rank + 1)
	if cost < 0 or skill_points < cost:
		return false
	for req_id in s.get("requires", {}):
		if skill_rank(req_id) < int(s["requires"][req_id]):
			return false
	return true


func purchase_skill(skill_id: String) -> bool:
	if not can_purchase_skill(skill_id):
		return false
	var rank := skill_rank(skill_id) + 1
	skill_points -= SkillDB.cost_for_rank(skill_id, rank)
	skills[skill_id] = rank
	if inventory:
		inventory.set_capacity(personal_slots())
	EventBus.skill_purchased.emit(skill_id, rank)
	EventBus.toast_requested.emit("%s rank %d" % [GameData.skill(skill_id).get("name", skill_id), rank], "good")
	return true


func personal_slots() -> int:
	var base := GameConfig.BASE_INVENTORY_SLOTS
	var bonus := int(round(base * skill_effect("storage_bonus")))
	return clampi(base + bonus, base, GameConfig.MAX_INVENTORY_SLOTS)


# --- Flags, recipes, districts --------------------------------------------

func set_flag(flag: String, value: bool = true) -> void:
	if value:
		flags[flag] = true
	else:
		flags.erase(flag)


func has_flag(flag: String) -> bool:
	return flags.has(flag)


func unlock_recipe(recipe_id: String) -> void:
	if recipe_id == "" or unlocked_recipes.has(recipe_id):
		return
	unlocked_recipes.append(recipe_id)
	EventBus.recipe_unlocked.emit(recipe_id)
	EventBus.toast_requested.emit("Recipe learned: " + String(GameData.recipe(recipe_id).get("name", recipe_id)), "good")


func knows_recipe(recipe_id: String) -> bool:
	return unlocked_recipes.has(recipe_id)


func unlock_district(district_id: String) -> void:
	if district_id == "" or unlocked_districts.has(district_id):
		return
	unlocked_districts.append(district_id)
	EventBus.district_unlocked.emit(district_id)
	EventBus.toast_requested.emit(GameData.district_name(district_id) + " is open to you", "good")


func district_unlocked(district_id: String) -> bool:
	return unlocked_districts.has(district_id)


# ===========================================================================
# STANDING
# ===========================================================================

func get_reputation(district_id: String) -> float:
	return float(reputation.get(district_id, 0.0))


func add_reputation(district_id: String, delta: float) -> void:
	if not reputation.has(district_id):
		reputation[district_id] = 0.0
	var v := clampf(float(reputation[district_id]) + delta, GameConfig.REP_MIN, GameConfig.REP_MAX)
	reputation[district_id] = v
	EventBus.reputation_changed.emit(district_id, v)


func average_reputation() -> float:
	if reputation.is_empty():
		return 0.0
	var total := 0.0
	for k in reputation:
		total += float(reputation[k])
	return total / float(reputation.size())


func min_reputation() -> float:
	var lowest := GameConfig.REP_MAX
	for did in unlocked_districts:
		lowest = minf(lowest, get_reputation(did))
	return lowest if not unlocked_districts.is_empty() else 0.0


func get_heat(district_id: String) -> float:
	return float(district_heat.get(district_id, 0.0))


func add_heat(district_id: String, delta: float) -> void:
	if not district_heat.has(district_id):
		district_heat[district_id] = 0.0
	var v := clampf(float(district_heat[district_id]) + delta, 0.0, 100.0)
	district_heat[district_id] = v
	EventBus.heat_changed.emit(district_id, v)


func relationship(npc_id: String) -> float:
	return float(relationships.get(npc_id, 0.0))


func add_relationship(npc_id: String, delta: float) -> void:
	var v := clampf(relationship(npc_id) + delta, -100.0, 100.0)
	relationships[npc_id] = v
	EventBus.npc_relationship_changed.emit(npc_id, v)


func meet_npc(npc_id: String) -> void:
	if met_npcs.has(npc_id):
		return
	met_npcs.append(npc_id)
	EventBus.npc_met.emit(npc_id)


# ===========================================================================
# PROPERTY & STAFF
# ===========================================================================

func owns_property(property_id: String) -> bool:
	var p: PropertyState = properties.get(property_id)
	return p != null and p.owned


func owned_property_count() -> int:
	var n := 0
	for pid in properties:
		if (properties[pid] as PropertyState).owned:
			n += 1
	return n


func get_property(property_id: String) -> PropertyState:
	return properties.get(property_id)


func grant_property(property_id: String) -> PropertyState:
	var p: PropertyState = properties.get(property_id)
	if p == null:
		p = PropertyState.new(property_id)
		properties[property_id] = p
	p.owned = true
	p.purchased_on_day = day
	p.sync_stations()
	EventBus.property_purchased.emit(property_id)
	return p


func all_owned_properties() -> Array[PropertyState]:
	var out: Array[PropertyState] = []
	for pid in properties:
		var p: PropertyState = properties[pid]
		if p.owned:
			out.append(p)
	return out


func total_stored_units() -> int:
	var n := inventory.total_units()
	for p in all_owned_properties():
		n += p.stored_units()
	return n


func employee_count() -> int:
	return employees.size()


func next_employee_id() -> String:
	_employee_counter += 1
	return "emp_%d" % _employee_counter


func employees_at(property_id: String) -> Array[Employee]:
	var out: Array[Employee] = []
	for eid in employees:
		var e: Employee = employees[eid]
		if e.property_id == property_id:
			out.append(e)
	return out


func daily_payroll() -> int:
	var total := 0
	for eid in employees:
		total += (employees[eid] as Employee).daily_wage()
	return total


func daily_upkeep_total() -> int:
	var total := 0
	for p in all_owned_properties():
		total += p.daily_upkeep()
	return total


func owns_vehicle(vehicle_type: String) -> bool:
	for v in owned_vehicles:
		if String(v.get("type", "")) == vehicle_type:
			return true
	return false


# ===========================================================================
# SAVE / LOAD
# ===========================================================================

func to_dict() -> Dictionary:
	var props := {}
	for pid in properties:
		props[pid] = (properties[pid] as PropertyState).to_dict()
	var emps := {}
	for eid in employees:
		emps[eid] = (employees[eid] as Employee).to_dict()
	return {
		"cash": cash, "bank": bank,
		"lifetime_earned": lifetime_earned, "lifetime_spent": lifetime_spent,
		"transactions": transactions.duplicate(true),
		"day": day, "hour": hour, "weather": weather,
		"xp": xp, "level": level, "skill_points": skill_points,
		"skills": skills.duplicate(), "influence": influence,
		"endgame_paths": endgame_paths.duplicate(),
		"unlocked_recipes": unlocked_recipes.duplicate(),
		"unlocked_districts": unlocked_districts.duplicate(),
		"flags": flags.duplicate(),
		"reputation": reputation.duplicate(), "district_heat": district_heat.duplicate(),
		"relationships": relationships.duplicate(), "met_npcs": met_npcs.duplicate(),
		"inventory": inventory.to_dict(),
		"properties": props, "employees": emps,
		"employee_counter": _employee_counter,
		"owned_vehicles": owned_vehicles.duplicate(true),
		"current_district": current_district,
		"player_position": [player_position.x, player_position.y, player_position.z],
		"player_yaw": player_yaw,
		"play_seconds": play_seconds, "seed_value": seed_value,
	}


func from_dict(d: Dictionary) -> void:
	reset()
	cash = int(d.get("cash", GameConfig.STARTING_CASH))
	bank = int(d.get("bank", 0))
	lifetime_earned = int(d.get("lifetime_earned", 0))
	lifetime_spent = int(d.get("lifetime_spent", 0))
	transactions.clear()
	for t in d.get("transactions", []):
		if typeof(t) == TYPE_DICTIONARY:
			transactions.append(t)

	day = int(d.get("day", 1))
	hour = float(d.get("hour", 8.0))
	_last_hour_int = int(hour)
	weather = String(d.get("weather", "clear"))

	xp = int(d.get("xp", 0))
	level = int(d.get("level", 1))
	skill_points = int(d.get("skill_points", 0))
	skills = (d.get("skills", {}) as Dictionary).duplicate()
	influence = float(d.get("influence", 0.0))
	endgame_paths = _to_string_array(d.get("endgame_paths", []))
	unlocked_recipes = _to_string_array(d.get("unlocked_recipes", []))
	unlocked_districts = _to_string_array(d.get("unlocked_districts", []))
	flags = (d.get("flags", {}) as Dictionary).duplicate()

	reputation = (d.get("reputation", {}) as Dictionary).duplicate()
	district_heat = (d.get("district_heat", {}) as Dictionary).duplicate()
	relationships = (d.get("relationships", {}) as Dictionary).duplicate()
	met_npcs = _to_string_array(d.get("met_npcs", []))
	for did in GameData.district_ids:
		if not reputation.has(did):
			reputation[did] = 0.0
		if not district_heat.has(did):
			district_heat[did] = 0.0

	inventory = Inventory.new("player", GameConfig.BASE_INVENTORY_SLOTS)
	inventory.from_dict(d.get("inventory", {}))
	inventory.set_capacity(personal_slots())

	properties.clear()
	var props: Dictionary = d.get("properties", {})
	for pid in props:
		if GameData.properties.has(pid):
			properties[pid] = PropertyState.from_dict(props[pid])

	employees.clear()
	var emps: Dictionary = d.get("employees", {})
	for eid in emps:
		employees[eid] = Employee.from_dict(emps[eid])
	_employee_counter = int(d.get("employee_counter", employees.size()))

	owned_vehicles.clear()
	for v in d.get("owned_vehicles", []):
		if typeof(v) == TYPE_DICTIONARY:
			owned_vehicles.append(v)

	current_district = String(d.get("current_district", "dockside"))
	var pp: Array = d.get("player_position", [0, 0, 0])
	if pp.size() >= 3:
		player_position = Vector3(pp[0], pp[1], pp[2])
	player_yaw = float(d.get("player_yaw", 0.0))
	play_seconds = float(d.get("play_seconds", 0.0))
	seed_value = int(d.get("seed_value", randi()))


func _to_string_array(src: Variant) -> Array[String]:
	var out: Array[String] = []
	if src is Array:
		for v in src:
			out.append(String(v))
	return out
