class_name ShopScreen
extends GameScreen
## Buying materials and packaging from a supplier.

var npc_id: String = ""
var _quantities: Dictionary = {}


func _ready() -> void:
	npc_id = String(payload.get("npc_id", ""))
	super._ready()


func build_content() -> void:
	set_titles(GameData.npc_name(npc_id), "Supplies")
	refresh()


func refresh() -> void:
	if content == null:
		return
	clear_content()
	content.add_child(UIKit.stat_line("Your cash",
		GameConfig.format_money(GameState.cash), UIKit.MONEY))
	content.add_child(UIKit.stat_line("Pocket space",
		"%d / %d slots" % [GameState.inventory.used_slots(), GameState.inventory.capacity]))

	section("For sale")
	for entry in TradeService.shop_stock(npc_id, GameState.current_district):
		content.add_child(_stock_row(entry))

	var buys: Array = GameData.npc(npc_id).get("shop", {}).get("buys", [])
	if not buys.is_empty():
		section("They will buy")
		for item_id in buys:
			var have := GameState.inventory.count(String(item_id))
			if have <= 0:
				continue
			var row := UIKit.list_row(GameData.item_icon(String(item_id)),
				GameData.item_color(String(item_id)),
				"%s x%d" % [GameData.item_name(String(item_id)), have],
				"Sell the lot",
				GameConfig.format_money(int(EconomyService.buy_price(String(item_id),
					GameState.current_district, 1.0) * 0.6) * have), UIKit.MONEY)
			var b := Button.new()
			b.flat = true
			b.set_anchors_preset(Control.PRESET_FULL_RECT)
			b.pressed.connect(func():
				var r := TradeService.sell_to_shop(npc_id, String(item_id), have,
					GameState.current_district)
				if bool(r.get("ok", false)):
					EventBus.toast_requested.emit("+%s" %
						GameConfig.format_money(int(r["payout"])), "money")
				refresh())
			row.add_child(b)
			content.add_child(row)


func _stock_row(entry: Dictionary) -> Control:
	var item_id := String(entry["item"])
	var price := int(entry["price"])
	var qty: int = int(_quantities.get(item_id, 1))

	var row := UIKit.panel(UIKit.BG_PANEL)
	var v := UIKit.vbox(6)
	row.add_child(v)

	var head := UIKit.hbox(8)
	head.add_child(UIKit.icon_tile(GameData.item_icon(item_id), GameData.item_color(item_id), 32.0))
	var n := UIKit.label(GameData.item_name(item_id), 16)
	n.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(n)
	head.add_child(UIKit.label(GameConfig.format_money(price), 16, UIKit.MONEY))
	v.add_child(head)
	v.add_child(UIKit.label(String(GameData.item(item_id).get("desc", "")), 12, UIKit.TEXT_DIM))
	v.add_child(UIKit.stat_line("You hold", str(GameState.inventory.count(item_id))))

	var qty_row := UIKit.hbox(6)
	for step in [1, 5, 10]:
		var b := UIKit.button("x%d" % step, "primary" if qty == step else "default")
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		b.pressed.connect(func():
			_quantities[item_id] = step
			refresh())
		qty_row.add_child(b)
	v.add_child(qty_row)

	var total := price * qty
	var buy := UIKit.button("Buy %d for %s" % [qty, GameConfig.format_money(total)], "good")
	buy.disabled = not GameState.can_afford(total)
	buy.pressed.connect(func():
		var r := TradeService.buy(npc_id, item_id, qty, GameState.current_district)
		if not bool(r.get("ok", false)):
			EventBus.toast_requested.emit(String(r.get("reason", "No")), "warn")
		refresh())
	v.add_child(buy)
	return row
