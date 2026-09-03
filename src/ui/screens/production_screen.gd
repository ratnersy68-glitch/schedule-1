class_name ProductionScreen
extends GameScreen
## Run a station: pick a recipe, slot additives, read the quality forecast,
## and commit.
##
## The forecast is the heart of the production loop, so it is shown before the
## player spends anything: predicted quality tier, the exact price that tier
## fetches in this district, and where the quality came from.

var property_id: String = ""
var station_index: int = 0
var selected_recipe: String = ""
var selected_additives: Array[String] = []

var _forecast_box: VBoxContainer
var _recipe_list: VBoxContainer
var _additive_list: VBoxContainer
var _start_button: Button
var _progress_bar: ProgressBar
var _tick := 0.0


func _ready() -> void:
	property_id = String(payload.get("property", ""))
	station_index = int(payload.get("station", 0))
	var prop := _property()
	set_titles("Production", prop.display_name() if prop != null else "")
	super._ready()
	set_process(true)


func _property() -> PropertyState:
	return GameState.get_property(property_id)


func _station() -> StationState:
	var p := _property()
	if p == null or station_index >= p.stations.size():
		return null
	return p.stations[station_index]


func build_content() -> void:
	var station := _station()
	if station == null:
		content.add_child(UIKit.body("This station is not installed."))
		return
	set_titles(station.display_name(), _property().display_name())

	_progress_bar = UIKit.progress(0.0, UIKit.ACCENT, 10.0)
	content.add_child(_progress_bar)

	_forecast_box = UIKit.vbox(4)
	var forecast_panel := UIKit.panel(UIKit.BG_PANEL)
	forecast_panel.add_child(_forecast_box)
	content.add_child(forecast_panel)

	section("Recipes")
	_recipe_list = UIKit.vbox(6)
	content.add_child(_recipe_list)

	section("Additives  (raise quality, cost materials)")
	_additive_list = UIKit.vbox(6)
	content.add_child(_additive_list)

	_start_button = UIKit.button("Start", "primary")
	_start_button.pressed.connect(_on_start)
	var collect := UIKit.button("Collect")
	collect.pressed.connect(_on_collect)
	actions([collect, _start_button] as Array[Button])


func refresh() -> void:
	var station := _station()
	if station == null or _recipe_list == null:
		return
	_rebuild_recipes(station)
	_rebuild_additives()
	_rebuild_forecast(station)


func _rebuild_recipes(station: StationState) -> void:
	for c in _recipe_list.get_children():
		c.queue_free()
		_recipe_list.remove_child(c)
	var available := RecipeDB.recipes_for_station(station.family, station.tier)
	if available.is_empty():
		_recipe_list.add_child(UIKit.body("No recipes run on this station yet."))
		return
	for recipe_id in available:
		var r: Dictionary = GameData.recipe(recipe_id)
		var known := GameState.knows_recipe(recipe_id)
		var check := ProductionService.can_start(_property(), station, recipe_id, selected_additives)
		var row := UIKit.list_row(
			GameData.item_icon(String(r["output"])),
			GameData.item_color(String(r["output"])),
			String(r["name"]),
			_recipe_inputs_text(r) if known else "Not learned yet",
			"%ds" % int(ProductionService.effective_seconds(recipe_id, selected_additives)),
			UIKit.TEXT_DIM)
		var btn := Button.new()
		btn.flat = true
		btn.set_anchors_preset(Control.PRESET_FULL_RECT)
		btn.mouse_filter = Control.MOUSE_FILTER_STOP
		btn.disabled = not known
		btn.pressed.connect(func():
			selected_recipe = recipe_id
			AudioDirector.play_ui("ui_tap")
			refresh())
		row.add_child(btn)
		if recipe_id == selected_recipe:
			var s := UIKit.panel_style(UIKit.BG_INPUT, 10, UIKit.ACCENT, 2)
			row.add_theme_stylebox_override("panel", s)
		elif not known or not bool(check["ok"]):
			row.modulate.a = 0.55
		_recipe_list.add_child(row)


func _recipe_inputs_text(r: Dictionary) -> String:
	var parts: Array[String] = []
	for item_id in r["inputs"]:
		var need := int(r["inputs"][item_id])
		var have := ProductionService.total_available(
			ProductionService.sources_for(_property()), item_id)
		parts.append("%s %d/%d" % [GameData.item_name(item_id), have, need])
	return " · ".join(parts)


func _rebuild_additives() -> void:
	for c in _additive_list.get_children():
		c.queue_free()
		_additive_list.remove_child(c)
	var slots := ProductionService.additive_slots()
	_additive_list.add_child(UIKit.label(
		"%d of %d slots used" % [selected_additives.size(), slots], 12, UIKit.TEXT_DIM))
	for additive_id in RecipeDB.additive_ids():
		var info: Dictionary = GameData.additives[additive_id]
		var have := ProductionService.total_available(
			ProductionService.sources_for(_property()), additive_id)
		var selected := selected_additives.has(additive_id)
		var row := UIKit.list_row(
			GameData.item_icon(additive_id), GameData.item_color(additive_id),
			GameData.item_name(additive_id),
			"%s   (have %d)" % [String(info.get("note", "")), have],
			"+%d%%" % int(float(info["quality"]) * 100.0),
			UIKit.GOOD if selected else UIKit.TEXT_DIM)
		var btn := Button.new()
		btn.flat = true
		btn.set_anchors_preset(Control.PRESET_FULL_RECT)
		btn.disabled = have <= 0 and not selected
		btn.pressed.connect(func():
			if selected:
				selected_additives.erase(additive_id)
			elif selected_additives.size() < slots:
				selected_additives.append(additive_id)
			else:
				EventBus.toast_requested.emit("No free additive slots", "warn")
			AudioDirector.play_ui("ui_tap")
			refresh())
		row.add_child(btn)
		if selected:
			row.add_theme_stylebox_override("panel",
				UIKit.panel_style(UIKit.BG_INPUT, 10, UIKit.GOOD, 2))
		elif have <= 0:
			row.modulate.a = 0.45
		_additive_list.add_child(row)


func _rebuild_forecast(station: StationState) -> void:
	for c in _forecast_box.get_children():
		c.queue_free()
		_forecast_box.remove_child(c)

	var now := GameState.absolute_hours()
	if station.is_busy(now):
		_forecast_box.add_child(UIKit.label("Running: " +
			String(GameData.recipe(station.recipe_id).get("name", "")), 16, UIKit.ACCENT))
		_forecast_box.add_child(UIKit.stat_line("Finishes in",
			"%ds" % int(station.seconds_remaining(now))))
		_forecast_box.add_child(UIKit.stat_line("Forecast quality",
			GameConfig.quality_name(station.quality), GameConfig.quality_color(station.quality)))
		_start_button.disabled = true
		_start_button.text = "Running"
		return
	if station.is_ready(now):
		_forecast_box.add_child(UIKit.label("Ready to collect", 16, UIKit.GOOD))
		_forecast_box.add_child(UIKit.stat_line("Output", "%d x %s" % [station.output_amount,
			GameData.item_name(String(GameData.recipe(station.recipe_id).get("output", "")))]))
		_start_button.disabled = true
		_start_button.text = "Collect first"
		return

	if selected_recipe == "":
		_forecast_box.add_child(UIKit.body("Choose a recipe below."))
		_start_button.disabled = true
		_start_button.text = "Start"
		return

	var r: Dictionary = GameData.recipe(selected_recipe)
	var prediction := ProductionService.predict_quality(station, selected_recipe,
		selected_additives)
	var quality := int(prediction["quality"])
	var item_id := String(r["output"])
	var unit_price := EconomyService.unit_price(item_id, quality, "", GameState.current_district)
	var amount := int(r.get("output_amount", 1))

	var head := UIKit.hbox(8)
	head.add_child(UIKit.label(String(r["name"]), 17, UIKit.TEXT))
	head.add_child(UIKit.quality_chip(quality))
	_forecast_box.add_child(head)

	_forecast_box.add_child(UIKit.stat_line("Output",
		"%d x %s" % [amount, GameData.item_name(item_id)]))
	_forecast_box.add_child(UIKit.stat_line("Time",
		"%d seconds" % int(ProductionService.effective_seconds(selected_recipe, selected_additives))))
	_forecast_box.add_child(UIKit.stat_line("Value here",
		"%s each  ·  %s total" % [GameConfig.format_money(unit_price),
			GameConfig.format_money(unit_price * amount)], UIKit.MONEY))
	_forecast_box.add_child(UIKit.separator())
	_forecast_box.add_child(UIKit.stat_line("Base lattice",
		"%d%%" % int(float(prediction["base"]) * 100.0)))
	_forecast_box.add_child(UIKit.stat_line("Station tier",
		"+%d%%" % int(float(prediction["station"]) * 100.0)))
	_forecast_box.add_child(UIKit.stat_line("Additives",
		"+%d%%" % int(float(prediction["additives"]) * 100.0),
		UIKit.GOOD if float(prediction["additives"]) > 0.0 else UIKit.TEXT_DIM))
	_forecast_box.add_child(UIKit.stat_line("Your skill",
		"+%d%%" % int(float(prediction["skill"]) * 100.0)))

	var check := ProductionService.can_start(_property(), station, selected_recipe,
		selected_additives)
	_start_button.disabled = not bool(check["ok"])
	_start_button.text = "Start" if bool(check["ok"]) else String(check["reason"])


func _on_start() -> void:
	var station := _station()
	if station == null or selected_recipe == "":
		return
	if ProductionService.start_job(_property(), station, selected_recipe, selected_additives):
		AudioDirector.play("craft_start", -6.0)
		selected_additives.clear()
		refresh()


func _on_collect() -> void:
	var station := _station()
	if station == null:
		return
	var n := ProductionService.collect(_property(), station)
	if n > 0:
		AudioDirector.play("craft_done", -4.0)
	refresh()


func _process(delta: float) -> void:
	_tick += delta
	if _tick < 0.25:
		return
	_tick = 0.0
	var station := _station()
	if station == null or _progress_bar == null:
		return
	var now := GameState.absolute_hours()
	_progress_bar.value = station.progress(now)
	if station.is_ready(now) or station.is_busy(now):
		_rebuild_forecast(station)
