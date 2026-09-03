class_name GameHud
extends Control
## The always-on heads-up display.
##
## Kept deliberately sparse: a status strip along the top, vitals bottom-left
## above the stick, the objective under the minimap, and a context prompt in
## the lower middle. Everything else lives in the phone.

var minimap: Minimap = null

var _money_label: Label
var _clock_label: Label
var _district_label: Label
var _health_bar: ProgressBar
var _stamina_bar: ProgressBar
var _wanted_row: HBoxContainer
var _suspicion_bar: ProgressBar
var _suspicion_panel: Control
var _objective_panel: PanelContainer
var _objective_title: Label
var _objective_step: Label
var _prompt_panel: PanelContainer
var _prompt_icon: Label
var _prompt_label: Label
var _prompt_sub: Label
var _toast_box: VBoxContainer
var _fps_label: Label
var _weather_label: Label
var _stars: Array[Label] = []
var _player: Node3D = null
var _clock_accum := 0.0


func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_build()
	_connect()
	_refresh_all()
	set_process(true)


# ===========================================================================
# CONSTRUCTION
# ===========================================================================

func _build() -> void:
	_build_top_bar()
	_build_minimap()
	_build_vitals()
	_build_objective()
	_build_prompt()
	_build_toasts()


func _build_top_bar() -> void:
	var bar := UIKit.panel(Color(UIKit.BG.r, UIKit.BG.g, UIKit.BG.b, 0.72))
	bar.set_anchors_preset(Control.PRESET_TOP_WIDE)
	bar.offset_left = 14
	bar.offset_right = -14
	bar.offset_top = 12
	bar.custom_minimum_size = Vector2(0, 44)
	bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(bar)

	var h := UIKit.hbox(14)
	h.mouse_filter = Control.MOUSE_FILTER_IGNORE
	bar.add_child(h)

	_money_label = UIKit.label("$0", 20, UIKit.MONEY)
	h.add_child(_money_label)

	h.add_child(_vsep())

	_clock_label = UIKit.label("Day 1  8:00 AM", 15, UIKit.TEXT)
	h.add_child(_clock_label)

	_weather_label = UIKit.label("", 15, UIKit.TEXT_DIM)
	h.add_child(_weather_label)

	h.add_child(_vsep())

	_district_label = UIKit.label("Dockside", 15, UIKit.ACCENT)
	_district_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	h.add_child(_district_label)

	_wanted_row = UIKit.hbox(3)
	h.add_child(_wanted_row)
	for i in 4:
		var star := UIKit.label("★", 18, Color(UIKit.TEXT_FAINT.r, UIKit.TEXT_FAINT.g,
			UIKit.TEXT_FAINT.b, 0.25))
		_wanted_row.add_child(star)
		_stars.append(star)

	_fps_label = UIKit.label("", 12, UIKit.TEXT_FAINT)
	h.add_child(_fps_label)


func _vsep() -> Control:
	var c := ColorRect.new()
	c.color = UIKit.LINE
	c.custom_minimum_size = Vector2(1, 20)
	return c


func _build_minimap() -> void:
	var holder := Control.new()
	holder.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	holder.position = Vector2(-160, 66)
	holder.custom_minimum_size = Vector2(132, 132)
	holder.size = Vector2(132, 132)
	holder.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(holder)

	minimap = Minimap.new()
	minimap.size = Vector2(132, 132)
	holder.add_child(minimap)


func _build_vitals() -> void:
	var box := UIKit.vbox(6)
	box.set_anchors_preset(Control.PRESET_BOTTOM_LEFT)
	box.position = Vector2(24, -230)
	box.custom_minimum_size = Vector2(190, 0)
	box.size = Vector2(190, 70)
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(box)

	_health_bar = UIKit.progress(1.0, UIKit.BAD, 9.0)
	_health_bar.custom_minimum_size = Vector2(190, 9)
	box.add_child(_health_bar)

	_stamina_bar = UIKit.progress(1.0, UIKit.GOOD, 6.0)
	_stamina_bar.custom_minimum_size = Vector2(190, 6)
	box.add_child(_stamina_bar)

	_suspicion_panel = UIKit.vbox(2)
	_suspicion_panel.modulate.a = 0.0
	box.add_child(_suspicion_panel)
	_suspicion_panel.add_child(UIKit.label("SUSPICION", 10, UIKit.WARN))
	_suspicion_bar = UIKit.progress(0.0, UIKit.WARN, 6.0)
	_suspicion_bar.custom_minimum_size = Vector2(190, 6)
	_suspicion_panel.add_child(_suspicion_bar)


func _build_objective() -> void:
	_objective_panel = UIKit.panel(Color(UIKit.BG.r, UIKit.BG.g, UIKit.BG.b, 0.72))
	_objective_panel.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	_objective_panel.position = Vector2(-268, 206)
	_objective_panel.custom_minimum_size = Vector2(244, 0)
	_objective_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_objective_panel)

	var v := UIKit.vbox(3)
	v.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_objective_panel.add_child(v)
	_objective_title = UIKit.label("", 13, UIKit.WARN)
	v.add_child(_objective_title)
	_objective_step = UIKit.label("", 15, UIKit.TEXT)
	_objective_step.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	v.add_child(_objective_step)
	_objective_panel.visible = false


func _build_prompt() -> void:
	_prompt_panel = UIKit.panel(Color(UIKit.BG_PANEL.r, UIKit.BG_PANEL.g, UIKit.BG_PANEL.b, 0.9))
	_prompt_panel.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	_prompt_panel.position = Vector2(-150, -170)
	_prompt_panel.custom_minimum_size = Vector2(300, 0)
	_prompt_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_prompt_panel)

	var h := UIKit.hbox(10)
	h.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_prompt_panel.add_child(h)
	_prompt_icon = UIKit.label("●", 22, UIKit.ACCENT)
	_prompt_icon.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	h.add_child(_prompt_icon)
	var v := UIKit.vbox(1)
	v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	h.add_child(v)
	_prompt_label = UIKit.label("", 16, UIKit.TEXT)
	v.add_child(_prompt_label)
	_prompt_sub = UIKit.label("", 12, UIKit.TEXT_DIM)
	v.add_child(_prompt_sub)
	_prompt_panel.visible = false


func _build_toasts() -> void:
	_toast_box = UIKit.vbox(6)
	_toast_box.set_anchors_preset(Control.PRESET_CENTER_TOP)
	_toast_box.position = Vector2(-190, 72)
	_toast_box.custom_minimum_size = Vector2(380, 0)
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
	_clock_label.text = "Day %d   %s" % [GameState.day, GameConfig.format_clock(GameState.hour)]
	if bool(SettingsService.get_value("graphics", "show_fps", false)):
		_fps_label.text = "%d fps" % Engine.get_frames_per_second()
	elif _fps_label.text != "":
		_fps_label.text = ""
	minimap.visible = bool(SettingsService.get_value("gameplay", "minimap", true))
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
	if GameState.bank != 0:
		_money_label.text += "  ·  " + GameConfig.format_money(GameState.bank) + " bank"


func _on_weather_changed(weather_id: String) -> void:
	var glyphs := {"clear": "☀", "overcast": "☁", "rain": "☂", "fog": "≈", "storm": "⚡"}
	_weather_label.text = String(glyphs.get(weather_id, ""))


func _on_suspicion_changed(value: float) -> void:
	_suspicion_bar.value = value / GameConfig.SUSPICION_MAX
	var target := 1.0 if value > 1.0 else 0.0
	if absf(_suspicion_panel.modulate.a - target) > 0.01:
		create_tween().tween_property(_suspicion_panel, "modulate:a", target, 0.3)


func _on_wanted_changed(level: int) -> void:
	for i in _stars.size():
		var lit := i < level
		_stars[i].add_theme_color_override("font_color",
			UIKit.BAD if lit else Color(UIKit.TEXT_FAINT.r, UIKit.TEXT_FAINT.g,
				UIKit.TEXT_FAINT.b, 0.25))
	if level > 0:
		_pulse(_wanted_row)


func _pulse(node: Control) -> void:
	var t := create_tween()
	t.tween_property(node, "scale", Vector2(1.18, 1.18), 0.12)
	t.tween_property(node, "scale", Vector2.ONE, 0.18)


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
	var step := String(obj.get("label", "Objective"))
	if target > 1:
		step += "   %d/%d" % [progress, target]
	_objective_step.text = step
	_objective_panel.visible = true

	# Point the minimap at the objective when it has a place.
	minimap.has_objective = false
	if obj.has("poi") and GameData.has_poi(String(obj["poi"])):
		minimap.objective_pos = GameData.poi_position(String(obj["poi"]))
		minimap.has_objective = true
	elif obj.has("npc"):
		var npc_id := String(obj["npc"])
		var n: Dictionary = GameData.npc(npc_id)
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
	_prompt_panel.visible = true
	_prompt_icon.text = String(payload.get("icon", "●"))
	_prompt_label.text = String(payload.get("prompt", ""))
	var sub := String(payload.get("subtitle", ""))
	if not bool(payload.get("enabled", true)):
		sub = String(payload.get("reason", sub))
		_prompt_label.add_theme_color_override("font_color", UIKit.TEXT_FAINT)
	else:
		_prompt_label.add_theme_color_override("font_color", UIKit.TEXT)
	_prompt_sub.text = sub
	_prompt_sub.visible = sub != ""


# ===========================================================================
# TOASTS
# ===========================================================================

func _on_toast(text: String, kind: String) -> void:
	var color := UIKit.color_for_kind(kind)
	var panel := UIKit.panel(Color(UIKit.BG_RAISED.r, UIKit.BG_RAISED.g, UIKit.BG_RAISED.b, 0.94))
	var style := UIKit.panel_style(Color(UIKit.BG_RAISED.r, UIKit.BG_RAISED.g,
		UIKit.BG_RAISED.b, 0.94), 10, color, 1)
	style.content_margin_top = 8
	style.content_margin_bottom = 8
	panel.add_theme_stylebox_override("panel", style)
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.modulate.a = 0.0

	var l := UIKit.label(text, 15, color, HORIZONTAL_ALIGNMENT_CENTER)
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	panel.add_child(l)
	_toast_box.add_child(panel)

	while _toast_box.get_child_count() > 4:
		var oldest := _toast_box.get_child(0)
		_toast_box.remove_child(oldest)
		oldest.queue_free()

	var t := create_tween()
	t.tween_property(panel, "modulate:a", 1.0, 0.18)
	t.tween_interval(2.6)
	t.tween_property(panel, "modulate:a", 0.0, 0.5)
	t.tween_callback(panel.queue_free)

	if kind == "good":
		AudioDirector.play_ui("notify")
	elif kind == "bad":
		AudioDirector.play_ui("ui_error")
