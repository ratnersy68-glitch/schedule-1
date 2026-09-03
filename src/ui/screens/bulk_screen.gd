class_name BulkScreen
extends GameScreen
## Selling everything at once to a broker: less per unit, far less exposure.

var npc_id: String = ""


func _ready() -> void:
	npc_id = String(payload.get("npc_id", ""))
	super._ready()


func build_content() -> void:
	set_titles(GameData.npc_name(npc_id), "Bulk lot")
	refresh()


func refresh() -> void:
	if content == null:
		return
	clear_content()
	var quote := TradeService.bulk_quote(npc_id, GameState.current_district)
	content.add_child(UIKit.body(
		"A broker takes the whole lot in one handover. You lose margin and gain quiet."))
	content.add_child(UIKit.stat_line("Rate", "%d%% of street price" %
		int(float(quote["discount"]) * 100.0)))
	content.add_child(UIKit.stat_line("Minimum lot", "%d units" % int(quote["minimum"])))

	section("Your lot")
	if (quote["lines"] as Array).is_empty():
		content.add_child(UIKit.body("You are not carrying anything they want."))
		return
	for line in quote["lines"]:
		content.add_child(UIKit.list_row(
			GameData.item_icon(String(line["item"])), GameData.item_color(String(line["item"])),
			"%s x%d" % [GameData.item_name(String(line["item"])), int(line["qty"])],
			GameConfig.quality_name(int(line["quality"])),
			GameConfig.format_money(int(line["total"])), UIKit.MONEY))

	content.add_child(UIKit.separator())
	content.add_child(UIKit.stat_line("Total units", str(int(quote["units"]))))
	content.add_child(UIKit.stat_line("Payout",
		GameConfig.format_money(int(quote["total"])), UIKit.MONEY))

	var sell := UIKit.button("Hand over the lot", "primary")
	sell.disabled = not bool(quote["ok"])
	if not bool(quote["ok"]):
		sell.text = "They want at least %d units" % int(quote["minimum"])
	sell.pressed.connect(func():
		var r := TradeService.sell_bulk(npc_id, GameState.current_district)
		if bool(r.get("ok", false)):
			EventBus.toast_requested.emit("Sold %d units for %s" %
				[int(r["units"]), GameConfig.format_money(int(r["payout"]))], "money")
			close()
		else:
			EventBus.toast_requested.emit(String(r.get("reason", "No deal")), "warn"))
	actions([sell] as Array[Button])
