export type ID = string;

export type MuscleGroup =
  | 'Chest'
  | 'Back'
  | 'Shoulders'
  | 'Legs'
  | 'Biceps'
  | 'Triceps'
  | 'Core'
  | 'Cardio'
  | 'Other';

export type Unit = 'lb' | 'kg';

export type SplitTemplate = 'ppl' | 'upper-lower' | 'full-body' | 'custom';

/** An exercise definition — either from the built-in catalog or user-created. */
export interface ExerciseDef {
  id: ID;
  name: string;
  group: MuscleGroup;
  custom?: boolean;
}

/** An exercise as planned inside a workout day. */
export interface PlanExercise {
  id: ID;
  exerciseId: ID;
  targetSets: number;
  repMin: number;
  repMax: number;
  notes?: string;
}

/** A single workout day in the split. dayOfWeek: 0=Sun .. 6=Sat, null = unscheduled. */
export interface WorkoutDay {
  id: ID;
  name: string;
  dayOfWeek: number | null;
  exercises: PlanExercise[];
}

export interface Split {
  id: ID;
  name: string;
  template: SplitTemplate;
  daysPerWeek: number;
  days: WorkoutDay[];
}

export interface LoggedSet {
  id: ID;
  weight: number;
  reps: number;
  done: boolean;
  /** True once the user has typed or stepped this set's numbers themselves. */
  touched?: boolean;
  /** Set at completion time if this set beat the all-time estimated 1RM for the exercise. */
  pr?: boolean;
  completedAt?: number;
}

export interface LoggedExercise {
  id: ID;
  exerciseId: ID;
  targetSets: number;
  repMin: number;
  repMax: number;
  notes?: string;
  sets: LoggedSet[];
}

/** A workout in progress or completed. */
export interface Session {
  id: ID;
  dayId: ID | null;
  name: string;
  startedAt: number;
  finishedAt?: number;
  exercises: LoggedExercise[];
}

export interface Settings {
  unit: Unit;
  defaultRest: number;
  restPresets: number[];
  soundOn: boolean;
}

export interface AppState {
  version: number;
  onboarded: boolean;
  split: Split | null;
  customExercises: ExerciseDef[];
  activeSession: Session | null;
  history: Session[];
  settings: Settings;
}

export interface ExerciseStats {
  exerciseId: ID;
  sessions: number;
  totalSets: number;
  totalVolume: number;
  heaviest: { weight: number; reps: number; date: number } | null;
  bestReps: { weight: number; reps: number; date: number } | null;
  bestE1rm: { weight: number; reps: number; e1rm: number; date: number } | null;
  bestSessionVolume: { volume: number; date: number } | null;
  lastPerformed: number | null;
}
