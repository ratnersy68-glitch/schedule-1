class_name StorageScreen
extends GameScreen
## Two-column transfer between your pockets and a property's shelves.
##
## Also the place packaging is applied, because packaging is a storage-side
## decision: you wrap a batch before it leaves the building.

var property_id: String = ""
var _left: VBoxContainer
var _right: VBoxContainer
var _summary: Label


func _ready() -> void:
	property_id = String(payload.get("property", ""))
	super._ready()


func _property() -> PropertyState:
	return GameState.get_property(property_id)


func build_content() -> void:
	var prop := _property()
	set_titles("Storage", prop.display_name() if prop != null else "")

	_summary = UIKit.label("", 13, UIKit.TEXT_DIM)
	content.add_child(_summary)

	var quick := UIKit.hbox(8)
	var store_all := UIKit.button("Store all products")
	store_all.pressed.connect(_store_all)
	store_all.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	quick.add_child(store_all)
	var take_all := UIKit.button("Take all materials")
	take_all.pressed.connect(_take_all_materials)
	take_all.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	quick.add_child(take_all)
	content.add_child(quick)

	var columns := UIKit.hbox(12)
	content.add_child(columns)

	var left_col := UIKit.vbox(6)
	left_col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	left_col.add_child(UIKit.label("ON YOU", 12, UIKit.TEXT_FAINT))
	_left = UIKit.vbox(6)
	left_col.add_child(_left)
	columns.add_child(left_col)

	var right_col := UIKit.vbox(6)
	right_col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	right_col.add_child(UIKit.label("ON SITE", 12, UIKit.TEXT_FAINT))
	_right = UIKit.vbox(6)
	right_col.add_child(_right)
	columns.add_child(right_col)


func refresh() -> void:
	var prop := _property()
	if prop == null or _left == null:
		return
	_summary.text = "Pockets %d/%d slots   ·   Site %d/%d units" % [
		GameState.inventory.used_slots(), GameState.inventory.capacity,
		prop.stored_units(), prop.storage_capacity()]
	_fill(_left, GameState.inventory, prop.storage, true)
	_fill(_right, prop.storage, GameState.inventory, false)


func _fill(container: VBoxContainer, source: Inventory, target: Inventory,
		is_player: bool) -> void:
	for c in container.get_children():
		c.queue_free()
		container.remove_child(c)
	if source.stacks.is_empty():
		container.add_child(UIKit.label("Empty", 13, UIKit.TEXT_FAINT))
		return
	for i in source.stacks.size():
		var s: Dictionary = source.stacks[i]
		var item_id := String(s["item"])
		var qty := int(s["qty"])
		var quality := int(s["quality"])
		var pack := String(s["pack"])
		var sub := ""
		if GameData.item(item_id).get("category", "") == ItemDB.CAT_PRODUCT:
			sub = GameConfig.quality_name(quality)
			if pack != "":
				sub += " · " + GameData.item_name(pack)
		var row := UIKit.list_row(GameData.item_icon(item_id), GameData.item_color(item_id),
			"%s x%d" % [GameData.item_name(item_id), qty], sub,
			">>" if is_player else "<<", UIKit.ACCENT)
		var btn := Button.new()
		btn.flat = true
		btn.set_anchors_preset(Control.PRESET_FULL_RECT)
		var index := i
		btn.pressed.connect(func():
			source.transfer_slot(index, target, qty)
			AudioDirector.play_ui("ui_tap")
			refresh())
		row.add_child(btn)
		container.add_child(row)

		# Packaging controls live next to products sitting on the shelves.
		if not is_player and GameData.item(item_id).get("category", "") == ItemDB.CAT_PRODUCT:
			container.add_child(_packaging_row(source, i))


func _packaging_row(inv: Inventory, index: int) -> Control:
	var h := UIKit.hbox(6)
	h.add_child(UIKit.label("Wrap:", 12, UIKit.TEXT_FAINT))
	for pack_id in GameData.packaging_ids:
		var have := GameState.inventory.count(pack_id) + _property().storage.count(pack_id)
		var b := UIKit.icon_button(GameData.item_icon(pack_id), 42.0,
			GameData.item_color(pack_id))
		b.tooltip_text = "%s (+%d%% value, -%d%% heat) - have %d" % [
			GameData.item_name(pack_id),
			int(float(GameData.item(pack_id).get("value_bonus", 0.0)) * 100.0),
			int(float(GameData.item(pack_id).get("heat_reduction", 0.0)) * 100.0), have]
		b.disabled = have <= 0
		b.pressed.connect(func():
			var moved := inv.package_slot(index, pack_id, _property().storage)
			if moved == 0:
				moved = inv.package_slot(index, pack_id, GameState.inventory)
			if moved > 0:
				EventBus.toast_requested.emit("Packed %d units in %s" %
					[moved, GameData.item_name(pack_id)], "good")
			else:
				EventBus.toast_requested.emit("Not enough packaging", "warn")
			refresh())
		h.add_child(b)
	return h


func _store_all() -> void:
	var prop := _property()
	if prop == null:
		return
	var moved := 0
	for i in range(GameState.inventory.stacks.size() - 1, -1, -1):
		var s: Dictionary = GameState.inventory.stacks[i]
		if GameData.item(String(s["item"])).get("category", "") != ItemDB.CAT_PRODUCT:
			continue
		moved += GameState.inventory.transfer_slot(i, prop.storage, int(s["qty"]))
	EventBus.toast_requested.emit("Stored %d units" % moved, "info" if moved > 0 else "warn")
	refresh()


func _take_all_materials() -> void:
	var prop := _property()
	if prop == null:
		return
	var moved := 0
	for i in range(prop.storage.stacks.size() - 1, -1, -1):
		var s: Dictionary = prop.storage.stacks[i]
		if GameData.item(String(s["item"])).get("category", "") != ItemDB.CAT_MATERIAL:
			continue
		moved += prop.storage.transfer_slot(i, GameState.inventory, int(s["qty"]))
	EventBus.toast_requested.emit("Took %d units" % moved, "info" if moved > 0 else "warn")
	refresh()
