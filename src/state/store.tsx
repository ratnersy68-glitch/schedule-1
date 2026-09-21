import {
  createContext,
  useCallback,
  useContext,
  useEffect,
  useMemo,
  useReducer,
  type ReactNode,
} from 'react';
import type {
  AppState,
  ExerciseDef,
  ID,
  LoggedExercise,
  LoggedSet,
  MuscleGroup,
  PlanExercise,
  Session,
  Settings,
  Split,
  WorkoutDay,
} from '../lib/types';
import { CATALOG } from '../lib/exercises';
import { uid } from '../lib/id';
import { loadState, saveState } from '../lib/storage';
import { bestE1rmExcluding, doneSets, e1rm, previousPerformance } from '../lib/stats';

function move<T>(arr: T[], from: number, to: number): T[] {
  if (from === to || from < 0 || to < 0 || from >= arr.length || to >= arr.length) return arr;
  const next = arr.slice();
  const [item] = next.splice(from, 1);
  next.splice(to, 0, item);
  return next;
}

export type Action =
  | { type: 'hydrate'; state: AppState }
  | { type: 'setSplit'; split: Split }
  | { type: 'renameSplit'; name: string }
  | { type: 'addDay'; day: WorkoutDay }
  | { type: 'updateDay'; dayId: ID; patch: Partial<Omit<WorkoutDay, 'id' | 'exercises'>> }
  | { type: 'deleteDay'; dayId: ID }
  | { type: 'reorderDays'; from: number; to: number }
  | { type: 'addPlanExercise'; dayId: ID; exercise: PlanExercise }
  | { type: 'updatePlanExercise'; dayId: ID; planId: ID; patch: Partial<Omit<PlanExercise, 'id'>> }
  | { type: 'deletePlanExercise'; dayId: ID; planId: ID }
  | { type: 'reorderPlanExercises'; dayId: ID; from: number; to: number }
  | { type: 'addCustomExercise'; exercise: ExerciseDef }
  | { type: 'deleteCustomExercise'; exerciseId: ID }
  | { type: 'startSession'; session: Session }
  | { type: 'discardSession' }
  | { type: 'finishSession' }
  | { type: 'addSessionExercise'; exercise: LoggedExercise }
  | { type: 'removeSessionExercise'; loggedId: ID }
  | { type: 'reorderSessionExercises'; from: number; to: number }
  | { type: 'updateSet'; loggedId: ID; setId: ID; patch: Partial<Omit<LoggedSet, 'id'>> }
  | { type: 'toggleSet'; loggedId: ID; setId: ID; done: boolean }
  | { type: 'addSet'; loggedId: ID }
  | { type: 'removeSet'; loggedId: ID; setId: ID }
  | { type: 'updateSettings'; patch: Partial<Settings> }
  | { type: 'importState'; state: AppState }
  | { type: 'deleteSession'; sessionId: ID }
  | { type: 'reset' };

function withSplit(state: AppState, fn: (split: Split) => Split): AppState {
  if (!state.split) return state;
  return { ...state, split: fn(state.split) };
}

function withDay(state: AppState, dayId: ID, fn: (day: WorkoutDay) => WorkoutDay): AppState {
  return withSplit(state, (split) => ({
    ...split,
    days: split.days.map((d) => (d.id === dayId ? fn(d) : d)),
  }));
}

function withSession(state: AppState, fn: (session: Session) => Session): AppState {
  if (!state.activeSession) return state;
  return { ...state, activeSession: fn(state.activeSession) };
}

function withLogged(state: AppState, loggedId: ID, fn: (ex: LoggedExercise) => LoggedExercise): AppState {
  return withSession(state, (session) => ({
    ...session,
    exercises: session.exercises.map((ex) => (ex.id === loggedId ? fn(ex) : ex)),
  }));
}

export function reducer(state: AppState, action: Action): AppState {
  switch (action.type) {
    case 'hydrate':
    case 'importState':
      return action.state;

    case 'setSplit':
      return { ...state, split: action.split, onboarded: true };

    case 'renameSplit':
      return withSplit(state, (split) => ({ ...split, name: action.name }));

    case 'addDay':
      return withSplit(state, (split) => ({
        ...split,
        days: [...split.days, action.day],
        daysPerWeek: split.days.length + 1,
      }));

    case 'updateDay':
      return withDay(state, action.dayId, (day) => ({ ...day, ...action.patch }));

    case 'deleteDay':
      return withSplit(state, (split) => {
        const days = split.days.filter((d) => d.id !== action.dayId);
        return { ...split, days, daysPerWeek: days.length };
      });

    case 'reorderDays':
      return withSplit(state, (split) => ({ ...split, days: move(split.days, action.from, action.to) }));

    case 'addPlanExercise':
      return withDay(state, action.dayId, (day) => ({
        ...day,
        exercises: [...day.exercises, action.exercise],
      }));

    case 'updatePlanExercise':
      return withDay(state, action.dayId, (day) => ({
        ...day,
        exercises: day.exercises.map((x) => (x.id === action.planId ? { ...x, ...action.patch } : x)),
      }));

    case 'deletePlanExercise':
      return withDay(state, action.dayId, (day) => ({
        ...day,
        exercises: day.exercises.filter((x) => x.id !== action.planId),
      }));

    case 'reorderPlanExercises':
      return withDay(state, action.dayId, (day) => ({
        ...day,
        exercises: move(day.exercises, action.from, action.to),
      }));

    case 'addCustomExercise':
      return { ...state, customExercises: [...state.customExercises, action.exercise] };

    case 'deleteCustomExercise':
      return {
        ...state,
        customExercises: state.customExercises.filter((x) => x.id !== action.exerciseId),
      };

    case 'startSession':
      return { ...state, activeSession: action.session };

    case 'discardSession':
      return { ...state, activeSession: null };

    case 'finishSession': {
      const session = state.activeSession;
      if (!session) return state;
      const exercises = session.exercises
        .map((ex) => ({ ...ex, sets: ex.sets.filter((s) => s.done) }))
        .filter((ex) => ex.sets.length > 0);
      if (!exercises.length) return { ...state, activeSession: null };
      const finished: Session = { ...session, exercises, finishedAt: Date.now() };
      return {
        ...state,
        activeSession: null,
        history: [finished, ...state.history],
      };
    }

    case 'deleteSession':
      return { ...state, history: state.history.filter((s) => s.id !== action.sessionId) };

    case 'addSessionExercise':
      return withSession(state, (session) => ({
        ...session,
        exercises: [...session.exercises, action.exercise],
      }));

    case 'removeSessionExercise':
      return withSession(state, (session) => ({
        ...session,
        exercises: session.exercises.filter((ex) => ex.id !== action.loggedId),
      }));

    case 'reorderSessionExercises':
      return withSession(state, (session) => ({
        ...session,
        exercises: move(session.exercises, action.from, action.to),
      }));

    case 'updateSet':
      return withLogged(state, action.loggedId, (ex) => ({
        ...ex,
        sets: ex.sets.map((s) =>
          s.id === action.setId ? { ...s, ...action.patch, touched: true } : s
        ),
      }));

    case 'toggleSet': {
      const session = state.activeSession;
      if (!session) return state;
      const logged = session.exercises.find((ex) => ex.id === action.loggedId);
      if (!logged) return state;
      const target = logged.sets.find((s) => s.id === action.setId);
      if (!target) return state;

      if (!action.done) {
        return withLogged(state, action.loggedId, (ex) => ({
          ...ex,
          sets: ex.sets.map((s) => (s.id === action.setId ? { ...s, done: false, pr: false } : s)),
        }));
      }

      // A set is a PR when it beats every estimated 1RM recorded before it,
      // including earlier sets of the workout in progress.
      const historyBest = bestE1rmExcluding(state.history, logged.exerciseId, session.id);
      const sessionBest = session.exercises
        .filter((ex) => ex.exerciseId === logged.exerciseId)
        .flatMap((ex) => doneSets(ex.sets))
        .filter((s) => s.id !== action.setId)
        .reduce((best, s) => Math.max(best, e1rm(s.weight, s.reps)), 0);
      const threshold = Math.max(historyBest, sessionBest);
      const value = e1rm(target.weight, target.reps);
      const isPr = value > 0 && value > threshold;

      // Carry today's numbers forward to later sets the user hasn't touched yet,
      // so a working weight only has to be entered once.
      return withLogged(state, action.loggedId, (ex) => {
        const at = ex.sets.findIndex((s) => s.id === action.setId);
        return {
          ...ex,
          sets: ex.sets.map((s, i) => {
            if (s.id === action.setId) return { ...s, done: true, pr: isPr, completedAt: Date.now() };
            if (i > at && !s.done && !s.touched) {
              return { ...s, weight: target.weight, reps: target.reps };
            }
            return s;
          }),
        };
      });
    }

    case 'addSet':
      return withLogged(state, action.loggedId, (ex) => {
        const last = ex.sets[ex.sets.length - 1];
        return {
          ...ex,
          sets: [
            ...ex.sets,
            {
              id: uid('set-'),
              weight: last?.weight ?? 0,
              reps: last?.reps ?? ex.repMin,
              done: false,
              touched: last?.touched,
            },
          ],
        };
      });

    case 'removeSet':
      return withLogged(state, action.loggedId, (ex) => ({
        ...ex,
        sets: ex.sets.length > 1 ? ex.sets.filter((s) => s.id !== action.setId) : ex.sets,
      }));

    case 'updateSettings':
      return { ...state, settings: { ...state.settings, ...action.patch } };

    case 'reset':
      return {
        version: state.version,
        onboarded: false,
        split: null,
        customExercises: [],
        activeSession: null,
        history: [],
        settings: state.settings,
      };

    default:
      return state;
  }
}

interface StoreValue {
  state: AppState;
  dispatch: React.Dispatch<Action>;
  allExercises: ExerciseDef[];
  exerciseName: (id: ID) => string;
  exerciseGroup: (id: ID) => MuscleGroup;
  buildSession: (day: WorkoutDay | null) => Session;
  buildLoggedExercise: (plan: Omit<PlanExercise, 'id'>) => LoggedExercise;
}

const StoreContext = createContext<StoreValue | null>(null);

export function StoreProvider({ children }: { children: ReactNode }) {
  const [state, dispatch] = useReducer(reducer, null, loadState);

  useEffect(() => {
    saveState(state);
  }, [state]);

  const allExercises = useMemo(
    () => [...CATALOG, ...state.customExercises].sort((a, b) => a.name.localeCompare(b.name)),
    [state.customExercises]
  );

  const byId = useMemo(() => {
    const map = new Map<ID, ExerciseDef>();
    for (const ex of allExercises) map.set(ex.id, ex);
    return map;
  }, [allExercises]);

  const exerciseName = useCallback((id: ID) => byId.get(id)?.name ?? 'Unknown exercise', [byId]);
  const exerciseGroup = useCallback((id: ID): MuscleGroup => byId.get(id)?.group ?? 'Other', [byId]);

  const historyRef = state.history;

  /** Build a logging row, pre-filled with last workout's weights and reps. */
  const buildLoggedExercise = useCallback(
    (plan: Omit<PlanExercise, 'id'>): LoggedExercise => {
      const prev = previousPerformance(historyRef, plan.exerciseId);
      const sets: LoggedSet[] = Array.from({ length: Math.max(1, plan.targetSets) }, (_, i) => {
        const prior = prev?.sets[i] ?? prev?.sets[prev.sets.length - 1];
        return {
          id: uid('set-'),
          weight: prior?.weight ?? 0,
          reps: prior?.reps ?? plan.repMin,
          done: false,
        };
      });
      return {
        id: uid('lex-'),
        exerciseId: plan.exerciseId,
        targetSets: plan.targetSets,
        repMin: plan.repMin,
        repMax: plan.repMax,
        notes: plan.notes,
        sets,
      };
    },
    [historyRef]
  );

  const buildSession = useCallback(
    (day: WorkoutDay | null): Session => ({
      id: uid('ses-'),
      dayId: day?.id ?? null,
      name: day?.name ?? 'Freestyle Workout',
      startedAt: Date.now(),
      exercises: (day?.exercises ?? []).map((plan) => buildLoggedExercise(plan)),
    }),
    [buildLoggedExercise]
  );

  const value = useMemo(
    () => ({ state, dispatch, allExercises, exerciseName, exerciseGroup, buildSession, buildLoggedExercise }),
    [state, allExercises, exerciseName, exerciseGroup, buildSession, buildLoggedExercise]
  );

  return <StoreContext.Provider value={value}>{children}</StoreContext.Provider>;
}

export function useStore(): StoreValue {
  const ctx = useContext(StoreContext);
  if (!ctx) throw new Error('useStore must be used inside StoreProvider');
  return ctx;
}
