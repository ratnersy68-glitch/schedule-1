class_name ProductionService
extends RefCounted
## Starting, timing, quality-rolling and collecting production jobs.
##
## Jobs are stored on the StationState as absolute game-hour timestamps, so
## production continues correctly while the player is across the city, in a
## menu, or between sessions. Nothing here needs a per-frame tick.

## Inputs are drawn from the property's storage first, then the player's
## pockets. Output lands in storage, spilling to the player when storage is
## full so a job is never silently lost.
static func sources_for(prop: PropertyState) -> Array[Inventory]:
	return [prop.storage, GameState.inventory] as Array[Inventory]


static func total_available(sources: Array[Inventory], item_id: String) -> int:
	var n := 0
	for inv in sources:
		n += inv.count(item_id)
	return n


static func consume(sources: Array[Inventory], item_id: String, amount: int) -> int:
	var remaining := amount
	for inv in sources:
		if remaining <= 0:
			break
		remaining -= inv.remove(item_id, remaining)
	return amount - remaining


## Everything the UI needs to decide whether the Start button is enabled.
static func can_start(prop: PropertyState, station: StationState, recipe_id: String,
		additives: Array[String]) -> Dictionary:
	var recipe: Dictionary = GameData.recipe(recipe_id)
	if recipe.is_empty():
		return {"ok": false, "reason": "Unknown recipe"}
	if not GameState.knows_recipe(recipe_id):
		return {"ok": false, "reason": "You do not know this lattice"}
	if station.family != String(recipe["station"]):
		return {"ok": false, "reason": "Wrong station type"}
	if station.tier < int(recipe["station_tier"]):
		return {"ok": false, "reason": "Station tier too low"}
	if not station.is_idle(GameState.absolute_hours()):
		return {"ok": false, "reason": "Station is busy"}
	if prop.is_shutdown(GameState.absolute_hours()):
		return {"ok": false, "reason": "Property is shut down"}

	var sources := sources_for(prop)
	var missing: Array[String] = []
	for item_id in recipe["inputs"]:
		var need := int(recipe["inputs"][item_id])
		if total_available(sources, item_id) < need:
			missing.append("%dx %s" % [need, GameData.item_name(item_id)])
	for a in additives:
		if total_available(sources, a) < 1:
			missing.append(GameData.item_name(a))
	if not missing.is_empty():
		return {"ok": false, "reason": "Need " + ", ".join(missing)}

	if additives.size() > additive_slots():
		return {"ok": false, "reason": "Too many additives"}
	return {"ok": true, "reason": ""}


static func additive_slots() -> int:
	return 2 + int(GameState.skill_effect("additive_slots"))


## Quality is rolled at start so the player commits to a decision and then
## lives with it, rather than save-scumming the collect.
static func predict_quality(station: StationState, recipe_id: String,
		additives: Array[String], operator: Employee = null) -> Dictionary:
	var recipe: Dictionary = GameData.recipe(recipe_id)
	var score := float(recipe.get("base_quality", 0.3))
	var breakdown := {"base": score}

	var tier_bonus := float(station.tier - 1) * 0.07
	score += tier_bonus
	breakdown["station"] = tier_bonus

	var additive_bonus := 0.0
	for a in additives:
		additive_bonus += float(GameData.additives.get(a, {}).get("quality", 0.0))
	score += additive_bonus
	breakdown["additives"] = additive_bonus

	var skill_bonus := GameState.skill_effect("quality_bonus")
	score += skill_bonus
	breakdown["skill"] = skill_bonus

	var op_bonus := 0.0
	if operator != null:
		# An employee runs the bench slightly worse than a focused owner unless
		# they are genuinely skilled.
		op_bonus = (operator.skill - 0.55) * 0.18
		score += op_bonus
	breakdown["operator"] = op_bonus

	breakdown["score"] = clampf(score, 0.0, 1.0)
	breakdown["quality"] = RecipeDB.score_to_quality(breakdown["score"])
	return breakdown


static func effective_seconds(recipe_id: String, additives: Array[String],
		operator: Employee = null) -> float:
	var recipe: Dictionary = GameData.recipe(recipe_id)
	var seconds := float(recipe.get("seconds", 30.0))
	var speed := 1.0 + GameState.skill_effect("craft_speed")
	for a in additives:
		speed += float(GameData.additives.get(a, {}).get("speed", 0.0))
	if operator != null:
		speed *= 0.75 + operator.effectiveness() * 0.35
	return maxf(3.0, seconds / maxf(0.2, speed))


## Consumes inputs, rolls quality and stamps the completion time.
static func start_job(prop: PropertyState, station: StationState, recipe_id: String,
		additives: Array[String], operator: Employee = null) -> bool:
	var check := can_start(prop, station, recipe_id, additives)
	if not bool(check["ok"]):
		EventBus.production_failed.emit(station.id, String(check["reason"]))
		EventBus.toast_requested.emit(String(check["reason"]), "warn")
		return false

	var recipe: Dictionary = GameData.recipe(recipe_id)
	var sources := sources_for(prop)
	var save_chance := GameState.skill_effect("input_save_chance")

	for item_id in recipe["inputs"]:
		var need := int(recipe["inputs"][item_id])
		if need > 1 and randf() < save_chance:
			need -= 1
		consume(sources, item_id, need)
	for a in additives:
		consume(sources, a, 1)

	var prediction := predict_quality(station, recipe_id, additives, operator)
	# A small random wobble keeps every batch from being identical.
	var final_score := clampf(float(prediction["score"]) + randf_range(-0.05, 0.05), 0.0, 1.0)

	var amount := int(recipe.get("output_amount", 1))
	if randf() < GameState.skill_effect("extra_yield_chance"):
		amount += 1

	var seconds := effective_seconds(recipe_id, additives, operator)
	var now := GameState.absolute_hours()

	station.recipe_id = recipe_id
	station.additives = additives.duplicate()
	station.quality = RecipeDB.score_to_quality(final_score)
	station.output_amount = amount
	station.started_at = now
	station.ends_at = now + seconds / GameConfig.SECONDS_PER_GAME_HOUR
	station.collected = false
	station.operator_id = operator.id if operator != null else ""

	# Loud additives make the site more interesting to the Bureau.
	var heat := 0.0
	for a in additives:
		heat += float(GameData.additives.get(a, {}).get("heat", 0.0))
	prop.heat = clampf(prop.heat + heat * 4.0, 0.0, 100.0)

	EventBus.production_started.emit(station.id, recipe_id, seconds)
	return true


## Moves finished output into storage (or the player's pockets when full).
## Returns the number of units collected.
static func collect(prop: PropertyState, station: StationState) -> int:
	var now := GameState.absolute_hours()
	if not station.is_ready(now):
		return 0
	var recipe: Dictionary = GameData.recipe(station.recipe_id)
	if recipe.is_empty():
		station.clear_job()
		return 0

	var item_id := String(recipe["output"])
	var amount := station.output_amount
	var quality := station.quality

	var into_storage := 0
	if prop.can_store(amount):
		into_storage = prop.storage.add(item_id, amount, quality)
	var leftover := amount - into_storage
	var into_player := 0
	if leftover > 0:
		into_player = GameState.inventory.add(item_id, leftover, quality)
	var collected := into_storage + into_player

	if collected < amount:
		EventBus.toast_requested.emit("No room for %d units - they were lost" % (amount - collected), "warn")

	GameState.add_xp(int(recipe.get("xp", 5)), "production")
	if station.operator_id != "":
		var e: Employee = GameState.employees.get(station.operator_id)
		if e != null:
			e.lifetime_produced += collected

	station.clear_job()
	EventBus.production_finished.emit(station.id, item_id, quality, collected)
	return collected


## Collects every finished job across every owned property. Used by the phone
## and by the "collect all" button at a workstation.
static func collect_all() -> int:
	var total := 0
	for prop in GameState.all_owned_properties():
		for station in prop.stations:
			total += collect(prop, station)
	return total


static func pending_output_count() -> int:
	var now := GameState.absolute_hours()
	var n := 0
	for prop in GameState.all_owned_properties():
		for station in prop.stations:
			if station.is_ready(now):
				n += station.output_amount
	return n
