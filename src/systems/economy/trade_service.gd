class_name TradeService
extends RefCounted
## Player-to-customer selling, supplier buying, and bulk brokerage.
##
## A customer publishes an *interest* (which products, what quality floor, how
## many) and the service turns the player's actual inventory into a list of
## concrete offers with prices. Accepting one moves goods, money, reputation,
## market saturation and suspicion in a single place.

# ===========================================================================
# SELLING TO A CUSTOMER
# ===========================================================================

## `customer` is the runtime NPC data dictionary produced by NpcBrain:
##   {id, name, archetype, prefers: [item_id], min_quality, quantity, loyalty}
static func build_offers(customer: Dictionary, district_id: String) -> Array[Dictionary]:
	var offers: Array[Dictionary] = []
	var inv := GameState.inventory
	var archetype := String(customer.get("archetype", "eager"))
	var arch: Dictionary = GameData.customer_archetypes.get(archetype, {})
	var min_quality := int(customer.get("min_quality", arch.get("min_quality", 0)))
	var prefers: Array = customer.get("prefers", [])
	var want_total := int(customer.get("quantity", 2))

	for i in inv.stacks.size():
		var s: Dictionary = inv.stacks[i]
		var item_id := String(s["item"])
		if GameData.item(item_id).get("category", "") != ItemDB.CAT_PRODUCT:
			continue
		var quality := int(s["quality"])
		if quality < min_quality:
			continue
		if not prefers.is_empty() and not prefers.has(item_id):
			continue

		var unit := EconomyService.unit_price(item_id, quality, String(s["pack"]),
			district_id, archetype)
		# Loyal regulars pay a little over the odds.
		var loyalty := float(customer.get("loyalty", 0.0))
		unit = int(round(unit * (1.0 + loyalty * 0.12)))
		var qty: int = mini(int(s["qty"]), want_total)
		if qty <= 0:
			continue
		offers.append({
			"slot": i,
			"item": item_id,
			"quality": quality,
			"pack": String(s["pack"]),
			"available": int(s["qty"]),
			"max_qty": qty,
			"unit_price": unit,
		})

	offers.sort_custom(func(a, b): return int(a["unit_price"]) > int(b["unit_price"]))
	return offers


## Why a customer will not deal, for the UI to explain.
static func refusal_reason(customer: Dictionary, district_id: String) -> String:
	var inv := GameState.inventory
	if inv.count_any_product() <= 0:
		return "You have nothing to sell."
	var arch: Dictionary = GameData.customer_archetypes.get(String(customer.get("archetype", "eager")), {})
	var min_quality := int(customer.get("min_quality", arch.get("min_quality", 0)))
	if inv.count_any_product(min_quality) <= 0:
		return "Nothing you are carrying is %s or better." % GameConfig.quality_name(min_quality)
	var prefers: Array = customer.get("prefers", [])
	if not prefers.is_empty():
		var names: Array[String] = []
		for p in prefers:
			names.append(GameData.item_name(String(p)))
		return "They only want " + " or ".join(names) + " today."
	if build_offers(customer, district_id).is_empty():
		return "They are not interested in what you have."
	return ""


## Executes a sale. `exposure` 0..1 describes how public the spot is and
## drives the suspicion cost - selling in a doorway is cheaper than selling
## in the middle of Market Row at noon.
static func sell(customer: Dictionary, offer: Dictionary, quantity: int,
		district_id: String, exposure: float = 0.5) -> Dictionary:
	var qty: int = clampi(quantity, 1, int(offer.get("max_qty", 1)))
	var item_id := String(offer["item"])
	var quality := int(offer["quality"])
	var pack := String(offer["pack"])
	var unit: int = int(offer["unit_price"])

	var removed := GameState.inventory.remove(item_id, qty, quality, false)
	if removed <= 0:
		return {"ok": false, "reason": "Those are gone."}
	var payout := unit * removed

	GameState.add_cash(payout, "Sold %dx %s" % [removed, GameData.item_name(item_id)])
	EconomyService.register_sale(district_id, item_id, removed, unit)

	# Reputation, relationship and progression.
	var rep_gain := GameConfig.REP_PER_GOOD_DEAL * removed * (0.6 + quality * 0.18)
	GameState.add_reputation(district_id, rep_gain)
	var npc_id := String(customer.get("id", ""))
	if npc_id != "":
		GameState.add_relationship(npc_id, 2.0 + quality)
	GameState.add_xp(6 + quality * 4 + removed * 2, "sale")

	# Risk. Packaging and a quiet spot both cut the suspicion cost sharply.
	var pack_reduction := 0.0
	if pack != "":
		pack_reduction = float(GameData.item(pack).get("heat_reduction", 0.0))
	var risk := GameConfig.SUSPICION_PER_PUBLIC_DEAL * exposure * (1.0 - pack_reduction)
	risk *= 0.6 + float(GameData.customer_archetypes.get(
		String(customer.get("archetype", "eager")), {}).get("public_risk", 1.0)) * 0.4
	risk *= 0.5 + 0.5 * clampf(float(removed) / 4.0, 0.3, 2.0)
	EnforcementService.add_suspicion(risk * (1.0 - clampf(GameState.skill_effect("suspicion_resist"), 0.0, 0.7)))
	GameState.add_heat(district_id, risk * 0.12)

	EventBus.deal_completed.emit(npc_id, item_id, removed, payout)
	AudioDirector.play("cash")
	return {"ok": true, "units": removed, "payout": payout, "unit": unit}


# ===========================================================================
# BULK BROKERAGE (Saoirse Lam)
# ===========================================================================

static func bulk_quote(npc_id: String, district_id: String) -> Dictionary:
	var npc: Dictionary = GameData.npc(npc_id)
	var discount := float(npc.get("bulk_discount", 0.82))
	discount += GameState.skill_effect("bulk_bonus")
	var minimum := int(npc.get("bulk_min", 5))
	var lines: Array[Dictionary] = []
	var total := 0
	var units := 0
	for i in GameState.inventory.stacks.size():
		var s: Dictionary = GameState.inventory.stacks[i]
		if GameData.item(String(s["item"])).get("category", "") != ItemDB.CAT_PRODUCT:
			continue
		var unit := int(round(EconomyService.unit_price(String(s["item"]), int(s["quality"]),
			String(s["pack"]), district_id) * discount))
		var qty := int(s["qty"])
		lines.append({"slot": i, "item": String(s["item"]), "quality": int(s["quality"]),
			"pack": String(s["pack"]), "qty": qty, "unit_price": unit, "total": unit * qty})
		total += unit * qty
		units += qty
	return {"lines": lines, "total": total, "units": units, "minimum": minimum,
		"ok": units >= minimum, "discount": discount}


static func sell_bulk(npc_id: String, district_id: String) -> Dictionary:
	var quote := bulk_quote(npc_id, district_id)
	if not bool(quote["ok"]):
		return {"ok": false, "reason": "They want at least %d units." % int(quote["minimum"])}
	var units := 0
	for line in quote["lines"]:
		var removed := GameState.inventory.remove(String(line["item"]), int(line["qty"]),
			int(line["quality"]), false)
		units += removed
		EconomyService.register_sale(district_id, String(line["item"]), removed, int(line["unit_price"]))
	var payout := int(quote["total"])
	GameState.add_cash(payout, "Bulk lot to " + GameData.npc_name(npc_id))
	GameState.add_reputation(district_id, units * 0.4)
	GameState.add_relationship(npc_id, units * 0.6)
	GameState.add_xp(units * 6, "bulk")
	# A single big handover is far quieter than the same units sold on corners.
	EnforcementService.add_suspicion(6.0 + units * 0.4)
	EventBus.deal_completed.emit(npc_id, "any", units, payout)
	AudioDirector.play("cash")
	return {"ok": true, "units": units, "payout": payout}


# ===========================================================================
# BUYING FROM A SUPPLIER
# ===========================================================================

static func shop_stock(npc_id: String, district_id: String) -> Array[Dictionary]:
	var npc: Dictionary = GameData.npc(npc_id)
	var shop: Dictionary = npc.get("shop", {})
	var markup := float(shop.get("markup", 1.0))
	var out: Array[Dictionary] = []
	for item_id in shop.get("stock", []):
		out.append({
			"item": String(item_id),
			"price": EconomyService.buy_price(String(item_id), district_id, markup),
			"name": GameData.item_name(String(item_id)),
		})
	return out


static func buy(npc_id: String, item_id: String, quantity: int, district_id: String) -> Dictionary:
	var npc: Dictionary = GameData.npc(npc_id)
	var markup := float(npc.get("shop", {}).get("markup", 1.0))
	var unit := EconomyService.buy_price(item_id, district_id, markup)
	var qty: int = maxi(1, quantity)
	var cost := unit * qty
	if not GameState.can_afford(cost):
		return {"ok": false, "reason": "Not enough money"}
	if not GameState.inventory.can_accept(item_id, qty):
		return {"ok": false, "reason": "No room in your pockets"}
	if not GameState.spend(cost, "Bought %dx %s" % [qty, GameData.item_name(item_id)]):
		return {"ok": false, "reason": "Payment failed"}
	GameState.inventory.add(item_id, qty)
	GameState.add_relationship(npc_id, 0.4 * qty)
	AudioDirector.play_ui("ui_confirm")
	return {"ok": true, "units": qty, "cost": cost}


## Suppliers who buy junk back off the player.
static func sell_to_shop(npc_id: String, item_id: String, quantity: int,
		district_id: String) -> Dictionary:
	var npc: Dictionary = GameData.npc(npc_id)
	if not (npc.get("shop", {}).get("buys", []) as Array).has(item_id):
		return {"ok": false, "reason": "They will not take that"}
	var unit := int(round(EconomyService.buy_price(item_id, district_id, 1.0) * 0.6))
	var removed := GameState.inventory.remove(item_id, quantity)
	if removed <= 0:
		return {"ok": false, "reason": "You have none"}
	var payout := unit * removed
	GameState.add_cash(payout, "Sold %dx %s" % [removed, GameData.item_name(item_id)])
	AudioDirector.play("cash")
	return {"ok": true, "units": removed, "payout": payout}
