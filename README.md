# Forge Training Log

A personal workout tracker built for use in the gym: build your split, log weight and reps
set by set, and watch the numbers move. Single user, no accounts, no backend — everything
lives on your device and can be exported to a JSON file.

## What it does

**Setup.** Pick how many days a week you train and a split (Push/Pull/Legs, Upper/Lower,
Full Body or Custom). Forge fills in sensible days and exercises, then you rename, reorder
and edit anything you like.

**Home.** Today's workout (or the next scheduled one on a rest day), the week at a glance,
workouts this week, current streak, lifetime total, and one tap to start training.

**Workout builder.** Create days, name them, pin them to a weekday, add exercises from the
library or your own, set target sets and rep ranges, add notes, drag to reorder, delete.

**Logging.** One exercise at a time with big numbers and big buttons. Every exercise shows
what you did last time and pre-fills today's weight from it. Completing a set saves it
immediately and carries the weight forward to the sets you haven't touched. Beat your best
estimated 1RM and the set is marked **NEW PR**.

**Rest timer.** Starts automatically after each set, with 30/60/90/120/180 second presets and
a custom duration. Finishing is announced with a flashing bar, a beep and a vibration.

**Progress.** Totals, streaks, volume and PR counts, plus a progression chart per exercise
that switches between weight, estimated 1RM, volume and reps. Tap any exercise anywhere in
the app to open its full history.

**History and records.** Every completed workout with its exercises, sets, volume and
duration, and a records page that updates itself whenever you beat a lift.

**Backup.** Export and import the whole database as `forge-workout-backup-YYYY-MM-DD.json`.

## Stack

React 19 · TypeScript · Vite 7 · Tailwind CSS 4 · `localStorage` · installable PWA.

No backend, no analytics, no third-party UI or chart libraries — the progression chart is
hand-rolled SVG and the drag-to-reorder uses pointer events so it works on touch.

## Running it

```bash
npm install
npm run dev        # http://localhost:5173
npm run build      # production build into dist/
npm run preview    # serve the production build on :4173
```

Deploy `dist/` to any static host. The service worker and manifest are only active in a
production build, so install-to-home-screen and offline use need `build` + `preview`
(or a real deployment), not `dev`.

`npm run build:static` produces `dist-static/`: the same app with relative asset paths and
hash routing, for hosts that serve from a sub-path and cannot rewrite unknown URLs to
`index.html`. Deep links and refreshes keep working there, but the service worker is left
out, so use the normal `build` when you want offline support.

### Installing on an iPhone

Open the deployed URL in Safari, then Share → Add to Home Screen. It launches full screen
with its own icon and keeps working without a connection.

## Data

Everything is one JSON document in `localStorage` under `forge.training.log.v1`:

| Piece | What it holds |
| --- | --- |
| `split` | Your training days, each with ordered exercises, target sets and rep ranges |
| `history` | Completed sessions, each set with weight, reps and a PR flag |
| `activeSession` | The workout in progress, so closing the app mid-workout loses nothing |
| `customExercises` | Exercises you created on top of the built-in catalog |
| `settings` | Units, default rest, rest presets, timer sound |

Records, streaks, volume and charts are all derived from `history` at read time, so deleting
or importing a workout keeps every number consistent. Estimated 1RM uses the Epley formula,
`weight × (1 + reps / 30)`.

## Tests

End-to-end smoke tests drive a real browser through onboarding, logging, the builder,
backup/restore and the PWA wiring.

```bash
npm run build && npm run preview &   # tests run against http://127.0.0.1:4173
npm run test:e2e
```

Set `FORGE_CHROME=/path/to/chrome` if Playwright's own Chromium is not installed, and
`FORGE_BASE_URL` to test against another origin. Screenshots land in `.screenshots/`.
