class_name AppNews
extends PhoneApp
## The Bay Ledger: world events, market conditions and Bureau activity.


func _init() -> void:
	super._init("news", "Ledger", "LDG", UIKit.TEXT_DIM)


func build(container: VBoxContainer) -> void:
	var panel := UIKit.panel(UIKit.BG_PANEL)
	var v := UIKit.vbox(4)
	panel.add_child(v)
	v.add_child(UIKit.stat_line("Weather", String(GameState.weather).capitalize()))
	v.add_child(UIKit.stat_line("Time", "Day %d, %s" %
		[GameState.day, GameConfig.format_clock(GameState.hour)]))
	v.add_child(UIKit.stat_line("Your record", EnforcementService.threat_label(),
		UIKit.BAD if EnforcementService.wanted_level > 0 else UIKit.GOOD))
	container.add_child(panel)

	if not EconomyService.modifiers.is_empty():
		container.add_child(UIKit.label("CONDITIONS", 11, UIKit.TEXT_FAINT))
		for mod in EconomyService.modifiers:
			var scope := String(mod.get("district", ""))
			var where := GameData.district_name(scope) if scope != "" else "Citywide"
			var hours := float(mod["expires_at"]) - GameState.absolute_hours()
			var kind := String(mod["kind"])
			var power := float(mod["power"])
			var text := "%s %s%d%%" % [kind.capitalize(),
				"+" if power >= 1.0 else "", int((power - 1.0) * 100.0)]
			container.add_child(UIKit.list_row("EV",
				UIKit.GOOD if power >= 1.0 else UIKit.BAD,
				text, where, "%.1fh left" % maxf(0.0, hours), UIKit.TEXT_DIM))

	container.add_child(UIKit.label("MARKET", 11, UIKit.TEXT_FAINT))
	for pid in GameData.product_ids:
		var item_id := String(pid)
		var best := EconomyService.best_district_for(item_id)
		if best == "":
			continue
		var price := EconomyService.unit_price(item_id, 2, "", best)
		container.add_child(UIKit.list_row(GameData.item_icon(item_id),
			GameData.item_color(item_id), GameData.item_name(item_id),
			"Best in " + GameData.district_name(best),
			GameConfig.format_money(price), UIKit.MONEY))

	container.add_child(UIKit.label("BUREAU", 11, UIKit.TEXT_FAINT))
	for did in GameState.unlocked_districts:
		var heat := GameState.get_heat(String(did))
		container.add_child(UIKit.stat_line(GameData.district_name(String(did)),
			"%d%% attention" % int(heat),
			UIKit.BAD if heat > 60.0 else (UIKit.WARN if heat > 25.0 else UIKit.GOOD)))
