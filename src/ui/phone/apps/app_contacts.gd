class_name AppContacts
extends PhoneApp
## Everyone you have met, what they do and where to find them right now.


func _init() -> void:
	super._init("contacts", "Contacts", "contacts", UIKit.VIOLET)


func build(container: VBoxContainer) -> void:
	if GameState.met_npcs.is_empty():
		container.add_child(UIKit.body("You have not met anybody yet. Try the Gull Cafe."))
		return
	for npc_id in GameState.met_npcs:
		var n: Dictionary = GameData.npc(npc_id)
		if n.is_empty():
			continue
		container.add_child(_contact_row(String(npc_id), n))


func _contact_row(npc_id: String, n: Dictionary) -> Control:
	var row := UIKit.panel(UIKit.BG_PANEL)
	var v := UIKit.vbox(4)
	row.add_child(v)

	var head := UIKit.hbox(8)
	var chip := PanelContainer.new()
	chip.add_theme_stylebox_override("panel",
		UIKit.flat_style((n.get("color", UIKit.ACCENT) as Color).darkened(0.5), 9))
	chip.custom_minimum_size = Vector2(38, 38)
	var initials := UIKit.label(String(n.get("initials", "?")), 15,
		n.get("color", UIKit.ACCENT), HORIZONTAL_ALIGNMENT_CENTER)
	initials.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	chip.add_child(initials)
	head.add_child(chip)

	var texts := UIKit.vbox(1)
	texts.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	texts.add_child(UIKit.label(String(n.get("name", npc_id)), 15))
	texts.add_child(UIKit.label(String(n.get("role", "")).capitalize() + " · " +
		GameData.district_name(String(n.get("district", ""))), 12, UIKit.TEXT_DIM))
	head.add_child(texts)
	v.add_child(head)

	v.add_child(UIKit.label(String(n.get("blurb", "")), 12, UIKit.TEXT_DIM))

	var rel := GameState.relationship(npc_id)
	v.add_child(UIKit.progress(clampf((rel + 100.0) / 200.0, 0.0, 1.0),
		UIKit.GOOD if rel >= 0.0 else UIKit.BAD, 6.0))

	var sched := NpcSchedule.new(n.get("schedule", []))
	var poi := sched.current_poi(GameState.hour)
	if GameData.has_poi(poi):
		v.add_child(UIKit.stat_line("Right now",
			String(GameData.pois[poi]["name"]), UIKit.ACCENT))
	return row
