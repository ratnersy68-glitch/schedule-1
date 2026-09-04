# UNDERLIGHT — Cobalt Bay

A first-person, mobile-first open-world business sim built in **Godot 4.3**.

You arrive in the port city of Cobalt Bay with $140 and a rusted shipping
container on Pier 3 that somebody has chalked your name onto. The city runs on
**Lumen** — bio-luminescent crystal light that the Civic Standards Bureau does
not license and cannot stop people wanting. Cultivate it, lattice it, package
it, sell it, and decide how much of the Bay you intend to own before the year
is out.

*Underlight is an original setting with original products, characters,
mechanics and story. Its fictional Lumen crystals are a light source, not a
substance, and nothing in the game describes or resembles a real-world
manufacturing process.*

---

## Play it

A WebGL build is published from `docs/play` to GitHub Pages:

**https://ratnersy68-glitch.github.io/schedule-1/**

It is a single-threaded build, so it needs no special server headers and runs
on a phone browser. First load pulls a 35 MB WebAssembly binary, so give it a
moment on mobile data. Tap the screen once at the title to start, then
**New game**.

**The link only works once Pages is switched on**, which only the repository
owner can do — the Actions token is refused when it tries ("Resource not
accessible by integration"). It is a one-time toggle:

> **Settings > Pages > Build and deployment > Source: Deploy from a branch**
> branch `claude/mobile-business-empire-game-9pm0j3`, folder `/docs`, **Save**

The site goes live a minute or so later. Choosing *Source: GitHub Actions*
instead also works and republishes on every push, via
`.github/workflows/pages.yml`.

Rebuild it with:

```bash
godot --headless --path . --export-release "Web" build/web/index.html
cp build/web/* docs/play/
```

## Running it

```bash
# Godot 4.3 or newer
godot --path .            # play
godot --path . -- --autostart          # skip the menu, straight into a new game
godot --path . -- --autostart --diag   # add a console status read-out
godot --path . -- --autostart --fasttime  # 20x clock, for testing days quickly
```

### Tests

```bash
tools/run_tests.sh /path/to/godot
```

Two headless suites run without a display and exit non-zero on failure:

| Suite | Scene | Covers |
|---|---|---|
| Rules | `scenes/dev/smoke_test.tscn` | content integrity, inventory, economy, production, trade, business, enforcement, missions, save/load |
| World | `scenes/dev/world_test.tscn` | city generation, navigation, population, interactables, UI screens, performance budgets, live saves |

Both currently pass, 173 checks in total.

Godot's headless renderer prints `Parameter "m" is null` once per
`MeshInstance3D`; that is the dummy rasteriser, not the game. `run_tests.sh`
filters it.

---

## What is in the build

**Playable now, end to end.** Walk out of the lockup, buy silt from Dez at
Pell's Corner, lattice a Pale Shard at the bench, wrap it, find a buyer on the
pier, get paid, upgrade the container, hire somebody, and keep going until you
own the Core.

- **First person on foot** — walk, sprint, crouch, jump, head-bob, procedural
  hands, contextual interaction, doors that swing, items you pick up.
- **Six districts** in one contiguous city: Dockside, Ironworks Flats, Old Town
  Rows, Market Row, Meridian Core and Hillcrest. Roads, pavements, alleys,
  interiors, a bay, a skyline.
- **A living population** — named characters on daily schedules, procedural
  customers with buying preferences, Bureau patrols with vision cones,
  civilians who flee when it goes wrong.
- **Production** with recipes, station tiers, optional additives, a visible
  quality forecast, and jobs that keep running while you are elsewhere.
- **A dynamic market** — price moves with quality, packaging, district wealth,
  live demand, your reputation, rival share, world events and the hour.
- **Seven properties** with four independent upgrade ladders each, on-site
  storage, staff, security and Bureau attention.
- **Employees** who produce, sell, haul supplies and guard the door — and who
  quit and steal if you stop paying them.
- **Enforcement** built around pressure rather than punishment: a suspicion
  meter, four wanted levels, investigations, raids, fines, seizures and
  temporary shutdowns. You never lose a run.
- **Vehicles** — five of them, arcade handling tuned for a thumb, with boot
  space and varying discretion.
- **A full phone** — map, contacts, messages, jobs, empire oversight, bank,
  ledger, pockets and settings.
- **Ten story chapters**, repeatable side jobs, rival and Bureau pressure jobs,
  seven random world events and **five distinct endgame paths**.
- **Save and load** — three manual slots plus autosave, JSON, atomic writes.

Everything you see and hear is generated at runtime. The repository contains no
binary assets: the city is built from code, the audio is synthesised at boot,
and the UI is drawn from a single design-token file.

---

## Controls

### Touch (the default)

| Input | Action |
|---|---|
| Left stick | Move (springs to your thumb by default) |
| Right side drag | Look |
| Right side tap | Interact with whatever is centred |
| ✋ | Use / talk / open. Becomes **Exit** in a vehicle |
| » | Sprint. Becomes **Brake** in a vehicle |
| ⌄ | Crouch (toggle by default) |
| ⌃ | Jump |
| ▤ | Pockets |
| ▮ | Phone |

Every button can be dragged to a new position (Settings → Controls → *Move the
buttons around*), and the whole layout mirrors for left-handed play. Stick size,
button size, opacity and sensitivity are all adjustable.

### Keyboard and gamepad

Both are wired to the same actions, so a controller works everywhere.

| | Keyboard | Gamepad |
|---|---|---|
| Move | WASD | Left stick |
| Look | Right-click then mouse | Right stick |
| Interact | E | X |
| Sprint / Crouch | Shift / Ctrl | L2 / R2 |
| Jump | Space | A |
| Phone / Pockets | P / I | Select / Y |
| Pause | Esc | Start |
| Leave vehicle | F | B |

### Driving

The movement stick becomes throttle and steering. Steering authority falls off
with speed so the car stays predictable one-handed.

---

## The loop

1. **Scavenge or buy** materials — Ferro-Silt, Bloomspore, Binder Resin.
2. **Lattice** them at a bench into a Pale Shard. Slot additives if you want
   better quality and can afford the risk.
3. **Package** the batch. Wrapping raises what buyers pay and cuts the heat the
   stock radiates.
4. **Sell** it. Where, when, to whom and how publicly are all real decisions —
   the game prices each of them.
5. **Reinvest** in storage, benches, staff and security. Then do it somewhere
   richer.

Suspicion is the tax on carelessness. Selling in the open at noon in Meridian
with an unwrapped Solar Halo in your pocket and an officer thirty feet away is
a choice the game will let you make, and then charge you for.

---

## Documentation

- [`docs/DESIGN.md`](docs/DESIGN.md) — the setting, systems and balance tables
- [`docs/ARCHITECTURE.md`](docs/ARCHITECTURE.md) — how the code is organised
- [`docs/ROADMAP.md`](docs/ROADMAP.md) — what is built and what comes next

## Requirements

Godot 4.3+. No addons, no external dependencies, no import step beyond Godot's
own. Targets the **Mobile** renderer; ships Android and iOS export presets plus
a desktop one for testing.
