# Underlight — Roadmap

## Phase 1 — Vertical slice ✅

The brief asked for thirteen things in the first playable version. All are in,
and all are reachable in a single unbroken play session.

| # | Requirement | Status |
|---|---|---|
| 1 | A small section of the city | Six full districts, not one |
| 2 | First-person player controller | Walk, sprint, crouch, jump, hands, bob |
| 3 | Mobile controls | Stick, look area, six buttons, fully customisable |
| 4 | One NPC | Ten named characters plus a procedural population |
| 5 | One fictional product | Five, in a tiered chain |
| 6 | Basic production system | Recipes, tiers, additives, quality forecast |
| 7 | Inventory | Slot/stack with quality and packaging variants |
| 8 | Selling system | Street deals, bulk brokerage, supplier trade, fronts |
| 9 | Money system | Cash, bank, laundering, upkeep, payroll, ledger |
| 10 | One property | Seven, each with four upgrade ladders |
| 11 | Basic mission | Ten story chapters, side jobs, events, pressure jobs |
| 12 | Save/load | Three slots, autosave, atomic JSON |
| 13 | Basic phone UI | Eight apps, fully interactive |

## Phase 2 — Expansion ✅

Everything the brief listed as "after the vertical slice" is also in:

- More city areas — all six districts generated and gated by progression.
- More products — the full five-tier chain.
- More NPCs — schedules, roles, relationships, reactions.
- Employees — four assignments, loyalty, wages, resignation.
- Vehicles — five, with storage and discretion values.
- Police — suspicion, four wanted levels, investigations, raids, busts.
- Businesses — fronts, passive revenue, laundering.
- Story missions — a ten-chapter arc.
- Rival businesses — Tidewell share pressure and rival jobs.
- Advanced progression — four skill trees and five endgame paths.

---

## Phase 3 — Next

Ordered by how much they would improve the game per unit of work.

### Feel
- **Haptics.** The settings toggle exists; wire `Input.vibrate_handheld()` to
  sales, busts and production completion.
- **Interaction hold.** `Interactable.hold_seconds` is respected by the data
  model but the touch button does not yet render a hold ring.
- **Footstep surfaces.** Currently indoor/outdoor. Sample the material under
  the player for gravel, metal decking and wet pavement.
- **Camera shake** on crashes and busts.

### World
- **Interior variety.** Every property interior uses the same shell. Vary
  layouts per property archetype.
- **NPC traffic.** The road graph exists and is pathable; nothing drives on it
  yet except the player. Spawn ambient cars from the vehicle pool.
- **Enterable landmarks.** Pell's Corner, the Gull and the Bureau lobby are
  solid volumes; give the three most-visited ones interiors.
- **Weather on surfaces.** Rain particles exist; add wet-surface roughness and
  puddle reflections gated behind the High quality preset.

### Systems
- **Rival territory.** Rival share is a number per district. Make it visible:
  Tidewell runners standing on corners you used to own.
- **Contracts.** Repeatable "deliver N of quality Q by day D" jobs from
  brokers, as a mid-game income floor.
- **Property specialisation.** Let a site declare itself a farm, a lab or a
  warehouse and bias its upgrade ladders accordingly.
- **Reputation consequences.** High standing should visibly change dialogue and
  spawn friendlier crowds; deep negative standing should close shops to you.

### Production
- **Batch queueing.** Let a station hold a short queue rather than one job.
- **Recipe discovery.** Experimenting with unusual additive combinations
  should occasionally reveal a new lattice.

### Presentation
- **Localisation pass.** All strings are inline; extract to a translation CSV.
  `gameplay/language` already exists in settings.
- **Accessibility.** Larger text option, colour-blind-safe quality palette,
  reduced-motion toggle for head bob and camera roll.

### Technical
- **Threaded city build.** 30 ms is fine, but a threaded build would remove the
  hitch entirely on slower hardware.
- **Save compression.** JSON is human-readable and currently small; if late
  saves grow, gzip them.
- **On-device profiling pass.** The budgets are set from first principles and
  validated headlessly. They need confirming on real mid-range hardware.

---

## Known limitations

- Ambient traffic is not implemented; roads carry only the player.
- Named-character interiors are shared shells rather than bespoke rooms.
- Dialogue is a router with personality rather than a deep branching system;
  it deliberately hands off to purpose-built screens.
- The headless test suites cover rules and integration, not input handling or
  rendering; those need a device.
