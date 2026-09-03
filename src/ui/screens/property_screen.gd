class_name PropertyScreen
extends GameScreen
## Buy, upgrade and staff a property.

var property_id: String = ""


func _ready() -> void:
	property_id = String(payload.get("property", ""))
	super._ready()


func build_content() -> void:
	var def: Dictionary = GameData.property(property_id)
	set_titles(String(def.get("name", property_id)), GameData.district_name(String(def.get("district", ""))))
	refresh()


func refresh() -> void:
	if content == null:
		return
	clear_content()
	var def: Dictionary = GameData.property(property_id)
	content.add_child(UIKit.body(String(def.get("desc", ""))))

	if not GameState.owns_property(property_id):
		_build_purchase(def)
		return

	var prop: PropertyState = GameState.get_property(property_id)
	prop.sync_stations()

	section("Site")
	var stats := UIKit.vbox(4)
	var panel := UIKit.panel(UIKit.BG_PANEL)
	panel.add_child(stats)
	content.add_child(panel)
	stats.add_child(UIKit.stat_line("Storage", "%d / %d units" %
		[prop.stored_units(), prop.storage_capacity()]))
	stats.add_child(UIKit.stat_line("Stations", "%d (tier %d)" %
		[prop.stations.size(), prop.station_tier()]))
	stats.add_child(UIKit.stat_line("Staff", "%d / %d" %
		[GameState.employees_at(property_id).size(), prop.employee_slots()]))
	stats.add_child(UIKit.stat_line("Security", "%d%%" % int(prop.security_rating() * 100.0)))
	stats.add_child(UIKit.stat_line("Daily upkeep",
		GameConfig.format_money(prop.daily_upkeep()), UIKit.BAD))
	stats.add_child(UIKit.stat_line("Lifetime revenue",
		GameConfig.format_money(prop.lifetime_revenue), UIKit.MONEY))
	var heat_color := UIKit.GOOD if prop.heat < 35.0 else (UIKit.WARN if prop.heat < 70.0 else UIKit.BAD)
	stats.add_child(UIKit.stat_line("Bureau attention", "%d%%" % int(prop.heat), heat_color))
	if prop.under_investigation:
		stats.add_child(UIKit.label("Under investigation - clear stock or raise security",
			12, UIKit.BAD))
	if prop.is_shutdown(GameState.absolute_hours()):
		var hours := prop.shutdown_until - GameState.absolute_hours()
		stats.add_child(UIKit.label("Shut down for %.1f more hours" % hours, 12, UIKit.BAD))

	section("Upgrades")
	for track in PropertyDB.TRACKS:
		content.add_child(_upgrade_row(prop, track))

	section("Staff")
	var staff := GameState.employees_at(property_id)
	if staff.is_empty():
		content.add_child(UIKit.body("Nobody works here. Wendell Pike in Old Town finds people."))
	for e in staff:
		content.add_child(_staff_row(e))


func _build_purchase(def: Dictionary) -> void:
	section("For sale")
	var stats := UIKit.vbox(4)
	var panel := UIKit.panel(UIKit.BG_PANEL)
	panel.add_child(stats)
	content.add_child(panel)
	stats.add_child(UIKit.stat_line("Price",
		GameConfig.format_money(int(def.get("price", 0))), UIKit.MONEY))
	stats.add_child(UIKit.stat_line("Storage", "%d units" % int(def.get("base_storage", 0))))
	stats.add_child(UIKit.stat_line("Stations", "%d (tier %d)" %
		[int(def.get("base_stations", 0)), int(def.get("base_station_tier", 1))]))
	stats.add_child(UIKit.stat_line("Staff slots", str(int(def.get("base_employees", 0)))))
	stats.add_child(UIKit.stat_line("Daily upkeep",
		GameConfig.format_money(int(def.get("daily_upkeep", 0))), UIKit.BAD))
	if bool(def.get("sale_front", false)):
		stats.add_child(UIKit.label("Legitimate front: sells stock passively and cuts laundering fees.",
			12, UIKit.GOOD))

	var check := BusinessService.can_buy(property_id)
	var buy := UIKit.button("Buy for " + GameConfig.format_money(int(def.get("price", 0))), "primary")
	buy.disabled = not bool(check["ok"])
	if not bool(check["ok"]):
		buy.text = String(check["reason"])
	buy.pressed.connect(func():
		if BusinessService.buy(property_id):
			refresh())
	actions([buy] as Array[Button])


func _upgrade_row(prop: PropertyState, track: String) -> Control:
	var level := int(prop.levels.get(track, 0))
	var maximum := PropertyDB.track_max(property_id, track)
	var cost := PropertyDB.track_cost(property_id, track, level + 1)
	var row := UIKit.panel(UIKit.BG_PANEL)
	var v := UIKit.vbox(6)
	row.add_child(v)

	var head := UIKit.hbox(8)
	var name_label := UIKit.label(String(PropertyDB.TRACK_LABELS.get(track, track)), 16)
	name_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(name_label)
	head.add_child(UIKit.label("Level %d / %d" % [level, maximum], 13, UIKit.TEXT_DIM))
	v.add_child(head)

	var pips := UIKit.hbox(4)
	for i in maximum:
		var pip := ColorRect.new()
		pip.custom_minimum_size = Vector2(0, 5)
		pip.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		pip.color = UIKit.ACCENT if i < level else UIKit.LINE
		pips.add_child(pip)
	v.add_child(pips)

	if level >= maximum:
		v.add_child(UIKit.label("Fully upgraded", 12, UIKit.GOOD))
	else:
		var check := BusinessService.can_upgrade(property_id, track)
		var btn := UIKit.button("Upgrade  " + GameConfig.format_money(cost),
			"primary" if bool(check["ok"]) else "default")
		btn.disabled = not bool(check["ok"])
		if not bool(check["ok"]):
			btn.text = String(check["reason"])
		btn.pressed.connect(func():
			if BusinessService.upgrade(property_id, track):
				refresh())
		v.add_child(btn)
	return row


func _staff_row(e: Employee) -> Control:
	var row := UIKit.panel(UIKit.BG_PANEL)
	var v := UIKit.vbox(6)
	row.add_child(v)
	var head := UIKit.hbox(8)
	var n := UIKit.label(e.name, 16)
	n.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(n)
	head.add_child(UIKit.chip(e.label(), UIKit.ACCENT))
	v.add_child(head)
	v.add_child(UIKit.stat_line("Wage", GameConfig.format_money(e.daily_wage()) + " / day", UIKit.BAD))
	v.add_child(UIKit.stat_line("Skill", "%d%%" % int(e.skill * 100.0)))
	v.add_child(UIKit.stat_line("Loyalty", "%d%%" % int(e.loyalty * 100.0),
		UIKit.GOOD if e.loyalty > 0.5 else UIKit.WARN))
	if e.unpaid_days > 0:
		v.add_child(UIKit.label("Unpaid for %d day(s)" % e.unpaid_days, 12, UIKit.BAD))

	var jobs := UIKit.hbox(6)
	for job in [Employee.ASSIGN_PRODUCTION, Employee.ASSIGN_SELL,
			Employee.ASSIGN_SECURITY, Employee.ASSIGN_HAUL]:
		if not e.can_do(job):
			continue
		var b := UIKit.button(String(Employee.ASSIGN_LABELS[job]),
			"primary" if e.assignment == job else "default")
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		b.add_theme_font_size_override("font_size", 13)
		b.pressed.connect(func():
			BusinessService.assign(e.id, job)
			refresh())
		jobs.add_child(b)
	v.add_child(jobs)

	var fire := UIKit.button("Let go", "bad")
	fire.pressed.connect(func():
		BusinessService.fire(e.id)
		refresh())
	v.add_child(fire)
	return row
