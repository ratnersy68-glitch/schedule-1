extends Control
## Title screen: continue, new game, load, settings.

var _content: VBoxContainer


func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	theme = UITheme.get_theme()
	_build()
	AudioDirector.set_music("music_calm", 1.5)


func _build() -> void:
	var bg := ColorRect.new()
	bg.color = UIKit.BG
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(bg)

	# A quiet skyline behind the menu, drawn from the same palette as the city.
	var skyline := MenuSkyline.new()
	skyline.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(skyline)

	# The skyline is atmosphere, not content: hold it back so type stays
	# readable over it wherever the buildings happen to fall.
	var scrim := ColorRect.new()
	scrim.set_anchors_preset(Control.PRESET_FULL_RECT)
	scrim.color = Color(UIKit.BG.r, UIKit.BG.g, UIKit.BG.b, 0.55)
	scrim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(scrim)

	var margin := MarginContainer.new()
	margin.set_anchors_preset(Control.PRESET_FULL_RECT)
	margin.add_theme_constant_override("margin_left", 46)
	margin.add_theme_constant_override("margin_right", 46)
	margin.add_theme_constant_override("margin_top", 40)
	margin.add_theme_constant_override("margin_bottom", 40)
	add_child(margin)

	var columns := UIKit.hbox(40)
	margin.add_child(columns)

	var left := UIKit.vbox(4)
	left.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	left.alignment = BoxContainer.ALIGNMENT_CENTER
	columns.add_child(left)
	left.add_child(UIKit.display(GameConfig.GAME_TITLE, 54, UIKit.ACCENT))
	left.add_child(UIKit.eyebrow(GameConfig.GAME_SUBTITLE, UIKit.TEXT_DIM))
	left.add_child(UIKit.spacer(14))
	var pitch := UIKit.body(
		"You have a hundred and forty in your pocket and a container on Pier 3 with your " +
		"name chalked on the side. The Bay runs on light nobody licensed. Somebody is going " +
		"to own that trade by the end of the year.", 15)
	pitch.custom_minimum_size = Vector2(360, 0)
	left.add_child(pitch)
	left.add_child(UIKit.spacer(10))
	left.add_child(UIKit.label("v" + str(ProjectSettings.get_setting("application/config/version", "0.1")),
		12, UIKit.TEXT_FAINT))

	var right_wrap := CenterContainer.new()
	right_wrap.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	columns.add_child(right_wrap)

	var card := UIKit.panel(Color(UIKit.SURFACE.r, UIKit.SURFACE.g, UIKit.SURFACE.b, 0.94))
	card.custom_minimum_size = Vector2(340, 0)
	right_wrap.add_child(card)

	var right := UIKit.vbox(10)
	card.add_child(right)
	_content = right
	_rebuild_buttons()


func _rebuild_buttons() -> void:
	for c in _content.get_children():
		_content.remove_child(c)
		c.queue_free()

	var recent := SaveService.most_recent_slot()
	if recent >= 0:
		var meta := SaveService.slot_summary(recent)
		var cont := UIKit.button("Continue", "primary")
		cont.pressed.connect(func(): SceneRouter.load_game(recent))
		_content.add_child(cont)
		_content.add_child(UIKit.label("%s · Day %d · Level %d · %s" %
			[SaveService.slot_label(recent), int(meta.get("day", 1)),
			int(meta.get("level", 1)), GameConfig.format_money(int(meta.get("net_worth", 0)))],
			12, UIKit.TEXT_FAINT, HORIZONTAL_ALIGNMENT_CENTER))

	var new_game := UIKit.button("New game", "primary" if recent < 0 else "default")
	new_game.pressed.connect(_confirm_new_game)
	_content.add_child(new_game)

	_content.add_child(UIKit.spacer(6))
	_content.add_child(UIKit.label("SAVES", 11, UIKit.TEXT_FAINT))
	for slot in range(0, GameConfig.MAX_SAVE_SLOTS + 1):
		_content.add_child(_slot_row(slot))

	_content.add_child(UIKit.spacer(6))
	var settings := UIKit.button("Settings")
	settings.pressed.connect(func(): EventBus.screen_requested.emit("settings", {}))
	_content.add_child(settings)

	if not OS.has_feature("web"):
		var quit := UIKit.button("Quit", "ghost")
		quit.pressed.connect(func(): get_tree().quit())
		_content.add_child(quit)


func _slot_row(slot: int) -> Control:
	var meta := SaveService.slot_summary(slot)
	var h := UIKit.hbox(6)
	var l := UIKit.label(SaveService.slot_label(slot) + ("  ·  empty" if meta.is_empty()
		else "  ·  Day %d" % int(meta.get("day", 1))), 13, UIKit.TEXT_DIM)
	l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	h.add_child(l)
	var load_btn := UIKit.button("Load")
	load_btn.disabled = meta.is_empty()
	load_btn.add_theme_font_size_override("font_size", 13)
	load_btn.pressed.connect(func(): SceneRouter.load_game(slot))
	h.add_child(load_btn)
	var del := UIKit.button("x", "ghost")
	del.disabled = meta.is_empty()
	del.custom_minimum_size = Vector2(44, 44)
	del.pressed.connect(func():
		SaveService.delete_slot(slot)
		_rebuild_buttons())
	h.add_child(del)
	return h


func _confirm_new_game() -> void:
	if not SaveService.has_any_save():
		SceneRouter.start_new_game()
		return
	var dialog := ConfirmationDialog.new()
	dialog.title = "New game"
	dialog.dialog_text = "Start over? Existing saves are kept, but the autosave will be overwritten as you play."
	dialog.confirmed.connect(func(): SceneRouter.start_new_game())
	add_child(dialog)
	dialog.popup_centered()
