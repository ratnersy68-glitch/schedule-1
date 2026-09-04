class_name PhoneApp
extends RefCounted
## Base class for an app on the player's phone.
##
## Apps are lightweight builders rather than scenes: the phone hands each one a
## container and it fills it. That keeps the whole phone to a handful of small
## files and makes adding an app a one-line registry change.

var id: String = "app"
var title: String = "App"
var glyph: String = "AP"
var accent: Color = UIKit.ACCENT
var badge: int = 0

var phone: Control = null


func _init(app_id: String, app_title: String, app_glyph: String, app_accent: Color) -> void:
	id = app_id
	title = app_title
	glyph = app_glyph
	accent = app_accent


## Fill `container` with the app's UI. Called every time the app is opened or
## the phone asks for a refresh.
func build(_container: VBoxContainer) -> void:
	pass


## Optional: a small number shown on the home-screen icon.
func badge_count() -> int:
	return badge
