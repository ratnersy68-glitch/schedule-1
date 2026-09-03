class_name StationState
extends RefCounted
## Persistent state of one production station inside a property.
##
## Stations run a single job at a time. A job records the recipe, the additives
## slotted into it, the quality score rolled at start, and the in-game hour the
## job completes at, so production keeps running while the player is elsewhere.

var id: String = ""
var family: String = RecipeDB.STATION_BENCH
var tier: int = 1
var property_id: String = ""

# Active job (empty when idle)
var recipe_id: String = ""
var additives: Array[String] = []
var quality: int = 0
var output_amount: int = 0
var started_at: float = 0.0      ## absolute game hours
var ends_at: float = 0.0         ## absolute game hours
var collected: bool = true       ## false when finished output is waiting
var operator_id: String = ""     ## employee running this station, if any


func is_busy(now_hours: float) -> bool:
	return recipe_id != "" and now_hours < ends_at


func is_ready(now_hours: float) -> bool:
	return recipe_id != "" and now_hours >= ends_at and not collected


func is_idle(now_hours: float) -> bool:
	return recipe_id == "" or (collected and now_hours >= ends_at)


func progress(now_hours: float) -> float:
	if recipe_id == "" or ends_at <= started_at:
		return 0.0
	return clampf((now_hours - started_at) / (ends_at - started_at), 0.0, 1.0)


func seconds_remaining(now_hours: float) -> float:
	return maxf(0.0, (ends_at - now_hours) * GameConfig.SECONDS_PER_GAME_HOUR)


func clear_job() -> void:
	recipe_id = ""
	additives.clear()
	quality = 0
	output_amount = 0
	started_at = 0.0
	ends_at = 0.0
	collected = true


func display_name() -> String:
	return RecipeDB.STATION_NAMES.get(family, "Station") + " " + ("I" if tier <= 1 else ("II" if tier == 2 else ("III" if tier == 3 else "IV")))


func to_dict() -> Dictionary:
	return {
		"id": id, "family": family, "tier": tier, "property_id": property_id,
		"recipe_id": recipe_id, "additives": additives.duplicate(),
		"quality": quality, "output_amount": output_amount,
		"started_at": started_at, "ends_at": ends_at, "collected": collected,
		"operator_id": operator_id,
	}


static func from_dict(d: Dictionary) -> StationState:
	var s := StationState.new()
	s.id = String(d.get("id", ""))
	s.family = String(d.get("family", RecipeDB.STATION_BENCH))
	s.tier = int(d.get("tier", 1))
	s.property_id = String(d.get("property_id", ""))
	s.recipe_id = String(d.get("recipe_id", ""))
	var adds: Array[String] = []
	for a in d.get("additives", []):
		adds.append(String(a))
	s.additives = adds
	s.quality = int(d.get("quality", 0))
	s.output_amount = int(d.get("output_amount", 0))
	s.started_at = float(d.get("started_at", 0.0))
	s.ends_at = float(d.get("ends_at", 0.0))
	s.collected = bool(d.get("collected", true))
	s.operator_id = String(d.get("operator_id", ""))
	if s.recipe_id != "" and not GameData.recipes.has(s.recipe_id):
		s.clear_job()  # recipe removed by a content update
	return s
