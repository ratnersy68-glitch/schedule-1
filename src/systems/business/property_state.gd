class_name PropertyState
extends RefCounted
## Runtime state of one owned property.
##
## Holds the upgrade ladder positions, on-site storage, production stations,
## assigned staff, accumulated heat and any active Bureau shutdown.

var id: String = ""
var owned: bool = false
var levels: Dictionary = {"storage": 0, "production": 0, "staff": 0, "security": 0}
var storage: Inventory = null
var stations: Array[StationState] = []
var employee_ids: Array[String] = []
var heat: float = 0.0                ## 0..100, on-site attention
var shutdown_until: float = -1.0     ## absolute game hours, -1 = open
var under_investigation: bool = false
var lifetime_revenue: int = 0
var lifetime_costs: int = 0
var purchased_on_day: int = 0


func _init(property_id: String = "") -> void:
	id = property_id
	storage = Inventory.new("prop_" + property_id, 12)
	storage.allow_overflow = true


func def() -> Dictionary:
	return GameData.property(id)


func display_name() -> String:
	return String(def().get("name", id))


func district_id() -> String:
	return String(def().get("district", "dockside"))


# --- Derived capacities ----------------------------------------------------

func storage_capacity() -> int:
	var base := float(def().get("base_storage", 20))
	var v := PropertyDB.track_value(id, "storage", int(levels.get("storage", 0)), "storage", base)
	v *= 1.0 + GameState.skill_effect("storage_bonus")
	return int(round(v))


func station_slots() -> int:
	var base := float(def().get("base_stations", 1))
	return int(PropertyDB.track_value(id, "production", int(levels.get("production", 0)), "stations", base))


func station_tier() -> int:
	var base := int(def().get("base_station_tier", 1))
	var up: Dictionary = def().get("upgrades", {}).get("production", {})
	var arr: Array = up.get("tier", [])
	var lvl := int(levels.get("production", 0))
	if lvl > 0 and not arr.is_empty():
		return int(arr[clampi(lvl - 1, 0, arr.size() - 1)])
	return base


func employee_slots() -> int:
	var base := float(def().get("base_employees", 0))
	return int(PropertyDB.track_value(id, "staff", int(levels.get("staff", 0)), "employees", base))


func security_rating() -> float:
	var base := float(def().get("base_security", 0.0))
	return clampf(PropertyDB.track_value(id, "security", int(levels.get("security", 0)), "security", base), 0.0, 0.95)


func daily_upkeep() -> int:
	var base := float(def().get("daily_upkeep", 0))
	# Upgrades add running cost: 6% of each upgrade's price per day.
	var extra := 0.0
	for track in PropertyDB.TRACKS:
		var lvl := int(levels.get(track, 0))
		for i in range(1, lvl + 1):
			extra += PropertyDB.track_cost(id, track, i) * 0.012
	var total := (base + extra) * (1.0 - clampf(GameState.skill_effect("upkeep_reduction"), 0.0, 0.7))
	return int(round(total))


func is_shutdown(now_hours: float) -> bool:
	return shutdown_until > 0.0 and now_hours < shutdown_until


func influence() -> float:
	return float(def().get("influence", 0.0))


# --- Stations --------------------------------------------------------------

func sync_stations() -> void:
	var want := station_slots()
	var tier := station_tier()
	# Grow: the first slot is a bench, then alternate cultivator / kiln / press.
	var order := [RecipeDB.STATION_BENCH, RecipeDB.STATION_CULTIVATOR,
		RecipeDB.STATION_KILN, RecipeDB.STATION_PRESS, RecipeDB.STATION_BENCH]
	while stations.size() < want:
		var s := StationState.new()
		s.id = "%s_st%d" % [id, stations.size()]
		s.family = order[stations.size() % order.size()]
		s.property_id = id
		stations.append(s)
	while stations.size() > want:
		stations.pop_back()
	for s in stations:
		s.tier = tier
	storage.set_capacity(maxi(12, int(ceil(storage_capacity() / 20.0)) + 8))


func station_by_id(station_id: String) -> StationState:
	for s in stations:
		if s.id == station_id:
			return s
	return null


func stored_units() -> int:
	return storage.total_units()


func storage_ratio() -> float:
	var cap := storage_capacity()
	if cap <= 0:
		return 1.0
	return clampf(float(stored_units()) / float(cap), 0.0, 1.0)


func can_store(amount: int) -> bool:
	return stored_units() + amount <= storage_capacity()


# --- Serialisation ---------------------------------------------------------

func to_dict() -> Dictionary:
	var st: Array = []
	for s in stations:
		st.append(s.to_dict())
	return {
		"id": id, "owned": owned, "levels": levels.duplicate(),
		"storage": storage.to_dict(), "stations": st,
		"employee_ids": employee_ids.duplicate(), "heat": heat,
		"shutdown_until": shutdown_until, "under_investigation": under_investigation,
		"lifetime_revenue": lifetime_revenue, "lifetime_costs": lifetime_costs,
		"purchased_on_day": purchased_on_day,
	}


static func from_dict(d: Dictionary) -> PropertyState:
	var p := PropertyState.new(String(d.get("id", "")))
	p.owned = bool(d.get("owned", false))
	var lv: Dictionary = d.get("levels", {})
	for track in PropertyDB.TRACKS:
		p.levels[track] = int(lv.get(track, 0))
	p.storage.from_dict(d.get("storage", {}))
	p.storage.allow_overflow = true
	p.stations.clear()
	for raw in d.get("stations", []):
		p.stations.append(StationState.from_dict(raw))
	var ids: Array[String] = []
	for e in d.get("employee_ids", []):
		ids.append(String(e))
	p.employee_ids = ids
	p.heat = float(d.get("heat", 0.0))
	p.shutdown_until = float(d.get("shutdown_until", -1.0))
	p.under_investigation = bool(d.get("under_investigation", false))
	p.lifetime_revenue = int(d.get("lifetime_revenue", 0))
	p.lifetime_costs = int(d.get("lifetime_costs", 0))
	p.purchased_on_day = int(d.get("purchased_on_day", 0))
	return p
