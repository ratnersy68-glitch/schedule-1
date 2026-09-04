class_name UITheme
extends RefCounted
## Builds the game's Godot Theme once and hands it to every root Control.
##
## Before this existed, each widget carried a pile of per-control theme
## overrides and everything else fell back to Godot's defaults, which is why
## the interface read as "programmer art". A real Theme means a plain Button,
## Label, ProgressBar or Slider is already correct, and UIKit only overrides
## where a control genuinely differs.
##
## Type is Inter, a variable font, so weights come off the `wght` axis instead
## of shipping a file per weight. Numerals use the `tnum` feature so money and
## the clock stop jittering as digits change.

const FONT_PATH := "res://assets/fonts/InterVariable.ttf"

# Weight stops used across the interface.
const W_REGULAR := 400
const W_MEDIUM := 500
const W_SEMIBOLD := 600
const W_BOLD := 700
const W_BLACK := 900

static var _theme: Theme = null
static var _base_font: FontFile = null
static var _variations: Dictionary = {}


## The shared Theme. Assign to a root Control and every child inherits it.
static func get_theme() -> Theme:
	if _theme == null:
		_theme = _build()
	return _theme


static func base_font() -> FontFile:
	if _base_font == null:
		var f := load(FONT_PATH)
		if f is FontFile:
			_base_font = f
			# Grey antialiasing with subpixel positioning keeps small UI text
			# crisp; hinting off suits a variable font being scaled freely.
			_base_font.antialiasing = TextServer.FONT_ANTIALIASING_GRAY
			_base_font.hinting = TextServer.HINTING_NONE
			_base_font.subpixel_positioning = TextServer.SUBPIXEL_POSITIONING_AUTO
		else:
			push_error("Interface font missing at " + FONT_PATH)
	return _base_font


## A weight off the variable axis. `tabular` locks numeral widths, which is
## what you want for anything that counts.
static func font(weight: int = W_REGULAR, tabular: bool = false) -> Font:
	var key := "%d_%s" % [weight, tabular]
	if _variations.has(key):
		return _variations[key]
	var base := base_font()
	if base == null:
		return ThemeDB.fallback_font
	var v := FontVariation.new()
	v.base_font = base
	v.variation_opentype = {"wght": weight}
	if tabular:
		v.opentype_features = {"tnum": 1}
	# A touch of tracking at display weights reads better on a dark background.
	if weight >= W_BOLD:
		v.spacing_glyph = 1
	_variations[key] = v
	return v


# ===========================================================================
# THEME CONSTRUCTION
# ===========================================================================

static func _build() -> Theme:
	var t := Theme.new()
	t.default_font = font(W_REGULAR)
	t.default_font_size = 15

	_style_labels(t)
	_style_buttons(t)
	_style_panels(t)
	_style_progress(t)
	_style_slider(t)
	_style_check(t)
	_style_scroll(t)
	_style_misc(t)
	return t


static func _style_labels(t: Theme) -> void:
	t.set_font("font", "Label", font(W_REGULAR))
	t.set_font_size("font_size", "Label", 15)
	t.set_color("font_color", "Label", UIKit.TEXT)
	t.set_color("font_shadow_color", "Label", Color(0, 0, 0, 0))
	t.set_constant("outline_size", "Label", 0)


static func _style_buttons(t: Theme) -> void:
	t.set_font("font", "Button", font(W_SEMIBOLD))
	t.set_font_size("font_size", "Button", 15)
	t.set_color("font_color", "Button", UIKit.TEXT)
	t.set_color("font_hover_color", "Button", Color.WHITE)
	t.set_color("font_pressed_color", "Button", Color.WHITE)
	t.set_color("font_focus_color", "Button", UIKit.TEXT)
	t.set_color("font_disabled_color", "Button", UIKit.TEXT_FAINT)

	t.set_stylebox("normal", "Button", _button_box(UIKit.SURFACE_INPUT))
	t.set_stylebox("hover", "Button", _button_box(UIKit.SURFACE_INPUT.lightened(0.07)))
	t.set_stylebox("pressed", "Button", _button_box(UIKit.SURFACE_INPUT.darkened(0.22)))
	t.set_stylebox("disabled", "Button", _button_box(UIKit.SURFACE.darkened(0.15), 0.35))
	var focus := _button_box(UIKit.SURFACE_INPUT)
	focus.border_color = UIKit.ACCENT
	focus.set_border_width_all(2)
	t.set_stylebox("focus", "Button", focus)


static func _button_box(color: Color, border_alpha: float = 1.0) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = color
	s.set_corner_radius_all(UIKit.RADIUS_SM)
	s.border_color = Color(UIKit.LINE.r, UIKit.LINE.g, UIKit.LINE.b, 0.9 * border_alpha)
	s.set_border_width_all(1)
	s.content_margin_left = 16
	s.content_margin_right = 16
	s.content_margin_top = 11
	s.content_margin_bottom = 11
	return s


static func _style_panels(t: Theme) -> void:
	var s := StyleBoxFlat.new()
	s.bg_color = UIKit.SURFACE
	s.set_corner_radius_all(UIKit.RADIUS)
	s.border_color = UIKit.LINE
	s.set_border_width_all(1)
	s.content_margin_left = UIKit.PAD
	s.content_margin_right = UIKit.PAD
	s.content_margin_top = UIKit.PAD
	s.content_margin_bottom = UIKit.PAD
	t.set_stylebox("panel", "PanelContainer", s)
	t.set_stylebox("panel", "Panel", s)


static func _style_progress(t: Theme) -> void:
	var bg := StyleBoxFlat.new()
	bg.bg_color = Color(0, 0, 0, 0.42)
	bg.set_corner_radius_all(4)
	var fill := StyleBoxFlat.new()
	fill.bg_color = UIKit.ACCENT
	fill.set_corner_radius_all(4)
	t.set_stylebox("background", "ProgressBar", bg)
	t.set_stylebox("fill", "ProgressBar", fill)
	t.set_font("font", "ProgressBar", font(W_MEDIUM, true))
	t.set_font_size("font_size", "ProgressBar", 11)
	t.set_color("font_color", "ProgressBar", UIKit.TEXT_DIM)


static func _style_slider(t: Theme) -> void:
	var track := StyleBoxFlat.new()
	track.bg_color = Color(0, 0, 0, 0.45)
	track.set_corner_radius_all(3)
	track.content_margin_top = 3
	track.content_margin_bottom = 3
	var filled := StyleBoxFlat.new()
	filled.bg_color = UIKit.ACCENT
	filled.set_corner_radius_all(3)
	filled.content_margin_top = 3
	filled.content_margin_bottom = 3
	t.set_stylebox("slider", "HSlider", track)
	t.set_stylebox("grabber_area", "HSlider", filled)
	t.set_stylebox("grabber_area_highlight", "HSlider", filled)

	# Godot wants a texture for the grabber; draw one once at runtime.
	var grabber := _circle_texture(11, UIKit.ACCENT, UIKit.BG)
	t.set_icon("grabber", "HSlider", grabber)
	t.set_icon("grabber_highlight", "HSlider", _circle_texture(12, Color.WHITE, UIKit.BG))


static func _style_check(t: Theme) -> void:
	t.set_font("font", "CheckButton", font(W_MEDIUM))
	t.set_font_size("font_size", "CheckButton", 15)
	t.set_color("font_color", "CheckButton", UIKit.TEXT)
	t.set_color("font_hover_color", "CheckButton", Color.WHITE)
	var flat := StyleBoxFlat.new()
	flat.bg_color = Color(0, 0, 0, 0)
	flat.content_margin_top = 8
	flat.content_margin_bottom = 8
	flat.content_margin_left = 2
	flat.content_margin_right = 2
	for state in ["normal", "hover", "pressed", "disabled", "focus"]:
		t.set_stylebox(state, "CheckButton", flat)
	t.set_icon("checked", "CheckButton", _switch_texture(true))
	t.set_icon("unchecked", "CheckButton", _switch_texture(false))


static func _style_scroll(t: Theme) -> void:
	var empty := StyleBoxEmpty.new()
	t.set_stylebox("panel", "ScrollContainer", empty)
	var bar := StyleBoxFlat.new()
	bar.bg_color = Color(0, 0, 0, 0.25)
	bar.set_corner_radius_all(3)
	bar.content_margin_left = 3
	bar.content_margin_right = 3
	var grab := StyleBoxFlat.new()
	grab.bg_color = Color(UIKit.TEXT_FAINT.r, UIKit.TEXT_FAINT.g, UIKit.TEXT_FAINT.b, 0.55)
	grab.set_corner_radius_all(3)
	t.set_stylebox("scroll", "VScrollBar", bar)
	t.set_stylebox("grabber", "VScrollBar", grab)
	t.set_stylebox("grabber_highlight", "VScrollBar", grab)
	t.set_stylebox("grabber_pressed", "VScrollBar", grab)


static func _style_misc(t: Theme) -> void:
	var sep := StyleBoxFlat.new()
	sep.bg_color = UIKit.LINE
	sep.content_margin_top = 1
	t.set_stylebox("separator", "HSeparator", sep)
	t.set_constant("separation", "HSeparator", 1)
	t.set_constant("separation", "VBoxContainer", 8)
	t.set_constant("separation", "HBoxContainer", 8)


# ===========================================================================
# GENERATED TEXTURES
# ===========================================================================

static func _circle_texture(radius: int, fill: Color, ring: Color) -> ImageTexture:
	var d := radius * 2
	var img := Image.create(d, d, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))
	var c := float(radius) - 0.5
	for y in d:
		for x in d:
			var dist := Vector2(x - c, y - c).length()
			if dist <= radius - 2.0:
				img.set_pixel(x, y, fill)
			elif dist <= radius - 0.5:
				# Feather the edge so the grabber does not look pixelated.
				var a := clampf((radius - 0.5 - dist) / 1.5, 0.0, 1.0)
				img.set_pixel(x, y, Color(ring.r, ring.g, ring.b, a))
	return ImageTexture.create_from_image(img)


static func _switch_texture(on: bool) -> ImageTexture:
	var w := 42
	var h := 24
	var img := Image.create(w, h, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))
	var track: Color = UIKit.ACCENT_DEEP if on else UIKit.SURFACE_INPUT
	var knob := Color.WHITE if on else UIKit.TEXT_DIM
	var r := h * 0.5
	for y in h:
		for x in w:
			var px := float(x)
			var py := float(y)
			# Rounded track: two end caps plus the bar between them.
			var inside := false
			if px >= r and px <= w - r:
				inside = true
			elif Vector2(px - r, py - r).length() <= r - 1.0:
				inside = true
			elif Vector2(px - (w - r), py - r).length() <= r - 1.0:
				inside = true
			if inside:
				img.set_pixel(x, y, track)
	var knob_x := (w - r) if on else r
	for y in h:
		for x in w:
			if Vector2(x - knob_x, y - r).length() <= r - 4.0:
				img.set_pixel(x, y, knob)
	return ImageTexture.create_from_image(img)
