class_name UIKit
extends RefCounted
## The visual language of Underlight's interface, in one place.
##
## Every screen builds its controls through these helpers so spacing, radii,
## colour and touch-target sizes stay consistent, and so a restyle is a single
## file edit rather than a hunt through twenty screens. Touch targets are never
## smaller than 44 units, which is the smallest comfortable thumb target.

# --- Palette ---------------------------------------------------------------
# Neon-noir: a deep blue-black city at night, lit by cyan Lumen and sodium
# street lamps. Surfaces step up in lightness as they come forward, so depth
# reads without needing drop shadows everywhere.
const BG            := Color(0.024, 0.031, 0.059)   # the page behind everything
const SURFACE       := Color(0.055, 0.075, 0.122)   # cards and panels
const SURFACE_RAISED:= Color(0.075, 0.102, 0.161)   # rows sitting on a card
const SURFACE_INPUT := Color(0.106, 0.137, 0.204)   # controls you can press
const OVERLAY       := Color(0.016, 0.022, 0.043)   # modal backdrop

const LINE          := Color(0.149, 0.192, 0.286)
const LINE_SOFT     := Color(0.149, 0.192, 0.286, 0.5)

const TEXT          := Color(0.910, 0.933, 0.973)
const TEXT_DIM      := Color(0.576, 0.631, 0.722)
const TEXT_FAINT    := Color(0.357, 0.412, 0.502)

const ACCENT        := Color(0.275, 0.863, 1.000)   # Lumen cyan
const ACCENT_DEEP   := Color(0.114, 0.435, 0.941)
const VIOLET        := Color(0.663, 0.482, 1.000)
const GOOD          := Color(0.247, 0.820, 0.541)
const WARN          := Color(1.000, 0.745, 0.302)
const BAD           := Color(1.000, 0.365, 0.420)
const MONEY         := Color(0.431, 0.906, 0.627)

# Older names kept so existing screens keep compiling.
const BG_RAISED     := SURFACE_RAISED
const BG_PANEL      := SURFACE
const BG_INPUT      := SURFACE_INPUT

const TOUCH_MIN := 46.0
const RADIUS_SM := 10
const RADIUS := 14
const RADIUS_LG := 20
const PAD := 15


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

static func panel_style(color: Color = SURFACE, radius: int = RADIUS,
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

static func panel(color: Color = SURFACE) -> PanelContainer:
	var p := PanelContainer.new()
	p.add_theme_stylebox_override("panel", panel_style(color))
	return p


static func label(text: String, size: int = 16, color: Color = TEXT,
		align: int = HORIZONTAL_ALIGNMENT_LEFT) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_override("font", UITheme.font(UITheme.W_MEDIUM))
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", color)
	l.horizontal_alignment = align
	return l


## Small all-caps section marker. Tracking makes short labels read as headings
## rather than as clipped sentences.
static func eyebrow(text: String, color: Color = TEXT_FAINT) -> Label:
	var l := Label.new()
	l.text = text.to_upper()
	l.add_theme_font_override("font", UITheme.font(UITheme.W_BOLD))
	l.add_theme_font_size_override("font_size", 11)
	l.add_theme_color_override("font_color", color)
	l.add_theme_constant_override("line_spacing", 0)
	return l


## Numerals that will change while on screen: tabular so nothing shuffles.
static func numeric(text: String, size: int = 16, color: Color = TEXT,
		weight: int = UITheme.W_SEMIBOLD) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_override("font", UITheme.font(weight, true))
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", color)
	return l


static func title(text: String, size: int = 22) -> Label:
	var l := label(text, size, TEXT)
	l.add_theme_font_override("font", UITheme.font(UITheme.W_BOLD))
	return l


## Display type for the title screen and headline moments.
static func display(text: String, size: int = 52, color: Color = ACCENT) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_override("font", UITheme.font(UITheme.W_BLACK))
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", color)
	return l


static func body(text: String, size: int = 14) -> Label:
	var l := label(text, size, TEXT_DIM)
	l.add_theme_font_override("font", UITheme.font(UITheme.W_REGULAR))
	l.add_theme_constant_override("line_spacing", 4)
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	return l


static func button(text: String, kind: String = "default") -> Button:
	var b := Button.new()
	b.text = text
	b.custom_minimum_size = Vector2(0, TOUCH_MIN)
	b.add_theme_font_size_override("font_size", 16)
	var base := SURFACE_INPUT
	var fg := TEXT
	var edge := LINE
	match kind:
		"primary":
			base = ACCENT_DEEP
			fg = Color.WHITE
			edge = ACCENT
		"good":
			base = Color(0.055, 0.204, 0.145)
			fg = GOOD
			edge = Color(GOOD.r, GOOD.g, GOOD.b, 0.55)
		"bad":
			base = Color(0.220, 0.075, 0.098)
			fg = BAD
			edge = Color(BAD.r, BAD.g, BAD.b, 0.5)
		"ghost":
			base = Color(0, 0, 0, 0)
			fg = TEXT_DIM
			edge = Color(0, 0, 0, 0)
	b.add_theme_font_override("font", UITheme.font(UITheme.W_SEMIBOLD))
	b.add_theme_stylebox_override("normal", _button_style(base, edge))
	b.add_theme_stylebox_override("hover", _button_style(base.lightened(0.09), edge))
	b.add_theme_stylebox_override("pressed", _button_style(base.darkened(0.2), edge))
	b.add_theme_stylebox_override("disabled",
		_button_style(Color(SURFACE.r, SURFACE.g, SURFACE.b, 0.85),
			Color(LINE.r, LINE.g, LINE.b, 0.5)))
	b.add_theme_stylebox_override("focus", _button_style(base, ACCENT))
	b.add_theme_color_override("font_color", fg)
	b.add_theme_color_override("font_hover_color", fg)
	b.add_theme_color_override("font_pressed_color", fg)
	b.add_theme_color_override("font_disabled_color", TEXT_FAINT)
	return b


static func _button_style(color: Color, border: Color = Color(0, 0, 0, 0)) -> StyleBoxFlat:
	var s := flat_style(color, RADIUS_SM)
	s.content_margin_left = 16
	s.content_margin_right = 16
	s.content_margin_top = 11
	s.content_margin_bottom = 11
	if border.a > 0.0:
		s.border_color = border
		s.set_border_width_all(1)
	return s


static func icon_button(icon_name: String, size: float = 56.0,
		tint: Color = TEXT) -> Button:
	var b := button("")
	b.custom_minimum_size = Vector2(size, size)
	var icon := IconRect.create(icon_name, size * 0.42, tint)
	icon.set_anchors_preset(Control.PRESET_FULL_RECT)
	var inset := size * 0.29
	icon.offset_left = inset
	icon.offset_top = inset
	icon.offset_right = -inset
	icon.offset_bottom = -inset
	b.add_child(icon)
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


## A row with a tinted icon tile, a title, a subtitle and a trailing value.
## `glyph` is a UIIcons name.
static func list_row(glyph: String, glyph_color: Color, title_text: String,
		subtitle_text: String, trailing: String = "",
		trailing_color: Color = TEXT) -> PanelContainer:
	var row := PanelContainer.new()
	var style := panel_style(SURFACE_RAISED, RADIUS_SM, LINE_SOFT, 1)
	style.content_margin_top = 11
	style.content_margin_bottom = 11
	style.content_margin_left = 12
	style.content_margin_right = 12
	row.add_theme_stylebox_override("panel", style)

	var h := hbox(12)
	row.add_child(h)
	h.add_child(icon_tile(glyph, glyph_color))

	var texts := vbox(2)
	texts.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	texts.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	texts.add_child(label(title_text, 15, TEXT))
	if subtitle_text != "":
		var sub := label(subtitle_text, 12, TEXT_DIM)
		sub.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		texts.add_child(sub)
	h.add_child(texts)

	if trailing != "":
		var tl := numeric(trailing, 15, trailing_color)
		tl.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		tl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		h.add_child(tl)
	return row


## A rounded tile carrying an icon, tinted from a single colour.
static func icon_tile(glyph: String, tint: Color, box: float = 38.0) -> PanelContainer:
	var tile := PanelContainer.new()
	var s := flat_style(Color(tint.r, tint.g, tint.b, 0.14), RADIUS_SM)
	s.border_color = Color(tint.r, tint.g, tint.b, 0.32)
	s.set_border_width_all(1)
	tile.add_theme_stylebox_override("panel", s)
	tile.custom_minimum_size = Vector2(box, box)
	tile.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	var icon := IconRect.create(glyph, box * 0.58, tint)
	icon.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	icon.size_flags_vertical = Control.SIZE_EXPAND_FILL
	tile.add_child(icon)
	return tile


## A labelled key/value line, used all over the stat panels.
static func stat_line(key: String, value: String, value_color: Color = TEXT) -> HBoxContainer:
	var h := hbox(8)
	var k := label(key, 13, TEXT_DIM)
	k.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	h.add_child(k)
	var v := numeric(value, 13, value_color, UITheme.W_MEDIUM)
	v.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	h.add_child(v)
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
	var l := label(text.to_upper(), 10, color)
	l.add_theme_font_override("font", UITheme.font(UITheme.W_BOLD))
	p.add_child(l)
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

	# A zero dimension means "size yourself to your content". Godot grows a
	# control right and down by default, which pushes a right- or
	# bottom-anchored card straight off the screen, so aim the growth inward.
	if box.x <= 0.0:
		match h:
			"right":
				c.grow_horizontal = Control.GROW_DIRECTION_BEGIN
			"center":
				c.grow_horizontal = Control.GROW_DIRECTION_BOTH
			_:
				c.grow_horizontal = Control.GROW_DIRECTION_END
	if box.y <= 0.0:
		c.grow_vertical = Control.GROW_DIRECTION_BEGIN if v == "bottom" \
			else Control.GROW_DIRECTION_END


## Full-bleed dim backdrop for modal screens.
static func backdrop(alpha: float = 0.72) -> ColorRect:
	var c := ColorRect.new()
	c.color = Color(OVERLAY.r, OVERLAY.g, OVERLAY.b, alpha)
	c.set_anchors_preset(Control.PRESET_FULL_RECT)
	c.mouse_filter = Control.MOUSE_FILTER_STOP
	return c
