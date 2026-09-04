class_name AppJobs
extends PhoneApp
## Active and completed work.


func _init() -> void:
	super._init("jobs", "Jobs", "JOB", UIKit.WARN)


func badge_count() -> int:
	return MissionService.active.size()


func build(container: VBoxContainer) -> void:
	if MissionService.active.is_empty():
		container.add_child(UIKit.body(
			"Nothing on. Talk to Mira Vance at the Gull, or anybody with something to say."))
	for mid in MissionService.active:
		container.add_child(_mission_card(String(mid)))

	if not MissionService.completed.is_empty():
		container.add_child(UIKit.label("DONE", 11, UIKit.TEXT_FAINT))
		for mid in MissionService.completed:
			var m: Dictionary = GameData.mission(String(mid))
			container.add_child(UIKit.list_row("OK", UIKit.GOOD,
				String(m.get("title", mid)),
				String(m.get("kind", "")).capitalize(), "", UIKit.TEXT_FAINT))


func _mission_card(mid: String) -> Control:
	var m: Dictionary = GameData.mission(mid)
	var row := UIKit.panel(UIKit.BG_PANEL)
	var v := UIKit.vbox(5)
	row.add_child(v)

	var head := UIKit.hbox(8)
	var t := UIKit.label(String(m.get("title", mid)), 16, UIKit.WARN)
	t.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(t)
	if MissionService.tracked_mission == mid:
		head.add_child(UIKit.chip("Tracked", UIKit.ACCENT))
	v.add_child(head)
	v.add_child(UIKit.body(String(m.get("brief", ""))))

	var current := MissionService.current_objective_index(mid)
	var objectives: Array = m.get("objectives", [])
	for i in objectives.size():
		var o: Dictionary = objectives[i]
		var target := MissionService.objective_target(o)
		var progress := MissionService.objective_progress(mid, i)
		var done := progress >= target
		var mark := "[x]" if done else ("->" if i == current else "-")
		var text := String(o.get("label", "Objective"))
		if target > 1:
			text += "  %d/%d" % [progress, target]
		v.add_child(UIKit.stat_line("%s %s" % [mark, text], "",
			UIKit.GOOD if done else UIKit.TEXT))
		if target > 1 and not done:
			v.add_child(UIKit.progress(float(progress) / float(target), UIKit.ACCENT, 5.0))

	var buttons := UIKit.hbox(6)
	var track := UIKit.button("Track")
	track.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	track.pressed.connect(func():
		MissionService.tracked_mission = mid
		if phone != null and phone.has_method("refresh_current"):
			phone.refresh_current())
	buttons.add_child(track)
	if String(m.get("kind", "")) != MissionDB.KIND_MAIN:
		var drop := UIKit.button("Abandon", "bad")
		drop.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		drop.pressed.connect(func():
			MissionService.abandon(mid)
			if phone != null and phone.has_method("refresh_current"):
				phone.refresh_current())
		buttons.add_child(drop)
	v.add_child(buttons)
	return row
