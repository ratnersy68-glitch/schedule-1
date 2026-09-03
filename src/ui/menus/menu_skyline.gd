class_name MenuSkyline
extends Control
## A slowly drifting silhouette of Cobalt Bay behind the title screen.
##
## Drawn procedurally so the menu carries the game's identity without shipping
## an image, and so it costs almost nothing on a phone.

var _towers: Array[Dictionary] = []
var _time := 0.0


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	var rng := RandomNumberGenerator.new()
	rng.seed = 90310
	for layer in 3:
		var count := 14 + layer * 6
		for i in count:
			_towers.append({
				"layer": layer,
				"x": rng.randf(),
				"w": rng.randf_range(0.03, 0.085) / (1.0 + layer * 0.4),
				"h": rng.randf_range(0.12, 0.42) * (1.0 - layer * 0.16),
				"lit": rng.randf() < 0.6,
				"hue": rng.randf(),
			})
	set_process(true)


func _process(delta: float) -> void:
	_time += delta
	queue_redraw()


func _draw() -> void:
	var w := size.x
	var h := size.y
	# Sky gradient.
	for i in 40:
		var t := float(i) / 39.0
		var col := Color(0.05, 0.08, 0.15).lerp(Color(0.13, 0.17, 0.26), t)
		draw_rect(Rect2(0, h * 0.42 * t, w, h * 0.42 / 39.0 + 1.0), col)

	var layer_colors := [Color(0.09, 0.12, 0.19), Color(0.06, 0.09, 0.15), Color(0.04, 0.06, 0.10)]
	for tower in _towers:
		var layer := int(tower["layer"])
		var drift := sin(_time * 0.04 + layer) * 0.01 * float(3 - layer)
		var tx := (float(tower["x"]) + drift) * w
		var tw := float(tower["w"]) * w
		var th := float(tower["h"]) * h
		var base := h * (0.62 + layer * 0.06)
		draw_rect(Rect2(tx, base - th, tw, th), layer_colors[2 - layer])
		if bool(tower["lit"]) and layer >= 1:
			var rows := int(th / 16.0)
			for r in rows:
				for c in maxi(1, int(tw / 12.0)):
					if fmod(float(r * 7 + c * 3) + float(tower["hue"]) * 10.0, 5.0) > 3.0:
						continue
					var flick := 0.6 + 0.4 * sin(_time * 0.8 + r * 1.7 + c * 2.3)
					draw_rect(Rect2(tx + 4.0 + c * 12.0, base - th + 6.0 + r * 16.0, 4.0, 6.0),
						Color(0.95, 0.82, 0.55, 0.55 * flick))

	# Water.
	draw_rect(Rect2(0, h * 0.78, w, h * 0.22), Color(0.03, 0.05, 0.09))
	for i in 26:
		var y := h * 0.79 + i * (h * 0.21 / 26.0)
		var shimmer := 0.02 + 0.03 * sin(_time * 0.6 + i * 0.7)
		draw_line(Vector2(0, y), Vector2(w, y),
			Color(0.30, 0.62, 0.78, shimmer), 1.0)
