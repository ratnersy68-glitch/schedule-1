class_name DealScreen
extends GameScreen
## Selling to a customer on the street.
##
## Shows what they want, what you have that matches, the offer per unit and the
## risk of doing it here. Risk is explicit because the whole point of the loop
## is choosing between a fast public sale and a slow safe one.

var agent: NpcAgent = null
var customer: CustomerProfile = null
var _offers: Array[Dictionary] = []
var _quantity: Dictionary = {}          ## slot -> chosen qty


func _ready() -> void:
	agent = payload.get("npc")
	if agent != null:
		customer = agent.customer
	super._ready()


func build_content() -> void:
	if customer == null:
		set_titles("Nobody there")
		content.add_child(UIKit.body("They wandered off."))
		return
	set_titles(customer.display_name, customer.archetype_label())
	refresh()


func refresh() -> void:
	if content == null or customer == null:
		return
	clear_content()

	var quote := UIKit.panel(UIKit.BG_PANEL)
	var qv := UIKit.vbox(4)
	quote.add_child(qv)
	qv.add_child(UIKit.label("\"" + customer.opener_line() + "\"", 15, UIKit.TEXT))
	var wants: Array[String] = []
	for p in customer.prefers:
		wants.append(GameData.item_name(p))
	qv.add_child(UIKit.stat_line("Looking for", " or ".join(wants) if not wants.is_empty() else "Anything"))
	qv.add_child(UIKit.stat_line("Minimum quality", GameConfig.quality_name(customer.min_quality),
		GameConfig.quality_color(customer.min_quality)))
	qv.add_child(UIKit.stat_line("Wants up to", "%d units" % customer.quantity))
	if customer.loyalty > 0.1:
		qv.add_child(UIKit.stat_line("Regular", "+%d%% offer" % int(customer.loyalty * 12.0), UIKit.GOOD))
	content.add_child(quote)

	var exposure := 0.5
	var player := get_tree().get_first_node_in_group("player")
	if player != null and player.has_method("exposure"):
		exposure = player.exposure()
	var risk_label := "Quiet spot"
	var risk_color := UIKit.GOOD
	if exposure > 0.65:
		risk_label = "Very exposed"
		risk_color = UIKit.BAD
	elif exposure > 0.42:
		risk_label = "Some eyes around"
		risk_color = UIKit.WARN
	content.add_child(UIKit.stat_line("Risk of dealing here", risk_label, risk_color))

	_offers = TradeService.build_offers(customer.to_data(), GameState.current_district)
	if _offers.is_empty():
		content.add_child(UIKit.spacer(6))
		content.add_child(UIKit.body(
			TradeService.refusal_reason(customer.to_data(), GameState.current_district)))
		var leave := UIKit.button("Walk away")
		leave.pressed.connect(close)
		actions([leave] as Array[Button])
		return

	section("Your stock they will take")
	for offer in _offers:
		content.add_child(_offer_row(offer, exposure))


func _offer_row(offer: Dictionary, exposure: float) -> Control:
	var slot := int(offer["slot"])
	var item_id := String(offer["item"])
	var quality := int(offer["quality"])
	var unit: int = int(offer["unit_price"])
	var max_qty: int = int(offer["max_qty"])
	var qty: int = clampi(int(_quantity.get(slot, max_qty)), 1, max_qty)
	_quantity[slot] = qty

	var row := UIKit.panel(UIKit.BG_PANEL)
	var v := UIKit.vbox(6)
	row.add_child(v)

	var head := UIKit.hbox(8)
	head.add_child(UIKit.label(GameData.item_icon(item_id), 20, GameData.item_color(item_id)))
	var name_label := UIKit.label(GameData.item_name(item_id), 16)
	name_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(name_label)
	head.add_child(UIKit.quality_chip(quality))
	if String(offer["pack"]) != "":
		head.add_child(UIKit.chip(GameData.item_name(String(offer["pack"])), UIKit.ACCENT))
	v.add_child(head)

	v.add_child(UIKit.stat_line("Offer", GameConfig.format_money(unit) + " each", UIKit.MONEY))

	var qty_row := UIKit.hbox(8)
	var minus := UIKit.button("−")
	minus.custom_minimum_size = Vector2(52, 44)
	minus.pressed.connect(func():
		_quantity[slot] = maxi(1, qty - 1)
		refresh())
	qty_row.add_child(minus)
	var qty_label := UIKit.label("%d" % qty, 18, UIKit.TEXT, HORIZONTAL_ALIGNMENT_CENTER)
	qty_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	qty_row.add_child(qty_label)
	var plus := UIKit.button("+")
	plus.custom_minimum_size = Vector2(52, 44)
	plus.pressed.connect(func():
		_quantity[slot] = mini(max_qty, qty + 1)
		refresh())
	qty_row.add_child(plus)
	v.add_child(qty_row)

	var sell := UIKit.button("Sell %d for %s" % [qty, GameConfig.format_money(unit * qty)], "good")
	sell.pressed.connect(func(): _do_sell(offer, qty, exposure))
	v.add_child(sell)
	return row


func _do_sell(offer: Dictionary, qty: int, exposure: float) -> void:
	var result := TradeService.sell(customer.to_data(), offer, qty,
		GameState.current_district, exposure)
	if not bool(result.get("ok", false)):
		EventBus.toast_requested.emit(String(result.get("reason", "No deal")), "warn")
		refresh()
		return
	customer.loyalty = clampf(customer.loyalty + 0.12 *
		(1.0 + GameState.skill_effect("loyalty_gain")), 0.0, 1.0)
	customer.last_served_day = GameState.day
	EventBus.toast_requested.emit("+%s from %s" %
		[GameConfig.format_money(int(result["payout"])), customer.display_name], "money")
	customer.quantity -= int(result["units"])
	if customer.quantity <= 0:
		close()
	else:
		refresh()


func close() -> void:
	if agent != null and is_instance_valid(agent):
		agent.end_conversation()
	super.close()
