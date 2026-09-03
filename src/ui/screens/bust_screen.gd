class_name BustScreen
extends GameScreen
## What the Bureau took, shown once so the consequence is legible.


func build_content() -> void:
	set_titles("Detained", "Civic Standards Bureau")
	var penalty: Dictionary = payload.get("penalty", {})

	content.add_child(UIKit.body(
		"You were stopped, searched and processed. They kept what they found and let you go."))

	var panel := UIKit.panel(UIKit.BG_PANEL)
	var v := UIKit.vbox(4)
	panel.add_child(v)
	v.add_child(UIKit.stat_line("Fine",
		GameConfig.format_money(int(penalty.get("fine", 0))), UIKit.BAD))
	v.add_child(UIKit.stat_line("Stock seized",
		"%d units" % int(penalty.get("seized_units", 0)), UIKit.BAD))
	if int(penalty.get("shutdown_hours", 0)) > 0:
		v.add_child(UIKit.stat_line("Closed",
			"%s for %d hours" % [String(penalty.get("property", "A site")),
				int(penalty.get("shutdown_hours", 0))], UIKit.BAD))
	v.add_child(UIKit.stat_line("Record", EnforcementService.threat_label()))
	content.add_child(panel)

	var seized: Array = penalty.get("seized", [])
	if not seized.is_empty():
		section("Taken")
		for s in seized:
			content.add_child(UIKit.list_row(
				GameData.item_icon(String(s["item"])), GameData.item_color(String(s["item"])),
				"%s x%d" % [GameData.item_name(String(s["item"])), int(s["qty"])],
				GameConfig.quality_name(int(s["quality"])), "", UIKit.BAD))

	content.add_child(UIKit.spacer(6))
	content.add_child(UIKit.body(
		"Packaging, quieter spots and the Nerve skill tree all make this less likely."))
	var ok := UIKit.button("Get on with it", "primary")
	ok.pressed.connect(close)
	actions([ok] as Array[Button])
