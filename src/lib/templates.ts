import type { PlanExercise, Split, SplitTemplate, WorkoutDay } from './types';
import { uid } from './id';

interface SeedExercise {
  exerciseId: string;
  targetSets: number;
  repMin: number;
  repMax: number;
}

interface SeedDay {
  name: string;
  exercises: SeedExercise[];
}

const e = (exerciseId: string, targetSets: number, repMin: number, repMax: number): SeedExercise => ({
  exerciseId,
  targetSets,
  repMin,
  repMax,
});

const PUSH: SeedDay = {
  name: 'Push Day',
  exercises: [
    e('bench-press', 3, 6, 8),
    e('incline-dumbbell-press', 3, 8, 12),
    e('dumbbell-shoulder-press', 3, 8, 12),
    e('lateral-raise', 3, 12, 15),
    e('tricep-pushdown', 3, 10, 15),
  ],
};

const PULL: SeedDay = {
  name: 'Pull Day',
  exercises: [
    e('lat-pulldown', 3, 8, 12),
    e('barbell-row', 3, 6, 10),
    e('seated-cable-row', 3, 8, 12),
    e('face-pull', 3, 12, 15),
    e('dumbbell-curl', 3, 10, 12),
  ],
};

const LEGS: SeedDay = {
  name: 'Leg Day',
  exercises: [
    e('squat', 3, 5, 8),
    e('romanian-deadlift', 3, 8, 10),
    e('leg-press', 3, 10, 12),
    e('leg-curl', 3, 10, 15),
    e('calf-raise', 4, 12, 15),
  ],
};

const UPPER: SeedDay = {
  name: 'Upper Body',
  exercises: [
    e('bench-press', 3, 6, 8),
    e('barbell-row', 3, 6, 10),
    e('incline-dumbbell-press', 3, 8, 12),
    e('lat-pulldown', 3, 8, 12),
    e('lateral-raise', 3, 12, 15),
    e('dumbbell-curl', 3, 10, 12),
    e('tricep-pushdown', 3, 10, 15),
  ],
};

const LOWER: SeedDay = {
  name: 'Lower Body',
  exercises: [
    e('squat', 3, 5, 8),
    e('romanian-deadlift', 3, 8, 10),
    e('leg-press', 3, 10, 12),
    e('leg-extension', 3, 12, 15),
    e('leg-curl', 3, 10, 15),
    e('calf-raise', 4, 12, 15),
  ],
};

const FULL: SeedDay = {
  name: 'Full Body',
  exercises: [
    e('squat', 3, 5, 8),
    e('bench-press', 3, 6, 8),
    e('barbell-row', 3, 8, 10),
    e('dumbbell-shoulder-press', 3, 8, 12),
    e('romanian-deadlift', 3, 8, 10),
    e('dumbbell-curl', 2, 10, 12),
    e('tricep-pushdown', 2, 10, 15),
  ],
};

/** Day-of-week slots that spread N training days sensibly across a week (0=Sun..6=Sat). */
export const WEEK_SLOTS: Record<number, number[]> = {
  1: [1],
  2: [1, 4],
  3: [1, 3, 5],
  4: [1, 2, 4, 5],
  5: [1, 2, 3, 5, 6],
  6: [1, 2, 3, 4, 5, 6],
  7: [0, 1, 2, 3, 4, 5, 6],
};

function cycle(days: SeedDay[], count: number): SeedDay[] {
  const out: SeedDay[] = [];
  for (let i = 0; i < count; i++) out.push(days[i % days.length]);
  return out;
}

export const TEMPLATE_META: Record<SplitTemplate, { label: string; blurb: string; defaultDays: number }> = {
  ppl: { label: 'Push / Pull / Legs', blurb: 'Rotate push, pull and legs. Great at 3–6 days.', defaultDays: 6 },
  'upper-lower': { label: 'Upper / Lower', blurb: 'Alternate upper and lower body. Great at 4 days.', defaultDays: 4 },
  'full-body': { label: 'Full Body', blurb: 'Hit everything each session. Great at 2–3 days.', defaultDays: 3 },
  custom: { label: 'Custom', blurb: 'Start blank and build your own days.', defaultDays: 4 },
};

function seedFor(template: SplitTemplate, daysPerWeek: number): SeedDay[] {
  switch (template) {
    case 'ppl':
      return cycle([PUSH, PULL, LEGS], daysPerWeek);
    case 'upper-lower':
      return cycle([UPPER, LOWER], daysPerWeek);
    case 'full-body':
      return cycle([FULL], daysPerWeek).map((d, i) => ({
        ...d,
        name: daysPerWeek > 1 ? `Full Body ${String.fromCharCode(65 + i)}` : 'Full Body',
      }));
    case 'custom':
      return Array.from({ length: daysPerWeek }, (_, i) => ({ name: `Day ${i + 1}`, exercises: [] }));
  }
}

export function buildSplit(template: SplitTemplate, daysPerWeek: number): Split {
  const slots = WEEK_SLOTS[daysPerWeek] ?? WEEK_SLOTS[3];
  const seeds = seedFor(template, daysPerWeek);
  const days: WorkoutDay[] = seeds.map((seed, i) => ({
    id: uid('day-'),
    name: seed.name,
    dayOfWeek: slots[i] ?? null,
    exercises: seed.exercises.map(
      (x): PlanExercise => ({
        id: uid('pe-'),
        exerciseId: x.exerciseId,
        targetSets: x.targetSets,
        repMin: x.repMin,
        repMax: x.repMax,
      })
    ),
  }));
  return {
    id: uid('split-'),
    name: TEMPLATE_META[template].label,
    template,
    daysPerWeek,
    days,
  };
}
