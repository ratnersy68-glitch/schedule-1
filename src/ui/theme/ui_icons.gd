class_name UIIcons
extends RefCounted
## One vector icon set, drawn with primitives.
##
## Godot's built-in font is a Latin subset, so symbol characters render as
## empty boxes. The first fix for that was two-letter monograms, which worked
## but looked like placeholder art. These are drawn instead: they scale
## crisply, tint to any colour, cost nothing to ship, and give the interface a
## single consistent visual language.
##
## Every icon is defined against a unit box - a centre `c` and a radius `r`
## derived from the target rect - so the same definition works at 14px in a
## list row and at 44px on a touch button.

const NAMES := [
	# actions
	"use", "run", "crouch", "jump", "exit", "brake", "close", "back",
	"plus", "minus", "chevron", "check", "warning",
	# apps and screens
	"map", "contacts", "messages", "jobs", "business", "bank", "legacy",
	"news", "bag", "phone", "settings", "skills",
	# world
	"door", "workstation", "storage", "property", "person", "bed", "vehicle",
	# materials and goods
	"crystal", "mineral", "culture", "resin", "flask", "spark", "frost",
	"package", "tin", "patch", "sim", "key", "slate", "scrap", "money",
]


## Draws `name` centred in `rect`. `weight` is the stroke width in pixels.
static func draw(ci: CanvasItem, name: String, rect: Rect2, color: Color,
		weight: float = 0.0) -> void:
	var c := rect.position + rect.size * 0.5
	var r: float = minf(rect.size.x, rect.size.y) * 0.5
	var w: float = weight if weight > 0.0 else maxf(1.25, r * 0.17)
	_draw_icon(ci, name, c, r * 0.82, w, color)


static func _draw_icon(ci: CanvasItem, name: String, c: Vector2, r: float,
		w: float, col: Color) -> void:
	match name:
		# --- actions -------------------------------------------------
		"use":
			ci.draw_arc(c, r * 0.92, 0.0, TAU, 28, col, w, true)
			ci.draw_circle(c, r * 0.4, col)
		"run":
			_chevrons(ci, c, r, w, col, Vector2.RIGHT, 2)
		"crouch":
			_chevrons(ci, c, r, w, col, Vector2.DOWN, 1)
			ci.draw_line(c + Vector2(-r, r * 0.92), c + Vector2(r, r * 0.92), col, w, true)
		"jump":
			_chevrons(ci, c, r, w, col, Vector2.UP, 1)
			ci.draw_line(c + Vector2(-r, r * 0.92), c + Vector2(r, r * 0.92), col, w, true)
		"brake":
			_polygon_outline(ci, c, r, 8, w, col)
		"exit":
			ci.draw_rect(Rect2(c + Vector2(-r, -r), Vector2(r * 0.9, r * 2.0)), col, false, w)
			_arrow(ci, c + Vector2(-r * 0.05, 0), c + Vector2(r * 0.95, 0), r * 0.45, w, col)
		"close":
			var d := r * 0.66
			ci.draw_line(c + Vector2(-d, -d), c + Vector2(d, d), col, w, true)
			ci.draw_line(c + Vector2(-d, d), c + Vector2(d, -d), col, w, true)
		"back":
			_arrow(ci, c + Vector2(r * 0.7, 0), c + Vector2(-r * 0.7, 0), r * 0.55, w, col)
		"plus":
			ci.draw_line(c + Vector2(-r * 0.7, 0), c + Vector2(r * 0.7, 0), col, w, true)
			ci.draw_line(c + Vector2(0, -r * 0.7), c + Vector2(0, r * 0.7), col, w, true)
		"minus":
			ci.draw_line(c + Vector2(-r * 0.7, 0), c + Vector2(r * 0.7, 0), col, w, true)
		"chevron":
			_chevrons(ci, c, r, w, col, Vector2.RIGHT, 1)
		"check":
			ci.draw_polyline(PackedVector2Array([
				c + Vector2(-r * 0.7, 0.0), c + Vector2(-r * 0.15, r * 0.55),
				c + Vector2(r * 0.75, -r * 0.6)]), col, w, true)
		"warning":
			_polygon_outline(ci, c + Vector2(0, r * 0.1), r, 3, w, col, -PI * 0.5)
			ci.draw_line(c + Vector2(0, -r * 0.25), c + Vector2(0, r * 0.25), col, w, true)
			ci.draw_circle(c + Vector2(0, r * 0.55), w * 0.75, col)

		# --- apps ----------------------------------------------------
		"map":
			ci.draw_arc(c, r * 0.92, 0.0, TAU, 28, col, w, true)
			ci.draw_line(c + Vector2(-r * 0.92, 0), c + Vector2(r * 0.92, 0), col, w * 0.7, true)
			_ellipse(ci, c, r * 0.45, r * 0.92, w * 0.7, col)
		"contacts":
			ci.draw_arc(c + Vector2(0, -r * 0.35), r * 0.42, 0.0, TAU, 20, col, w, true)
			ci.draw_arc(c + Vector2(0, r * 0.75), r * 0.78, PI, TAU, 20, col, w, true)
		"messages":
			ci.draw_rect(Rect2(c + Vector2(-r * 0.95, -r * 0.7),
				Vector2(r * 1.9, r * 1.25)), col, false, w)
			ci.draw_polyline(PackedVector2Array([
				c + Vector2(-r * 0.95, -r * 0.7), c + Vector2(0, r * 0.05),
				c + Vector2(r * 0.95, -r * 0.7)]), col, w, true)
		"jobs":
			ci.draw_rect(Rect2(c + Vector2(-r * 0.75, -r * 0.9),
				Vector2(r * 1.5, r * 1.8)), col, false, w)
			for i in 2:
				var y := c.y - r * 0.35 + i * r * 0.7
				ci.draw_polyline(PackedVector2Array([
					Vector2(c.x - r * 0.4, y), Vector2(c.x - r * 0.15, y + r * 0.22),
					Vector2(c.x + r * 0.45, y - r * 0.3)]), col, w * 0.8, true)
		"business", "property":
			# A building with a pitched roof.
			ci.draw_polyline(PackedVector2Array([
				c + Vector2(-r, -r * 0.05), c + Vector2(0, -r * 0.95),
				c + Vector2(r, -r * 0.05)]), col, w, true)
			ci.draw_rect(Rect2(c + Vector2(-r * 0.72, -r * 0.05),
				Vector2(r * 1.44, r * 1.0)), col, false, w)
			ci.draw_rect(Rect2(c + Vector2(-r * 0.22, r * 0.35),
				Vector2(r * 0.44, r * 0.6)), col, false, w * 0.75)
		"bank", "money":
			ci.draw_line(c + Vector2(-r, -r * 0.45), c + Vector2(r, -r * 0.45), col, w, true)
			ci.draw_polyline(PackedVector2Array([
				c + Vector2(-r, -r * 0.45), c + Vector2(0, -r * 0.95),
				c + Vector2(r, -r * 0.45)]), col, w, true)
			for i in 3:
				var x := c.x - r * 0.6 + i * r * 0.6
				ci.draw_line(Vector2(x, c.y - r * 0.2), Vector2(x, c.y + r * 0.6), col, w * 0.8, true)
			ci.draw_line(c + Vector2(-r, r * 0.85), c + Vector2(r, r * 0.85), col, w, true)
		"legacy":
			_star(ci, c, r, w, col)
		"news":
			ci.draw_rect(Rect2(c + Vector2(-r * 0.95, -r * 0.8),
				Vector2(r * 1.9, r * 1.6)), col, false, w)
			for i in 3:
				var y := c.y - r * 0.35 + i * r * 0.42
				ci.draw_line(Vector2(c.x - r * 0.6, y), Vector2(c.x + r * 0.6, y), col, w * 0.7, true)
		"bag":
			ci.draw_rect(Rect2(c + Vector2(-r * 0.9, -r * 0.35),
				Vector2(r * 1.8, r * 1.3)), col, false, w)
			ci.draw_arc(c + Vector2(0, -r * 0.35), r * 0.5, PI, TAU, 18, col, w, true)
		"phone":
			ci.draw_rect(Rect2(c + Vector2(-r * 0.62, -r), Vector2(r * 1.24, r * 2.0)),
				col, false, w)
			ci.draw_line(c + Vector2(-r * 0.2, -r * 0.72), c + Vector2(r * 0.2, -r * 0.72),
				col, w * 0.8, true)
			ci.draw_circle(c + Vector2(0, r * 0.72), w * 0.85, col)
		"settings":
			ci.draw_arc(c, r * 0.42, 0.0, TAU, 20, col, w, true)
			for i in 6:
				var a := TAU * float(i) / 6.0
				var dir := Vector2(cos(a), sin(a))
				ci.draw_line(c + dir * r * 0.68, c + dir * r * 0.98, col, w, true)
		"skills":
			# Three rising bars.
			for i in 3:
				var h := r * (0.5 + i * 0.42)
				var x := c.x - r * 0.6 + i * r * 0.6
				ci.draw_line(Vector2(x, c.y + r * 0.85), Vector2(x, c.y + r * 0.85 - h),
					col, w * 1.3, true)

		# --- world ---------------------------------------------------
		"door":
			ci.draw_rect(Rect2(c + Vector2(-r * 0.7, -r * 0.95),
				Vector2(r * 1.4, r * 1.9)), col, false, w)
			ci.draw_circle(c + Vector2(r * 0.35, r * 0.1), w * 0.9, col)
		"workstation":
			ci.draw_line(c + Vector2(-r, r * 0.25), c + Vector2(r, r * 0.25), col, w, true)
			ci.draw_line(c + Vector2(-r * 0.7, r * 0.25), c + Vector2(-r * 0.7, r * 0.95),
				col, w, true)
			ci.draw_line(c + Vector2(r * 0.7, r * 0.25), c + Vector2(r * 0.7, r * 0.95),
				col, w, true)
			_diamond(ci, c + Vector2(0, -r * 0.4), r * 0.5, w, col)
		"storage":
			ci.draw_rect(Rect2(c + Vector2(-r * 0.95, -r * 0.9),
				Vector2(r * 1.9, r * 1.8)), col, false, w)
			ci.draw_line(c + Vector2(-r * 0.95, -r * 0.3), c + Vector2(r * 0.95, -r * 0.3),
				col, w * 0.8, true)
			ci.draw_line(c + Vector2(-r * 0.95, r * 0.3), c + Vector2(r * 0.95, r * 0.3),
				col, w * 0.8, true)
		"person":
			ci.draw_arc(c + Vector2(0, -r * 0.45), r * 0.38, 0.0, TAU, 18, col, w, true)
			ci.draw_arc(c + Vector2(0, r * 0.7), r * 0.72, PI, TAU, 18, col, w, true)
		"bed":
			ci.draw_line(c + Vector2(-r * 0.95, r * 0.6), c + Vector2(r * 0.95, r * 0.6),
				col, w, true)
			ci.draw_line(c + Vector2(-r * 0.95, r * 0.6), c + Vector2(-r * 0.95, -r * 0.2),
				col, w, true)
			ci.draw_arc(c + Vector2(-r * 0.3, r * 0.15), r * 0.32, PI, TAU, 14, col, w, true)
			ci.draw_line(c + Vector2(0, r * 0.15), c + Vector2(r * 0.95, r * 0.15), col, w, true)
			ci.draw_line(c + Vector2(r * 0.95, r * 0.15), c + Vector2(r * 0.95, r * 0.6),
				col, w, true)
		"vehicle":
			ci.draw_rect(Rect2(c + Vector2(-r * 0.95, -r * 0.15),
				Vector2(r * 1.9, r * 0.7)), col, false, w)
			ci.draw_polyline(PackedVector2Array([
				c + Vector2(-r * 0.6, -r * 0.15), c + Vector2(-r * 0.35, -r * 0.75),
				c + Vector2(r * 0.35, -r * 0.75), c + Vector2(r * 0.6, -r * 0.15)]),
				col, w * 0.85, true)
			ci.draw_circle(c + Vector2(-r * 0.5, r * 0.62), w * 1.1, col)
			ci.draw_circle(c + Vector2(r * 0.5, r * 0.62), w * 1.1, col)

		# --- goods ---------------------------------------------------
		"crystal":
			# The Lumen shard: the game's signature mark.
			ci.draw_polyline(PackedVector2Array([
				c + Vector2(0, -r), c + Vector2(r * 0.78, -r * 0.2),
				c + Vector2(0, r), c + Vector2(-r * 0.78, -r * 0.2),
				c + Vector2(0, -r)]), col, w, true)
			ci.draw_line(c + Vector2(-r * 0.78, -r * 0.2), c + Vector2(r * 0.78, -r * 0.2),
				col, w * 0.6, true)
		"mineral":
			_polygon_outline(ci, c, r * 0.95, 6, w, col)
		"culture":
			ci.draw_arc(c, r * 0.85, 0.0, TAU, 24, col, w, true)
			for i in 4:
				var a := TAU * float(i) / 4.0 + PI * 0.25
				ci.draw_circle(c + Vector2(cos(a), sin(a)) * r * 0.42, w * 1.0, col)
		"resin":
			# A droplet.
			ci.draw_arc(c + Vector2(0, r * 0.25), r * 0.65, 0.0, PI, 18, col, w, true)
			ci.draw_line(c + Vector2(-r * 0.65, r * 0.25), c + Vector2(0, -r * 0.9), col, w, true)
			ci.draw_line(c + Vector2(r * 0.65, r * 0.25), c + Vector2(0, -r * 0.9), col, w, true)
		"flask":
			ci.draw_line(c + Vector2(-r * 0.35, -r * 0.9), c + Vector2(-r * 0.35, -r * 0.15),
				col, w, true)
			ci.draw_line(c + Vector2(r * 0.35, -r * 0.9), c + Vector2(r * 0.35, -r * 0.15),
				col, w, true)
			ci.draw_polyline(PackedVector2Array([
				c + Vector2(-r * 0.35, -r * 0.15), c + Vector2(-r * 0.85, r * 0.8),
				c + Vector2(r * 0.85, r * 0.8), c + Vector2(r * 0.35, -r * 0.15)]),
				col, w, true)
			ci.draw_line(c + Vector2(-r * 0.55, -r * 0.9), c + Vector2(r * 0.55, -r * 0.9),
				col, w, true)
		"spark":
			ci.draw_polyline(PackedVector2Array([
				c + Vector2(r * 0.25, -r * 0.95), c + Vector2(-r * 0.5, r * 0.1),
				c + Vector2(r * 0.05, r * 0.1), c + Vector2(-r * 0.25, r * 0.95),
				c + Vector2(r * 0.5, -r * 0.1), c + Vector2(-r * 0.05, -r * 0.1),
				c + Vector2(r * 0.25, -r * 0.95)]), col, w * 0.85, true)
		"frost":
			for i in 3:
				var a := PI * float(i) / 3.0
				var dir := Vector2(cos(a), sin(a))
				ci.draw_line(c - dir * r * 0.9, c + dir * r * 0.9, col, w, true)
				for sign_dir: float in [-1.0, 1.0]:
					var tip: Vector2 = c + dir * r * 0.9 * sign_dir
					var back: Vector2 = dir * r * 0.3 * sign_dir
					var side := Vector2(-dir.y, dir.x) * r * 0.28
					ci.draw_line(tip, tip - back + side, col, w * 0.7, true)
					ci.draw_line(tip, tip - back - side, col, w * 0.7, true)
		"package":
			ci.draw_rect(Rect2(c + Vector2(-r * 0.9, -r * 0.7),
				Vector2(r * 1.8, r * 1.5)), col, false, w)
			ci.draw_line(c + Vector2(0, -r * 0.7), c + Vector2(0, r * 0.8), col, w * 0.75, true)
			ci.draw_line(c + Vector2(-r * 0.9, -r * 0.15), c + Vector2(r * 0.9, -r * 0.15),
				col, w * 0.75, true)
		"tin":
			_ellipse(ci, c + Vector2(0, -r * 0.55), r * 0.6, r * 0.22, w, col)
			ci.draw_line(c + Vector2(-r * 0.6, -r * 0.55), c + Vector2(-r * 0.6, r * 0.6),
				col, w, true)
			ci.draw_line(c + Vector2(r * 0.6, -r * 0.55), c + Vector2(r * 0.6, r * 0.6),
				col, w, true)
			_ellipse(ci, c + Vector2(0, r * 0.6), r * 0.6, r * 0.22, w, col)
		"patch":
			ci.draw_line(c + Vector2(-r * 0.85, 0), c + Vector2(r * 0.85, 0), col, w * 1.5, true)
			ci.draw_line(c + Vector2(0, -r * 0.85), c + Vector2(0, r * 0.85), col, w * 1.5, true)
		"sim":
			ci.draw_polyline(PackedVector2Array([
				c + Vector2(-r * 0.7, -r * 0.9), c + Vector2(r * 0.35, -r * 0.9),
				c + Vector2(r * 0.7, -r * 0.5), c + Vector2(r * 0.7, r * 0.9),
				c + Vector2(-r * 0.7, r * 0.9), c + Vector2(-r * 0.7, -r * 0.9)]),
				col, w, true)
			ci.draw_rect(Rect2(c + Vector2(-r * 0.3, -r * 0.25),
				Vector2(r * 0.6, r * 0.7)), col, false, w * 0.7)
		"key":
			ci.draw_arc(c + Vector2(-r * 0.42, 0), r * 0.42, 0.0, TAU, 18, col, w, true)
			ci.draw_line(c + Vector2(0, 0), c + Vector2(r * 0.95, 0), col, w, true)
			ci.draw_line(c + Vector2(r * 0.6, 0), c + Vector2(r * 0.6, r * 0.42), col, w, true)
			ci.draw_line(c + Vector2(r * 0.9, 0), c + Vector2(r * 0.9, r * 0.35), col, w, true)
		"slate":
			ci.draw_rect(Rect2(c + Vector2(-r * 0.75, -r * 0.95),
				Vector2(r * 1.5, r * 1.9)), col, false, w)
			ci.draw_rect(Rect2(c + Vector2(-r * 0.42, -r * 0.6),
				Vector2(r * 0.84, r * 1.0)), col, false, w * 0.7)
		"scrap":
			ci.draw_polyline(PackedVector2Array([
				c + Vector2(-r * 0.9, r * 0.5), c + Vector2(-r * 0.3, -r * 0.8),
				c + Vector2(r * 0.2, r * 0.1), c + Vector2(r * 0.9, -r * 0.6)]),
				col, w, true)
			ci.draw_line(c + Vector2(-r * 0.9, r * 0.9), c + Vector2(r * 0.9, r * 0.9),
				col, w * 0.8, true)
		_:
			ci.draw_arc(c, r * 0.8, 0.0, TAU, 20, col, w, true)


# ===========================================================================
# PRIMITIVES
# ===========================================================================

static func _chevrons(ci: CanvasItem, c: Vector2, r: float, w: float, col: Color,
		dir: Vector2, count: int) -> void:
	var perp := Vector2(-dir.y, dir.x)
	for i in count:
		var offset := dir * (r * (-0.32 + float(i) * 0.66))
		var tip := c + offset + dir * r * 0.5
		ci.draw_line(tip, c + offset - dir * r * 0.14 + perp * r * 0.64, col, w, true)
		ci.draw_line(tip, c + offset - dir * r * 0.14 - perp * r * 0.64, col, w, true)


static func _arrow(ci: CanvasItem, from: Vector2, to: Vector2, head: float,
		w: float, col: Color) -> void:
	ci.draw_line(from, to, col, w, true)
	var dir := (to - from).normalized()
	var perp := Vector2(-dir.y, dir.x)
	ci.draw_line(to, to - dir * head + perp * head * 0.72, col, w, true)
	ci.draw_line(to, to - dir * head - perp * head * 0.72, col, w, true)


static func _polygon_outline(ci: CanvasItem, c: Vector2, r: float, sides: int,
		w: float, col: Color, rotation: float = 0.0) -> void:
	var pts := PackedVector2Array()
	for i in sides:
		var a := TAU * (float(i) + 0.5) / float(sides) + rotation
		pts.append(c + Vector2(cos(a), sin(a)) * r)
	pts.append(pts[0])
	ci.draw_polyline(pts, col, w, true)


static func _diamond(ci: CanvasItem, c: Vector2, r: float, w: float, col: Color) -> void:
	ci.draw_polyline(PackedVector2Array([
		c + Vector2(0, -r), c + Vector2(r, 0), c + Vector2(0, r),
		c + Vector2(-r, 0), c + Vector2(0, -r)]), col, w, true)


static func _ellipse(ci: CanvasItem, c: Vector2, rx: float, ry: float,
		w: float, col: Color) -> void:
	var pts := PackedVector2Array()
	for i in 25:
		var a := TAU * float(i) / 24.0
		pts.append(c + Vector2(cos(a) * rx, sin(a) * ry))
	ci.draw_polyline(pts, col, w, true)


static func _star(ci: CanvasItem, c: Vector2, r: float, w: float, col: Color) -> void:
	var pts := PackedVector2Array()
	for i in 11:
		var a := TAU * float(i) / 10.0 - PI * 0.5
		var radius: float = r if i % 2 == 0 else r * 0.45
		pts.append(c + Vector2(cos(a), sin(a)) * radius)
	ci.draw_polyline(pts, col, w, true)
