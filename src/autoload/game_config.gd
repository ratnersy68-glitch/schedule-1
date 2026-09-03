extends Node
## Central tuning table.
##
## Every balance number the designer might want to touch lives here so that
## gameplay scripts stay free of magic constants. Values are deliberately
## grouped by system and documented with their unit.

# --- Identity --------------------------------------------------------------
const GAME_TITLE := "UNDERLIGHT"
const GAME_SUBTITLE := "Cobalt Bay"
const SAVE_VERSION := 4
const MAX_SAVE_SLOTS := 3
const AUTOSAVE_SLOT := 0

# --- World clock -----------------------------------------------------------
## Real seconds that make up one in-game hour. 60s => a 24 minute day.
const SECONDS_PER_GAME_HOUR := 60.0
const START_DAY := 1
const START_HOUR := 8.0
const CURFEW_HOUR := 23      # enforcement is more aggressive after this
const DAWN_HOUR := 6
const DUSK_HOUR := 19

# --- Player movement (metres / second) -------------------------------------
const WALK_SPEED := 3.4
const SPRINT_SPEED := 6.3
const CROUCH_SPEED := 1.7
const ACCELERATION := 12.0
const AIR_ACCELERATION := 2.5
const FRICTION := 14.0
const JUMP_VELOCITY := 6.0
const STAND_HEIGHT := 1.8
const CROUCH_HEIGHT := 1.1
const CAMERA_EYE_OFFSET := 0.15   # below capsule top
const MAX_PITCH_DEG := 88.0

# --- Stamina ---------------------------------------------------------------
const STAMINA_MAX := 100.0
const STAMINA_SPRINT_DRAIN := 13.0   # per second
const STAMINA_JUMP_COST := 9.0
const STAMINA_REGEN := 16.0          # per second when not sprinting
const STAMINA_REGEN_DELAY := 0.9     # seconds after sprinting stops
const STAMINA_SPRINT_MIN := 8.0      # cannot start a sprint below this

# --- Health ----------------------------------------------------------------
const HEALTH_MAX := 100.0
const HEALTH_REGEN := 1.4            # per second, out of combat
const HEALTH_REGEN_DELAY := 6.0
const FALL_DAMAGE_THRESHOLD := 9.0   # m/s downward
const FALL_DAMAGE_SCALE := 7.0

# --- Interaction -----------------------------------------------------------
const INTERACT_RANGE := 2.6
const INTERACT_RADIUS := 0.22        # shape-cast forgiveness for touch aiming
const CARRY_DISTANCE := 0.75

# --- Inventory -------------------------------------------------------------
const BASE_INVENTORY_SLOTS := 8
const MAX_INVENTORY_SLOTS := 24
const DEFAULT_STACK_SIZE := 20

# --- Economy ---------------------------------------------------------------
const STARTING_CASH := 140
const STARTING_BANK := 0
const BANK_DAILY_INTEREST := 0.004   # 0.4% per in-game day on positive balance
const LAUNDER_FEE := 0.12            # cash -> bank conversion fee
const PRICE_MEMORY := 0.82           # market price smoothing per tick
const DEMAND_RECOVERY := 0.05        # per hour, back toward 1.0
const SATURATION_PER_UNIT := 0.035   # demand lost per unit sold in a district
const MAX_PRICE_MULT := 2.4
const MIN_PRICE_MULT := 0.45

# --- Quality ---------------------------------------------------------------
## Quality is an int 0..4 mapped to these names and price multipliers.
const QUALITY_NAMES := ["Dull", "Clear", "Vivid", "Radiant", "Immaculate"]
const QUALITY_MULTIPLIERS := [0.6, 0.85, 1.15, 1.6, 2.3]
const QUALITY_COLORS := [
	Color(0.55, 0.58, 0.62),
	Color(0.55, 0.78, 0.92),
	Color(0.36, 0.72, 1.0),
	Color(0.66, 0.45, 1.0),
	Color(1.0, 0.78, 0.35),
]

# --- Reputation ------------------------------------------------------------
const REP_MAX := 100.0
const REP_MIN := -50.0
const REP_PER_GOOD_DEAL := 1.1
const REP_LOSS_PER_REFUSAL := 0.8
const REP_DECAY_PER_DAY := 0.35

# --- Progression -----------------------------------------------------------
const XP_CURVE_BASE := 240
const XP_CURVE_POWER := 1.34
const MAX_LEVEL := 40
const SKILL_POINTS_PER_LEVEL := 1

# --- Enforcement -----------------------------------------------------------
const SUSPICION_MAX := 100.0
const SUSPICION_DECAY := 1.6         # per second when unobserved
const SUSPICION_DECAY_HIDDEN := 4.0  # per second while crouched & out of sight
const SUSPICION_PER_PUBLIC_DEAL := 22.0
const SUSPICION_PER_SPRINT_NEAR_OFFICER := 6.0
const SUSPICION_CARRY_PENALTY := 0.35 # per contraband unit carried, per second in view
const WANTED_THRESHOLDS := [0.0, 100.0, 240.0, 430.0, 700.0]
const WANTED_DECAY_PER_SECOND := 3.2
const BUST_FINE_BASE := 120
const BUST_FINE_PER_LEVEL := 240
const BUST_SEIZE_FRACTION := [0.0, 0.35, 0.6, 0.85, 1.0]
const SHUTDOWN_HOURS := [0, 0, 4, 10, 20]

# --- Vehicles --------------------------------------------------------------
const VEHICLE_ENTER_RANGE := 3.0

# --- Performance -----------------------------------------------------------
const NPC_ACTIVE_RADIUS := 62.0      # full AI + animation
const NPC_SIM_RADIUS := 140.0        # cheap schedule simulation only
const NPC_CULL_RADIUS := 165.0       # despawn to pool
const MAX_ACTIVE_NPCS := 26
const AI_TICKS_PER_SECOND := 6.0     # brain updates, staggered across frames
const LOD_NEAR := 35.0
const LOD_FAR := 95.0


static func quality_name(q: int) -> String:
	return QUALITY_NAMES[clampi(q, 0, QUALITY_NAMES.size() - 1)]


static func quality_multiplier(q: int) -> float:
	return QUALITY_MULTIPLIERS[clampi(q, 0, QUALITY_MULTIPLIERS.size() - 1)]


static func quality_color(q: int) -> Color:
	return QUALITY_COLORS[clampi(q, 0, QUALITY_COLORS.size() - 1)]


static func xp_for_level(level: int) -> int:
	if level <= 1:
		return 0
	return int(XP_CURVE_BASE * pow(float(level - 1), XP_CURVE_POWER))


static func format_money(amount: int) -> String:
	var neg := amount < 0
	var s := str(absi(amount))
	var out := ""
	var count := 0
	for i in range(s.length() - 1, -1, -1):
		out = s[i] + out
		count += 1
		if count % 3 == 0 and i > 0:
			out = "," + out
	return ("-$" if neg else "$") + out


static func format_clock(hour_float: float) -> String:
	var h := int(floor(hour_float)) % 24
	var m := int((hour_float - floor(hour_float)) * 60.0)
	var suffix := "AM" if h < 12 else "PM"
	var h12 := h % 12
	if h12 == 0:
		h12 = 12
	return "%d:%02d %s" % [h12, m, suffix]
