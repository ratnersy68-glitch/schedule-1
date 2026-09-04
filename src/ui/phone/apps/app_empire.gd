class_name AppEmpire
extends PhoneApp
## Endgame progress across all five paths, plus the citywide scoreboard.


func _init() -> void:
	super._init("empire", "Legacy", "LEG", UIKit.VIOLET)


func build(container: VBoxContainer) -> void:
	container.add_child(UIKit.body(
		"Cobalt Bay will belong to somebody. There is more than one way to be that somebody, " +
		"and reaching any one of them ends your story on your terms."))

	var panel := UIKit.panel(UIKit.BG_PANEL)
	var v := UIKit.vbox(4)
	panel.add_child(v)
	v.add_child(UIKit.stat_line("Districts controlled",
		"%d / 6" % EconomyService.districts_controlled(), UIKit.ACCENT))
	v.add_child(UIKit.stat_line("City influence",
		"%d%%" % int(GameState.influence * 100.0), UIKit.VIOLET))
	v.add_child(UIKit.stat_line("Lowest standing",
		"%d" % int(GameState.min_reputation())))
	v.add_child(UIKit.stat_line("Properties owned",
		"%d / %d" % [GameState.owned_property_count(), PropertyDB.ids().size()]))
	container.add_child(panel)

	container.add_child(UIKit.label("PATHS", 11, UIKit.TEXT_FAINT))
	for path_id in GameData.endgames:
		container.add_child(_path_card(String(path_id)))


func _path_card(path_id: String) -> Control:
	var e: Dictionary = GameData.endgames[path_id]
	var progress := MissionService.endgame_progress(path_id)
	var achieved := GameState.endgame_paths.has(path_id)

	var row := UIKit.panel(UIKit.BG_PANEL)
	var v := UIKit.vbox(5)
	row.add_child(v)
	var head := UIKit.hbox(8)
	var t := UIKit.label(String(e.get("name", path_id)), 16,
		UIKit.GOOD if achieved else UIKit.TEXT)
	t.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(t)
	head.add_child(UIKit.label("%d%%" % int(progress * 100.0), 14,
		UIKit.GOOD if achieved else UIKit.ACCENT))
	v.add_child(head)
	v.add_child(UIKit.label(String(e.get("desc", "")), 12, UIKit.TEXT_DIM))
	v.add_child(UIKit.progress(progress, UIKit.GOOD if achieved else UIKit.ACCENT, 7.0))
	if achieved:
		v.add_child(UIKit.body(String(e.get("epilogue", ""))))
	return row
