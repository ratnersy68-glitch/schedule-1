class_name AppMessages
extends PhoneApp
## The message feed. Notifications from every system land here.

static var inbox: Array[Dictionary] = []
const MAX_MESSAGES := 60


func _init() -> void:
	super._init("messages", "Messages", "MSG", UIKit.GOOD)


static func push(app_id: String, title: String, body: String) -> void:
	inbox.push_front({
		"app": app_id, "title": title, "body": body,
		"day": GameState.day, "hour": GameState.hour, "read": false,
	})
	if inbox.size() > MAX_MESSAGES:
		inbox.resize(MAX_MESSAGES)


static func unread_count() -> int:
	var n := 0
	for m in inbox:
		if not bool(m.get("read", false)):
			n += 1
	return n


func badge_count() -> int:
	return unread_count()


func build(container: VBoxContainer) -> void:
	if inbox.is_empty():
		container.add_child(UIKit.body("No messages. Enjoy it while it lasts."))
		return
	var clear := UIKit.button("Mark all read", "ghost")
	clear.pressed.connect(func():
		for m in inbox:
			m["read"] = true
		if phone != null and phone.has_method("refresh_current"):
			phone.refresh_current())
	container.add_child(clear)

	for m in inbox:
		var unread := not bool(m.get("read", false))
		var row := UIKit.panel(UIKit.BG_PANEL if not unread else UIKit.BG_INPUT)
		var v := UIKit.vbox(3)
		row.add_child(v)
		var head := UIKit.hbox(8)
		var t := UIKit.label(String(m.get("title", "")), 15,
			UIKit.TEXT if unread else UIKit.TEXT_DIM)
		t.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		head.add_child(t)
		head.add_child(UIKit.label("Day %d, %s" % [int(m.get("day", 1)),
			GameConfig.format_clock(float(m.get("hour", 0.0)))], 11, UIKit.TEXT_FAINT))
		v.add_child(head)
		v.add_child(UIKit.body(String(m.get("body", ""))))
		m["read"] = true
		container.add_child(row)
