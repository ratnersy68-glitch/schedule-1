extends Node
## Global signal hub.
##
## Systems emit here instead of holding references to one another. This keeps
## every subsystem (economy, missions, enforcement, UI...) independently
## testable and lets the UI layer subscribe without knowing who produced an
## event. Nothing in this file should hold state.

# --- Economy / money -------------------------------------------------------
signal cash_changed(new_cash: int, delta: int)
signal bank_changed(new_balance: int, delta: int)
signal transaction_logged(entry: Dictionary)
signal market_tick(day: int, hour: int)

# --- Inventory -------------------------------------------------------------
signal inventory_changed(inventory_id: String)
signal item_gained(item_id: String, amount: int, quality: int)
signal item_lost(item_id: String, amount: int, quality: int)
signal inventory_full(item_id: String)

# --- Production ------------------------------------------------------------
signal production_started(station_id: String, recipe_id: String, seconds: float)
signal production_progress(station_id: String, ratio: float)
signal production_finished(station_id: String, item_id: String, quality: int, amount: int)
signal production_failed(station_id: String, reason: String)
signal recipe_unlocked(recipe_id: String)

# --- Business / property ---------------------------------------------------
signal property_purchased(property_id: String)
signal property_upgraded(property_id: String, track: String, level: int)
signal property_raided(property_id: String)
signal employee_hired(employee_id: String, property_id: String)
signal employee_fired(employee_id: String)
signal employee_paid(employee_id: String, amount: int)
signal daily_settlement(summary: Dictionary)

# --- Missions --------------------------------------------------------------
signal mission_offered(mission_id: String)
signal mission_started(mission_id: String)
signal mission_objective_updated(mission_id: String, index: int, progress: int, target: int)
signal mission_completed(mission_id: String)
signal mission_failed(mission_id: String, reason: String)
signal story_chapter_changed(chapter: int)

# --- Reputation / progression ---------------------------------------------
signal reputation_changed(district_id: String, value: float)
signal xp_gained(amount: int, source: String)
signal level_up(new_level: int, skill_points: int)
signal skill_purchased(skill_id: String, rank: int)
signal endgame_path_achieved(path_id: String)

# --- Enforcement -----------------------------------------------------------
signal suspicion_changed(value: float)
signal wanted_level_changed(level: int)
signal heat_changed(district_id: String, value: float)
signal player_busted(penalty: Dictionary)
signal investigation_opened(property_id: String)
signal investigation_closed(property_id: String)

# --- NPC / social ----------------------------------------------------------
signal npc_relationship_changed(npc_id: String, value: float)
signal npc_met(npc_id: String)
signal dialogue_requested(npc_id: String, node_id: String)
signal dialogue_closed()
signal deal_completed(npc_id: String, item_id: String, amount: int, payout: int)
signal deal_refused(npc_id: String, reason: String)

# --- World -----------------------------------------------------------------
signal hour_passed(day: int, hour: int)
signal day_passed(day: int)
signal weather_changed(weather_id: String)
signal district_unlocked(district_id: String)
signal world_ready()

# --- Player ----------------------------------------------------------------
signal player_spawned(player: Node3D)
signal player_health_changed(current: float, maximum: float)
signal player_stamina_changed(current: float, maximum: float)
signal player_entered_vehicle(vehicle: Node3D)
signal player_exited_vehicle(vehicle: Node3D)
signal player_entered_district(district_id: String)

# --- UI --------------------------------------------------------------------
signal interaction_target_changed(payload: Dictionary)
signal toast_requested(text: String, kind: String)
signal phone_toggled(open: bool)
signal phone_notification(app_id: String, title: String, body: String)
signal screen_requested(screen_id: String, payload: Dictionary)
signal settings_changed(section: String)
signal ui_input_blocked(blocked: bool)

# --- Save ------------------------------------------------------------------
signal save_started(slot: int)
signal save_completed(slot: int)
signal load_completed(slot: int)
signal save_failed(slot: int, reason: String)


## Convenience helper so callers do not have to remember the toast contract.
## kind: "info" | "good" | "warn" | "bad" | "money"
func toast(text: String, kind: String = "info") -> void:
	toast_requested.emit(text, kind)
