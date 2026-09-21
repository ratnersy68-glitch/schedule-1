import { writeFileSync } from 'node:fs';

const DAY = 86400000;
const uid = (p) => p + Math.random().toString(36).slice(2, 10);

const plan = {
  Push: [['bench-press', 3, 6, 8, 135, 2.5], ['incline-dumbbell-press', 3, 8, 12, 50, 1.25],
         ['dumbbell-shoulder-press', 3, 8, 12, 40, 1.25], ['lateral-raise', 3, 12, 15, 15, 0.5],
         ['tricep-pushdown', 3, 10, 15, 40, 1.25]],
  Pull: [['lat-pulldown', 3, 8, 12, 120, 2.5], ['barbell-row', 3, 6, 10, 115, 2.5],
         ['seated-cable-row', 3, 8, 12, 110, 2.5], ['face-pull', 3, 12, 15, 35, 1],
         ['dumbbell-curl', 3, 10, 12, 25, 0.75]],
  Legs: [['squat', 3, 5, 8, 185, 5], ['romanian-deadlift', 3, 8, 10, 155, 2.5],
         ['leg-press', 3, 10, 12, 270, 5], ['leg-curl', 3, 10, 15, 70, 1.5],
         ['calf-raise', 4, 12, 15, 90, 2]],
};
const names = { Push: 'Push Day', Pull: 'Pull Day', Legs: 'Leg Day' };
const dows = { Push: 1, Pull: 3, Legs: 5 };

const days = Object.entries(plan).map(([key, list]) => ({
  id: uid('day-'), name: names[key], dayOfWeek: dows[key],
  exercises: list.map(([exerciseId, sets, lo, hi]) => ({ id: uid('pe-'), exerciseId, targetSets: sets, repMin: lo, repMax: hi })),
}));

const history = [];
const now = Date.now();
const best = {};
for (let week = 7; week >= 0; week--) {
  for (const [key, list] of Object.entries(plan)) {
    const offset = (week * 7) + (5 - dows[key]);
    const started = now - offset * DAY - 3 * 3600_000;
    if (started > now) continue;
    const exercises = list.map(([exerciseId, setCount, lo, hi, base, step]) => {
      const weight = Math.round((base + (7 - week) * step) * 2) / 2;
      const sets = Array.from({ length: setCount }, (_, i) => {
        const reps = Math.max(lo, hi - i - (week % 2));
        const e1 = weight * (1 + reps / 30);
        const pr = e1 > (best[exerciseId] ?? 0) + 0.001;
        if (pr) best[exerciseId] = e1;
        return { id: uid('set-'), weight, reps, done: true, touched: true, pr, completedAt: started + i * 180000 };
      });
      return { id: uid('lex-'), exerciseId, targetSets: setCount, repMin: lo, repMax: hi, sets };
    });
    history.push({
      id: uid('ses-'), dayId: days.find((d) => d.name === names[key]).id, name: names[key],
      startedAt: started, finishedAt: started + (48 + Math.round(Math.random() * 14)) * 60000, exercises,
    });
  }
}
history.sort((a, b) => b.finishedAt - a.finishedAt);

const payload = {
  app: 'forge-training-log', version: 1, exportedAt: new Date().toISOString(),
  data: {
    version: 1, onboarded: true,
    split: { id: uid('split-'), name: 'Push / Pull / Legs', template: 'ppl', daysPerWeek: 3, days },
    customExercises: [], activeSession: null, history,
    settings: { unit: 'lb', defaultRest: 90, restPresets: [30, 60, 90, 120, 180], soundOn: true },
  },
};
writeFileSync(process.argv[2], JSON.stringify(payload, null, 2));
console.log('seeded', history.length, 'workouts');
