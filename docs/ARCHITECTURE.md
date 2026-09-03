# Underlight — Architecture

## Principles

1. **No system holds a reference to another system.** Everything talks through
   `EventBus`. Economy does not know the UI exists; the HUD does not know who
   produced a toast.
2. **Content is data, code is rules.** Items, recipes, districts, properties,
   characters, missions, skills and vehicles are plain dictionaries in
   `src/data/`. Adding a product is a dictionary entry, not a code change.
3. **State lives in one place.** `GameState` is the only thing that owns player
   truth. Services read and mutate it; none of them keep a private copy.
4. **The simulation runs on the clock, not the frame.** Production, wages,
   sales and market drift are driven by in-game hours, so they resolve
   correctly whether the player is present, in a menu, or was asleep.
5. **Nothing binary.** The city is generated, the audio is synthesised, the UI
   is drawn. The repository is text.

---

## Layout

```
project.godot          autoloads, input map, mobile render settings
export_presets.cfg     Android / iOS / desktop

src/
  autoload/            singletons, loaded in dependency order
    event_bus.gd         every cross-system signal, no state
    game_config.gd       all balance constants and formatters
    game_data.gd         loads and caches the content databases, POI registry
    settings_service.gd  persisted controls / graphics / audio / gameplay
    player_input.gd      touch + keyboard + gamepad merged into one API
    game_state.gd        money, clock, progression, standing, possessions
    economy_service.gd   per-district demand, price drift, event modifiers
    mission_service.gd   offering, objective tracking, world events, endings
    enforcement_service.gd suspicion, wanted, investigations, raids, busts
    audio_director.gd    procedural synthesis, buses, ambience, music mix
    save_service.gd      JSON slots, atomic writes, autosave
    scene_router.gd      transitions with a fade curtain

  data/                static content tables (no logic)
    item_db, recipe_db, district_db, property_db,
    npc_db, mission_db, skill_db, vehicle_db, dialogue_db

  systems/
    inventory/inventory.gd            slot/stack container used by everything
    economy/trade_service.gd          customer offers, bulk lots, suppliers
    production/station_state.gd       one bench's persistent job
    production/production_service.gd  quality model, start, collect
    business/property_state.gd        upgrades, storage, stations, heat
    business/employee.gd              one person on the payroll
    business/business_service.gd      buying, upgrading, hiring, hourly sim
    world/mesh_factory.gd             shared meshes and materials
    world/city_graph.gd               waypoint navigation with A*
    world/city_builder.gd             procedural city generation
    world/world_manager.gd            runtime world: lighting, population, ticks
    npc/npc_agent.gd                  one person, all roles
    npc/npc_schedule.gd               daily timetable resolution
    npc/customer_profile.gd           generated buyers
    perf/object_pool.gd               fixed-size node recycling
    perf/lod_manager.gd               view-distance and shadow policy

  player/                player.gd, interactor.gd, first_person_hands.gd
  interactables/         base + door, pickup, workstation, storage, board,
                         npc, bed
  vehicles/vehicle.gd    arcade driving model

  ui/
    theme/ui_kit.gd      the entire design system: palette, styles, widgets
    hud/                 hud, minimap, touch_controls, virtual_joystick,
                         look_area, touch_button
    screens/             game_screen base, screen_manager, and 13 screens
    phone/               phone shell, map view, and eight apps
    menus/               boot, main menu, animated skyline
    game_ui.gd           assembles the in-game interface layer

scenes/
  player/player.tscn     the first-person rig
  world/game.tscn        world + UI + screen layers
  ui/boot.tscn, main_menu.tscn
  dev/smoke_test.tscn, world_test.tscn

tools/
  smoke_test.gd          106 rules checks
  world_test.gd          67 integration checks
  run_tests.sh           CI entry point
```

---

## Data flow

```
                 ┌─────────────┐
   input ───────▶│ PlayerInput │──▶ Player ──▶ Interactor ──▶ Interactable
                 └─────────────┘                                  │
                                                                  ▼
   ┌──────────┐   signals    ┌──────────┐              EventBus.screen_requested
   │   HUD    │◀────────────▶│ EventBus │◀───────────────────┐    │
   │  Phone   │              └──────────┘                    │    ▼
   │ Screens  │                   ▲  ▲                       │  ScreenManager
   └──────────┘                   │  │                       │
        │                         │  │                       │
        ▼                         │  │                       │
   TradeService ──▶ GameState ◀───┘  └── EconomyService ──────┘
   ProductionService     ▲                MissionService
   BusinessService ──────┘                EnforcementService
        │
        ▼
   SaveService ──▶ user://saves/*.json
```

`GameState` is the hub of *truth*; `EventBus` is the hub of *notification*.
Nothing else is shared.

---

## The clock

`GameState` advances `hour` in `_process` at 60 real seconds per in-game hour
and emits `hour_passed` / `day_passed`. Those two signals drive:

- `EconomyService` — demand recovery, price drift, rival share, bank interest.
- `WorldManager` → `BusinessService.tick_hour()` — employee production, street
  sales, supply runs, retail fronts.
- `WorldManager` → `BusinessService.settle_day()` — wages, upkeep, loyalty,
  resignations, reputation decay.

Production jobs store an **absolute completion hour** rather than a countdown,
so a bench that was started before a save finishes correctly after a load, and
`_sleep_until_morning()` can fast-forward by simply emitting the intervening
hour ticks.

---

## Rendering strategy

The city is designed around draw-call count, because that is what kills mobile
frame rates.

- Buildings, windows, props and lane markings are batched into **one
  `MultiMeshInstance3D` per district per category** — 18 nodes for the whole
  city plus one for road paint — using per-instance colours and a single
  vertex-coloured material.
- Collision is a handful of `StaticBody3D` nodes each holding many box shapes.
- Large buildings additionally emit a `BoxOccluder3D`, budgeted at 70, so the
  renderer can skip whatever stands behind a tower.
- `LodManager` range-culls props first, then window glow, then buildings,
  scaled by the player's view-distance setting.
- Interiors, doors and interactables are real nodes, because the player touches
  them and there are only a few dozen.

Result on the reference build: the entire city is roughly 20 batches.

---

## Population budget

NPCs come from an `ObjectPool` of 26 pre-allocated agents. Every 1.2 seconds
`WorldManager` recycles anyone past the cull radius, spawns named characters
whose schedule has brought them near, and tops up civilians, customers and
patrols to the current district's targets.

Each agent thinks at 6 Hz, staggered by a random initial offset so the cost is
spread across frames rather than spiking. Movement follows the waypoint graph
rather than a navmesh: a runtime navmesh bake is slow on a phone and
unnecessary for a city built from a grid.

---

## Adding content

| To add | Edit | Notes |
|---|---|---|
| An item | `src/data/item_db.gd` | Appears in shops, inventory and pricing automatically |
| A recipe | `src/data/recipe_db.gd` | Shows up on any station of the right family and tier |
| A district | `src/data/district_db.gd` + `CELL_MAP` | Needs a grid cell; the builder does the rest |
| A property | `src/data/property_db.gd` | Placed, reserved and given an interior automatically |
| A character | `src/data/npc_db.gd` (+ `dialogue_db.gd`) | Spawns on their schedule |
| A mission | `src/data/mission_db.gd` | Objectives are tracked by type, no code needed |
| A skill | `src/data/skill_db.gd` | Read via `GameState.skill_effect(key)` |
| A phone app | `src/ui/phone/apps/` + `Phone.APP_CLASSES` | Subclass `PhoneApp`, implement `build()` |
| A screen | `src/ui/screens/` + `ScreenManager.SCREENS` | Subclass `GameScreen`, implement `build_content()` |

`GameData._validate()` runs at boot and pushes an error for any recipe, mission
or property that points at something that does not exist, so content typos fail
loudly rather than producing an empty shop.

---

## Saving

`SaveService` writes a single JSON document per slot containing a version
stamp, a header for the load menu, and one section per service. Writes go to a
temp file and are renamed, so a crash mid-write cannot destroy an existing
save. Every reader uses `.get(key, default)` and drops unknown item, property
and mission ids, so a content update degrades a save rather than breaking it.
