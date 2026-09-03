class_name VehicleShopScreen
extends GameScreen
## Teo Marchetti's forecourt.


func build_content() -> void:
	set_titles("Marchetti Motors", "Papers included, mostly")
	refresh()


func refresh() -> void:
	if content == null:
		return
	clear_content()
	content.add_child(UIKit.stat_line("Your cash",
		GameConfig.format_money(GameState.cash + GameState.bank), UIKit.MONEY))
	for type_id in VehicleDB.ids():
		content.add_child(_vehicle_row(String(type_id)))


func _vehicle_row(type_id: String) -> Control:
	var v: Dictionary = GameData.vehicle(type_id)
	var owned := GameState.owns_vehicle(type_id)
	var locked := GameState.level < int(v.get("unlock_level", 1))
	var price := int(v.get("price", 0))

	var row := UIKit.panel(UIKit.BG_PANEL)
	var col := UIKit.vbox(6)
	row.add_child(col)

	var head := UIKit.hbox(8)
	var swatch := ColorRect.new()
	swatch.color = v.get("color", Color.WHITE)
	swatch.custom_minimum_size = Vector2(28, 28)
	head.add_child(swatch)
	var n := UIKit.label(String(v.get("name", type_id)), 16)
	n.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(n)
	head.add_child(UIKit.label(GameConfig.format_money(price), 16, UIKit.MONEY))
	col.add_child(head)
	col.add_child(UIKit.body(String(v.get("desc", ""))))

	col.add_child(_bar("Speed", float(v.get("top_speed", 10.0)) / 32.0, UIKit.ACCENT))
	col.add_child(_bar("Handling", float(v.get("grip", 4.0)) / 8.0, UIKit.VIOLET))
	col.add_child(_bar("Storage", float(v.get("storage", 10)) / 80.0, UIKit.GOOD))
	col.add_child(_bar("Discretion", float(v.get("heat_shield", 0.0)), UIKit.WARN))

	if owned:
		col.add_child(UIKit.label("Already on your books", 13, UIKit.GOOD))
	elif locked:
		col.add_child(UIKit.label("Teo will not sell you this until level %d" %
			int(v.get("unlock_level", 1)), 13, UIKit.TEXT_FAINT))
	else:
		var buy := UIKit.button("Buy", "primary")
		buy.disabled = not GameState.can_afford(price)
		if not GameState.can_afford(price):
			buy.text = "Need " + GameConfig.format_money(price)
		buy.pressed.connect(func(): _buy(type_id, price))
		col.add_child(buy)
	return row


func _bar(label_text: String, ratio: float, color: Color) -> Control:
	var h := UIKit.hbox(8)
	var l := UIKit.label(label_text, 12, UIKit.TEXT_DIM)
	l.custom_minimum_size = Vector2(84, 0)
	h.add_child(l)
	var p := UIKit.progress(clampf(ratio, 0.0, 1.0), color, 7.0)
	p.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	h.add_child(p)
	return h


func _buy(type_id: String, price: int) -> void:
	if not GameState.spend(price, "Bought " + String(GameData.vehicle(type_id).get("name", type_id))):
		EventBus.toast_requested.emit("Not enough money", "warn")
		return
	var world := get_tree().get_first_node_in_group("world_manager")
	if world != null and world.has_method("deliver_vehicle"):
		world.deliver_vehicle(type_id)
	EventBus.toast_requested.emit("It is on the forecourt. Keys are in it.", "good")
	AudioDirector.play_ui("ui_confirm")
	refresh()
