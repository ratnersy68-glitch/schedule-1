class_name GameHud
extends Control
## The always-on heads-up display.
##
## Laid out as separate modules rather than one wide bar: a money pill and a
## time/place pill top-left, the heat meter and minimap top-right, vitals above
## the movement stick, the objective under the map, and a context card at the
## bottom centre. Grouping keeps each readout scannable at a glance on a phone
## without covering the middle of the screen, which is where the game is.

var minimap: Minimap = null

var _money_label: Label
var _bank_label: Label
var _clock_label: Label
var _district_label: Label
var _weather_label: Label
var _health_bar: ProgressBar
var _stamina_bar: ProgressBar
var _wanted_row: HBoxContainer
var _pips: Array[PanelContainer] = []
var _suspicion_bar: ProgressBar
var _suspicion_panel: Control
var _objective_panel: PanelContainer
var _objective_title: Label
var _objective_step: Label
var _objective_bar: ProgressBar
var _prompt_panel: PanelContainer
var _prompt_icon: IconRect
var _prompt_label: Label
var _prompt_sub: Label
var _toast_box: VBoxContainer
var _fps_label: Label
var _player: Node3D = null
var _clock_accum := 0.0


func _ready() -> void:
	UIKit.fill_viewport(self)
	theme = UITheme.get_theme()
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_build()
	_connect()
	_refresh_all()
	set_process(true)


# ===========================================================================
# CONSTRUCTION
# ===========================================================================

var _top_left: HBoxContainer


func _build() -> void:
	_top_left = UIKit.hbox(10)
	_top_left.mouse_filter = Control.MOUSE_FILTER_IGNORE
	UIKit.anchor_to(_top_left, "left", "top", Vector2(16, 14), Vector2(0, 0))
	add_child(_top_left)
	_build_money()
	_build_place()
	_build_heat()
	_build_minimap()
	_build_objective()
	_build_vitals()
	_build_prompt()
	_build_toasts()


## A floating card. Slightly translucent so the world still reads behind it.
func _card(alpha: float = 0.82) -> PanelContainer:
	var p := PanelContainer.new()
	var s := UIKit.panel_style(Color(UIKit.BG.r, UIKit.BG.g, UIKit.BG.b, alpha),
		UIKit.RADIUS_SM, UIKit.LINE_SOFT, 1)
	s.content_margin_left = 12
	s.content_margin_right = 12
	s.content_margin_top = 8
	s.content_margin_bottom = 8
	p.add_theme_stylebox_override("panel", s)
	p.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return p


func _build_money() -> void:
	var card := _card(0.86)
	_top_left.add_child(card)

	var h := UIKit.hbox(10)
	h.mouse_filter = Control.MOUSE_FILTER_IGNORE
	card.add_child(h)
	h.add_child(UIKit.icon_tile("money", UIKit.MONEY, 32.0))

	var col := UIKit.vbox(0)
	col.mouse_filter = Control.MOUSE_FILTER_IGNORE
	h.add_child(col)
	_money_label = UIKit.numeric("$0", 21, UIKit.MONEY, UITheme.W_BOLD)
	col.add_child(_money_label)
	_bank_label = UIKit.numeric("", 11, UIKit.TEXT_FAINT, UITheme.W_MEDIUM)
	col.add_child(_bank_label)


func _build_place() -> void:
	var card := _card(0.78)
	card.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	_top_left.add_child(card)

	var h := UIKit.hbox(9)
	h.mouse_filter = Control.MOUSE_FILTER_IGNORE
	card.add_child(h)

	_district_label = UIKit.label("Dockside", 13, UIKit.ACCENT)
	_district_label.add_theme_font_override("font", UITheme.font(UITheme.W_BOLD))
	h.add_child(_district_label)
	h.add_child(_dot())
	_clock_label = UIKit.numeric("D1  8:00 AM", 13, UIKit.TEXT_DIM, UITheme.W_MEDIUM)
	h.add_child(_clock_label)
	h.add_child(_dot())
	_weather_label = UIKit.label("", 13, UIKit.TEXT_DIM)
	h.add_child(_weather_label)

	_fps_label = UIKit.numeric("", 11, UIKit.TEXT_FAINT, UITheme.W_MEDIUM)
	h.add_child(_fps_label)


func _dot() -> Control:
	var c := ColorRect.new()
	c.color = UIKit.LINE
	c.custom_minimum_size = Vector2(1, 13)
	c.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	return c


func _build_heat() -> void:
	var card := _card(0.78)
	UIKit.anchor_to(card, "right", "top", Vector2(16, 14), Vector2(0, 0))
	add_child(card)

	var h := UIKit.hbox(8)
	h.mouse_filter = Control.MOUSE_FILTER_IGNORE
	card.add_child(h)
	h.add_child(UIKit.eyebrow("Heat"))

	_wanted_row = UIKit.hbox(3)
	_wanted_row.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	h.add_child(_wanted_row)
	for i in 4:
		var pip := PanelContainer.new()
		pip.custom_minimum_size = Vector2(16, 7)
		pip.add_theme_stylebox_override("panel", UIKit.flat_style(
			Color(UIKit.TEXT_FAINT.r, UIKit.TEXT_FAINT.g, UIKit.TEXT_FAINT.b, 0.22), 3))
		_wanted_row.add_child(pip)
		_pips.append(pip)


func _build_minimap() -> void:
	var frame := PanelContainer.new()
	var s := UIKit.panel_style(UIKit.BG, UIKit.RADIUS_SM, UIKit.LINE, 1)
	s.content_margin_left = 2
	s.content_margin_right = 2
	s.content_margin_top = 2
	s.content_margin_bottom = 2
	frame.add_theme_stylebox_override("panel", s)
	frame.mouse_filter = Control.MOUSE_FILTER_IGNORE
	UIKit.anchor_to(frame, "right", "top", Vector2(16, 54), Vector2(138, 138))
	add_child(frame)

	minimap = Minimap.new()
	minimap.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	minimap.size_flags_vertical = Control.SIZE_EXPAND_FILL
	frame.add_child(minimap)


func _build_objective() -> void:
	_objective_panel = PanelContainer.new()
	var s := UIKit.panel_style(Color(UIKit.BG.r, UIKit.BG.g, UIKit.BG.b, 0.86),
		UIKit.RADIUS_SM, UIKit.LINE_SOFT, 1)
	s.content_margin_left = 13
	s.content_margin_right = 13
	s.content_margin_top = 9
	s.content_margin_bottom = 9
	# An accent edge marks it as the thing you are meant to be doing.
	s.border_width_left = 3
	s.border_color = UIKit.WARN
	_objective_panel.add_theme_stylebox_override("panel", s)
	_objective_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	UIKit.anchor_to(_objective_panel, "right", "top", Vector2(16, 200), Vector2(252, 0))
	add_child(_objective_panel)

	var v := UIKit.vbox(4)
	v.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_objective_panel.add_child(v)
	_objective_title = UIKit.eyebrow("", UIKit.WARN)
	v.add_child(_objective_title)
	_objective_step = UIKit.label("", 14, UIKit.TEXT)
	_objective_step.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	v.add_child(_objective_step)
	_objective_bar = UIKit.progress(0.0, UIKit.WARN, 4.0)
	v.add_child(_objective_bar)
	_objective_panel.visible = false


func _build_vitals() -> void:
	var card := _card(0.7)
	UIKit.anchor_to(card, "left", "bottom", Vector2(24, 200), Vector2(210, 0))
	add_child(card)

	var v := UIKit.vbox(7)
	v.mouse_filter = Control.MOUSE_FILTER_IGNORE
	card.add_child(v)

	_health_bar = UIKit.progress(1.0, UIKit.BAD, 7.0)
	v.add_child(_vital_row("patch", UIKit.BAD, _health_bar))
	_stamina_bar = UIKit.progress(1.0, UIKit.GOOD, 7.0)
	v.add_child(_vital_row("run", UIKit.GOOD, _stamina_bar))

	_suspicion_panel = UIKit.vbox(3)
	_suspicion_panel.modulate.a = 0.0
	_suspicion_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	v.add_child(_suspicion_panel)
	_suspicion_panel.add_child(UIKit.eyebrow("Suspicion", UIKit.WARN))
	_suspicion_bar = UIKit.progress(0.0, UIKit.WARN, 5.0)
	_suspicion_panel.add_child(_suspicion_bar)


func _vital_row(icon: String, tint: Color, bar: ProgressBar) -> Control:
	var h := UIKit.hbox(8)
	h.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var i := IconRect.create(icon, 13.0, Color(tint.r, tint.g, tint.b, 0.85))
	i.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	h.add_child(i)
	bar.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	bar.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	h.add_child(bar)
	return h


func _build_prompt() -> void:
	_prompt_panel = _card(0.92)
	UIKit.anchor_to(_prompt_panel, "center", "bottom", Vector2(0, 172), Vector2(330, 0))
	add_child(_prompt_panel)

	var h := UIKit.hbox(11)
	h.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_prompt_panel.add_child(h)
	_prompt_icon = IconRect.create("use", 26.0, UIKit.ACCENT)
	_prompt_icon.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	h.add_child(_prompt_icon)

	var v := UIKit.vbox(1)
	v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	v.mouse_filter = Control.MOUSE_FILTER_IGNORE
	h.add_child(v)
	_prompt_label = UIKit.label("", 15, UIKit.TEXT)
	_prompt_label.add_theme_font_override("font", UITheme.font(UITheme.W_SEMIBOLD))
	v.add_child(_prompt_label)
	_prompt_sub = UIKit.label("", 12, UIKit.TEXT_DIM)
	v.add_child(_prompt_sub)
	_prompt_panel.visible = false


func _build_toasts() -> void:
	_toast_box = UIKit.vbox(7)
	UIKit.anchor_to(_toast_box, "center", "top", Vector2(0, 22), Vector2(400, 0))
	_toast_box.alignment = BoxContainer.ALIGNMENT_BEGIN
	_toast_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_toast_box)


# ===========================================================================
# SIGNALS
# ===========================================================================

func _connect() -> void:
	EventBus.cash_changed.connect(func(_c, _d): _refresh_money())
	EventBus.bank_changed.connect(func(_b, _d): _refresh_money())
	EventBus.player_health_changed.connect(func(c, m): _health_bar.value = c / m)
	EventBus.player_stamina_changed.connect(func(c, m): _stamina_bar.value = c / m)
	EventBus.suspicion_changed.connect(_on_suspicion_changed)
	EventBus.wanted_level_changed.connect(_on_wanted_changed)
	EventBus.player_entered_district.connect(func(d): _district_label.text = GameData.district_name(d))
	EventBus.weather_changed.connect(_on_weather_changed)
	EventBus.toast_requested.connect(_on_toast)
	EventBus.mission_started.connect(func(_m): _refresh_objective())
	EventBus.mission_completed.connect(func(_m): _refresh_objective())
	EventBus.mission_objective_updated.connect(func(_m, _i, _p, _t): _refresh_objective())
	EventBus.interaction_target_changed.connect(_on_interaction_target)
	EventBus.player_spawned.connect(func(p):
		_player = p
		minimap.player = p)


func _process(delta: float) -> void:
	_clock_accum += delta
	if _clock_accum < 0.25:
		return
	_clock_accum = 0.0
	_clock_label.text = "D%d  %s" % [GameState.day, GameConfig.format_clock(GameState.hour)]
	if bool(SettingsService.get_value("graphics", "show_fps", false)):
		_fps_label.text = "%d" % Engine.get_frames_per_second()
	elif _fps_label.text != "":
		_fps_label.text = ""
	minimap.get_parent().visible = bool(SettingsService.get_value("gameplay", "minimap", true))
	_refresh_objective()


# ===========================================================================
# REFRESH
# ===========================================================================

func _refresh_all() -> void:
	_refresh_money()
	_district_label.text = GameData.district_name(GameState.current_district)
	_on_weather_changed(GameState.weather)
	_refresh_objective()


func _refresh_money() -> void:
	_money_label.text = GameConfig.format_money(GameState.cash)
	_bank_label.text = ("banked " + GameConfig.format_money(GameState.bank)) \
		if GameState.bank != 0 else ""


func _on_weather_changed(weather_id: String) -> void:
	_weather_label.text = String(weather_id).capitalize()


func _on_suspicion_changed(value: float) -> void:
	_suspicion_bar.value = value / GameConfig.SUSPICION_MAX
	var target := 1.0 if value > 1.0 else 0.0
	if absf(_suspicion_panel.modulate.a - target) > 0.01:
		create_tween().tween_property(_suspicion_panel, "modulate:a", target, 0.3)


func _on_wanted_changed(level: int) -> void:
	for i in _pips.size():
		var lit := i < level
		_pips[i].add_theme_stylebox_override("panel", UIKit.flat_style(
			UIKit.BAD if lit else Color(UIKit.TEXT_FAINT.r, UIKit.TEXT_FAINT.g,
				UIKit.TEXT_FAINT.b, 0.22), 3))
	if level > 0:
		var t := create_tween()
		t.tween_property(_wanted_row, "modulate", Color(1.6, 1.6, 1.6), 0.1)
		t.tween_property(_wanted_row, "modulate", Color.WHITE, 0.25)


func _refresh_objective() -> void:
	var mid := MissionService.tracked_mission
	if mid == "" and not MissionService.active.is_empty():
		mid = MissionService.active.keys()[0]
		MissionService.tracked_mission = mid
	if mid == "" or not MissionService.is_active(mid):
		_objective_panel.visible = false
		minimap.has_objective = false
		return
	var mission: Dictionary = GameData.mission(mid)
	var idx := MissionService.current_objective_index(mid)
	if idx < 0:
		_objective_panel.visible = false
		return
	var obj: Dictionary = mission["objectives"][idx]
	var target := MissionService.objective_target(obj)
	var progress := MissionService.objective_progress(mid, idx)
	_objective_title.text = String(mission.get("title", "")).to_upper()
	_objective_step.text = String(obj.get("label", "Objective"))
	if target > 1:
		_objective_bar.visible = true
		_objective_bar.value = float(progress) / float(target)
		_objective_step.text += "   %d/%d" % [progress, target]
	else:
		_objective_bar.visible = false
	_objective_panel.visible = true

	minimap.has_objective = false
	if obj.has("poi") and GameData.has_poi(String(obj["poi"])):
		minimap.objective_pos = GameData.poi_position(String(obj["poi"]))
		minimap.has_objective = true
	elif obj.has("npc"):
		var n: Dictionary = GameData.npc(String(obj["npc"]))
		if not n.is_empty():
			var sched := NpcSchedule.new(n.get("schedule", []))
			var poi := sched.current_poi(GameState.hour)
			if GameData.has_poi(poi):
				minimap.objective_pos = GameData.poi_position(poi)
				minimap.has_objective = true
	elif obj.has("property"):
		var pdef: Dictionary = GameData.property(String(obj["property"]))
		if not pdef.is_empty():
			minimap.objective_pos = pdef["position"]
			minimap.has_objective = true


func _on_interaction_target(payload: Dictionary) -> void:
	if payload.is_empty():
		_prompt_panel.visible = false
		return
	var was_hidden := not _prompt_panel.visible
	_prompt_panel.visible = true
	_prompt_icon.icon_name = String(payload.get("icon", "use"))
	_prompt_label.text = String(payload.get("prompt", ""))
	var enabled := bool(payload.get("enabled", true))
	var sub := String(payload.get("subtitle", ""))
	if not enabled:
		sub = String(payload.get("reason", sub))
	_prompt_icon.color = UIKit.ACCENT if enabled else UIKit.TEXT_FAINT
	_prompt_label.add_theme_color_override("font_color",
		UIKit.TEXT if enabled else UIKit.TEXT_FAINT)
	_prompt_sub.text = sub
	_prompt_sub.visible = sub != ""
	if was_hidden:
		_prompt_panel.modulate.a = 0.0
		create_tween().tween_property(_prompt_panel, "modulate:a", 1.0, 0.12)


# ===========================================================================
# TOASTS
# ===========================================================================

const TOAST_ICONS := {
	"good": "check", "bad": "warning", "warn": "warning",
	"money": "money", "info": "chevron",
}


func _on_toast(text: String, kind: String) -> void:
	var color := UIKit.color_for_kind(kind)
	var panel := PanelContainer.new()
	var style := UIKit.panel_style(Color(UIKit.SURFACE.r, UIKit.SURFACE.g,
		UIKit.SURFACE.b, 0.96), UIKit.RADIUS_SM, UIKit.LINE_SOFT, 1)
	style.border_width_left = 3
	style.border_color = color
	style.content_margin_top = 9
	style.content_margin_bottom = 9
	style.content_margin_left = 12
	panel.add_theme_stylebox_override("panel", style)
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.modulate.a = 0.0

	var h := UIKit.hbox(10)
	h.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.add_child(h)
	var icon := IconRect.create(String(TOAST_ICONS.get(kind, "chevron")), 17.0, color)
	icon.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	h.add_child(icon)
	var l := UIKit.label(text, 14, UIKit.TEXT)
	l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	h.add_child(l)
	_toast_box.add_child(panel)

	while _toast_box.get_child_count() > 4:
		var oldest := _toast_box.get_child(0)
		_toast_box.remove_child(oldest)
		oldest.queue_free()

	var t := create_tween()
	t.tween_property(panel, "modulate:a", 1.0, 0.16)
	t.tween_interval(2.7)
	t.tween_property(panel, "modulate:a", 0.0, 0.5)
	t.tween_callback(panel.queue_free)

	if kind == "good" or kind == "money":
		AudioDirector.play_ui("notify")
	elif kind == "bad":
		AudioDirector.play_ui("ui_error")
