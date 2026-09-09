# The Break Room

A sports hobby box opening, collecting and grading simulator. Buy sealed hobby
boxes, rip packs, chase parallels and autographs, build a collection, send cards
to a grader and work the market to afford better product.

Hobby configuration only. There are no blasters, hangers, mega boxes, fat packs
or retail packs anywhere in the game.

```bash
npm install        # only needed for the headless flow tests
npm run build      # redraw every asset and rewrite the manifests
npm start          # serve at http://localhost:4173
```

No bundler, no framework, no build step for the game itself. The browser loads
ES modules directly; `npm run build` only regenerates artwork and documentation.

---

## The loop

Earn money → browse hobby boxes → buy one → break the seal → pick a pack → rip it
→ reveal cards one at a time → keep, sell or grade what comes out → wait for the
grader → see the value move → reinvest in better product.

A typical box returns well under its price. The mean sits above it, funded by the
rare hits, so the player trends upward while most individual breaks feel like a
loss. That gap is deliberate and is measured, not guessed — see **Balance** below.

---

## Layout

```
data/          every tunable number and the asset manifest
assets/        generated artwork, organised by kind, plus vendored fonts
styles/        design tokens, base shell, components, card renderer, screens
src/core/      events, RNG, formatting, DOM helper, colour, asset registry, store
src/systems/   independent game systems (no DOM)
src/ui/        components and screens (no game rules)
src/audio/     the modular sound system
src/effects/   canvas particle layer
tools/         asset pipeline, balance simulator, static server, flow tests
```

The rule the codebase follows: **systems never touch the DOM, screens never
contain game rules, and nothing outside `src/core/assets.js` writes an asset path.**

### Systems

| Module | Responsibility |
| --- | --- |
| `DataService` | Loads and indexes every JSON data file |
| `CardSystem` | Creates card instances; owns all valuation rules |
| `OddsSystem` | The only place probabilities are resolved, and the source of published odds |
| `PackSystem` | Builds one pack from a product's slot configuration |
| `BoxSystem` | Builds a sealed box: packs, guaranteed hits, case hit |
| `BreakSystem` | Lifecycle of a purchased box: vault, seal, pack opening |
| `InventorySystem` | The collection: adding pulls, removing sales, patching grades |
| `EconomySystem` | Cash, the ledger, lifetime statistics |
| `MarketSystem` | Simulated per-athlete price index, headlines, sale execution |
| `GradingSystem` | Submissions, grade computation, turnaround, collection |
| `CollectionSystem` | Filtering, sorting, facets, set progress |
| `ProgressionSystem` | XP, levels, product unlocks |
| `ChallengeSystem` | Daily challenges |
| `SaveSystem` | Versioned localStorage persistence with migration |
| `AnimationSystem` | Timing, easing and the reveal choreography table |
| `AudioSystem` | Cue registry: synthesised by default, replaceable with files |

---

## Odds

Packs are not "roll a rarity". Each product points at a profile in
`data/odds.json` describing:

- a fixed number of **base slots** per pack,
- **upgrade slots** that convert base slots into inserts or parallels, each with
  its own chance (a chance above 1 means a guaranteed one plus a roll for another),
- a number of **guaranteed hits** per box, allocated across random packs,
- a **case hit** chance that forces the scarcest print run and can land the 1/1,
- weighted **parallel** and **hit** tables,
- **player tier weights**, separate for base cards and for hits, so premium
  products pull from a checklist skewed toward stars.

`OddsSystem.publishedOdds()` computes the store's odds table from those same
numbers, so what a player reads before buying is literally what the pull uses.

## Valuation

Treatments do not all compound. A parallel's multiplier already prices in its
print run, so scarcity is counted once:

- a **parallel** card uses its own multiplier,
- a **hit** prices off the hit multiplier and the hit's own serial run, with any
  parallel contributing a damped, capped bonus on top.

Without that rule the multipliers stack into six-figure commons. Everything is in
`data/economy.json` under `value`.

## Grading

Four hidden condition values (centering, corners, edges, surface) are rolled once
when a card is pulled and never re-rolled. At submission the grader adds noise
scaled by the service tier, converts each face to a subgrade, and takes a weighted
composite dragged down by the worst face. A flawless card still fails to gem 14%
of the time. The grader is **Apex Grading Authority**, a fictional service.

Measured gem rates: about 13% on entry stock, 35% on luxury stock.

## Balance

`tools/simulate.mjs` opens every product thousands of times and reports real
expected value, hit counts, chase frequency and the grading distribution.

```bash
node tools/simulate.mjs            # report
RUNS=20000 node tools/simulate.mjs # tighter numbers
node tools/simulate.mjs --write    # also price every product from its measured EV
```

`--write` sets each product's price from its measured expected value using the
per-profile target ratios in `data/odds.json`. Expensive boxes deliberately return
more per dollar (about 1.10 at entry, 1.16 at the top), which is what makes
climbing the shelf worth doing.

---

## Artwork

Every image is listed in [`ASSET_MANIFEST.md`](ASSET_MANIFEST.md) and in the
machine-readable `data/assets.manifest.json`: key, path, dimensions, format, what
it is for, and whether it is required.

The runtime resolves art by key through `src/core/assets.js`. To replace a piece:

1. drop a new file at the same path, **or**
2. map the key to any other path in `data/assets.overrides.json`.

Vector files are inlined so they inherit CSS custom properties; raster overrides
are rendered as `<img>`. Cards read five franchise tokens (`--tp`, `--tp-l`,
`--tp-d`, `--ts`, `--ta`) and four product tokens (`--ps`, `--pf`, `--pi`, `--pb`),
which is why one athlete file serves all 24 franchises and one template serves
every card in a product.

Artwork ships as generated vector art produced by `tools/generate-assets.mjs` —
finished, shippable illustration rather than grey-box placeholder, but vector
illustration, not licensed photography. Any slot can be swapped for commissioned
art or photography with no code change.

```bash
npm run assets     # redraw every asset and rewrite the manifest
npm run manifest   # rewrite ASSET_MANIFEST.md from the manifest
```

Type is vendored under `assets/fonts` (Archivo Black, Bebas Neue, Inter, JetBrains
Mono — all open licence) so the game renders identically offline.

## Audio

`src/audio/AudioSystem.js` holds a cue registry. Cues synthesise through WebAudio
by default, so the repository ships no binary audio. Any cue can be replaced by a
file: drop it under `assets/audio/` and list it in `SAMPLE_OVERRIDES`; the sampler
wins whenever a file loads. Reveal cues are chosen from the card itself, so a
numbered card, an autograph, a patch and a one-of-one all sound different.

---

## Testing

Flow tests drive the real interface in headless Chromium and capture each beat.

```bash
npm start &
node tools/playthrough.mjs  ./shots   # buy, break, rip, reveal, tour every screen
node tools/playthrough2.mjs ./shots   # inspect, grade, open slabs, sell
node tools/reveal-test.mjs  ./shots   # buys until a one-of-one drops, then rips it
node tools/shoot.mjs <url> <out.png>  # one-off screenshot with console errors
```

`tools/cardsheet.html?view=parallels|hits|templates|inserts|slabs|sports` renders
contact sheets of the real card component for art review.

## Tinkering

The whole model is exposed at `window.BreakRoom` for tooling and modding:
`state()`, `store`, `navigate()`, `systems.*` and `fastForwardGrading()`.

Keyboard: `1`-`7` jump between screens, `space` advances a card reveal.

## Saving

Everything persists to `localStorage` under `breakroom.save`: cash, the vault,
the collection, slabs, pending submissions, market state, the ledger, statistics,
level, challenges and settings. Writes are debounced and also happen on tab hide
and unload. The Ledger screen can export, import and wipe a save.

---

## Fiction

Every athlete, franchise, league, manufacturer, product and the grading service is
fictional and unaffiliated with any real league, brand or grading company. The data
model matches how real licensed products are described, so a licensed checklist
could be dropped into `data/` without touching code.
