class_name Phone
extends Control
## The player's in-game smartphone.
##
## Slides in from the bottom-right, has a home screen of app icons with unread
## badges, and hosts every out-of-world management task. Opening it disables
## world input so a thumb on the phone never also drives the player.

const APP_CLASSES := ["map", "contacts", "messages", "jobs", "business", "bank",
	"empire", "news", "inventory", "settings"]

var is_open := false

var _frame: PanelContainer
var _status_time: Label
var _status_signal: Label
var _title: Label
var _back: Button
var _content: VBoxContainer
var _scroll: ScrollContainer
var _home_grid: GridContainer
var _apps: Dictionary = {}
var _current: String = ""
var _tick := 0.0


func _ready() -> void:
	UIKit.fill_viewport(self)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_register_apps()
	_build()
	visible = false
	EventBus.phone_notification.connect(_on_notification)
	set_process(true)


func _register_apps() -> void:
	_add_app(AppMap.new())
	_add_app(AppContacts.new())
	_add_app(AppMessages.new())
	_add_app(AppJobs.new())
	_add_app(AppBusiness.new())
	_add_app(AppBank.new())
	_add_app(AppEmpire.new())
	_add_app(AppNews.new())


func _add_app(app: PhoneApp) -> void:
	app.phone = self
	_apps[app.id] = app


# ===========================================================================
# CONSTRUCTION
# ===========================================================================

func _build() -> void:
	_frame = PanelContainer.new()
	var style := UIKit.panel_style(UIKit.BG_RAISED, 22, UIKit.LINE, 2)
	style.content_margin_left = 12
	style.content_margin_right = 12
	style.content_margin_top = 10
	style.content_margin_bottom = 12
	style.shadow_size = 18
	style.shadow_color = Color(0, 0, 0, 0.5)
	_frame.add_theme_stylebox_override("panel", style)
	_frame.custom_minimum_size = Vector2(348, 560)
	UIKit.anchor_to(_frame, "right", "bottom", Vector2(22, 20), Vector2(348, 560))
	_frame.pivot_offset = Vector2(174, 560)
	_frame.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(_frame)

	var column := UIKit.vbox(8)
	_frame.add_child(column)

	# Status bar.
	var status := UIKit.hbox(8)
	_status_time = UIKit.label("8:00 AM", 12, UIKit.TEXT_DIM)
	status.add_child(_status_time)
	var spacer := Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	status.add_child(spacer)
	_status_signal = UIKit.label("LTE  D1", 12, UIKit.TEXT_DIM)
	status.add_child(_status_signal)
	column.add_child(status)

	# Title row with back button.
	var head := UIKit.hbox(8)
	_back = UIKit.icon_button("<", 38.0)
	_back.pressed.connect(go_home)
	_back.visible = false
	head.add_child(_back)
	_title = UIKit.title("Underlight OS", 19)
	_title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(_title)
	var close_btn := UIKit.icon_button("X", 38.0)
	close_btn.pressed.connect(close)
	head.add_child(close_btn)
	column.add_child(head)
	column.add_child(UIKit.separator())

	_scroll = UIKit.scroll()
	_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	column.add_child(_scroll)

	_content = UIKit.vbox(8)
	_content.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_scroll.add_child(_content)

	_build_home()


func _build_home() -> void:
	_home_grid = GridContainer.new()
	_home_grid.columns = 4
	_home_grid.add_theme_constant_override("h_separation", 10)
	_home_grid.add_theme_constant_override("v_separation", 12)


func _populate_home() -> void:
	for c in _home_grid.get_children():
		_home_grid.remove_child(c)
		c.queue_free()
	for app_id in APP_CLASSES:
		_home_grid.add_child(_app_icon(String(app_id)))


func _app_icon(app_id: String) -> Control:
	var glyph := "AP"
	var title := app_id.capitalize()
	var accent := UIKit.ACCENT
	var badge := 0
	if _apps.has(app_id):
		var app: PhoneApp = _apps[app_id]
		glyph = app.glyph
		title = app.title
		accent = app.accent
		badge = app.badge_count()
	elif app_id == "inventory":
		glyph = "BAG"
		title = "Pockets"
		accent = UIKit.GOOD
	elif app_id == "settings":
		glyph = "SET"
		title = "Settings"
		accent = UIKit.TEXT_DIM

	var holder := UIKit.vbox(4)
	var btn := Button.new()
	btn.custom_minimum_size = Vector2(66, 66)
	btn.text = glyph
	btn.add_theme_font_size_override("font_size", 19)
	btn.add_theme_color_override("font_color", accent)
	btn.add_theme_stylebox_override("normal", UIKit.flat_style(accent.darkened(0.62), 16))
	btn.add_theme_stylebox_override("hover", UIKit.flat_style(accent.darkened(0.5), 16))
	btn.add_theme_stylebox_override("pressed", UIKit.flat_style(accent.darkened(0.72), 16))
	btn.pressed.connect(func(): open_app(app_id))
	holder.add_child(btn)
	var l := UIKit.label(title, 11, UIKit.TEXT_DIM, HORIZONTAL_ALIGNMENT_CENTER)
	holder.add_child(l)

	if badge > 0:
		var badge_label := UIKit.label(str(badge), 11, UIKit.BAD, HORIZONTAL_ALIGNMENT_CENTER)
		holder.add_child(badge_label)
	return holder


# ===========================================================================
# NAVIGATION
# ===========================================================================

func toggle() -> void:
	if is_open:
		close()
	else:
		open()


func open() -> void:
	if is_open:
		return
	is_open = true
	visible = true
	go_home()
	PlayerInput.set_gameplay_enabled(false)
	EventBus.phone_toggled.emit(true)
	AudioDirector.play_ui("ui_tap")
	_frame.modulate.a = 0.0
	_frame.scale = Vector2(0.94, 0.88)
	var t := create_tween().set_parallel(true)
	t.tween_property(_frame, "modulate:a", 1.0, 0.14)
	t.tween_property(_frame, "scale", Vector2.ONE, 0.22).set_trans(Tween.TRANS_BACK)


func close() -> void:
	if not is_open:
		return
	is_open = false
	PlayerInput.set_gameplay_enabled(true)
	EventBus.phone_toggled.emit(false)
	AudioDirector.play_ui("ui_cancel")
	var t := create_tween()
	t.tween_property(_frame, "scale", Vector2(0.94, 0.88), 0.16)
	t.parallel().tween_property(_frame, "modulate:a", 0.0, 0.16)
	t.tween_callback(func(): visible = false)


func go_home() -> void:
	_current = ""
	_title.text = "Underlight OS"
	_back.visible = false
	_clear_content()
	_populate_home()
	_content.add_child(_home_grid)
	_content.add_child(UIKit.spacer(6))
	_content.add_child(_status_card())


func _status_card() -> Control:
	var panel := UIKit.panel(UIKit.BG_PANEL)
	var v := UIKit.vbox(4)
	panel.add_child(v)
	v.add_child(UIKit.stat_line("Cash", GameConfig.format_money(GameState.cash), UIKit.MONEY))
	v.add_child(UIKit.stat_line("Bank", GameConfig.format_money(GameState.bank), UIKit.MONEY))
	v.add_child(UIKit.stat_line("Level", "%d" % GameState.level, UIKit.ACCENT))
	v.add_child(UIKit.progress(GameState.xp_progress(), UIKit.ACCENT, 5.0))
	v.add_child(UIKit.stat_line("Location",
		GameData.district_name(GameState.current_district)))
	if GameState.skill_points > 0:
		var skills := UIKit.button("%d skill point%s to spend" %
			[GameState.skill_points, "" if GameState.skill_points == 1 else "s"], "primary")
		skills.pressed.connect(func():
			close()
			EventBus.screen_requested.emit("skills", {}))
		v.add_child(skills)
	return panel


func open_app(app_id: String) -> void:
	AudioDirector.play_ui("ui_tap")
	# Two apps are really full screens; route rather than duplicate them.
	if app_id == "inventory":
		close()
		EventBus.screen_requested.emit("inventory", {})
		return
	if app_id == "settings":
		close()
		EventBus.screen_requested.emit("settings", {})
		return
	if not _apps.has(app_id):
		return
	_current = app_id
	var app: PhoneApp = _apps[app_id]
	_title.text = app.title
	_back.visible = true
	_clear_content()
	app.build(_content)


func refresh_current() -> void:
	if _current == "":
		go_home()
	else:
		open_app(_current)


func _clear_content() -> void:
	for c in _content.get_children():
		_content.remove_child(c)
		if c != _home_grid:
			c.queue_free()


func _on_notification(app_id: String, title: String, body: String) -> void:
	AppMessages.push(app_id, title, body)
	AudioDirector.play_ui("notify")


func _process(delta: float) -> void:
	if not is_open:
		return
	_tick += delta
	if _tick < 0.5:
		return
	_tick = 0.0
	_status_time.text = GameConfig.format_clock(GameState.hour)
	var bars := "LTE"
	if EnforcementService.wanted_level > 0:
		bars = "SOS"
	_status_signal.text = "%s  D%d" % [bars, GameState.day]


func _unhandled_input(event: InputEvent) -> void:
	if not is_open:
		return
	if event.is_action_pressed("pause_menu") or event.is_action_pressed("toggle_phone"):
		close()
		get_viewport().set_input_as_handled()
