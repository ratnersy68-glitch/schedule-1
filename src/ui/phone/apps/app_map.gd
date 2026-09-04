class_name AppMap
extends PhoneApp
## Full city map with districts, your holdings and live market read-outs.


func _init() -> void:
	super._init("map", "Map", "MAP", UIKit.ACCENT)


func build(container: VBoxContainer) -> void:
	var map := MapView.new()
	map.custom_minimum_size = Vector2(0, 260)
	container.add_child(map)

	container.add_child(UIKit.label("DISTRICTS", 11, UIKit.TEXT_FAINT))
	for did in GameData.district_ids:
		container.add_child(_district_row(String(did)))


func _district_row(did: String) -> Control:
	var d: Dictionary = GameData.district(did)
	var unlocked := GameState.district_unlocked(did)
	var row := UIKit.panel(UIKit.BG_PANEL)
	var v := UIKit.vbox(4)
	row.add_child(v)

	var head := UIKit.hbox(8)
	var swatch := ColorRect.new()
	swatch.color = d.get("accent", UIKit.ACCENT)
	swatch.custom_minimum_size = Vector2(6, 22)
	head.add_child(swatch)
	var n := UIKit.label(String(d.get("name", did)), 15, UIKit.TEXT if unlocked else UIKit.TEXT_FAINT)
	n.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(n)
	if did == GameState.current_district:
		head.add_child(UIKit.chip("Here", UIKit.ACCENT))
	v.add_child(head)

	if not unlocked:
		v.add_child(UIKit.label(String(d.get("unlock_note", "Locked")), 12, UIKit.TEXT_FAINT))
		return row

	v.add_child(UIKit.label(String(d.get("tagline", "")), 12, UIKit.TEXT_DIM))
	v.add_child(UIKit.stat_line("Your standing", "%d" % int(GameState.get_reputation(did)),
		UIKit.GOOD if GameState.get_reputation(did) > 0.0 else UIKit.TEXT_DIM))
	var heat := GameState.get_heat(did)
	v.add_child(UIKit.stat_line("Bureau heat", "%d%%" % int(heat),
		UIKit.BAD if heat > 60.0 else (UIKit.WARN if heat > 25.0 else UIKit.GOOD)))
	v.add_child(UIKit.stat_line("Your market share",
		"%d%%" % int(EconomyService.player_market_share(did) * 100.0), UIKit.ACCENT))

	if GameState.skill_effect("see_market") > 0.0:
		v.add_child(UIKit.separator())
		for pid in GameData.product_ids:
			var demand := EconomyService.demand_for(did, String(pid))
			var price := EconomyService.unit_price(String(pid), 2, "", did)
			v.add_child(UIKit.stat_line(GameData.item_name(String(pid)),
				"%s · %s" % [GameConfig.format_money(price), EconomyService.demand_label(demand)],
				GameData.item_color(String(pid))))
	else:
		v.add_child(UIKit.label("Buy the Market Reader skill to see live prices here.",
			11, UIKit.TEXT_FAINT))
	return row
