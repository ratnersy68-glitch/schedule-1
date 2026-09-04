extends Node
## Headless regression test for the simulation layer.
##
## Run with:
##   godot --headless --path . res://scenes/dev/smoke_test.tscn
## Exits with code 0 when every check passes and 1 otherwise, so it can gate CI.
##
## This deliberately drives the *services* rather than the scene tree: it is a
## test of the game's rules, not of its rendering.

var _passed := 0
var _failed := 0
var _failures: Array[String] = []


func _ready() -> void:
	print("\n=== UNDERLIGHT smoke test ===\n")
	_test_content_integrity()
	_test_interface_theme()
	_test_inventory()
	_test_economy()
	_test_production()
	_test_trade()
	_test_business()
	_test_enforcement()
	_test_missions()
	_test_save_load()
	_report()


# ===========================================================================
# CHECKS
# ===========================================================================

func check(label: String, condition: bool, detail: String = "") -> void:
	if condition:
		_passed += 1
		print("  ok    %s" % label)
	else:
		_failed += 1
		_failures.append(label + ("  (" + detail + ")" if detail != "" else ""))
		print("  FAIL  %s%s" % [label, "  (" + detail + ")" if detail != "" else ""])


func section(name: String) -> void:
	print("\n-- %s" % name)


# ===========================================================================
# TESTS
# ===========================================================================

func _test_content_integrity() -> void:
	section("Content")
	check("items loaded", GameData.items.size() >= 20, str(GameData.items.size()))
	check("recipes loaded", GameData.recipes.size() >= 6)
	check("districts loaded", GameData.districts.size() == 6)
	check("properties loaded", GameData.properties.size() == 7)
	check("missions loaded", GameData.missions.size() >= 15)
	check("skills loaded", GameData.skills.size() >= 18)
	check("vehicles loaded", GameData.vehicles.size() == 5)

	var recipe_outputs := {}
	for rid in GameData.recipes:
		recipe_outputs[GameData.recipes[rid]["output"]] = true
	var reachable := true
	for pid in GameData.product_ids:
		if not recipe_outputs.has(pid):
			reachable = false
	check("every product has a recipe", reachable)

	var chain_ok := true
	var mid := "ch1_keys"
	var seen := 0
	while mid != "" and seen < 40:
		seen += 1
		if not GameData.missions.has(mid):
			chain_ok = false
			break
		mid = String(GameData.missions[mid].get("next", ""))
	check("main story chain resolves", chain_ok and seen >= 10, "%d chapters" % seen)


func _test_interface_theme() -> void:
	section("Interface theme")
	var base := UITheme.base_font()
	check("interface font loads", base != null and base is FontFile)
	if base == null:
		return
	check("font has glyphs", base.get_face_count() >= 1)

	var regular := UITheme.font(UITheme.W_REGULAR)
	var black := UITheme.font(UITheme.W_BLACK)
	check("weights are distinct resources", regular != black)
	# A heavier weight must actually be wider, or the variable axis is not
	# being applied and every weight is silently identical.
	var w_regular := regular.get_string_size("Cobalt Bay 1234", HORIZONTAL_ALIGNMENT_LEFT, -1, 32).x
	var w_black := black.get_string_size("Cobalt Bay 1234", HORIZONTAL_ALIGNMENT_LEFT, -1, 32).x
	check("weight axis changes metrics", w_black > w_regular,
		"%.1f vs %.1f" % [w_regular, w_black])

	# Tabular numerals must all advance the same width.
	var tab := UITheme.font(UITheme.W_SEMIBOLD, true)
	var w_ones := tab.get_string_size("111111", HORIZONTAL_ALIGNMENT_LEFT, -1, 24).x
	var w_mixed := tab.get_string_size("098472", HORIZONTAL_ALIGNMENT_LEFT, -1, 24).x
	check("numerals are tabular", absf(w_ones - w_mixed) < 0.5,
		"%.2f vs %.2f" % [w_ones, w_mixed])

	var theme := UITheme.get_theme()
	check("theme built", theme != null)
	check("theme carries the font", theme.default_font != null)
	check("buttons are styled", theme.get_stylebox("normal", "Button") != null)
	check("panels are styled", theme.get_stylebox("panel", "PanelContainer") != null)
	check("sliders have a grabber", theme.get_icon("grabber", "HSlider") != null)
	check("check buttons have a switch", theme.get_icon("checked", "CheckButton") != null)


func _test_inventory() -> void:
	section("Inventory")
	GameState.reset()
	var inv := GameState.inventory
	check("starts empty", inv.is_empty())

	inv.add("ferro_silt", 5)
	check("add stacks", inv.count("ferro_silt") == 5)

	inv.add("pale_shard", 3, 2)
	inv.add("pale_shard", 2, 4)
	check("quality separates stacks", inv.count("pale_shard", 2) == 3 and inv.count("pale_shard", 4) == 2)
	check("min-quality query", inv.count_min_quality("pale_shard", 3) == 2)

	inv.remove("pale_shard", 1)
	check("removes lowest quality first", inv.count("pale_shard", 2) == 2)

	var heat_before := inv.contraband_heat()
	inv.add("vac_pouch", 4)
	var idx := inv.find_stack("pale_shard", 2, "")
	inv.package_slot(idx, "vac_pouch", inv)
	check("packaging applied", inv.count("pale_shard", 2, "vac_pouch") == 2)
	check("packaging cuts heat", inv.contraband_heat() < heat_before)

	var cap := inv.capacity
	inv.set_capacity(2)
	var added := inv.add("cryo_gel", 40)
	check("capacity is respected", added < 40, "added %d" % added)
	inv.set_capacity(cap)

	var round_trip := Inventory.new("t", 8)
	round_trip.from_dict(inv.to_dict())
	check("inventory serialises", round_trip.total_units() == inv.total_units())


func _test_economy() -> void:
	section("Economy")
	GameState.reset()
	EconomyService.reset()

	var low := EconomyService.unit_price("pale_shard", 0, "", "dockside")
	var high := EconomyService.unit_price("pale_shard", 4, "", "dockside")
	check("quality raises price", high > low * 2, "%d vs %d" % [low, high])

	var poor := EconomyService.unit_price("aurora_prism", 2, "", "dockside")
	var rich := EconomyService.unit_price("aurora_prism", 2, "", "hillcrest")
	check("wealthy districts pay more", rich > poor, "%d vs %d" % [poor, rich])

	var before := EconomyService.demand_for("dockside", "pale_shard")
	EconomyService.register_sale("dockside", "pale_shard", 10, 40)
	var after := EconomyService.demand_for("dockside", "pale_shard")
	check("flooding a district cuts demand", after < before, "%.2f -> %.2f" % [before, after])

	var plain := EconomyService.unit_price("pale_shard", 2, "", "dockside")
	var packed := EconomyService.unit_price("pale_shard", 2, "courier_box", "dockside")
	check("packaging raises price", packed > plain)

	EconomyService.add_modifier("price", 1.5, 5.0, "")
	var boosted := EconomyService.unit_price("pale_shard", 2, "", "dockside")
	check("event modifiers apply", boosted > plain)
	EconomyService.reset()

	check("money formatting", GameConfig.format_money(1234567) == "$1,234,567",
		GameConfig.format_money(1234567))
	check("negative money formatting", GameConfig.format_money(-250) == "-$250")


func _test_production() -> void:
	section("Production")
	GameState.reset()
	EconomyService.reset()
	var prop := GameState.grant_property("dockside_lockup")
	check("property granted", prop != null and prop.owned)
	check("station created", prop.stations.size() >= 1)

	var station := prop.stations[0]
	station.family = RecipeDB.STATION_BENCH
	station.tier = 1

	GameState.inventory.add("ferro_silt", 4)
	GameState.inventory.add("bloomspore", 2)
	GameState.inventory.add("binder_resin", 2)

	var blocked := ProductionService.can_start(prop, station, "cobalt_bloom", [])
	check("unknown recipes are blocked", not bool(blocked["ok"]), String(blocked["reason"]))

	var allowed := ProductionService.can_start(prop, station, "pale_shard", [])
	check("known recipe with inputs is allowed", bool(allowed["ok"]), String(allowed["reason"]))

	var started := ProductionService.start_job(prop, station, "pale_shard", [])
	check("job starts", started)
	check("inputs consumed", GameState.inventory.count("ferro_silt") == 2)
	check("station busy", station.is_busy(GameState.absolute_hours()))

	# Fast-forward past the completion time.
	GameState.hour += 2.0
	check("station ready", station.is_ready(GameState.absolute_hours()))
	var made := ProductionService.collect(prop, station)
	check("output collected", made >= 2, "%d units" % made)
	check("output stored", prop.storage.count("pale_shard") + GameState.inventory.count("pale_shard") >= 2)
	check("xp awarded", GameState.xp > 0)

	# Additives should raise the forecast.
	var plain := ProductionService.predict_quality(station, "pale_shard", [])
	var boosted := ProductionService.predict_quality(station, "pale_shard", ["prism_flake"])
	check("additives raise quality", float(boosted["score"]) > float(plain["score"]))
	check("additive slots limited", ProductionService.additive_slots() == 2)


func _test_trade() -> void:
	section("Trade")
	GameState.reset()
	EconomyService.reset()
	GameState.inventory.add("pale_shard", 4, 2)

	var customer := {
		"id": "test_buyer", "name": "Test Buyer", "archetype": "eager",
		"prefers": ["pale_shard"], "min_quality": 0, "quantity": 3, "loyalty": 0.0,
	}
	var offers := TradeService.build_offers(customer, "dockside")
	check("offers generated", offers.size() == 1, str(offers.size()))
	check("offer respects wanted quantity", int(offers[0]["max_qty"]) == 3)

	var cash_before := GameState.cash
	var result := TradeService.sell(customer, offers[0], 3, "dockside", 0.5)
	check("sale completes", bool(result.get("ok", false)))
	check("cash increased", GameState.cash > cash_before)
	check("stock reduced", GameState.inventory.count("pale_shard") == 1)
	check("reputation gained", GameState.get_reputation("dockside") > 0.0)
	check("suspicion generated", EnforcementService.suspicion > 0.0)

	var picky := {
		"id": "picky", "name": "Picky", "archetype": "collector",
		"prefers": ["solar_halo"], "min_quality": 4, "quantity": 1, "loyalty": 0.0,
	}
	check("mismatched buyer gets no offers",
		TradeService.build_offers(picky, "dockside").is_empty())
	check("refusal is explained",
		TradeService.refusal_reason(picky, "dockside") != "")

	# Buying from a supplier.
	GameState.add_cash(500, "test")
	var buy := TradeService.buy("dez_okonkwo", "ferro_silt", 3, "dockside")
	check("supplier purchase works", bool(buy.get("ok", false)))
	check("materials received", GameState.inventory.count("ferro_silt") == 3)


func _test_business() -> void:
	section("Business")
	GameState.reset()
	EconomyService.reset()
	GameState.grant_property("dockside_lockup")

	var prop: PropertyState = GameState.get_property("dockside_lockup")
	var storage_before := prop.storage_capacity()
	GameState.add_cash(50000, "test funds")
	check("upgrade succeeds", BusinessService.upgrade("dockside_lockup", "storage"))
	check("upgrade raises capacity", prop.storage_capacity() > storage_before,
		"%d -> %d" % [storage_before, prop.storage_capacity()])

	check("staff slots start at zero", prop.employee_slots() == 0)
	check("hiring blocked without space",
		not bool(BusinessService.can_hire("hand", "dockside_lockup")["ok"]))
	BusinessService.upgrade("dockside_lockup", "staff")
	check("staff upgrade adds a slot", prop.employee_slots() >= 1)

	var employee := BusinessService.hire("hand", "dockside_lockup", "Test Worker")
	check("hire works", employee != null)
	check("employee on payroll", GameState.employee_count() == 1)
	check("payroll computed", GameState.daily_payroll() > 0)
	check("assignment defaults to production",
		employee != null and employee.assignment == Employee.ASSIGN_PRODUCTION)

	# The hourly tick should put an idle bench to work.
	prop.storage.add("tide_ash", 20)
	prop.storage.add("binder_resin", 20)
	prop.storage.add("ferro_silt", 20)
	prop.storage.add("bloomspore", 20)
	BusinessService.tick_hour()
	var any_busy := false
	for s in prop.stations:
		if s.recipe_id != "":
			any_busy = true
	check("staff start production unattended", any_busy)

	var cash_before := GameState.cash + GameState.bank
	var summary := BusinessService.settle_day()
	check("daily settlement charges costs", int(summary["total"]) > 0)
	check("money actually deducted", GameState.cash + GameState.bank < cash_before)

	BusinessService.fire(employee.id)
	check("firing removes them", GameState.employee_count() == 0)


func _test_enforcement() -> void:
	section("Enforcement")
	GameState.reset()
	EnforcementService.reset()
	GameState.inventory.add("cobalt_bloom", 6, 2)

	EnforcementService.report_incident("public_deal", 1.0)
	check("incidents raise suspicion", EnforcementService.suspicion > 0.0)

	EnforcementService.escalate(150.0, "test")
	check("wanted level rises", EnforcementService.wanted_level >= 1,
		str(EnforcementService.wanted_level))

	var cash_before := GameState.cash
	GameState.add_cash(2000, "test funds")
	var units_before := GameState.inventory.count("cobalt_bloom")
	EnforcementService.bust()
	check("bust fines the player", GameState.cash < cash_before + 2000)
	check("bust seizes stock", GameState.inventory.count("cobalt_bloom") < units_before,
		"%d -> %d" % [units_before, GameState.inventory.count("cobalt_bloom")])
	check("bust clears the wanted level", EnforcementService.wanted_level == 0)

	EnforcementService.escalate(300.0)
	EnforcementService.clear_wanted(1.0)
	check("burner clears wanted", EnforcementService.wanted_level == 0)


func _test_missions() -> void:
	section("Missions")
	GameState.reset()
	MissionService.reset()
	EconomyService.reset()

	check("first chapter is offerable", MissionService.can_offer("ch1_keys"))
	check("later chapters are gated", not MissionService.can_offer("ch3_blue_line"))

	MissionService.start("ch1_first_lattice")
	check("mission is active", MissionService.is_active("ch1_first_lattice"))
	check("first objective is current",
		MissionService.current_objective_index("ch1_first_lattice") == 0)

	GameState.inventory.add("ferro_silt", 2)
	MissionService._refresh_stateful()
	check("collect objectives track inventory",
		MissionService.objective_progress("ch1_first_lattice", 0) == 2)

	GameState.inventory.add("bloomspore", 1)
	GameState.inventory.add("binder_resin", 1)
	MissionService._refresh_stateful()
	check("later objectives fill in",
		MissionService.objective_progress("ch1_first_lattice", 2) == 1)

	var xp_before := GameState.xp
	EventBus.production_finished.emit("s", "pale_shard", 2, 2)
	check("craft objective completes the mission",
		MissionService.is_completed("ch1_first_lattice"))
	check("rewards granted", GameState.xp > xp_before)
	check("story flag set", GameState.has_flag("crafted_first"))
	check("next chapter auto-started", MissionService.is_active("ch1_first_sale"))

	# Deliveries.
	GameState.set_flag("has_lockup")
	check("side job offerable once its flag is set", MissionService.can_offer("side_scrap_run"))
	MissionService.start("side_scrap_run")
	GameState.inventory.add("scrap_bundle", 6)
	MissionService.notify_deliver("dez_okonkwo", "scrap_bundle", 6, 0)
	check("delivery completes the job", MissionService.is_completed("side_scrap_run"))
	check("repeatable job goes on cooldown", not MissionService.can_offer("side_scrap_run"))

	# Failure path.
	MissionService.start("law_audit")
	MissionService.fail("law_audit", "test")
	check("failing removes the job", not MissionService.is_active("law_audit"))
	check("failure is recorded", MissionService.failed.has("law_audit"))

	# Quest items are requested exactly once.
	var requests: Array[Dictionary] = []
	var probe := func(screen_id: String, payload: Dictionary):
		if screen_id == "spawn_quest_item":
			requests.append(payload)
	EventBus.screen_requested.connect(probe)
	MissionService.start("ch9_ledger")
	MissionService._check_quest_spawns()
	MissionService._check_quest_spawns()
	EventBus.screen_requested.disconnect(probe)
	check("quest item requested", requests.size() == 1, str(requests.size()))
	check("quest item is the ledger",
		requests.size() > 0 and String(requests[0].get("item", "")) == "tidewell_ledger")

	# Endgame progress should be a sane 0..1.
	var progress := MissionService.endgame_progress("wealth")
	check("endgame progress in range", progress >= 0.0 and progress <= 1.0)
	GameState.bank = 2000000
	check("wealth path completes at target",
		MissionService.endgame_progress("wealth") >= 1.0)


func _test_save_load() -> void:
	section("Save and load")
	GameState.reset()
	EconomyService.reset()
	MissionService.reset()
	EnforcementService.reset()

	GameState.add_cash(4321, "test")
	GameState.bank = 8765
	GameState.day = 9
	GameState.hour = 15.5
	GameState.add_xp(900, "test")
	GameState.inventory.add("aurora_prism", 3, 3)
	GameState.inventory.add("cryo_gel", 7)
	GameState.grant_property("dockside_lockup")
	GameState.get_property("dockside_lockup").storage.add("pale_shard", 12, 1)
	GameState.add_reputation("dockside", 33.0)
	GameState.unlock_recipe("cobalt_bloom")
	GameState.set_flag("test_flag")
	GameState.skill_points = 3
	GameState.purchase_skill("silver_tongue")
	MissionService.start("ch1_first_sale")
	EnforcementService.escalate(120.0)

	var slot := 2
	check("save writes", SaveService.save_game(slot, true))
	check("slot reports existing", SaveService.slot_exists(slot))
	var meta := SaveService.slot_summary(slot)
	check("save metadata readable", int(meta.get("day", 0)) == 9, str(meta.get("day", 0)))

	# Scramble everything, then load it back.
	GameState.reset()
	MissionService.reset()
	EnforcementService.reset()
	check("state cleared before load", GameState.cash == GameConfig.STARTING_CASH)

	check("load succeeds", SaveService.load_into_state(slot))
	var expected_cash := GameConfig.STARTING_CASH + 4321
	check("cash restored", GameState.cash == expected_cash, str(GameState.cash))
	check("bank restored", GameState.bank == 8765)
	check("clock restored", GameState.day == 9 and absf(GameState.hour - 15.5) < 0.01)
	check("inventory restored",
		GameState.inventory.count("aurora_prism", 3) == 3 and GameState.inventory.count("cryo_gel") == 7)
	check("property restored", GameState.owns_property("dockside_lockup"))
	check("property storage restored",
		GameState.get_property("dockside_lockup").storage.count("pale_shard") == 12)
	check("reputation restored", absf(GameState.get_reputation("dockside") - 33.0) < 0.01)
	check("recipes restored", GameState.knows_recipe("cobalt_bloom"))
	check("flags restored", GameState.has_flag("test_flag"))
	check("skills restored", GameState.skill_rank("silver_tongue") == 1)
	check("skill effect applies", GameState.skill_effect("sale_price_mult") > 0.0)
	check("missions restored", MissionService.is_active("ch1_first_sale"))
	check("enforcement restored", EnforcementService.wanted_level >= 1)

	SaveService.delete_slot(slot)
	check("slot deleted", not SaveService.slot_exists(slot))


# ===========================================================================
# REPORT
# ===========================================================================

func _report() -> void:
	print("\n=== %d passed, %d failed ===" % [_passed, _failed])
	if _failed > 0:
		print("Failures:")
		for f in _failures:
			print("  - " + f)
	get_tree().quit(0 if _failed == 0 else 1)
