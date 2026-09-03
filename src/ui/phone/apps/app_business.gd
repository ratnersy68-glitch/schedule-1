class_name AppBusiness
extends PhoneApp
## Remote oversight of every property: production, storage, staff, heat.


func _init() -> void:
	super._init("business", "Empire", "⌂", UIKit.WARN)


func badge_count() -> int:
	return ProductionService.pending_output_count()


func build(container: VBoxContainer) -> void:
	var owned := GameState.all_owned_properties()
	if owned.is_empty():
		container.add_child(UIKit.body("You do not own anything yet."))
		return

	var summary := UIKit.panel(UIKit.BG_PANEL)
	var sv := UIKit.vbox(4)
	summary.add_child(sv)
	sv.add_child(UIKit.stat_line("Properties", str(owned.size())))
	sv.add_child(UIKit.stat_line("Staff", str(GameState.employee_count())))
	sv.add_child(UIKit.stat_line("Daily payroll",
		GameConfig.format_money(GameState.daily_payroll()), UIKit.BAD))
	sv.add_child(UIKit.stat_line("Daily upkeep",
		GameConfig.format_money(GameState.daily_upkeep_total()), UIKit.BAD))
	sv.add_child(UIKit.stat_line("Stock on hand", "%d units" % GameState.total_stored_units()))
	container.add_child(summary)

	var pending := ProductionService.pending_output_count()
	if pending > 0:
		var collect := UIKit.button("Collect %d finished units" % pending, "primary")
		collect.pressed.connect(func():
			var n := ProductionService.collect_all()
			EventBus.toast_requested.emit("Collected %d units into storage" % n, "good")
			if phone != null and phone.has_method("refresh_current"):
				phone.refresh_current())
		container.add_child(collect)

	for prop in owned:
		container.add_child(_property_card(prop))


func _property_card(prop: PropertyState) -> Control:
	var now := GameState.absolute_hours()
	var row := UIKit.panel(UIKit.BG_PANEL)
	var v := UIKit.vbox(5)
	row.add_child(v)

	var head := UIKit.hbox(8)
	var n := UIKit.label(prop.display_name(), 16)
	n.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(n)
	if prop.is_shutdown(now):
		head.add_child(UIKit.chip("Shut down", UIKit.BAD))
	elif prop.under_investigation:
		head.add_child(UIKit.chip("Watched", UIKit.WARN))
	v.add_child(head)

	v.add_child(UIKit.label(GameData.district_name(prop.district_id()), 12, UIKit.TEXT_DIM))
	v.add_child(UIKit.stat_line("Storage", "%d / %d" %
		[prop.stored_units(), prop.storage_capacity()]))
	v.add_child(UIKit.progress(prop.storage_ratio(), UIKit.ACCENT, 6.0))
	v.add_child(UIKit.stat_line("Heat", "%d%%" % int(prop.heat),
		UIKit.BAD if prop.heat > 60.0 else UIKit.TEXT_DIM))

	for i in prop.stations.size():
		var s := prop.stations[i]
		var line := ""
		var color := UIKit.TEXT_DIM
		if s.is_ready(now):
			line = "Ready: %d x %s" % [s.output_amount,
				GameData.item_name(String(GameData.recipe(s.recipe_id).get("output", "")))]
			color = UIKit.GOOD
		elif s.is_busy(now):
			line = "%s  %d%%" % [String(GameData.recipe(s.recipe_id).get("name", "")),
				int(s.progress(now) * 100.0)]
			color = UIKit.ACCENT
		else:
			line = "Idle"
		v.add_child(UIKit.stat_line(s.display_name(), line, color))

	var staff := GameState.employees_at(prop.id)
	if not staff.is_empty():
		v.add_child(UIKit.separator())
		for e in staff:
			v.add_child(UIKit.stat_line(e.name,
				String(Employee.ASSIGN_LABELS.get(e.assignment, "Idle")),
				UIKit.GOOD if e.loyalty > 0.4 else UIKit.WARN))
	return row
