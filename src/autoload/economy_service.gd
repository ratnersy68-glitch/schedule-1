extends Node
## Dynamic market simulation.
##
## Every (district, product) pair carries a demand value that decays when you
## flood it and recovers over time, plus a slowly drifting price multiplier.
## Sale price is then assembled from base value, quality, packaging, district
## wealth, live demand, your reputation, rival pressure and your skills.

## district_id -> { product_id -> {demand, price_mult, sold_today, last_price} }
var market: Dictionary = {}

## Temporary global/district modifiers created by world events.
## [{scope, district, kind, power, expires_at}]
var modifiers: Array[Dictionary] = []

## Rival share per district, 0..1. Rivals push your prices down.
var rival_share: Dictionary = {}

var _accum: float = 0.0


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_PAUSABLE
	reset()
	EventBus.hour_passed.connect(_on_hour_passed)
	EventBus.day_passed.connect(_on_day_passed)


func reset() -> void:
	market.clear()
	modifiers.clear()
	rival_share.clear()
	for did in GameData.district_ids:
		var d := {}
		var district: Dictionary = GameData.district(did)
		var demand_table: Dictionary = district.get("demand", {})
		for pid in GameData.product_ids:
			d[pid] = {
				"demand": float(demand_table.get(pid, 0.5)),
				"base_demand": float(demand_table.get(pid, 0.5)),
				"price_mult": 1.0,
				"sold_today": 0,
				"last_price": 0,
			}
		market[did] = d
		rival_share[did] = 0.25


# ===========================================================================
# PRICING
# ===========================================================================

## Full price breakdown for one unit. Returns a Dictionary so the UI can
## explain *why* an offer is what it is, which is most of the fun.
func price_breakdown(item_id: String, quality: int, pack: String,
		district_id: String, archetype: String = "") -> Dictionary:
	var item: Dictionary = GameData.item(item_id)
	if item.is_empty():
		return {"total": 0}

	var base := float(item.get("base_value", 0))
	var q_mult := GameConfig.quality_multiplier(quality)
	var pack_mult := 1.0
	if pack != "":
		pack_mult += float(GameData.item(pack).get("value_bonus", 0.0))

	var district: Dictionary = GameData.district(district_id)
	var wealth := float(district.get("wealth", 0.5))
	var wealth_mult := 0.72 + wealth * 0.62          # 0.72 .. 1.34

	var entry: Dictionary = _entry(district_id, item_id)
	var demand := float(entry.get("demand", 1.0))
	var demand_mult := clampf(0.55 + demand * 0.6, 0.4, 1.9)
	var drift := float(entry.get("price_mult", 1.0))

	var rep := GameState.get_reputation(district_id)
	var rep_mult := 1.0 + clampf(rep / GameConfig.REP_MAX, -0.4, 1.0) * 0.28

	var rival := float(rival_share.get(district_id, 0.25))
	var rival_mult := clampf(1.15 - rival * 0.5, 0.7, 1.15)

	var arch_mult := 1.0
	if archetype != "":
		arch_mult = float(GameData.customer_archetypes.get(archetype, {}).get("price_bias", 1.0))

	var skill_mult := 1.0 + GameState.skill_effect("sale_price_mult")
	var prestige := 1.0
	for p in GameState.all_owned_properties():
		prestige += float(GameData.property(p.id).get("rep_bonus", 0.0))

	var event_mult := _event_multiplier(district_id, "price")

	# Night trade pays a premium, daylight trade is safer but cheaper.
	var time_mult := 1.12 if GameState.is_night() else 1.0

	var total := base * q_mult * pack_mult * wealth_mult * demand_mult * drift \
		* rep_mult * rival_mult * arch_mult * skill_mult * prestige * event_mult * time_mult

	var clamped := clampf(total, base * GameConfig.MIN_PRICE_MULT, base * GameConfig.MAX_PRICE_MULT * 3.0)

	return {
		"total": int(round(clamped)),
		"base": int(base),
		"quality": q_mult,
		"packaging": pack_mult,
		"district": wealth_mult,
		"demand": demand_mult,
		"drift": drift,
		"reputation": rep_mult,
		"rivals": rival_mult,
		"buyer": arch_mult,
		"skills": skill_mult,
		"prestige": prestige,
		"event": event_mult,
		"time": time_mult,
	}


func unit_price(item_id: String, quality: int, pack: String, district_id: String,
		archetype: String = "") -> int:
	return int(price_breakdown(item_id, quality, pack, district_id, archetype).get("total", 0))


## What a supplier charges you for a material.
func buy_price(item_id: String, district_id: String, markup: float = 1.0) -> int:
	var base := float(GameData.item_value(item_id))
	var district: Dictionary = GameData.district(district_id)
	var wealth := float(district.get("wealth", 0.5))
	var event_mult := _event_multiplier(district_id, "price")
	var scarcity := 1.0
	if GameData.item(item_id).get("category", "") == ItemDB.CAT_MATERIAL:
		scarcity = 1.0 + float(GameData.item(item_id).get("tier", 1) - 1) * 0.05
	var p := base * markup * (0.9 + wealth * 0.3) * event_mult * scarcity
	return maxi(1, int(round(p)))


# ===========================================================================
# TRADE
# ===========================================================================

## Applies the market consequences of a completed sale.
func register_sale(district_id: String, item_id: String, amount: int, unit_value: int) -> void:
	var entry: Dictionary = _entry(district_id, item_id)
	if entry.is_empty():
		return
	var saturation := GameConfig.SATURATION_PER_UNIT * amount
	entry["demand"] = maxf(0.08, float(entry["demand"]) - saturation)
	entry["sold_today"] = int(entry["sold_today"]) + amount
	entry["last_price"] = unit_value
	# Heavy trading in a district nudges its long-run price drift down.
	entry["price_mult"] = clampf(float(entry["price_mult"]) - 0.004 * amount, 0.7, 1.4)
	rival_share[district_id] = maxf(0.0, float(rival_share.get(district_id, 0.25)) - 0.012 * amount)


func demand_for(district_id: String, item_id: String) -> float:
	return float(_entry(district_id, item_id).get("demand", 0.0))


func demand_label(value: float) -> String:
	if value < 0.3:
		return "Flooded"
	if value < 0.6:
		return "Soft"
	if value < 0.95:
		return "Steady"
	if value < 1.3:
		return "Strong"
	return "Hungry"


## The district where a product currently fetches the most, among unlocked ones.
func best_district_for(item_id: String) -> String:
	var best := ""
	var best_price := -1
	for did in GameState.unlocked_districts:
		var p := unit_price(item_id, 2, "", did)
		if p > best_price:
			best_price = p
			best = did
	return best


## Fraction of the city's trade you control - drives the domination ending.
func player_market_share(district_id: String) -> float:
	var rep := GameState.get_reputation(district_id) / GameConfig.REP_MAX
	var rival := float(rival_share.get(district_id, 0.25))
	return clampf(rep * 0.8 + (1.0 - rival) * 0.4, 0.0, 1.0)


func districts_controlled() -> int:
	var n := 0
	for did in GameState.unlocked_districts:
		if player_market_share(did) >= 0.7:
			n += 1
	return n


# ===========================================================================
# EVENT MODIFIERS
# ===========================================================================

func add_modifier(kind: String, power: float, hours: float, district_id: String = "") -> void:
	modifiers.append({
		"kind": kind,
		"power": power,
		"district": district_id,
		"expires_at": GameState.absolute_hours() + hours,
	})


func _event_multiplier(district_id: String, kind: String) -> float:
	var m := 1.0
	for mod in modifiers:
		if String(mod["kind"]) != kind:
			continue
		var scope: String = String(mod["district"])
		if scope != "" and scope != district_id:
			continue
		m *= float(mod["power"])
	return m


func patrol_multiplier(district_id: String) -> float:
	return _event_multiplier(district_id, "patrol")


func demand_multiplier(district_id: String) -> float:
	return _event_multiplier(district_id, "demand")


func _prune_modifiers() -> void:
	var now := GameState.absolute_hours()
	var kept: Array[Dictionary] = []
	for mod in modifiers:
		if float(mod["expires_at"]) > now:
			kept.append(mod)
	modifiers = kept


# ===========================================================================
# TICKS
# ===========================================================================

func _on_hour_passed(day: int, hour: int) -> void:
	_prune_modifiers()
	for did in market:
		var event_demand := demand_multiplier(did)
		for pid in market[did]:
			var e: Dictionary = market[did][pid]
			var target := float(e["base_demand"]) * event_demand
			# Demand walks back toward its baseline.
			e["demand"] = lerpf(float(e["demand"]), target, GameConfig.DEMAND_RECOVERY * 4.0)
			# Price drift is a slow random walk, smoothed so it never whipsaws.
			var noise := randf_range(-0.035, 0.035)
			var drift := lerpf(float(e["price_mult"]), 1.0 + noise, 1.0 - GameConfig.PRICE_MEMORY)
			e["price_mult"] = clampf(drift, 0.7, 1.4)
		# Rivals slowly reclaim share where you are absent.
		var share := float(rival_share.get(did, 0.25))
		rival_share[did] = clampf(share + 0.006, 0.0, 0.95)
	EventBus.market_tick.emit(day, hour)


func _on_day_passed(_day: int) -> void:
	for did in market:
		for pid in market[did]:
			market[did][pid]["sold_today"] = 0
	# Bank interest on a positive balance.
	if GameState.bank > 0:
		var interest := int(round(GameState.bank * GameConfig.BANK_DAILY_INTEREST))
		if interest > 0:
			GameState.bank += interest
			EventBus.bank_changed.emit(GameState.bank, interest)


func _entry(district_id: String, item_id: String) -> Dictionary:
	if not market.has(district_id):
		return {}
	return market[district_id].get(item_id, {})


# --- Serialisation ---------------------------------------------------------

func to_dict() -> Dictionary:
	return {"market": market.duplicate(true), "modifiers": modifiers.duplicate(true),
		"rival_share": rival_share.duplicate()}


func from_dict(d: Dictionary) -> void:
	reset()
	var m: Dictionary = d.get("market", {})
	for did in m:
		if not market.has(did):
			continue
		for pid in m[did]:
			if market[did].has(pid):
				market[did][pid] = m[did][pid]
	modifiers.clear()
	for mod in d.get("modifiers", []):
		if typeof(mod) == TYPE_DICTIONARY:
			modifiers.append(mod)
	var rs: Dictionary = d.get("rival_share", {})
	for did in rs:
		rival_share[did] = float(rs[did])
