extends Node
## Mission offering, objective tracking, rewards, world events and endings.
##
## Objectives come in two flavours:
##   * cumulative  - craft / sell / talk / deliver / earn: a counter that only
##                   ever goes up, fed by EventBus signals.
##   * stateful    - collect / level / rep / buy_property / hire / flag /
##                   avoid_wanted / evade / goto: recomputed from GameState on
##                   a slow poll so they cannot desync from reality.

const POLL_INTERVAL := 0.5
const EVENT_MIN_HOURS := 5.0
const EVENT_MAX_HOURS := 11.0

## mission_id -> {objectives: [int], started_day, counters: {}}
var active: Dictionary = {}
var completed: Array[String] = []
var failed: Array[String] = []
## mission_id -> day it may next be offered
var cooldowns: Dictionary = {}
var offered: Array[String] = []

var tracked_mission: String = ""
var _poll: float = 0.0
var _next_event_at: float = 0.0
var _clean_streak: float = 0.0     ## seconds at wanted 0, for avoid_wanted
var _evade_streak: float = 0.0     ## seconds unseen, for evade
var _player: Node3D = null
## Quest-item spawn requests already fulfilled, so a reload does not duplicate.
var spawned_items: Array[String] = []


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_PAUSABLE
	EventBus.production_finished.connect(_on_production_finished)
	EventBus.deal_completed.connect(_on_deal_completed)
	EventBus.day_passed.connect(_on_day_passed)
	EventBus.player_spawned.connect(func(p): _player = p)
	reset()


func reset() -> void:
	active.clear()
	completed.clear()
	failed.clear()
	cooldowns.clear()
	offered.clear()
	tracked_mission = ""
	spawned_items.clear()
	_clean_streak = 0.0
	_evade_streak = 0.0
	_next_event_at = GameState.absolute_hours() + randf_range(EVENT_MIN_HOURS, EVENT_MAX_HOURS)


func _process(delta: float) -> void:
	if not GameState.clock_running:
		return
	_track_streaks(delta)
	_poll -= delta
	if _poll > 0.0:
		return
	_poll = POLL_INTERVAL
	_refresh_stateful()
	_check_quest_spawns()
	_check_random_event()
	_check_endgame()
	_auto_offer()


# ===========================================================================
# OFFERING
# ===========================================================================

func is_active(mission_id: String) -> bool:
	return active.has(mission_id)


func is_completed(mission_id: String) -> bool:
	return completed.has(mission_id)


func can_offer(mission_id: String) -> bool:
	var m: Dictionary = GameData.mission(mission_id)
	if m.is_empty() or active.has(mission_id):
		return false
	var repeatable := bool(m.get("repeatable", false))
	if completed.has(mission_id) and not repeatable:
		return false
	if cooldowns.has(mission_id) and GameState.day < int(cooldowns[mission_id]):
		return false
	if not _chain_ready(mission_id):
		return false
	return check_requirement(m.get("requires", {}))


## Evaluates a requirement dictionary against current state.
## Supported keys: flag, level, district, property, rep {district, value},
## mission (a completed prerequisite), cash.
func check_requirement(req: Dictionary) -> bool:
	if req.is_empty():
		return true
	if req.has("flag") and not GameState.has_flag(String(req["flag"])):
		return false
	if req.has("level") and GameState.level < int(req["level"]):
		return false
	if req.has("district") and not GameState.district_unlocked(String(req["district"])):
		return false
	if req.has("property") and not GameState.owns_property(String(req["property"])):
		return false
	if req.has("mission") and not completed.has(String(req["mission"])):
		return false
	if req.has("cash") and GameState.cash < int(req["cash"]):
		return false
	if req.has("rep"):
		var r: Dictionary = req["rep"]
		if GameState.get_reputation(String(r.get("district", ""))) < float(r.get("value", 0)):
			return false
	return true


## Missions a particular character can hand out right now.
func missions_from(npc_id: String) -> Array[String]:
	var out: Array[String] = []
	for mid in GameData.missions:
		var m: Dictionary = GameData.missions[mid]
		if String(m.get("giver", "")) != npc_id:
			continue
		if can_offer(mid):
			out.append(mid)
	return out


## Story missions only unlock once their predecessor is done.
func _chain_ready(mission_id: String) -> bool:
	var m: Dictionary = GameData.mission(mission_id)
	if String(m.get("kind", "")) != MissionDB.KIND_MAIN:
		return true
	for other_id in GameData.missions:
		if String(GameData.missions[other_id].get("next", "")) == mission_id:
			return completed.has(other_id)
	return true  # first link in the chain


func _auto_offer() -> void:
	for mid in GameData.missions:
		if bool(GameData.missions[mid].get("auto_offer", false)) and can_offer(mid):
			start(mid)
			return


func start(mission_id: String) -> bool:
	if active.has(mission_id):
		return false
	var m: Dictionary = GameData.mission(mission_id)
	if m.is_empty():
		return false
	var objectives: Array = m.get("objectives", [])
	var progress: Array[int] = []
	progress.resize(objectives.size())
	progress.fill(0)
	active[mission_id] = {
		"objectives": progress,
		"started_day": GameState.day,
		"deadline_day": GameState.day + int(m.get("fail_after_days", 0)) if m.has("fail_after_days") else -1,
	}
	if tracked_mission == "":
		tracked_mission = mission_id
	EventBus.mission_started.emit(mission_id)
	EventBus.toast_requested.emit("New job: " + String(m.get("title", mission_id)), "info")
	EventBus.phone_notification.emit("jobs", String(m.get("title", mission_id)), String(m.get("brief", "")))
	_refresh_stateful()
	return true


func abandon(mission_id: String) -> void:
	if not active.has(mission_id):
		return
	active.erase(mission_id)
	if tracked_mission == mission_id:
		tracked_mission = ""
	EventBus.mission_failed.emit(mission_id, "abandoned")


# ===========================================================================
# PROGRESS
# ===========================================================================

func objective_target(obj: Dictionary) -> int:
	match String(obj.get("type", "")):
		"collect", "craft", "sell", "deliver", "hire":
			return int(obj.get("count", 1))
		"earn":
			return int(obj.get("amount", 1))
		"level":
			return int(obj.get("value", 1))
		"rep":
			return int(obj.get("value", 1))
		"upgrade":
			return int(obj.get("level", 1))
		"evade", "avoid_wanted":
			return int(obj.get("seconds", 60))
		_:
			return 1


func objective_progress(mission_id: String, index: int) -> int:
	var rec: Dictionary = active.get(mission_id, {})
	var arr: Array = rec.get("objectives", [])
	if index < 0 or index >= arr.size():
		return 0
	return int(arr[index])


## The first unfinished objective of a mission, or -1 when all are done.
func current_objective_index(mission_id: String) -> int:
	var m: Dictionary = GameData.mission(mission_id)
	var objs: Array = m.get("objectives", [])
	for i in objs.size():
		if objective_progress(mission_id, i) < objective_target(objs[i]):
			return i
	return -1


func _set_progress(mission_id: String, index: int, value: int) -> void:
	var rec: Dictionary = active.get(mission_id, {})
	var arr: Array = rec.get("objectives", [])
	if index < 0 or index >= arr.size():
		return
	var objs: Array = GameData.mission(mission_id).get("objectives", [])
	var target := objective_target(objs[index])
	var clamped: int = clampi(value, 0, target)
	if clamped == int(arr[index]):
		return
	arr[index] = clamped
	EventBus.mission_objective_updated.emit(mission_id, index, clamped, target)
	_try_complete(mission_id)


func _bump(mission_id: String, index: int, delta: int) -> void:
	_set_progress(mission_id, index, objective_progress(mission_id, index) + delta)


## Recomputes every objective whose truth is derivable from current state.
func _refresh_stateful() -> void:
	for mid in active.keys():
		var objs: Array = GameData.mission(mid).get("objectives", [])
		for i in objs.size():
			var o: Dictionary = objs[i]
			match String(o.get("type", "")):
				"collect":
					var mq := int(o.get("min_quality", -1))
					var item_id := String(o.get("item", ""))
					var n := GameState.inventory.count_min_quality(item_id, mq) if mq >= 0 \
						else GameState.inventory.count(item_id)
					_set_progress(mid, i, n)
				"level":
					_set_progress(mid, i, GameState.level)
				"rep":
					_set_progress(mid, i, int(GameState.get_reputation(String(o.get("district", "")))))
				"earn":
					_set_progress(mid, i, GameState.lifetime_earned)
				"buy_property":
					_set_progress(mid, i, 1 if GameState.owns_property(String(o.get("property", ""))) else 0)
				"upgrade":
					var p: PropertyState = GameState.get_property(String(o.get("property", "")))
					_set_progress(mid, i, int(p.levels.get(String(o.get("track", "storage")), 0)) if p else 0)
				"hire":
					_set_progress(mid, i, GameState.employee_count())
				"flag":
					_set_progress(mid, i, 1 if GameState.has_flag(String(o.get("flag", ""))) else 0)
				"goto":
					_set_progress(mid, i, 1 if _player_at(o) else 0)
				"avoid_wanted":
					_set_progress(mid, i, int(_clean_streak))
				"evade":
					_set_progress(mid, i, int(_evade_streak))
		_try_complete(mid)


## Some story beats need an object to exist in the world before the player can
## pick it up. Each mission can declare `spawns`, and the entry is fulfilled
## once the objective it hangs off becomes the current one.
func _check_quest_spawns() -> void:
	for mid in active.keys():
		var spawns: Array = GameData.mission(mid).get("spawns", [])
		if spawns.is_empty():
			continue
		var idx := current_objective_index(mid)
		for spawn in spawns:
			var key := "%s:%s" % [mid, String(spawn.get("item", ""))]
			if spawned_items.has(key):
				continue
			if idx < int(spawn.get("after_objective", 0)):
				continue
			if GameState.inventory.count(String(spawn.get("item", ""))) > 0:
				spawned_items.append(key)
				continue
			spawned_items.append(key)
			EventBus.screen_requested.emit("spawn_quest_item", {
				"item": String(spawn.get("item", "")),
				"poi": String(spawn.get("poi", "")),
				"offset": spawn.get("offset", [0.0, 0.0, 0.0]),
			})
			var poi_name := String(GameData.pois.get(String(spawn.get("poi", "")), {}).get("name", "the city"))
			EventBus.phone_notification.emit("jobs", "Lead",
				"%s is somewhere around %s." %
				[GameData.item_name(String(spawn.get("item", ""))), poi_name])


func _player_at(o: Dictionary) -> bool:
	if _player == null or not is_instance_valid(_player):
		return false
	var target := Vector3.ZERO
	if o.has("poi"):
		if not GameData.has_poi(String(o["poi"])):
			return false
		target = GameData.poi_position(String(o["poi"]))
	elif o.has("pos"):
		var p: Array = o["pos"]
		target = Vector3(p[0], p[1], p[2])
	else:
		return false
	var radius := float(o.get("radius", 5.0))
	return _player.global_position.distance_to(target) <= radius


func _track_streaks(delta: float) -> void:
	if EnforcementService.wanted_level == 0:
		_clean_streak += delta
	else:
		_clean_streak = 0.0
	if not EnforcementService.is_observed:
		_evade_streak += delta
	else:
		_evade_streak = 0.0


# --- Event-driven objectives ----------------------------------------------

func _on_production_finished(_station_id: String, item_id: String, quality: int, amount: int) -> void:
	_for_each_objective("craft", func(mid: String, i: int, o: Dictionary):
		if String(o.get("item", "")) != item_id:
			return
		if quality < int(o.get("min_quality", 0)):
			return
		_bump(mid, i, amount))


func _on_deal_completed(_npc_id: String, item_id: String, amount: int, _payout: int) -> void:
	_for_each_objective("sell", func(mid: String, i: int, o: Dictionary):
		var want := String(o.get("item", "any"))
		if want != "any" and want != item_id:
			return
		var dist := String(o.get("district", ""))
		if dist != "" and GameState.current_district != dist:
			return
		_bump(mid, i, amount))


## Called by the dialogue runner when the player speaks to somebody.
func notify_talk(npc_id: String) -> void:
	_for_each_objective("talk", func(mid: String, i: int, o: Dictionary):
		if String(o.get("npc", "")) == npc_id:
			_set_progress(mid, i, 1))


## Called when the player hands items to a character.
func notify_deliver(npc_id: String, item_id: String, amount: int, quality: int) -> void:
	_for_each_objective("deliver", func(mid: String, i: int, o: Dictionary):
		if String(o.get("npc", "")) != npc_id:
			return
		var want := String(o.get("item", "any"))
		if want != "any" and want != item_id:
			return
		if quality < int(o.get("min_quality", 0)):
			return
		_bump(mid, i, amount))


## Iterates only the *current* objective of each active mission so a player
## cannot complete step three before step one.
func _for_each_objective(type_name: String, fn: Callable) -> void:
	for mid in active.keys():
		var idx := current_objective_index(mid)
		if idx < 0:
			continue
		var objs: Array = GameData.mission(mid).get("objectives", [])
		var o: Dictionary = objs[idx]
		if String(o.get("type", "")) == type_name:
			fn.call(mid, idx, o)


# ===========================================================================
# COMPLETION
# ===========================================================================

func _try_complete(mission_id: String) -> void:
	if not active.has(mission_id):
		return
	if current_objective_index(mission_id) >= 0:
		return
	_complete(mission_id)


func _complete(mission_id: String) -> void:
	var m: Dictionary = GameData.mission(mission_id)
	active.erase(mission_id)
	if not completed.has(mission_id):
		completed.append(mission_id)
	if bool(m.get("repeatable", false)):
		cooldowns[mission_id] = GameState.day + int(m.get("cooldown_days", 1))
	if tracked_mission == mission_id:
		tracked_mission = ""

	_grant_rewards(m.get("rewards", {}))
	EventBus.mission_completed.emit(mission_id)
	EventBus.toast_requested.emit("Job complete: " + String(m.get("title", mission_id)), "good")

	var chapter := int(m.get("chapter", 0))
	if chapter > 0:
		EventBus.story_chapter_changed.emit(chapter)

	# Offer the next link of a story chain immediately.
	var nxt := String(m.get("next", ""))
	if nxt != "" and can_offer(nxt):
		start(nxt)
	if tracked_mission == "" and not active.is_empty():
		tracked_mission = active.keys()[0]


func _grant_rewards(r: Dictionary) -> void:
	if r.is_empty():
		return
	var cash := int(r.get("cash", 0))
	if cash != 0:
		GameState.add_cash(cash, "Job payment")
	var xp := int(r.get("xp", 0))
	if xp > 0:
		GameState.add_xp(xp, "mission")
	for item_id in r.get("items", {}):
		GameState.inventory.add(item_id, int(r["items"][item_id]))
	for did in r.get("rep", {}):
		GameState.add_reputation(did, float(r["rep"][did]))
	for f in r.get("flags", []):
		GameState.set_flag(String(f))
	if r.has("unlock_recipe"):
		GameState.unlock_recipe(String(r["unlock_recipe"]))
	if r.has("unlock_district"):
		GameState.unlock_district(String(r["unlock_district"]))
	if r.has("unlock_property"):
		GameState.grant_property(String(r["unlock_property"]))
	if r.has("influence"):
		GameState.influence = clampf(GameState.influence + float(r["influence"]), 0.0, 1.0)


func fail(mission_id: String, reason: String) -> void:
	if not active.has(mission_id):
		return
	var m: Dictionary = GameData.mission(mission_id)
	active.erase(mission_id)
	if not failed.has(mission_id):
		failed.append(mission_id)
	if tracked_mission == mission_id:
		tracked_mission = ""
	var pen: Dictionary = m.get("fail_penalty", {})
	for did in pen.get("rep", {}):
		GameState.add_reputation(did, float(pen["rep"][did]))
	if pen.has("seize_fraction"):
		GameState.inventory.seize(float(pen["seize_fraction"]))
	cooldowns[mission_id] = GameState.day + int(m.get("cooldown_days", 2))
	EventBus.mission_failed.emit(mission_id, reason)
	EventBus.toast_requested.emit("Job failed: " + String(m.get("title", mission_id)), "bad")


func _on_day_passed(_day: int) -> void:
	for mid in active.keys():
		var deadline := int(active[mid].get("deadline_day", -1))
		if deadline > 0 and GameState.day > deadline:
			fail(mid, "out of time")


# ===========================================================================
# WORLD EVENTS
# ===========================================================================

func _check_random_event() -> void:
	if GameState.absolute_hours() < _next_event_at:
		return
	_next_event_at = GameState.absolute_hours() + randf_range(EVENT_MIN_HOURS, EVENT_MAX_HOURS)
	var pool: Array = GameData.random_events
	if pool.is_empty():
		return
	var total := 0
	for e in pool:
		total += int(e.get("weight", 1))
	var roll := randi() % maxi(1, total)
	var chosen: Dictionary = pool[0]
	for e in pool:
		roll -= int(e.get("weight", 1))
		if roll < 0:
			chosen = e
			break
	_apply_event(chosen)


func _apply_event(e: Dictionary) -> void:
	var effect := String(e.get("effect", ""))
	var district := String(e.get("district", ""))
	var power := float(e.get("power", 1.0))
	var hours := float(e.get("hours", 4.0))
	match effect:
		"price_up":
			EconomyService.add_modifier("price", power, hours, district)
		"price_down":
			EconomyService.add_modifier("price", power, hours, district)
		"demand_up":
			EconomyService.add_modifier("demand", power, hours, district)
		"patrol_up":
			EconomyService.add_modifier("patrol", power, hours, district)
		"rival_pressure":
			var target := _random_unlocked_district()
			EconomyService.rival_share[target] = clampf(
				float(EconomyService.rival_share.get(target, 0.25)) + 0.22, 0.0, 0.95)
			if can_offer("rival_squeeze"):
				start("rival_squeeze")
		"warn_raid":
			EnforcementService.warn_of_raid()
		"spawn_pickups":
			EventBus.screen_requested.emit("spawn_pickups", {"district": district})
	EventBus.phone_notification.emit("news", String(e.get("title", "Something happened")),
		String(e.get("body", "")))
	EventBus.toast_requested.emit(String(e.get("title", "")), "info")


func _random_unlocked_district() -> String:
	if GameState.unlocked_districts.is_empty():
		return "dockside"
	return GameState.unlocked_districts[randi() % GameState.unlocked_districts.size()]


# ===========================================================================
# ENDGAME
# ===========================================================================

func endgame_progress(path_id: String) -> float:
	var e: Dictionary = GameData.endgames.get(path_id, {})
	var c: Dictionary = e.get("check", {})
	var ratios: Array[float] = []
	if c.has("bank"):
		ratios.append(clampf(float(GameState.bank) / float(c["bank"]), 0.0, 1.0))
	if c.has("influence"):
		ratios.append(clampf(GameState.influence / float(c["influence"]), 0.0, 1.0))
	if c.has("districts_controlled"):
		ratios.append(clampf(float(EconomyService.districts_controlled()) / float(c["districts_controlled"]), 0.0, 1.0))
	if c.has("min_rep_all"):
		ratios.append(clampf(GameState.min_reputation() / float(c["min_rep_all"]), 0.0, 1.0))
	if c.has("properties"):
		ratios.append(clampf(float(GameState.owned_property_count()) / float(c["properties"]), 0.0, 1.0))
	if c.has("flag"):
		ratios.append(1.0 if GameState.has_flag(String(c["flag"])) else 0.0)
	if ratios.is_empty():
		return 0.0
	var total := 0.0
	for r in ratios:
		total += r
	return total / float(ratios.size())


func _check_endgame() -> void:
	for path_id in GameData.endgames:
		if GameState.endgame_paths.has(path_id):
			continue
		if endgame_progress(path_id) >= 1.0:
			GameState.endgame_paths.append(path_id)
			GameState.set_flag("endgame_reached")
			EventBus.endgame_path_achieved.emit(path_id)
			var e: Dictionary = GameData.endgames[path_id]
			EventBus.toast_requested.emit("Endgame reached: " + String(e.get("name", path_id)), "good")
			EventBus.phone_notification.emit("empire", String(e.get("name", path_id)),
				String(e.get("epilogue", "")))


# --- Serialisation ---------------------------------------------------------

func to_dict() -> Dictionary:
	return {
		"active": active.duplicate(true),
		"completed": completed.duplicate(),
		"failed": failed.duplicate(),
		"cooldowns": cooldowns.duplicate(),
		"tracked": tracked_mission,
		"next_event_at": _next_event_at,
		"spawned_items": spawned_items.duplicate(),
	}


func from_dict(d: Dictionary) -> void:
	reset()
	var a: Dictionary = d.get("active", {})
	for mid in a:
		if not GameData.missions.has(mid):
			continue
		var rec: Dictionary = a[mid]
		var progress: Array[int] = []
		for v in rec.get("objectives", []):
			progress.append(int(v))
		# Repair length if the mission definition changed between versions.
		var want: int = GameData.mission(mid).get("objectives", []).size()
		while progress.size() < want:
			progress.append(0)
		progress.resize(want)
		active[mid] = {
			"objectives": progress,
			"started_day": int(rec.get("started_day", GameState.day)),
			"deadline_day": int(rec.get("deadline_day", -1)),
		}
	for mid in d.get("completed", []):
		completed.append(String(mid))
	for mid in d.get("failed", []):
		failed.append(String(mid))
	cooldowns = (d.get("cooldowns", {}) as Dictionary).duplicate()
	tracked_mission = String(d.get("tracked", ""))
	_next_event_at = float(d.get("next_event_at", GameState.absolute_hours() + 6.0))
	spawned_items.clear()
	for key in d.get("spawned_items", []):
		spawned_items.append(String(key))
