class_name DialogueScreen
extends GameScreen
## Runs a branching conversation with a named character.
##
## Dialogue actions hand off to the other screens (shop, hire, vehicles) rather
## than reimplementing them, so a conversation is a router with personality.

var npc_id: String = ""
var agent: NpcAgent = null
var node_id: String = "root"

var _tree: Dictionary = {}


func _ready() -> void:
	npc_id = String(payload.get("npc_id", ""))
	agent = payload.get("npc")
	_tree = GameData.dialogue.get(npc_id, {})
	MissionService.notify_talk(npc_id)
	super._ready()


func build_content() -> void:
	var npc: Dictionary = GameData.npc(npc_id)
	set_titles(String(npc.get("name", npc_id)), String(npc.get("blurb", "")))
	refresh()


func refresh() -> void:
	if content == null:
		return
	clear_content()
	var npc: Dictionary = GameData.npc(npc_id)

	var rel := GameState.relationship(npc_id)
	var rel_label := "Stranger"
	if rel > 60.0:
		rel_label = "Trusted"
	elif rel > 25.0:
		rel_label = "Friendly"
	elif rel < -20.0:
		rel_label = "Hostile"
	elif rel > 5.0:
		rel_label = "Known"
	content.add_child(UIKit.stat_line("Standing with them", rel_label,
		UIKit.GOOD if rel > 0.0 else UIKit.TEXT_DIM))

	var node: Dictionary = _tree.get(node_id, {})
	if node.is_empty():
		content.add_child(UIKit.body(String(npc.get("blurb", "They have nothing to say."))))
		var bye := UIKit.button("Leave")
		bye.pressed.connect(close)
		actions([bye] as Array[Button])
		return

	var speech := UIKit.panel(UIKit.BG_PANEL)
	var sv := UIKit.vbox(4)
	speech.add_child(sv)
	sv.add_child(UIKit.body(String(node.get("text", "")), 16))
	content.add_child(speech)

	# Anything an active job wants handed to this person.
	var deliveries := _pending_deliveries()
	if not deliveries.is_empty():
		section("Hand over")
		for delivery in deliveries:
			content.add_child(_delivery_row(delivery))

	# Offer any mission this character can hand out right now.
	var available := MissionService.missions_from(npc_id)
	if not available.is_empty():
		section("Work")
		for mid in available:
			content.add_child(_mission_offer(mid))

	section("Say")
	for option in node.get("options", []):
		var o: Dictionary = option
		if o.has("cond") and not MissionService.check_requirement(o["cond"]):
			continue
		var b := UIKit.button(String(o.get("label", "...")))
		b.pressed.connect(func(): _choose(o))
		content.add_child(b)


## Deliver objectives the player can satisfy right now with this character.
func _pending_deliveries() -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for mid in MissionService.active.keys():
		var idx := MissionService.current_objective_index(String(mid))
		if idx < 0:
			continue
		var o: Dictionary = GameData.mission(String(mid))["objectives"][idx]
		if String(o.get("type", "")) != "deliver":
			continue
		if String(o.get("npc", "")) != npc_id:
			continue
		var want := String(o.get("item", "any"))
		var min_quality := int(o.get("min_quality", 0))
		var needed := MissionService.objective_target(o) - MissionService.objective_progress(String(mid), idx)
		var have := 0
		if want == "any":
			have = GameState.inventory.count_any_product(min_quality)
		else:
			have = GameState.inventory.count_min_quality(want, min_quality)
		out.append({"mission": String(mid), "item": want, "min_quality": min_quality,
			"needed": needed, "have": have, "label": String(o.get("label", ""))})
	return out


func _delivery_row(delivery: Dictionary) -> Control:
	var row := UIKit.panel(UIKit.BG_PANEL)
	var v := UIKit.vbox(5)
	row.add_child(v)
	var want := String(delivery["item"])
	var item_label := "any product" if want == "any" else GameData.item_name(want)
	v.add_child(UIKit.label(String(delivery["label"]), 15, UIKit.WARN))
	v.add_child(UIKit.stat_line("Needed", "%d x %s" % [int(delivery["needed"]), item_label]))
	if int(delivery["min_quality"]) > 0:
		v.add_child(UIKit.stat_line("Minimum quality",
			GameConfig.quality_name(int(delivery["min_quality"])),
			GameConfig.quality_color(int(delivery["min_quality"]))))
	v.add_child(UIKit.stat_line("You are carrying", str(int(delivery["have"])),
		UIKit.GOOD if int(delivery["have"]) > 0 else UIKit.BAD))

	var can_give: int = mini(int(delivery["have"]), int(delivery["needed"]))
	var give := UIKit.button("Hand over %d" % can_give, "primary")
	give.disabled = can_give <= 0
	if can_give <= 0:
		give.text = "You do not have those on you"
	give.pressed.connect(func(): _hand_over(delivery, can_give))
	v.add_child(give)
	return row


func _hand_over(delivery: Dictionary, amount: int) -> void:
	var want := String(delivery["item"])
	var min_quality := int(delivery["min_quality"])
	var given := 0
	if want == "any":
		# Give the cheapest qualifying products first; the player keeps the good ones.
		for i in range(GameState.inventory.stacks.size() - 1, -1, -1):
			if given >= amount:
				break
			var stack: Dictionary = GameState.inventory.stacks[i]
			var item_id := String(stack["item"])
			if GameData.item(item_id).get("category", "") != ItemDB.CAT_PRODUCT:
				continue
			if int(stack["quality"]) < min_quality:
				continue
			var take: int = mini(int(stack["qty"]), amount - given)
			var quality := int(stack["quality"])
			GameState.inventory.remove(item_id, take, quality)
			MissionService.notify_deliver(npc_id, item_id, take, quality)
			given += take
	else:
		var quality := min_quality
		for stack in GameState.inventory.stacks:
			if String(stack["item"]) == want and int(stack["quality"]) >= min_quality:
				quality = int(stack["quality"])
				break
		given = GameState.inventory.remove(want, amount, min_quality)
		if given > 0:
			MissionService.notify_deliver(npc_id, want, given, quality)
	if given > 0:
		GameState.add_relationship(npc_id, 3.0 + given)
		AudioDirector.play_ui("ui_confirm")
		EventBus.toast_requested.emit("Handed over %d" % given, "good")
	refresh()


func _mission_offer(mission_id: String) -> Control:
	var m: Dictionary = GameData.mission(mission_id)
	var row := UIKit.panel(UIKit.BG_PANEL)
	var v := UIKit.vbox(6)
	row.add_child(v)
	var head := UIKit.hbox(8)
	var t := UIKit.label(String(m.get("title", mission_id)), 16, UIKit.WARN)
	t.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(t)
	head.add_child(UIKit.chip(String(m.get("kind", "job")).capitalize(), UIKit.ACCENT))
	v.add_child(head)
	v.add_child(UIKit.body(String(m.get("brief", ""))))
	var rewards: Dictionary = m.get("rewards", {})
	var reward_bits: Array[String] = []
	if int(rewards.get("cash", 0)) > 0:
		reward_bits.append(GameConfig.format_money(int(rewards["cash"])))
	if int(rewards.get("xp", 0)) > 0:
		reward_bits.append("%d XP" % int(rewards["xp"]))
	if rewards.has("unlock_recipe"):
		reward_bits.append("new recipe")
	if rewards.has("unlock_district"):
		reward_bits.append("new district")
	if not reward_bits.is_empty():
		v.add_child(UIKit.stat_line("Pays", " · ".join(reward_bits), UIKit.MONEY))
	var accept := UIKit.button("Take the job", "primary")
	accept.pressed.connect(func():
		MissionService.start(mission_id)
		AudioDirector.play_ui("ui_confirm")
		refresh())
	v.add_child(accept)
	return row


func _choose(option: Dictionary) -> void:
	AudioDirector.play_ui("ui_tap")
	var action := String(option.get("action", ""))
	match action:
		"end":
			close()
			return
		"shop":
			EventBus.screen_requested.emit("shop", {"npc_id": npc_id})
			return
		"bulk":
			EventBus.screen_requested.emit("bulk", {"npc_id": npc_id})
			return
		"hire":
			EventBus.screen_requested.emit("hire", {"npc_id": npc_id})
			return
		"vehicles":
			EventBus.screen_requested.emit("vehicles", {"npc_id": npc_id})
			return
		"teach":
			EventBus.screen_requested.emit("teach", {"npc_id": npc_id})
			return
		"sell":
			# Named characters can buy too: give the live agent a buyer profile
			# rather than conjuring a throwaway one.
			if agent != null and is_instance_valid(agent):
				if agent.customer == null:
					agent.customer = CustomerProfile.from_named(npc_id)
				EventBus.screen_requested.emit("deal", {"npc": agent})
			return
		"mission":
			node_id = "root"
			refresh()
			return
	if option.has("next"):
		node_id = String(option["next"])
		refresh()
	else:
		close()


func close() -> void:
	if agent != null and is_instance_valid(agent):
		agent.end_conversation()
	EventBus.dialogue_closed.emit()
	super.close()
