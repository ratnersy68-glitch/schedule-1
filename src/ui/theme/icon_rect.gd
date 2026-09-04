class_name IconRect
extends Control
## Draws one named vector icon, tinted and sized to the control.

var icon_name: String = "use":
	set(value):
		icon_name = value
		queue_redraw()

var color: Color = UIKit.TEXT:
	set(value):
		color = value
		queue_redraw()

## Stroke width in pixels. 0 scales the stroke with the icon.
var stroke: float = 0.0:
	set(value):
		stroke = value
		queue_redraw()


static func create(name: String, size: float, tint: Color = UIKit.TEXT) -> IconRect:
	var i := IconRect.new()
	i.icon_name = name
	i.color = tint
	i.custom_minimum_size = Vector2(size, size)
	i.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return i


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func _draw() -> void:
	UIIcons.draw(self, icon_name, Rect2(Vector2.ZERO, size), color, stroke)


func _notification(what: int) -> void:
	if what == NOTIFICATION_RESIZED:
		queue_redraw()
