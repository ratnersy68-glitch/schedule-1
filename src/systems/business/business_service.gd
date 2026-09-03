class_name BusinessService
extends RefCounted
## Property purchase and upgrades, hiring, and the offline empire simulation.
##
## Everything here is driven by the world clock rather than a frame tick, so an
## empire keeps producing, selling and costing money whether or not the player
## is standing in the building.

# ===========================================================================
# PROPERTY
# ===========================================================================

static func unlock_met(property_id: String) -> bool:
	var def: Dictionary = GameData.property(property_id)
	var u: Dictionary = def.get("unlock", {})
	match String(u.get("type", "")):
		"level":
			return GameState.level >= int(u.get("value", 1))
		"district":
			return GameState.district_unlocked(String(u.get("value", "")))
		"story":
			return MissionService.is_completed(String(u.get("value", "")))
		"flag":
			return GameState.has_flag(String(u.get("value", "")))
		_:
			return true


static func unlock_hint(property_id: String) -> String:
	var u: Dictionary = GameData.property(property_id).get("unlock", {})
	match String(u.get("type", "")):
		"level":
			return "Requires level %d" % int(u.get("value", 1))
		"district":
			return "Requires access to " + GameData.district_name(String(u.get("value", "")))
		"story":
			return "Requires: " + String(GameData.mission(String(u.get("value", ""))).get("title", "a job"))
		"flag":
			return "Not available yet"
		_:
			return ""


static func can_buy(property_id: String) -> Dictionary:
	if GameState.owns_property(property_id):
		return {"ok": false, "reason": "Already yours"}
	if not unlock_met(property_id):
		return {"ok": false, "reason": unlock_hint(property_id)}
	var price := int(GameData.property(property_id).get("price", 0))
	if not GameState.can_afford(price):
		return {"ok": false, "reason": "Need " + GameConfig.format_money(price)}
	return {"ok": true, "reason": ""}


static func buy(property_id: String) -> bool:
	var check := can_buy(property_id)
	if not bool(check["ok"]):
		EventBus.toast_requested.emit(String(check["reason"]), "warn")
		return false
	var price := int(GameData.property(property_id).get("price", 0))
	if price > 0 and not GameState.spend(price, "Bought " + String(GameData.property(property_id).get("name", property_id))):
		return false
	GameState.grant_property(property_id)
	EventBus.toast_requested.emit("You own " + String(GameData.property(property_id).get("name", property_id)), "good")
	AudioDirector.play_ui("ui_confirm")
	return true


static func can_upgrade(property_id: String, track: String) -> Dictionary:
	var p: PropertyState = GameState.get_property(property_id)
	if p == null or not p.owned:
		return {"ok": false, "reason": "You do not own this"}
	var level := int(p.levels.get(track, 0))
	if level >= PropertyDB.track_max(property_id, track):
		return {"ok": false, "reason": "Fully upgraded"}
	var cost := PropertyDB.track_cost(property_id, track, level + 1)
	if cost < 0:
		return {"ok": false, "reason": "Fully upgraded"}
	if not GameState.can_afford(cost):
		return {"ok": false, "reason": "Need " + GameConfig.format_money(cost)}
	return {"ok": true, "reason": "", "cost": cost}


static func upgrade(property_id: String, track: String) -> bool:
	var check := can_upgrade(property_id, track)
	if not bool(check["ok"]):
		EventBus.toast_requested.emit(String(check["reason"]), "warn")
		return false
	var p: PropertyState = GameState.get_property(property_id)
	var cost := int(check["cost"])
	if not GameState.spend(cost, "%s upgrade - %s" % [PropertyDB.TRACK_LABELS.get(track, track), p.display_name()]):
		return false
	p.levels[track] = int(p.levels.get(track, 0)) + 1
	p.sync_stations()
	GameState.add_xp(int(cost / 40.0) + 20, "upgrade")
	EventBus.property_upgraded.emit(property_id, track, int(p.levels[track]))
	EventBus.toast_requested.emit("%s upgraded to level %d" %
		[PropertyDB.TRACK_LABELS.get(track, track), int(p.levels[track])], "good")
	AudioDirector.play_ui("ui_confirm")
	return true


# ===========================================================================
# STAFF
# ===========================================================================

static func free_employee_slots(property_id: String) -> int:
	var p: PropertyState = GameState.get_property(property_id)
	if p == null:
		return 0
	return maxi(0, p.employee_slots() - GameState.employees_at(property_id).size())


static func can_hire(archetype: String, property_id: String) -> Dictionary:
	var p: PropertyState = GameState.get_property(property_id)
	if p == null or not p.owned:
		return {"ok": false, "reason": "Buy the property first"}
	if free_employee_slots(property_id) <= 0:
		return {"ok": false, "reason": "No staff space - upgrade Staff Quarters"}
	var cost := int(GameData.employee_archetypes.get(archetype, {}).get("hire_cost", 0))
	if not GameState.can_afford(cost):
		return {"ok": false, "reason": "Need " + GameConfig.format_money(cost)}
	return {"ok": true, "reason": "", "cost": cost}


static func random_person_name() -> String:
	var first := NpcDB.first_names()
	var last := NpcDB.last_names()
	return "%s %s" % [first[randi() % first.size()], last[randi() % last.size()]]


static func hire(archetype: String, property_id: String, person_name: String = "") -> Employee:
	var check := can_hire(archetype, property_id)
	if not bool(check["ok"]):
		EventBus.toast_requested.emit(String(check["reason"]), "warn")
		return null
	if not GameState.spend(int(check["cost"]), "Hired " + String(GameData.employee_archetypes[archetype].get("label", "staff"))):
		return null
	var e := Employee.create(archetype, person_name if person_name != "" else random_person_name(),
		GameState.next_employee_id())
	e.property_id = property_id
	e.assignment = _default_assignment(archetype)
	GameState.employees[e.id] = e
	var p: PropertyState = GameState.get_property(property_id)
	if p != null and not p.employee_ids.has(e.id):
		p.employee_ids.append(e.id)
	EventBus.employee_hired.emit(e.id, property_id)
	EventBus.toast_requested.emit("%s joined at %s" % [e.name, p.display_name() if p else property_id], "good")
	return e


static func _default_assignment(archetype: String) -> String:
	var jobs: Array = GameData.employee_archetypes.get(archetype, {}).get("jobs", [])
	if jobs.has(Employee.ASSIGN_PRODUCTION):
		return Employee.ASSIGN_PRODUCTION
	if jobs.has(Employee.ASSIGN_SELL):
		return Employee.ASSIGN_SELL
	if jobs.has(Employee.ASSIGN_SECURITY):
		return Employee.ASSIGN_SECURITY
	return Employee.ASSIGN_IDLE


static func fire(employee_id: String) -> void:
	var e: Employee = GameState.employees.get(employee_id)
	if e == null:
		return
	var p: PropertyState = GameState.get_property(e.property_id)
	if p != null:
		p.employee_ids.erase(employee_id)
		for s in p.stations:
			if s.operator_id == employee_id:
				s.operator_id = ""
	GameState.employees.erase(employee_id)
	# A poorly-treated worker leaves with a grudge and a little of your heat.
	if e.loyalty < 0.3:
		GameState.add_heat(p.district_id() if p else GameState.current_district, 8.0)
		EventBus.toast_requested.emit("%s left angry. Somebody will hear about it." % e.name, "warn")
	else:
		EventBus.toast_requested.emit("%s is off the payroll" % e.name, "info")
	EventBus.employee_fired.emit(employee_id)


static func assign(employee_id: String, assignment: String) -> bool:
	var e: Employee = GameState.employees.get(employee_id)
	if e == null:
		return false
	if assignment != Employee.ASSIGN_IDLE and not e.can_do(assignment):
		EventBus.toast_requested.emit("%s cannot do that job" % e.name, "warn")
		return false
	e.assignment = assignment
	return true


static func transfer(employee_id: String, property_id: String) -> bool:
	var e: Employee = GameState.employees.get(employee_id)
	if e == null or e.property_id == property_id:
		return false
	if free_employee_slots(property_id) <= 0:
		EventBus.toast_requested.emit("No space at that property", "warn")
		return false
	var old: PropertyState = GameState.get_property(e.property_id)
	if old != null:
		old.employee_ids.erase(employee_id)
		for s in old.stations:
			if s.operator_id == employee_id:
				s.operator_id = ""
	e.property_id = property_id
	var p: PropertyState = GameState.get_property(property_id)
	if p != null and not p.employee_ids.has(employee_id):
		p.employee_ids.append(employee_id)
	return true


# ===========================================================================
# HOURLY SIMULATION
# ===========================================================================

## Runs once per in-game hour for every owned property.
static func tick_hour() -> void:
	var now := GameState.absolute_hours()
	for p in GameState.all_owned_properties():
		if p.is_shutdown(now):
			continue
		_tick_production(p, now)
		_tick_sales(p)
		_tick_haul(p)
		_tick_front(p)


static func _tick_production(p: PropertyState, now: float) -> void:
	var workers: Array[Employee] = []
	for e in GameState.employees_at(p.id):
		if e.assignment == Employee.ASSIGN_PRODUCTION:
			workers.append(e)
	if workers.is_empty():
		return

	var wi := 0
	for station in p.stations:
		# Always sweep finished output into storage so a bench never stalls.
		if station.is_ready(now):
			ProductionService.collect(p, station)
		if not station.is_idle(now):
			continue
		if wi >= workers.size():
			break
		var worker := workers[wi]
		var recipe_id := _best_recipe_for(p, station)
		if recipe_id == "":
			wi += 1
			continue
		station.operator_id = worker.id
		if ProductionService.start_job(p, station, recipe_id, [], worker):
			wi += 1


## Picks the most valuable recipe this station can actually run right now.
static func _best_recipe_for(p: PropertyState, station: StationState) -> String:
	var best := ""
	var best_value := -1
	for recipe_id in GameState.unlocked_recipes:
		var r: Dictionary = GameData.recipe(recipe_id)
		if r.is_empty() or String(r["station"]) != station.family:
			continue
		if station.tier < int(r["station_tier"]):
			continue
		var check := ProductionService.can_start(p, station, recipe_id, [])
		if not bool(check["ok"]):
			continue
		var value := GameData.item_value(String(r["output"])) * int(r.get("output_amount", 1))
		if value > best_value:
			best_value = value
			best = recipe_id
	return best


static func _tick_sales(p: PropertyState) -> void:
	var district := p.district_id()
	for e in GameState.employees_at(p.id):
		if e.assignment != Employee.ASSIGN_SELL:
			continue
		var rate := 0.6 * e.effectiveness()
		var units := int(floor(rate))
		if randf() < rate - units:
			units += 1
		if units <= 0:
			continue
		_sell_from_storage(p, district, units, e)


static func _sell_from_storage(p: PropertyState, district: String, units: int,
		seller: Employee) -> void:
	var sold := 0
	var revenue := 0
	for stack in p.storage.stacks.duplicate():
		if sold >= units:
			break
		var item_id := String(stack["item"])
		if GameData.item(item_id).get("category", "") != ItemDB.CAT_PRODUCT:
			continue
		var take: int = mini(int(stack["qty"]), units - sold)
		if take <= 0:
			continue
		var unit_value := EconomyService.unit_price(item_id, int(stack["quality"]),
			String(stack["pack"]), district)
		# Staff sell at a discount: they are not you.
		unit_value = int(unit_value * (0.72 + seller.skill * 0.2))
		p.storage.remove(item_id, take, int(stack["quality"]))
		revenue += unit_value * take
		sold += take
		EconomyService.register_sale(district, item_id, take, unit_value)
		# Careless staff attract attention.
		var heat := (1.0 - seller.discretion) * take * 1.6
		GameState.add_heat(district, heat)
		p.heat = clampf(p.heat + heat * 0.4, 0.0, 100.0)
	if sold > 0:
		GameState.add_cash(revenue, "%s street sales" % seller.name)
		seller.lifetime_sold += sold
		seller.lifetime_earned += revenue
		p.lifetime_revenue += revenue
		GameState.add_reputation(district, sold * 0.25)


## Haulers spend cash restocking the cheapest missing inputs.
static func _tick_haul(p: PropertyState) -> void:
	for e in GameState.employees_at(p.id):
		if e.assignment != Employee.ASSIGN_HAUL:
			continue
		var budget := int(120 * e.effectiveness())
		if GameState.cash < budget:
			continue
		var wanted := _shopping_list(p)
		if wanted.is_empty():
			continue
		var spent := 0
		for item_id in wanted:
			var price := EconomyService.buy_price(item_id, p.district_id(), 1.08)
			var qty: int = mini(int(wanted[item_id]), maxi(1, int((budget - spent) / maxi(1, price))))
			if qty <= 0:
				continue
			var cost := price * qty
			if spent + cost > budget or not GameState.can_afford(cost, false):
				continue
			if GameState.spend(cost, "%s supply run" % e.name, false):
				p.storage.add(item_id, qty)
				p.lifetime_costs += cost
				spent += cost


static func _shopping_list(p: PropertyState) -> Dictionary:
	var need := {}
	for recipe_id in GameState.unlocked_recipes:
		var r: Dictionary = GameData.recipe(recipe_id)
		if r.is_empty():
			continue
		var runnable := false
		for station in p.stations:
			if station.family == String(r["station"]) and station.tier >= int(r["station_tier"]):
				runnable = true
				break
		if not runnable:
			continue
		for item_id in r["inputs"]:
			if GameData.item(item_id).get("category", "") != ItemDB.CAT_MATERIAL:
				continue
			var have := p.storage.count(item_id)
			var target := int(r["inputs"][item_id]) * 6
			if have < target:
				need[item_id] = maxi(int(need.get(item_id, 0)), target - have)
	return need


## Retail fronts convert stock into clean revenue slowly and safely.
static func _tick_front(p: PropertyState) -> void:
	if not bool(GameData.property(p.id).get("sale_front", false)):
		return
	var staffed := 0
	for e in GameState.employees_at(p.id):
		if e.assignment == Employee.ASSIGN_SELL or e.assignment == Employee.ASSIGN_PRODUCTION:
			staffed += 1
	if staffed <= 0:
		return
	var rate := float(GameData.property(p.id).get("front_rate", 0.3)) * staffed
	rate *= 1.0 + GameState.skill_effect("front_rate")
	var units := int(floor(rate))
	if randf() < rate - units:
		units += 1
	if units <= 0:
		return
	var district := p.district_id()
	var sold := 0
	var revenue := 0
	for stack in p.storage.stacks.duplicate():
		if sold >= units:
			break
		var item_id := String(stack["item"])
		if GameData.item(item_id).get("category", "") != ItemDB.CAT_PRODUCT:
			continue
		var take: int = mini(int(stack["qty"]), units - sold)
		var unit_value := int(EconomyService.unit_price(item_id, int(stack["quality"]),
			String(stack["pack"]), district) * 0.85)
		p.storage.remove(item_id, take, int(stack["quality"]))
		revenue += unit_value * take
		sold += take
		EconomyService.register_sale(district, item_id, take, unit_value)
	if sold > 0:
		# Front revenue arrives clean, straight into the bank.
		GameState.bank += revenue
		EventBus.bank_changed.emit(GameState.bank, revenue)
		p.lifetime_revenue += revenue


# ===========================================================================
# DAILY SETTLEMENT
# ===========================================================================

static func settle_day() -> Dictionary:
	var wages := 0
	var upkeep := 0
	var unpaid: Array[String] = []
	var quits: Array[String] = []

	for p in GameState.all_owned_properties():
		var cost := p.daily_upkeep()
		upkeep += cost
		p.lifetime_costs += cost

	for eid in GameState.employees.keys():
		var e: Employee = GameState.employees[eid]
		wages += e.daily_wage()

	var total := wages + upkeep
	var paid := GameState.spend(total, "Daily costs")
	if not paid:
		# Pay what we can: upkeep first (losing a property is worse).
		var available := GameState.cash + GameState.bank
		if available >= upkeep:
			GameState.spend(upkeep, "Property upkeep")
			var left := available - upkeep
			for eid in GameState.employees.keys():
				var e: Employee = GameState.employees[eid]
				var wage := e.daily_wage()
				if left >= wage:
					GameState.spend(wage, "Wages")
					left -= wage
					e.unpaid_days = 0
					e.loyalty = clampf(e.loyalty + 0.02, 0.0, 1.0)
				else:
					e.unpaid_days += 1
					e.loyalty = clampf(e.loyalty - 0.22, 0.0, 1.0)
					unpaid.append(e.name)
		else:
			for eid in GameState.employees.keys():
				var e: Employee = GameState.employees[eid]
				e.unpaid_days += 1
				e.loyalty = clampf(e.loyalty - 0.3, 0.0, 1.0)
				unpaid.append(e.name)
			GameState.spend(available, "Partial upkeep")
	else:
		for eid in GameState.employees.keys():
			var e: Employee = GameState.employees[eid]
			e.unpaid_days = 0
			e.days_employed += 1
			e.loyalty = clampf(e.loyalty + 0.015, 0.0, 1.0)

	# Disloyal, unpaid staff walk out (and sometimes take stock with them).
	for eid in GameState.employees.keys():
		var e: Employee = GameState.employees[eid]
		if e.unpaid_days >= 2 and e.loyalty < 0.25:
			quits.append(e.name)
			var p: PropertyState = GameState.get_property(e.property_id)
			if p != null and randf() < 0.5:
				p.storage.seize(0.12)
			fire(eid)

	# Reputation erodes if you go quiet.
	for did in GameState.unlocked_districts:
		GameState.add_reputation(did, -GameConfig.REP_DECAY_PER_DAY)

	var summary := {
		"day": GameState.day, "wages": wages, "upkeep": upkeep,
		"total": total, "paid": paid, "unpaid": unpaid, "quits": quits,
		"cash": GameState.cash, "bank": GameState.bank,
	}
	EventBus.daily_settlement.emit(summary)
	if total > 0:
		var kind := "info" if paid else "bad"
		EventBus.phone_notification.emit("bank", "Day %d costs" % GameState.day,
			"Wages %s, upkeep %s.%s" % [GameConfig.format_money(wages),
				GameConfig.format_money(upkeep),
				"" if paid else " You could not cover it."])
		EventBus.toast_requested.emit("Daily costs: " + GameConfig.format_money(total), kind)
	return summary
