import type { ExerciseStats, ID, LoggedSet, Session, Split } from './types';

export const DAY_MS = 86_400_000;

/** Epley estimated one-rep max. */
export function e1rm(weight: number, reps: number): number {
  if (weight <= 0 || reps <= 0) return 0;
  if (reps === 1) return weight;
  return weight * (1 + reps / 30);
}

export function dateKey(ts: number): string {
  const d = new Date(ts);
  return `${d.getFullYear()}-${String(d.getMonth() + 1).padStart(2, '0')}-${String(d.getDate()).padStart(2, '0')}`;
}

export function startOfDay(ts: number): number {
  const d = new Date(ts);
  d.setHours(0, 0, 0, 0);
  return d.getTime();
}

/** Monday-based start of week. */
export function startOfWeek(ts: number): number {
  const d = new Date(startOfDay(ts));
  const shift = (d.getDay() + 6) % 7;
  return d.getTime() - shift * DAY_MS;
}

export function startOfMonth(ts: number): number {
  const d = new Date(ts);
  return new Date(d.getFullYear(), d.getMonth(), 1).getTime();
}

export function sessionTime(s: Session): number {
  return s.finishedAt ?? s.startedAt;
}

export function doneSets(sets: LoggedSet[]): LoggedSet[] {
  return sets.filter((s) => s.done && s.reps > 0);
}

export function setVolume(s: LoggedSet): number {
  return Math.max(0, s.weight) * Math.max(0, s.reps);
}

export function sessionVolume(session: Session): number {
  return session.exercises.reduce(
    (total, ex) => total + doneSets(ex.sets).reduce((sum, s) => sum + setVolume(s), 0),
    0
  );
}

export function sessionSetCount(session: Session): number {
  return session.exercises.reduce((n, ex) => n + doneSets(ex.sets).length, 0);
}

export function sessionDuration(session: Session): number {
  if (!session.finishedAt) return Date.now() - session.startedAt;
  return Math.max(0, session.finishedAt - session.startedAt);
}

export interface ExerciseEntry {
  sessionId: ID;
  sessionName: string;
  date: number;
  sets: LoggedSet[];
  volume: number;
  topWeight: number;
  topReps: number;
  bestE1rm: number;
}

/** All completed appearances of an exercise, newest first. */
export function exerciseEntries(history: Session[], exerciseId: ID): ExerciseEntry[] {
  const out: ExerciseEntry[] = [];
  for (const session of history) {
    for (const ex of session.exercises) {
      if (ex.exerciseId !== exerciseId) continue;
      const sets = doneSets(ex.sets);
      if (!sets.length) continue;
      out.push({
        sessionId: session.id,
        sessionName: session.name,
        date: sessionTime(session),
        sets,
        volume: sets.reduce((sum, s) => sum + setVolume(s), 0),
        topWeight: Math.max(...sets.map((s) => s.weight)),
        topReps: Math.max(...sets.map((s) => s.reps)),
        bestE1rm: Math.max(...sets.map((s) => e1rm(s.weight, s.reps))),
      });
    }
  }
  return out.sort((a, b) => b.date - a.date);
}

export function statsFor(history: Session[], exerciseId: ID): ExerciseStats {
  const entries = exerciseEntries(history, exerciseId);
  const stats: ExerciseStats = {
    exerciseId,
    sessions: entries.length,
    totalSets: 0,
    totalVolume: 0,
    heaviest: null,
    bestReps: null,
    bestE1rm: null,
    bestSessionVolume: null,
    lastPerformed: entries[0]?.date ?? null,
  };

  for (const entry of entries) {
    stats.totalSets += entry.sets.length;
    stats.totalVolume += entry.volume;
    if (!stats.bestSessionVolume || entry.volume > stats.bestSessionVolume.volume) {
      stats.bestSessionVolume = { volume: entry.volume, date: entry.date };
    }
    for (const set of entry.sets) {
      if (
        !stats.heaviest ||
        set.weight > stats.heaviest.weight ||
        (set.weight === stats.heaviest.weight && set.reps > stats.heaviest.reps)
      ) {
        stats.heaviest = { weight: set.weight, reps: set.reps, date: entry.date };
      }
      if (
        !stats.bestReps ||
        set.reps > stats.bestReps.reps ||
        (set.reps === stats.bestReps.reps && set.weight > stats.bestReps.weight)
      ) {
        stats.bestReps = { weight: set.weight, reps: set.reps, date: entry.date };
      }
      const est = e1rm(set.weight, set.reps);
      if (!stats.bestE1rm || est > stats.bestE1rm.e1rm) {
        stats.bestE1rm = { weight: set.weight, reps: set.reps, e1rm: est, date: entry.date };
      }
    }
  }
  return stats;
}

/** Best estimated 1RM recorded for an exercise, ignoring one session (the one in progress). */
export function bestE1rmExcluding(history: Session[], exerciseId: ID, excludeSessionId?: ID): number {
  let best = 0;
  for (const session of history) {
    if (session.id === excludeSessionId) continue;
    for (const ex of session.exercises) {
      if (ex.exerciseId !== exerciseId) continue;
      for (const set of doneSets(ex.sets)) best = Math.max(best, e1rm(set.weight, set.reps));
    }
  }
  return best;
}

export interface PreviousPerformance {
  date: number;
  sessionName: string;
  sets: LoggedSet[];
}

/** The most recent completed performance of an exercise. */
export function previousPerformance(
  history: Session[],
  exerciseId: ID,
  excludeSessionId?: ID
): PreviousPerformance | null {
  const entries = exerciseEntries(
    excludeSessionId ? history.filter((s) => s.id !== excludeSessionId) : history,
    exerciseId
  );
  const entry = entries[0];
  return entry ? { date: entry.date, sessionName: entry.sessionName, sets: entry.sets } : null;
}

export interface PersonalRecord {
  exerciseId: ID;
  weight: number;
  reps: number;
  e1rm: number;
  date: number;
  heaviest: number;
  bestReps: number;
  totalVolume: number;
}

/** One record per exercise, ranked by estimated 1RM. */
export function personalRecords(history: Session[]): PersonalRecord[] {
  const ids = new Set<ID>();
  for (const s of history) for (const ex of s.exercises) if (doneSets(ex.sets).length) ids.add(ex.exerciseId);

  const records: PersonalRecord[] = [];
  for (const id of ids) {
    const stats = statsFor(history, id);
    if (!stats.bestE1rm) continue;
    records.push({
      exerciseId: id,
      weight: stats.bestE1rm.weight,
      reps: stats.bestE1rm.reps,
      e1rm: stats.bestE1rm.e1rm,
      date: stats.bestE1rm.date,
      heaviest: stats.heaviest?.weight ?? 0,
      bestReps: stats.bestReps?.reps ?? 0,
      totalVolume: stats.totalVolume,
    });
  }
  return records.sort((a, b) => b.e1rm - a.e1rm);
}

export function prCount(history: Session[]): number {
  return history.reduce(
    (n, s) => n + s.exercises.reduce((m, ex) => m + ex.sets.filter((set) => set.done && set.pr).length, 0),
    0
  );
}

/**
 * Consecutive completed workouts without missing a scheduled training day.
 * Rest days never break the streak; a missed scheduled day does.
 */
export function currentStreak(history: Session[], split: Split | null): number {
  const trained = new Set(history.map((s) => dateKey(sessionTime(s))));
  const scheduledDows = new Set(
    (split?.days ?? []).map((d) => d.dayOfWeek).filter((d): d is number => d !== null)
  );

  let streak = 0;
  const today = startOfDay(Date.now());
  for (let i = 0; i < 400; i++) {
    const ts = today - i * DAY_MS;
    const key = dateKey(ts);
    if (trained.has(key)) {
      streak += 1;
      continue;
    }
    if (i === 0) continue; // today isn't over yet
    if (scheduledDows.has(new Date(ts).getDay())) break; // missed a planned day
  }
  return streak;
}

export interface GlobalStats {
  total: number;
  thisWeek: number;
  thisMonth: number;
  streak: number;
  totalVolume: number;
  totalSets: number;
  prs: number;
  weeklyTarget: number;
}

export function globalStats(history: Session[], split: Split | null): GlobalStats {
  const weekStart = startOfWeek(Date.now());
  const monthStart = startOfMonth(Date.now());
  let thisWeek = 0;
  let thisMonth = 0;
  let totalVolume = 0;
  let totalSets = 0;

  for (const s of history) {
    const t = sessionTime(s);
    if (t >= weekStart) thisWeek += 1;
    if (t >= monthStart) thisMonth += 1;
    totalVolume += sessionVolume(s);
    totalSets += sessionSetCount(s);
  }

  return {
    total: history.length,
    thisWeek,
    thisMonth,
    streak: currentStreak(history, split),
    totalVolume,
    totalSets,
    prs: prCount(history),
    weeklyTarget: split?.days.filter((d) => d.dayOfWeek !== null).length ?? 0,
  };
}

export type Metric = 'weight' | 'reps' | 'volume' | 'e1rm';

export const METRIC_LABEL: Record<Metric, string> = {
  weight: 'Weight',
  reps: 'Reps',
  volume: 'Volume',
  e1rm: 'Est. 1RM',
};

export interface SeriesPoint {
  date: number;
  value: number;
}

export function metricSeries(entries: ExerciseEntry[], metric: Metric): SeriesPoint[] {
  return entries
    .map((entry) => ({
      date: entry.date,
      value:
        metric === 'weight'
          ? entry.topWeight
          : metric === 'reps'
            ? entry.topReps
            : metric === 'volume'
              ? entry.volume
              : Math.round(entry.bestE1rm * 10) / 10,
    }))
    .sort((a, b) => a.date - b.date);
}

/** Which day in the split is scheduled for a given weekday, if any. */
export function dayForWeekday(split: Split | null, weekday: number) {
  return split?.days.find((d) => d.dayOfWeek === weekday) ?? null;
}

/** Today's workout, or the next scheduled one within the coming week. */
export function nextScheduled(split: Split | null, from = Date.now()) {
  if (!split) return null;
  const base = new Date(from);
  for (let i = 0; i < 8; i++) {
    const weekday = (base.getDay() + i) % 7;
    const day = dayForWeekday(split, weekday);
    if (day) return { day, offset: i, weekday };
  }
  return null;
}
