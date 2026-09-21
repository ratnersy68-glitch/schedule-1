import type { ExerciseDef, MuscleGroup } from './types';

const def = (id: string, name: string, group: MuscleGroup): ExerciseDef => ({ id, name, group });

/** Built-in exercise catalog. Ids are stable slugs so history survives app updates. */
export const CATALOG: ExerciseDef[] = [
  // Chest
  def('bench-press', 'Bench Press', 'Chest'),
  def('incline-bench-press', 'Incline Bench Press', 'Chest'),
  def('dumbbell-bench-press', 'Dumbbell Bench Press', 'Chest'),
  def('incline-dumbbell-press', 'Incline Dumbbell Press', 'Chest'),
  def('chest-fly', 'Chest Fly', 'Chest'),
  def('pec-deck', 'Pec Deck', 'Chest'),
  def('cable-crossover', 'Cable Crossover', 'Chest'),
  // Back
  def('lat-pulldown', 'Lat Pulldown', 'Back'),
  def('pull-up', 'Pull-Up', 'Back'),
  def('assisted-pull-up', 'Assisted Pull-Up', 'Back'),
  def('seated-cable-row', 'Seated Cable Row', 'Back'),
  def('chest-supported-row', 'Chest Supported Row', 'Back'),
  def('barbell-row', 'Barbell Row', 'Back'),
  def('dumbbell-row', 'Dumbbell Row', 'Back'),
  def('machine-row', 'Machine Row', 'Back'),
  // Shoulders
  def('shoulder-press', 'Shoulder Press', 'Shoulders'),
  def('dumbbell-shoulder-press', 'Dumbbell Shoulder Press', 'Shoulders'),
  def('machine-shoulder-press', 'Machine Shoulder Press', 'Shoulders'),
  def('lateral-raise', 'Lateral Raise', 'Shoulders'),
  def('cable-lateral-raise', 'Cable Lateral Raise', 'Shoulders'),
  def('rear-delt-fly', 'Rear Delt Fly', 'Shoulders'),
  def('face-pull', 'Face Pull', 'Shoulders'),
  // Legs
  def('squat', 'Squat', 'Legs'),
  def('leg-press', 'Leg Press', 'Legs'),
  def('hack-squat', 'Hack Squat', 'Legs'),
  def('leg-extension', 'Leg Extension', 'Legs'),
  def('leg-curl', 'Leg Curl', 'Legs'),
  def('romanian-deadlift', 'Romanian Deadlift', 'Legs'),
  def('calf-raise', 'Calf Raise', 'Legs'),
  // Biceps
  def('dumbbell-curl', 'Dumbbell Curl', 'Biceps'),
  def('barbell-curl', 'Barbell Curl', 'Biceps'),
  def('hammer-curl', 'Hammer Curl', 'Biceps'),
  def('preacher-curl', 'Preacher Curl', 'Biceps'),
  def('cable-curl', 'Cable Curl', 'Biceps'),
  // Triceps
  def('tricep-pushdown', 'Tricep Pushdown', 'Triceps'),
  def('overhead-tricep-extension', 'Overhead Tricep Extension', 'Triceps'),
  def('skull-crushers', 'Skull Crushers', 'Triceps'),
  def('dips', 'Dips', 'Triceps'),
  def('machine-dip', 'Machine Dip', 'Triceps'),
];

export const GROUP_ORDER: MuscleGroup[] = [
  'Chest',
  'Back',
  'Shoulders',
  'Legs',
  'Biceps',
  'Triceps',
  'Core',
  'Cardio',
  'Other',
];

export const GROUP_ACCENT: Record<MuscleGroup, string> = {
  Chest: '#F97362',
  Back: '#5AC8FA',
  Shoulders: '#FFB020',
  Legs: '#A78BFA',
  Biceps: '#4ADE80',
  Triceps: '#F472B6',
  Core: '#38BDF8',
  Cardio: '#FB923C',
  Other: '#9CA3AF',
};
