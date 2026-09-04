class_name UIKit
extends RefCounted
## The visual language of Underlight's interface, in one place.
##
## Every screen builds its controls through these helpers so spacing, radii,
## colour and touch-target sizes stay consistent, and so a restyle is a single
## file edit rather than a hunt through twenty screens. Touch targets are never
## smaller than 44 units, which is the smallest comfortable thumb target.

# --- Palette ---------------------------------------------------------------
const BG            := Color(0.043, 0.055, 0.086)
const BG_RAISED     := Color(0.071, 0.086, 0.125)
const BG_PANEL      := Color(0.094, 0.113, 0.157)
const BG_INPUT      := Color(0.129, 0.149, 0.196)
const LINE          := Color(0.20, 0.23, 0.29)
const TEXT          := Color(0.90, 0.93, 0.96)
const TEXT_DIM      := Color(0.58, 0.63, 0.70)
const TEXT_FAINT    := Color(0.40, 0.45, 0.52)
const ACCENT        := Color(0.33, 0.78, 1.00)
const ACCENT_DEEP   := Color(0.20, 0.48, 0.85)
const GOOD          := Color(0.35, 0.85, 0.58)
const WARN          := Color(0.98, 0.75, 0.30)
const BAD           := Color(0.98, 0.38, 0.42)
const MONEY         := Color(0.55, 0.92, 0.65)
const VIOLET        := Color(0.66, 0.45, 1.00)

const TOUCH_MIN := 46.0
const RADIUS := 12
const PAD := 14


static func color_for_kind(kind: String) -> Color:
	match kind:
		"good":
			return GOOD
		"warn":
			return WARN
		"bad":
			return BAD
		"money":
			return MONEY
		_:
			return ACCENT


# --- Style boxes -----------------------------------------------------------

static func panel_style(color: Color = BG_PANEL, radius: int = RADIUS,
		border: Color = LINE, border_width: int = 1) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = color
	s.corner_radius_top_left = radius
	s.corner_radius_top_right = radius
	s.corner_radius_bottom_left = radius
	s.corner_radius_bottom_right = radius
	if border_width > 0:
		s.border_color = border
		s.set_border_width_all(border_width)
	s.content_margin_left = PAD
	s.content_margin_right = PAD
	s.content_margin_top = PAD
	s.content_margin_bottom = PAD
	return s


static func flat_style(color: Color, radius: int = RADIUS) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = color
	s.corner_radius_top_left = radius
	s.corner_radius_top_right = radius
	s.corner_radius_bottom_left = radius
	s.corner_radius_bottom_right = radius
	return s


# --- Controls --------------------------------------------------------------

static func panel(color: Color = BG_PANEL) -> PanelContainer:
	var p := PanelContainer.new()
	p.add_theme_stylebox_override("panel", panel_style(color))
	return p


static func label(text: String, size: int = 16, color: Color = TEXT,
		align: int = HORIZONTAL_ALIGNMENT_LEFT) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", color)
	l.horizontal_alignment = align
	return l


static func title(text: String, size: int = 24) -> Label:
	var l := label(text, size, TEXT)
	l.add_theme_color_override("font_color", TEXT)
	return l


static func body(text: String, size: int = 14) -> Label:
	var l := label(text, size, TEXT_DIM)
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	return l


static func button(text: String, kind: String = "default") -> Button:
	var b := Button.new()
	b.text = text
	b.custom_minimum_size = Vector2(0, TOUCH_MIN)
	b.add_theme_font_size_override("font_size", 16)
	var base := BG_INPUT
	var fg := TEXT
	match kind:
		"primary":
			base = ACCENT_DEEP
			fg = Color.WHITE
		"good":
			base = Color(0.13, 0.36, 0.26)
			fg = GOOD
		"bad":
			base = Color(0.32, 0.13, 0.16)
			fg = BAD
		"ghost":
			base = Color(0, 0, 0, 0)
			fg = TEXT_DIM
	b.add_theme_stylebox_override("normal", _button_style(base))
	b.add_theme_stylebox_override("hover", _button_style(base.lightened(0.08)))
	b.add_theme_stylebox_override("pressed", _button_style(base.darkened(0.18)))
	b.add_theme_stylebox_override("disabled", _button_style(base.darkened(0.45)))
	b.add_theme_stylebox_override("focus", _button_style(base, ACCENT))
	b.add_theme_color_override("font_color", fg)
	b.add_theme_color_override("font_hover_color", fg)
	b.add_theme_color_override("font_pressed_color", fg)
	b.add_theme_color_override("font_disabled_color", TEXT_FAINT)
	return b


static func _button_style(color: Color, border: Color = Color(0, 0, 0, 0)) -> StyleBoxFlat:
	var s := flat_style(color, 10)
	s.content_margin_left = 16
	s.content_margin_right = 16
	s.content_margin_top = 10
	s.content_margin_bottom = 10
	if border.a > 0.0:
		s.border_color = border
		s.set_border_width_all(2)
	return s


static func icon_button(glyph: String, size: float = 56.0) -> Button:
	var b := button(glyph)
	b.custom_minimum_size = Vector2(size, size)
	b.add_theme_font_size_override("font_size", int(size * 0.42))
	return b


static func progress(value: float, color: Color, height: float = 8.0) -> ProgressBar:
	var p := ProgressBar.new()
	p.min_value = 0.0
	p.max_value = 1.0
	p.value = value
	p.show_percentage = false
	p.custom_minimum_size = Vector2(0, height)
	var bg := flat_style(Color(0, 0, 0, 0.35), int(height * 0.5))
	var fg := flat_style(color, int(height * 0.5))
	p.add_theme_stylebox_override("background", bg)
	p.add_theme_stylebox_override("fill", fg)
	return p


static func separator() -> HSeparator:
	var s := HSeparator.new()
	var style := StyleBoxFlat.new()
	style.bg_color = LINE
	style.content_margin_top = 1
	s.add_theme_stylebox_override("separator", style)
	return s


static func spacer(height: float = 8.0) -> Control:
	var c := Control.new()
	c.custom_minimum_size = Vector2(0, height)
	return c


static func hbox(separation: int = 8) -> HBoxContainer:
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", separation)
	return h


static func vbox(separation: int = 8) -> VBoxContainer:
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", separation)
	return v


static func scroll() -> ScrollContainer:
	var s := ScrollContainer.new()
	s.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	s.size_flags_vertical = Control.SIZE_EXPAND_FILL
	s.follow_focus = true
	return s


## A row with a coloured glyph chip, a title, a subtitle and a trailing value.
static func list_row(glyph: String, glyph_color: Color, title_text: String,
		subtitle_text: String, trailing: String = "",
		trailing_color: Color = TEXT) -> PanelContainer:
	var row := PanelContainer.new()
	var style := panel_style(BG_RAISED, 10, LINE, 1)
	style.content_margin_top = 10
	style.content_margin_bottom = 10
	row.add_theme_stylebox_override("panel", style)

	var h := hbox(12)
	row.add_child(h)

	var chip := PanelContainer.new()
	chip.add_theme_stylebox_override("panel", flat_style(glyph_color.darkened(0.55), 9))
	chip.custom_minimum_size = Vector2(40, 40)
	var gl := label(glyph, 20, glyph_color, HORIZONTAL_ALIGNMENT_CENTER)
	gl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	chip.add_child(gl)
	h.add_child(chip)

	var texts := vbox(2)
	texts.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	texts.add_child(label(title_text, 16, TEXT))
	if subtitle_text != "":
		texts.add_child(label(subtitle_text, 12, TEXT_DIM))
	h.add_child(texts)

	if trailing != "":
		var tl := label(trailing, 16, trailing_color, HORIZONTAL_ALIGNMENT_RIGHT)
		tl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		h.add_child(tl)
	return row


## A labelled key/value line, used all over the stat panels.
static func stat_line(key: String, value: String, value_color: Color = TEXT) -> HBoxContainer:
	var h := hbox(8)
	var k := label(key, 13, TEXT_DIM)
	k.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	h.add_child(k)
	h.add_child(label(value, 13, value_color, HORIZONTAL_ALIGNMENT_RIGHT))
	return h


static func chip(text: String, color: Color) -> PanelContainer:
	var p := PanelContainer.new()
	var s := flat_style(color.darkened(0.6), 8)
	s.content_margin_left = 8
	s.content_margin_right = 8
	s.content_margin_top = 3
	s.content_margin_bottom = 3
	s.border_color = color.darkened(0.2)
	s.set_border_width_all(1)
	p.add_theme_stylebox_override("panel", s)
	p.add_child(label(text, 11, color))
	return p


static func quality_chip(q: int) -> PanelContainer:
	return chip(GameConfig.quality_name(q), GameConfig.quality_color(q))


static func slider(min_v: float, max_v: float, step: float, value: float) -> HSlider:
	var s := HSlider.new()
	s.min_value = min_v
	s.max_value = max_v
	s.step = step
	s.value = value
	s.custom_minimum_size = Vector2(160, TOUCH_MIN)
	s.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	return s


static func toggle(text: String, pressed: bool) -> CheckButton:
	var c := CheckButton.new()
	c.text = text
	c.button_pressed = pressed
	c.custom_minimum_size = Vector2(0, TOUCH_MIN)
	c.add_theme_font_size_override("font_size", 15)
	c.add_theme_color_override("font_color", TEXT)
	return c


## Makes a root Control genuinely fill the screen, and keeps it filling it.
##
## A Control added to a CanvasLayer from code does not inherit the viewport
## rect: it stays 0x0, and every anchored child then resolves against zero and
## lands off-screen. Anchors cannot fix that, because the anchor maths
## multiplies by a parent size that is still zero. Setting explicit offsets
## with top-left anchors gives the control a real rect that later layout passes
## will not recompute away.
static func fill_viewport(c: Control) -> void:
	c.anchor_left = 0.0
	c.anchor_top = 0.0
	c.anchor_right = 0.0
	c.anchor_bottom = 0.0
	_resize_to_viewport(c)
	var viewport := c.get_viewport()
	if viewport != null and not viewport.size_changed.is_connected(_resize_to_viewport.bind(c)):
		viewport.size_changed.connect(_resize_to_viewport.bind(c))


static func _resize_to_viewport(c: Control) -> void:
	if not is_instance_valid(c) or not c.is_inside_tree():
		return
	var vp := c.get_viewport_rect().size
	c.offset_left = 0.0
	c.offset_top = 0.0
	c.offset_right = vp.x
	c.offset_bottom = vp.y


## Anchors a control to an edge or corner using explicit offsets.
##
## Setting `position` on a control that has anchors is absolute in parent
## space, not relative to the anchor, which silently puts right- and
## bottom-anchored elements off-screen. This does the offset arithmetic once so
## no caller has to remember that.
##
## h: "left" | "center" | "right"   v: "top" | "bottom"
## A height of 0 lets the control size itself to its content and grow down.
static func anchor_to(c: Control, h: String, v: String, margin: Vector2,
		box: Vector2) -> void:
	match h:
		"right":
			c.anchor_left = 1.0
			c.anchor_right = 1.0
			c.offset_left = -(margin.x + box.x)
			c.offset_right = -margin.x
		"center":
			c.anchor_left = 0.5
			c.anchor_right = 0.5
			c.offset_left = -box.x * 0.5
			c.offset_right = box.x * 0.5
		_:
			c.anchor_left = 0.0
			c.anchor_right = 0.0
			c.offset_left = margin.x
			c.offset_right = margin.x + box.x
	if v == "bottom":
		c.anchor_top = 1.0
		c.anchor_bottom = 1.0
		c.offset_top = -(margin.y + box.y)
		c.offset_bottom = -margin.y
	else:
		c.anchor_top = 0.0
		c.anchor_bottom = 0.0
		c.offset_top = margin.y
		c.offset_bottom = margin.y + box.y


## Full-bleed dim backdrop for modal screens.
static func backdrop(alpha: float = 0.72) -> ColorRect:
	var c := ColorRect.new()
	c.color = Color(BG.r, BG.g, BG.b, alpha)
	c.set_anchors_preset(Control.PRESET_FULL_RECT)
	c.mouse_filter = Control.MOUSE_FILTER_STOP
	return c
