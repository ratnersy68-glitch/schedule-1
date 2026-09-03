extends Node
## The Civic Standards Bureau: suspicion, wanted level, raids and busts.
##
## Design intent: pressure, not punishment. Suspicion is highly recoverable,
## wanted levels decay quickly once you break line of sight, and a bust costs
## money and stock but never a run. The Bureau is a tax on carelessness.

var suspicion: float = 0.0        ## 0..100, the "about to be noticed" meter
var wanted_points: float = 0.0    ## raw score behind the star rating
var wanted_level: int = 0         ## 0..4
var is_observed: bool = false     ## an officer currently has line of sight
var observers: int = 0
var last_bust_day: int = -99
var raid_warning_until: float = -1.0

var _player: Node3D = null
var _decay_grace: float = 0.0
var _busted_cooldown: float = 0.0
var _raid_check_accum: float = 0.0


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_PAUSABLE
	EventBus.player_spawned.connect(func(p): _player = p)
	EventBus.day_passed.connect(_on_day_passed)
	reset()


func reset() -> void:
	suspicion = 0.0
	wanted_points = 0.0
	wanted_level = 0
	is_observed = false
	observers = 0
	last_bust_day = -99
	raid_warning_until = -1.0
	_decay_grace = 0.0
	_busted_cooldown = 0.0


func _process(delta: float) -> void:
	if not GameState.clock_running:
		return
	_update_suspicion(delta)
	_update_wanted(delta)
	_update_property_heat(delta)


# ===========================================================================
# SUSPICION
# ===========================================================================

## Called each frame by police NPCs that can see the player.
func report_observation(count: int) -> void:
	observers = count
	is_observed = count > 0


func _update_suspicion(delta: float) -> void:
	var resist := clampf(GameState.skill_effect("suspicion_resist"), 0.0, 0.7)

	if is_observed and _player != null and is_instance_valid(_player):
		# Carrying contraband in view of an officer is the main slow leak.
		var carry := GameState.inventory.contraband_heat()
		carry *= 1.0 - clampf(GameState.skill_effect("carry_heat_reduction"), 0.0, 0.8)
		if _is_hidden():
			carry = 0.0
		var gain := carry * GameConfig.SUSPICION_CARRY_PENALTY * observers
		gain *= 1.0 - resist
		gain *= EconomyService.patrol_multiplier(GameState.current_district)
		if GameState.hour >= GameConfig.CURFEW_HOUR or GameState.hour < 4.0:
			gain *= 1.35
		add_suspicion(gain * delta)
		_decay_grace = 1.2
	else:
		_decay_grace = maxf(0.0, _decay_grace - delta)
		if _decay_grace <= 0.0:
			var decay := GameConfig.SUSPICION_DECAY
			if _is_hidden():
				decay = GameConfig.SUSPICION_DECAY_HIDDEN
			decay *= 1.0 + resist
			if suspicion > 0.0:
				suspicion = maxf(0.0, suspicion - decay * delta)
				EventBus.suspicion_changed.emit(suspicion)

	if suspicion >= GameConfig.SUSPICION_MAX:
		escalate(float(GameConfig.WANTED_THRESHOLDS[1]) + 10.0, "spotted")
		suspicion = 55.0
		EventBus.suspicion_changed.emit(suspicion)


func _is_hidden() -> bool:
	if _player == null or not is_instance_valid(_player):
		return false
	if not _player.has_method("is_crouching"):
		return false
	if not _player.is_crouching():
		return false
	# The Ghost skill makes crouching a hard counter to patrol vision.
	return GameState.skill_effect("crouch_invisible") > 0.0 or observers == 0


func add_suspicion(amount: float) -> void:
	if amount <= 0.0:
		return
	suspicion = clampf(suspicion + amount, 0.0, GameConfig.SUSPICION_MAX)
	EventBus.suspicion_changed.emit(suspicion)


## A discrete suspicious act: a public deal, a sprint past an officer, a
## broken window. Scales with how exposed the player is.
func report_incident(kind: String, magnitude: float = 1.0) -> void:
	var resist := clampf(GameState.skill_effect("suspicion_resist"), 0.0, 0.7)
	var amount := 0.0
	match kind:
		"public_deal":
			amount = GameConfig.SUSPICION_PER_PUBLIC_DEAL * magnitude
		"sprint_near_officer":
			amount = GameConfig.SUSPICION_PER_SPRINT_NEAR_OFFICER * magnitude
		"trespass":
			amount = 18.0 * magnitude
		"crash":
			amount = 12.0 * magnitude
		_:
			amount = 8.0 * magnitude
	if not is_observed:
		amount *= 0.35   # nobody saw it, but word travels
	add_suspicion(amount * (1.0 - resist))
	GameState.add_heat(GameState.current_district, amount * 0.15)


# ===========================================================================
# WANTED
# ===========================================================================

func escalate(points: float, reason: String = "") -> void:
	wanted_points += maxf(0.0, points)
	_recalc_wanted()
	if reason != "" and wanted_level > 0:
		EventBus.toast_requested.emit("The Bureau has you: " + reason, "bad")


func _recalc_wanted() -> void:
	var new_level := 0
	for i in range(GameConfig.WANTED_THRESHOLDS.size() - 1, -1, -1):
		if wanted_points >= GameConfig.WANTED_THRESHOLDS[i]:
			new_level = i
			break
	if new_level != wanted_level:
		wanted_level = new_level
		EventBus.wanted_level_changed.emit(wanted_level)


func _update_wanted(delta: float) -> void:
	if wanted_points <= 0.0:
		return
	if is_observed and wanted_level > 0:
		return  # cannot cool off while they can see you
	var rate := GameConfig.WANTED_DECAY_PER_SECOND * (1.0 + GameState.skill_effect("wanted_decay"))
	wanted_points = maxf(0.0, wanted_points - rate * delta)
	_recalc_wanted()


func clear_wanted(fraction: float = 1.0) -> void:
	wanted_points = maxf(0.0, wanted_points * (1.0 - clampf(fraction, 0.0, 1.0)))
	suspicion *= 1.0 - clampf(fraction, 0.0, 1.0)
	_recalc_wanted()
	EventBus.suspicion_changed.emit(suspicion)


## Called by a patrol NPC that has physically caught the player.
func bust() -> void:
	if _busted_cooldown > 0.0:
		return
	_busted_cooldown = 8.0

	var mitigation := clampf(GameState.skill_effect("bust_mitigation"), 0.0, 0.75)
	var level := clampi(wanted_level, 0, 4)

	var fine := int(round((GameConfig.BUST_FINE_BASE + GameConfig.BUST_FINE_PER_LEVEL * level)
		* (1.0 - mitigation)))
	fine = mini(fine, GameState.cash + GameState.bank)
	if fine > 0:
		GameState.spend(fine, "Bureau fine")

	var seize_fraction: float = float(GameConfig.BUST_SEIZE_FRACTION[level]) * (1.0 - mitigation)
	var seized := GameState.inventory.seize(seize_fraction)
	var seized_units := 0
	for s in seized:
		seized_units += int(s["qty"])

	# A serious bust closes your highest-heat property for a while.
	var shutdown_hours: int = int(GameConfig.SHUTDOWN_HOURS[level])
	var closed_name := ""
	if shutdown_hours > 0:
		var worst: PropertyState = null
		for p in GameState.all_owned_properties():
			if worst == null or p.heat > worst.heat:
				worst = p
		if worst != null:
			worst.shutdown_until = GameState.absolute_hours() + shutdown_hours
			closed_name = worst.display_name()

	GameState.add_reputation(GameState.current_district, -4.0)
	last_bust_day = GameState.day
	wanted_points = 0.0
	suspicion = 0.0
	_recalc_wanted()
	EventBus.suspicion_changed.emit(0.0)

	var penalty := {
		"fine": fine, "seized_units": seized_units, "seized": seized,
		"shutdown_hours": shutdown_hours, "property": closed_name, "level": level,
	}
	EventBus.player_busted.emit(penalty)
	EventBus.toast_requested.emit("Detained. Fined %s, lost %d units."
		% [GameConfig.format_money(fine), seized_units], "bad")


func _on_day_passed(_day: int) -> void:
	for did in GameData.district_ids:
		var district: Dictionary = GameData.district(did)
		var decay := float(district.get("heat_decay", 1.0)) * 6.0
		GameState.add_heat(did, -decay)


# ===========================================================================
# PROPERTY HEAT, INVESTIGATIONS AND RAIDS
# ===========================================================================

func warn_of_raid() -> void:
	raid_warning_until = GameState.absolute_hours() + 8.0
	EventBus.toast_requested.emit("Somebody tipped you off. Move your stock.", "warn")


func _update_property_heat(delta: float) -> void:
	_raid_check_accum += delta
	if _raid_check_accum < 5.0:
		return
	_raid_check_accum = 0.0

	var now := GameState.absolute_hours()
	for p in GameState.all_owned_properties():
		var district: Dictionary = GameData.district(p.district_id())
		# Storing lots of contraband on site attracts attention.
		var stock_pressure := clampf(p.storage.contraband_heat() * 0.02, 0.0, 3.0)
		var district_pressure := GameState.get_heat(p.district_id()) * 0.004
		var gain := (stock_pressure + district_pressure) * float(district.get("heat_gain", 1.0))
		gain *= 1.0 - p.security_rating()
		# Minders on site suppress attention.
		for e in GameState.employees_at(p.id):
			if e.assignment == Employee.ASSIGN_SECURITY:
				gain *= 0.72
		p.heat = clampf(p.heat + gain - 0.35, 0.0, 100.0)

		if p.heat > 70.0 and not p.under_investigation:
			p.under_investigation = true
			EventBus.investigation_opened.emit(p.id)
			EventBus.phone_notification.emit("news", "Bureau interest",
				"%s is being looked at. Clear the stock or raise security."
				% p.display_name())
		elif p.heat < 40.0 and p.under_investigation:
			p.under_investigation = false
			EventBus.investigation_closed.emit(p.id)

		if p.under_investigation and p.heat > 88.0 and not p.is_shutdown(now):
			if randf() < 0.12 * (1.0 - p.security_rating()):
				_raid(p)


func _raid(p: PropertyState) -> void:
	var mitigation := p.security_rating() + clampf(GameState.skill_effect("bust_mitigation"), 0.0, 0.5)
	if raid_warning_until > GameState.absolute_hours():
		mitigation += 0.25   # you were warned and had time to prepare
	var fraction := clampf(0.75 - mitigation, 0.05, 0.9)
	var seized := p.storage.seize(fraction)
	var units := 0
	for s in seized:
		units += int(s["qty"])
	var fine := int(round(units * 22.0 * (1.0 - clampf(GameState.skill_effect("bust_mitigation"), 0.0, 0.6))))
	if fine > 0:
		GameState.spend(fine, "Raid penalty - " + p.display_name())
	p.heat = 25.0
	p.under_investigation = false
	p.shutdown_until = GameState.absolute_hours() + 8.0
	for s in p.stations:
		s.clear_job()
	EventBus.property_raided.emit(p.id)
	EventBus.investigation_closed.emit(p.id)
	EventBus.phone_notification.emit("news", "Raid: " + p.display_name(),
		"The Bureau took %d units and fined you %s. Closed for eight hours."
			% [units, GameConfig.format_money(fine)])
	EventBus.toast_requested.emit("%s was raided" % p.display_name(), "bad")


func threat_label() -> String:
	match wanted_level:
		0:
			return "Clear"
		1:
			return "Noticed"
		2:
			return "Pursued"
		3:
			return "Hunted"
		_:
			return "Citywide"


# --- Serialisation ---------------------------------------------------------

func to_dict() -> Dictionary:
	return {
		"suspicion": suspicion, "wanted_points": wanted_points,
		"last_bust_day": last_bust_day, "raid_warning_until": raid_warning_until,
	}


func from_dict(d: Dictionary) -> void:
	reset()
	suspicion = float(d.get("suspicion", 0.0))
	wanted_points = float(d.get("wanted_points", 0.0))
	last_bust_day = int(d.get("last_bust_day", -99))
	raid_warning_until = float(d.get("raid_warning_until", -1.0))
	_recalc_wanted()
