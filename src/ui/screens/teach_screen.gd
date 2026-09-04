class_name TeachScreen
extends GameScreen
## Odette Sang teaching lattices, paid for in cash and standing.

var npc_id: String = ""


func _ready() -> void:
	npc_id = String(payload.get("npc_id", "odette_sang"))
	super._ready()


func build_content() -> void:
	set_titles("Lattice Tuition", GameData.npc_name(npc_id))
	refresh()


func refresh() -> void:
	if content == null:
		return
	clear_content()
	var teaches: Array = GameData.npc(npc_id).get("teaches_recipes", [])
	if teaches.is_empty():
		content.add_child(UIKit.body("They have nothing to teach you."))
		return
	content.add_child(UIKit.stat_line("Standing with them",
		"%d" % int(GameState.relationship(npc_id))))

	for recipe_id in teaches:
		content.add_child(_recipe_row(String(recipe_id)))


func _recipe_row(recipe_id: String) -> Control:
	var r: Dictionary = GameData.recipe(recipe_id)
	var known := GameState.knows_recipe(recipe_id)
	var out_id := String(r.get("output", ""))
	var price := int(GameData.item_value(out_id) * 14)
	var required_rel := float(GameData.item(out_id).get("tier", 1)) * 12.0

	var row := UIKit.panel(UIKit.BG_PANEL)
	var v := UIKit.vbox(6)
	row.add_child(v)

	var head := UIKit.hbox(8)
	head.add_child(UIKit.icon_tile(GameData.item_icon(out_id), GameData.item_color(out_id), 32.0))
	var n := UIKit.label(String(r.get("name", recipe_id)), 16)
	n.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(n)
	if known:
		head.add_child(UIKit.chip("Learned", UIKit.GOOD))
	else:
		head.add_child(UIKit.label(GameConfig.format_money(price), 16, UIKit.MONEY))
	v.add_child(head)
	v.add_child(UIKit.body(String(r.get("desc", ""))))

	if not known:
		var rel := GameState.relationship(npc_id)
		var learn := UIKit.button("Learn", "primary")
		if rel < required_rel:
			learn.disabled = true
			learn.text = "She needs to trust you more (%d/%d)" % [int(rel), int(required_rel)]
		elif not GameState.can_afford(price):
			learn.disabled = true
			learn.text = "Need " + GameConfig.format_money(price)
		learn.pressed.connect(func():
			if GameState.spend(price, "Tuition: " + String(r.get("name", recipe_id))):
				GameState.unlock_recipe(recipe_id)
				GameState.add_relationship(npc_id, 5.0)
				AudioDirector.play_ui("ui_confirm")
				refresh())
		v.add_child(learn)
	return row
