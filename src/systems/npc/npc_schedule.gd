class_name NpcSchedule
extends RefCounted
## Resolves "where should this person be right now" from a daily timetable.
##
## Entries are {hour, poi, action}. The active entry is the latest one whose
## hour has passed, wrapping around midnight, so a schedule that ends at 22:00
## still governs 03:00.

var entries: Array = []


func _init(schedule_entries: Array = []) -> void:
	entries = schedule_entries.duplicate()
	entries.sort_custom(func(a, b): return int(a.get("hour", 0)) < int(b.get("hour", 0)))


func is_empty() -> bool:
	return entries.is_empty()


func current(hour: float) -> Dictionary:
	if entries.is_empty():
		return {}
	var chosen: Dictionary = entries[entries.size() - 1]   # wrap: last of yesterday
	for e in entries:
		if hour >= float(e.get("hour", 0)):
			chosen = e
		else:
			break
	return chosen


func current_action(hour: float) -> String:
	return String(current(hour).get("action", "idle"))


func current_poi(hour: float) -> String:
	return String(current(hour).get("poi", ""))


## Generates a plausible civilian day: home, work, an errand, home again.
static func generate_civilian(home_poi: String, work_poi: String, errand_poi: String) -> NpcSchedule:
	return NpcSchedule.new([
		{"hour": 7, "poi": home_poi, "action": "idle"},
		{"hour": 9, "poi": work_poi, "action": "work"},
		{"hour": 13, "poi": errand_poi, "action": "shop"},
		{"hour": 15, "poi": work_poi, "action": "work"},
		{"hour": 18, "poi": errand_poi, "action": "wander"},
		{"hour": 22, "poi": home_poi, "action": "sleep"},
	])
