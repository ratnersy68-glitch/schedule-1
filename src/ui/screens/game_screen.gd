class_name GameScreen
extends Control
## Base class for every modal screen.
##
## Provides the shared chrome: a dimmed backdrop, a titled header with a close
## control, and a scrolling content column. Subclasses only implement
## `build_content()` and optionally `refresh()`.

signal closed()

var title_text: String = "Screen"
var subtitle_text: String = ""
var payload: Dictionary = {}
var content: VBoxContainer = null
var header_extra: HBoxContainer = null

var _panel: PanelContainer
var _title_label: Label
var _subtitle_label: Label
var _max_width: float = 720.0


func _ready() -> void:
	UIKit.fill_viewport(self)
	mouse_filter = Control.MOUSE_FILTER_STOP
	_build_chrome()
	build_content()
	refresh()
	_animate_in()


func open_with(data: Dictionary) -> void:
	payload = data


func _build_chrome() -> void:
	var backdrop := UIKit.backdrop(0.78)
	backdrop.gui_input.connect(func(e):
		if e is InputEventScreenTouch and (e as InputEventScreenTouch).pressed:
			close())
	add_child(backdrop)

	var margin := MarginContainer.new()
	margin.set_anchors_preset(Control.PRESET_FULL_RECT)
	margin.add_theme_constant_override("margin_left", 18)
	margin.add_theme_constant_override("margin_right", 18)
	margin.add_theme_constant_override("margin_top", 16)
	margin.add_theme_constant_override("margin_bottom", 16)
	add_child(margin)

	var centerer := CenterContainer.new()
	centerer.set_anchors_preset(Control.PRESET_FULL_RECT)
	margin.add_child(centerer)

	_panel = UIKit.panel(UIKit.BG_RAISED)
	_panel.custom_minimum_size = Vector2(minf(_max_width, get_viewport_rect().size.x - 40.0), 0)
	_panel.size_flags_vertical = Control.SIZE_EXPAND_FILL
	centerer.add_child(_panel)

	var column := UIKit.vbox(10)
	_panel.add_child(column)

	var header := UIKit.hbox(10)
	column.add_child(header)

	var titles := UIKit.vbox(1)
	titles.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_title_label = UIKit.title(title_text, 22)
	titles.add_child(_title_label)
	_subtitle_label = UIKit.label(subtitle_text, 13, UIKit.TEXT_DIM)
	_subtitle_label.visible = subtitle_text != ""
	titles.add_child(_subtitle_label)
	header.add_child(titles)

	header_extra = UIKit.hbox(8)
	header.add_child(header_extra)

	var close_btn := UIKit.icon_button("X", 44.0)
	close_btn.pressed.connect(close)
	header.add_child(close_btn)

	column.add_child(UIKit.separator())

	var scroll := UIKit.scroll()
	scroll.custom_minimum_size = Vector2(0, 260)
	column.add_child(scroll)

	content = UIKit.vbox(10)
	content.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(content)


func set_titles(new_title: String, new_subtitle: String = "") -> void:
	title_text = new_title
	subtitle_text = new_subtitle
	if _title_label != null:
		_title_label.text = new_title
		_subtitle_label.text = new_subtitle
		_subtitle_label.visible = new_subtitle != ""


func clear_content() -> void:
	for child in content.get_children():
		child.queue_free()
		content.remove_child(child)


## Subclasses build their UI here.
func build_content() -> void:
	pass


## Called after build and whenever state the screen shows has changed.
func refresh() -> void:
	pass


func _animate_in() -> void:
	_panel.modulate.a = 0.0
	_panel.scale = Vector2(0.97, 0.97)
	_panel.pivot_offset = _panel.size * 0.5
	var t := create_tween().set_parallel(true)
	t.tween_property(_panel, "modulate:a", 1.0, 0.16)
	t.tween_property(_panel, "scale", Vector2.ONE, 0.18).set_trans(Tween.TRANS_BACK)


func close() -> void:
	AudioDirector.play_ui("ui_cancel")
	closed.emit()
	queue_free()


func _unhandled_input(event: InputEvent) -> void:
	# Back closes; interact must not, or every tap-to-use would dismiss the
	# screen it just opened.
	if event.is_action_pressed("pause_menu"):
		close()
		get_viewport().set_input_as_handled()


## Helper: a full-width section heading inside the content column.
func section(text: String) -> void:
	content.add_child(UIKit.spacer(2))
	content.add_child(UIKit.label(text.to_upper(), 12, UIKit.TEXT_FAINT))


## Helper: a full-width action button row.
func actions(buttons: Array[Button]) -> HBoxContainer:
	var h := UIKit.hbox(8)
	for b in buttons:
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		h.add_child(b)
	content.add_child(h)
	return h
