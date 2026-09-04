class_name InventoryScreen
extends GameScreen
## What you are carrying, what it is worth, and what it is costing you in risk.


func build_content() -> void:
	set_titles("Pockets", "")
	refresh()


func refresh() -> void:
	if content == null:
		return
	clear_content()
	var inv := GameState.inventory
	set_titles("Pockets", "%d / %d slots" % [inv.used_slots(), inv.capacity])

	var summary := UIKit.panel(UIKit.BG_PANEL)
	var sv := UIKit.vbox(4)
	summary.add_child(sv)
	sv.add_child(UIKit.stat_line("Estimated value",
		GameConfig.format_money(inv.estimated_value()), UIKit.MONEY))
	sv.add_child(UIKit.stat_line("Contraband units", str(inv.contraband_units()),
		UIKit.WARN if inv.contraband_units() > 0 else UIKit.TEXT_DIM))
	var heat := inv.contraband_heat()
	sv.add_child(UIKit.stat_line("Heat you radiate", "%.1f" % heat,
		UIKit.BAD if heat > 6.0 else (UIKit.WARN if heat > 2.0 else UIKit.GOOD)))
	sv.add_child(UIKit.stat_line("Carried weight", "%.1f kg" % inv.total_weight()))
	content.add_child(summary)

	if inv.stacks.is_empty():
		content.add_child(UIKit.body("Empty. Scavenge the alleys or buy from Dez at Pell's Corner."))
		return

	var groups := {ItemDB.CAT_PRODUCT: [], ItemDB.CAT_MATERIAL: [],
		ItemDB.CAT_PACKAGING: [], ItemDB.CAT_CONSUMABLE: [], ItemDB.CAT_TOOL: [],
		ItemDB.CAT_MISC: []}
	for i in inv.stacks.size():
		var cat := String(GameData.item(String(inv.stacks[i]["item"])).get("category", ItemDB.CAT_MISC))
		if not groups.has(cat):
			groups[cat] = []
		groups[cat].append(i)

	for cat in groups:
		if (groups[cat] as Array).is_empty():
			continue
		section(String(cat).capitalize())
		for i in groups[cat]:
			content.add_child(_stack_row(int(i)))


func _stack_row(index: int) -> Control:
	var s: Dictionary = GameState.inventory.stacks[index]
	var item_id := String(s["item"])
	var item: Dictionary = GameData.item(item_id)
	var qty := int(s["qty"])
	var quality := int(s["quality"])
	var pack := String(s["pack"])

	var row := UIKit.panel(UIKit.BG_PANEL)
	var v := UIKit.vbox(4)
	row.add_child(v)

	var head := UIKit.hbox(8)
	head.add_child(UIKit.icon_tile(GameData.item_icon(item_id), GameData.item_color(item_id), 32.0))
	var n := UIKit.label("%s x%d" % [GameData.item_name(item_id), qty], 16)
	n.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(n)
	if String(item.get("category", "")) == ItemDB.CAT_PRODUCT:
		head.add_child(UIKit.quality_chip(quality))
	if pack != "":
		head.add_child(UIKit.chip(GameData.item_name(pack), UIKit.ACCENT))
	v.add_child(head)
	v.add_child(UIKit.label(String(item.get("desc", "")), 12, UIKit.TEXT_DIM))

	if String(item.get("category", "")) == ItemDB.CAT_PRODUCT:
		var here := EconomyService.unit_price(item_id, quality, pack, GameState.current_district)
		var best := EconomyService.best_district_for(item_id)
		v.add_child(UIKit.stat_line("Value here", GameConfig.format_money(here), UIKit.MONEY))
		if best != "" and best != GameState.current_district:
			var there := EconomyService.unit_price(item_id, quality, pack, best)
			v.add_child(UIKit.stat_line("Best market",
				"%s  %s" % [GameData.district_name(best), GameConfig.format_money(there)],
				UIKit.ACCENT))

	if String(item.get("category", "")) == ItemDB.CAT_CONSUMABLE:
		var use := UIKit.button("Use one", "good")
		use.pressed.connect(func(): _consume(item_id))
		v.add_child(use)

	var drop := UIKit.button("Drop one", "ghost")
	drop.pressed.connect(func():
		GameState.inventory.remove(item_id, 1, quality)
		refresh())
	v.add_child(drop)
	return row


func _consume(item_id: String) -> void:
	var item: Dictionary = GameData.item(item_id)
	if GameState.inventory.remove(item_id, 1) <= 0:
		return
	var power := float(item.get("power", 0.0))
	match String(item.get("effect", "")):
		"stamina":
			var p := get_tree().get_first_node_in_group("player")
			if p != null and p.has_method("restore_stamina"):
				p.restore_stamina(power)
			EventBus.toast_requested.emit("Stamina restored", "good")
		"health":
			var p2 := get_tree().get_first_node_in_group("player")
			if p2 != null and p2.has_method("heal"):
				p2.heal(power)
			EventBus.toast_requested.emit("Patched up", "good")
		"clear_wanted":
			EnforcementService.clear_wanted(0.9)
			EventBus.toast_requested.emit("The Bureau lost the thread", "good")
		"clear_heat":
			GameState.add_heat(GameState.current_district, -power)
			for prop in GameState.all_owned_properties():
				prop.heat = maxf(0.0, prop.heat - power * 0.5)
			EventBus.toast_requested.emit("Records quietly amended", "good")
	AudioDirector.play_ui("ui_confirm")
	refresh()
