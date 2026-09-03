class_name PauseScreen
extends GameScreen
## Pause menu: save, load, settings, quit.


func _ready() -> void:
	get_tree().paused = true
	super._ready()


func build_content() -> void:
	set_titles(GameConfig.GAME_TITLE, GameConfig.GAME_SUBTITLE)
	refresh()


func refresh() -> void:
	if content == null:
		return
	clear_content()

	var summary := UIKit.panel(UIKit.BG_PANEL)
	var v := UIKit.vbox(4)
	summary.add_child(v)
	v.add_child(UIKit.stat_line("Day", "%d, %s" %
		[GameState.day, GameConfig.format_clock(GameState.hour)]))
	v.add_child(UIKit.stat_line("Cash", GameConfig.format_money(GameState.cash), UIKit.MONEY))
	v.add_child(UIKit.stat_line("Bank", GameConfig.format_money(GameState.bank), UIKit.MONEY))
	v.add_child(UIKit.stat_line("Net worth", GameConfig.format_money(GameState.net_worth()), UIKit.MONEY))
	v.add_child(UIKit.stat_line("Level", str(GameState.level), UIKit.ACCENT))
	v.add_child(UIKit.stat_line("Properties", str(GameState.owned_property_count())))
	v.add_child(UIKit.stat_line("Played", _format_time(GameState.play_seconds)))
	content.add_child(summary)

	var resume := UIKit.button("Resume", "primary")
	resume.pressed.connect(close)
	content.add_child(resume)

	section("Save")
	for slot in range(1, GameConfig.MAX_SAVE_SLOTS + 1):
		content.add_child(_slot_row(slot))
	content.add_child(_slot_row(GameConfig.AUTOSAVE_SLOT))

	section("Other")
	var settings := UIKit.button("Settings")
	settings.pressed.connect(func(): EventBus.screen_requested.emit("settings", {}))
	content.add_child(settings)

	var skills := UIKit.button("Skills")
	skills.pressed.connect(func(): EventBus.screen_requested.emit("skills", {}))
	content.add_child(skills)

	var quit := UIKit.button("Save and quit to menu", "bad")
	quit.pressed.connect(func():
		SaveService.save_game(GameConfig.AUTOSAVE_SLOT, true)
		get_tree().paused = false
		SceneRouter.quit_to_menu())
	content.add_child(quit)


func _slot_row(slot: int) -> Control:
	var meta := SaveService.slot_summary(slot)
	var row := UIKit.panel(UIKit.BG_PANEL)
	var h := UIKit.hbox(8)
	row.add_child(h)

	var texts := UIKit.vbox(2)
	texts.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	texts.add_child(UIKit.label(SaveService.slot_label(slot), 15))
	if meta.is_empty():
		texts.add_child(UIKit.label("Empty", 12, UIKit.TEXT_FAINT))
	else:
		texts.add_child(UIKit.label("Day %d · Level %d · %s · %s" %
			[int(meta.get("day", 1)), int(meta.get("level", 1)),
			GameConfig.format_money(int(meta.get("net_worth", 0))),
			String(meta.get("date", ""))], 12, UIKit.TEXT_DIM))
	h.add_child(texts)

	if slot != GameConfig.AUTOSAVE_SLOT:
		var save := UIKit.button("Save")
		save.pressed.connect(func():
			SaveService.save_game(slot)
			refresh())
		h.add_child(save)
	var load_btn := UIKit.button("Load")
	load_btn.disabled = meta.is_empty()
	load_btn.pressed.connect(func():
		get_tree().paused = false
		SceneRouter.load_game(slot))
	h.add_child(load_btn)
	return row


func _format_time(seconds: float) -> String:
	var total := int(seconds)
	return "%dh %02dm" % [total / 3600, (total % 3600) / 60]


func close() -> void:
	get_tree().paused = false
	super.close()
