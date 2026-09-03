extends Node
## Save / load with three manual slots plus an autosave slot.
##
## Saves are JSON so they survive content updates gracefully: every consumer
## reads with .get(key, default), unknown ids are dropped on load, and a
## version stamp lets us migrate. Writes go to a temp file first and are then
## renamed, so a crash mid-write cannot destroy an existing save.

const DIR := "user://saves"
const AUTOSAVE_NAME := "autosave"

var autosave_enabled: bool = true
var _autosave_timer: float = 0.0
var _world: Node = null            ## set by WorldManager when a world exists
var _busy: bool = false


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	DirAccess.make_dir_recursive_absolute(DIR)


func _process(delta: float) -> void:
	if not autosave_enabled or not GameState.clock_running or _world == null:
		return
	var minutes := float(SettingsService.get_value("gameplay", "autosave_minutes", 3.0))
	if minutes <= 0.0:
		return
	_autosave_timer += delta
	if _autosave_timer >= minutes * 60.0:
		_autosave_timer = 0.0
		save_game(GameConfig.AUTOSAVE_SLOT, true)


func register_world(world: Node) -> void:
	_world = world
	_autosave_timer = 0.0


func unregister_world() -> void:
	_world = null


# ===========================================================================
# PATHS AND METADATA
# ===========================================================================

func slot_path(slot: int) -> String:
	if slot == GameConfig.AUTOSAVE_SLOT:
		return "%s/%s.json" % [DIR, AUTOSAVE_NAME]
	return "%s/slot_%d.json" % [DIR, slot]


func slot_exists(slot: int) -> bool:
	return FileAccess.file_exists(slot_path(slot))


func slot_label(slot: int) -> String:
	return "Autosave" if slot == GameConfig.AUTOSAVE_SLOT else "Slot %d" % slot


## Header-only read for the load menu. Returns {} when a slot is empty.
func slot_summary(slot: int) -> Dictionary:
	if not slot_exists(slot):
		return {}
	var f := FileAccess.open(slot_path(slot), FileAccess.READ)
	if f == null:
		return {}
	var text := f.get_as_text()
	f.close()
	var parsed = JSON.parse_string(text)
	if typeof(parsed) != TYPE_DICTIONARY:
		return {}
	return parsed.get("meta", {})


func has_any_save() -> bool:
	for i in GameConfig.MAX_SAVE_SLOTS + 1:
		if slot_exists(i):
			return true
	return false


func most_recent_slot() -> int:
	var best := -1
	var best_time := -1
	for i in GameConfig.MAX_SAVE_SLOTS + 1:
		var meta := slot_summary(i)
		if meta.is_empty():
			continue
		var t := int(meta.get("timestamp", 0))
		if t > best_time:
			best_time = t
			best = i
	return best


# ===========================================================================
# SAVE
# ===========================================================================

func save_game(slot: int, silent: bool = false) -> bool:
	if _busy:
		return false
	_busy = true
	EventBus.save_started.emit(slot)

	var payload := {
		"version": GameConfig.SAVE_VERSION,
		"meta": _build_meta(),
		"state": GameState.to_dict(),
		"economy": EconomyService.to_dict(),
		"missions": MissionService.to_dict(),
		"enforcement": EnforcementService.to_dict(),
		"world": _world.to_dict() if _world != null and _world.has_method("to_dict") else {},
	}

	var ok := _write_json(slot_path(slot), payload)
	_busy = false
	if ok:
		EventBus.save_completed.emit(slot)
		if not silent:
			EventBus.toast_requested.emit("Saved to " + slot_label(slot), "good")
		else:
			EventBus.toast_requested.emit("Autosaved", "info")
	else:
		EventBus.save_failed.emit(slot, "write failed")
		EventBus.toast_requested.emit("Could not save", "bad")
	return ok


func _build_meta() -> Dictionary:
	return {
		"timestamp": int(Time.get_unix_time_from_system()),
		"date": Time.get_datetime_string_from_system(false, true),
		"day": GameState.day,
		"hour": GameState.hour,
		"clock": GameConfig.format_clock(GameState.hour),
		"level": GameState.level,
		"cash": GameState.cash,
		"bank": GameState.bank,
		"net_worth": GameState.net_worth(),
		"district": GameData.district_name(GameState.current_district),
		"properties": GameState.owned_property_count(),
		"chapter": _current_chapter(),
		"play_seconds": int(GameState.play_seconds),
	}


func _current_chapter() -> int:
	var best := 0
	for mid in MissionService.completed:
		best = maxi(best, int(GameData.mission(mid).get("chapter", 0)))
	return best


func _write_json(path: String, payload: Dictionary) -> bool:
	var tmp := path + ".tmp"
	var f := FileAccess.open(tmp, FileAccess.WRITE)
	if f == null:
		push_error("Save failed: cannot open %s (%d)" % [tmp, FileAccess.get_open_error()])
		return false
	f.store_string(JSON.stringify(payload))
	f.close()
	var dir := DirAccess.open(DIR)
	if dir == null:
		return false
	if FileAccess.file_exists(path):
		dir.remove(path.get_file())
	var err := dir.rename(tmp.get_file(), path.get_file())
	if err != OK:
		push_error("Save failed: rename error %d" % err)
		return false
	return true


# ===========================================================================
# LOAD
# ===========================================================================

## Reads a slot into the services. Does NOT build the world - SceneRouter
## calls this after the game scene is ready so the world can restore itself.
func load_into_state(slot: int) -> bool:
	if not slot_exists(slot):
		return false
	var f := FileAccess.open(slot_path(slot), FileAccess.READ)
	if f == null:
		EventBus.save_failed.emit(slot, "cannot open")
		return false
	var text := f.get_as_text()
	f.close()
	var parsed = JSON.parse_string(text)
	if typeof(parsed) != TYPE_DICTIONARY:
		EventBus.save_failed.emit(slot, "corrupt")
		EventBus.toast_requested.emit("That save is unreadable", "bad")
		return false

	var data: Dictionary = parsed
	var version := int(data.get("version", 1))
	if version > GameConfig.SAVE_VERSION:
		EventBus.toast_requested.emit("That save is from a newer build", "warn")
		return false

	GameState.from_dict(data.get("state", {}))
	EconomyService.from_dict(data.get("economy", {}))
	MissionService.from_dict(data.get("missions", {}))
	EnforcementService.from_dict(data.get("enforcement", {}))
	pending_world = data.get("world", {})
	return true


## World payload waiting to be consumed by the next WorldManager.
var pending_world: Dictionary = {}


func take_pending_world() -> Dictionary:
	var w := pending_world
	pending_world = {}
	return w


func delete_slot(slot: int) -> void:
	if not slot_exists(slot):
		return
	var dir := DirAccess.open(DIR)
	if dir != null:
		dir.remove(slot_path(slot).get_file())


func reset_autosave_timer() -> void:
	_autosave_timer = 0.0
