class_name HireScreen
extends GameScreen
## Wendell Pike's list of people looking for work.

var _selected_property: String = ""


func build_content() -> void:
	set_titles("Hiring", "Wendell knows people")
	var props := GameState.all_owned_properties()
	if not props.is_empty():
		_selected_property = props[0].id
	refresh()


func refresh() -> void:
	if content == null:
		return
	clear_content()
	var props := GameState.all_owned_properties()
	if props.is_empty():
		content.add_child(UIKit.body("Buy a property first. Nobody works on a street corner."))
		return

	section("Place of work")
	var picker := UIKit.vbox(6)
	content.add_child(picker)
	for p in props:
		var free := BusinessService.free_employee_slots(p.id)
		var row := UIKit.list_row("PR", UIKit.ACCENT, p.display_name(),
			GameData.district_name(p.district_id()),
			"%d free" % free, UIKit.GOOD if free > 0 else UIKit.TEXT_FAINT)
		if p.id == _selected_property:
			row.add_theme_stylebox_override("panel",
				UIKit.panel_style(UIKit.BG_INPUT, 10, UIKit.ACCENT, 2))
		var b := Button.new()
		b.flat = true
		b.set_anchors_preset(Control.PRESET_FULL_RECT)
		b.pressed.connect(func():
			_selected_property = p.id
			refresh())
		row.add_child(b)
		picker.add_child(row)

	section("Available")
	for archetype in GameData.employee_archetypes:
		content.add_child(_candidate_row(archetype))


func _candidate_row(archetype: String) -> Control:
	var a: Dictionary = GameData.employee_archetypes[archetype]
	var row := UIKit.panel(UIKit.BG_PANEL)
	var v := UIKit.vbox(6)
	row.add_child(v)

	var head := UIKit.hbox(8)
	var n := UIKit.label(String(a.get("label", archetype)), 16)
	n.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(n)
	head.add_child(UIKit.label(GameConfig.format_money(int(a.get("hire_cost", 0))), 16, UIKit.MONEY))
	v.add_child(head)
	v.add_child(UIKit.body(String(a.get("blurb", ""))))
	v.add_child(UIKit.stat_line("Wage",
		GameConfig.format_money(int(a.get("wage", 0))) + " / day", UIKit.BAD))
	v.add_child(UIKit.stat_line("Skill", "%d%%" % int(float(a.get("skill", 0.0)) * 100.0)))
	v.add_child(UIKit.stat_line("Discretion", "%d%%" % int(float(a.get("discretion", 0.0)) * 100.0)))
	var jobs: Array = a.get("jobs", [])
	var job_names: Array[String] = []
	for j in jobs:
		job_names.append(String(Employee.ASSIGN_LABELS.get(String(j), String(j))))
	v.add_child(UIKit.stat_line("Can do", ", ".join(job_names)))

	var check := BusinessService.can_hire(archetype, _selected_property)
	var hire := UIKit.button("Hire", "primary")
	hire.disabled = not bool(check["ok"])
	if not bool(check["ok"]):
		hire.text = String(check["reason"])
	hire.pressed.connect(func():
		if BusinessService.hire(archetype, _selected_property) != null:
			refresh())
	v.add_child(hire)
	return row
