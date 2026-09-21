import { useEffect, useMemo, useRef, useState } from 'react';
import { Link, useNavigate } from 'react-router-dom';
import { useStore } from '../state/store';
import { useTimer } from '../state/timer';
import { Card, EmptyState, Screen, Sheet, TopBar } from '../components/ui';
import ExercisePicker from '../components/ExercisePicker';
import NumberStepper from '../components/NumberStepper';
import {
  CheckIcon,
  ChevronLeft,
  ChevronRight,
  DumbbellIcon,
  HistoryIcon,
  PlayIcon,
  PlusIcon,
  TimerIcon,
  TrashIcon,
  TrophyIcon,
} from '../components/Icons';
import { fmtClock, fmtDate, fmtVolume, fmtWeight, relativeDay } from '../lib/format';
import { previousPerformance, sessionVolume } from '../lib/stats';
import type { LoggedSet } from '../lib/types';

export default function Workout() {
  const { state } = useStore();
  return state.activeSession ? <ActiveWorkout /> : <StartWorkout />;
}

/* ------------------------------- start screen ------------------------------ */

function StartWorkout() {
  const navigate = useNavigate();
  const { state, dispatch, buildSession, exerciseName } = useStore();
  const split = state.split;

  const start = (dayId: string | null) => {
    const day = split?.days.find((d) => d.id === dayId) ?? null;
    dispatch({ type: 'startSession', session: buildSession(day) });
    navigate('/workout');
  };

  return (
    <Screen>
      <TopBar title="Start a workout" subtitle="Pick a day from your split" />

      {!split || split.days.length === 0 ? (
        <EmptyState
          icon={<DumbbellIcon size={28} />}
          title="No workout days yet"
          body="Build your split first, then come back to train."
          action={
            <Link to="/builder" className="btn btn-primary h-12 px-6">
              Build my split
            </Link>
          }
        />
      ) : (
        <div className="flex flex-col gap-2.5">
          {split.days.map((day) => (
            <button
              key={day.id}
              type="button"
              onClick={() => start(day.id)}
              className="card flex items-center gap-3 px-4 py-4 text-left active:bg-surface-2"
            >
              <span className="min-w-0 flex-1">
                <span className="block truncate text-lg font-extrabold tracking-tight">{day.name}</span>
                <span className="mt-0.5 block truncate text-xs text-muted">
                  {day.exercises.length === 0
                    ? 'No exercises'
                    : day.exercises
                        .slice(0, 3)
                        .map((x) => exerciseName(x.exerciseId))
                        .join(' · ')}
                </span>
              </span>
              <span className="flex h-11 w-11 shrink-0 items-center justify-center rounded-full bg-volt text-ink">
                <PlayIcon size={16} />
              </span>
            </button>
          ))}
        </div>
      )}

      <button type="button" onClick={() => start(null)} className="btn btn-secondary mt-3 h-12 w-full">
        <PlusIcon size={18} /> Freestyle workout
      </button>
    </Screen>
  );
}

/* ------------------------------ active workout ----------------------------- */

function ActiveWorkout() {
  const navigate = useNavigate();
  const { state, dispatch, exerciseName, buildLoggedExercise } = useStore();
  const timer = useTimer();
  const session = state.activeSession!;
  const unit = state.settings.unit;
  const weightStep = unit === 'kg' ? 2.5 : 5;

  const [index, setIndex] = useState(0);
  const [selectedSetId, setSelectedSetId] = useState<string | null>(null);
  const [picking, setPicking] = useState(false);
  const [finishing, setFinishing] = useState(false);
  const [prFlash, setPrFlash] = useState<string | null>(null);
  const [elapsed, setElapsed] = useState(Date.now() - session.startedAt);
  const chipsRef = useRef<HTMLDivElement>(null);
  const actionRef = useRef<HTMLDivElement>(null);

  const safeIndex = Math.min(index, Math.max(0, session.exercises.length - 1));
  const current = session.exercises[safeIndex];

  useEffect(() => {
    const id = window.setInterval(() => setElapsed(Date.now() - session.startedAt), 1000);
    return () => window.clearInterval(id);
  }, [session.startedAt]);

  // Keep the exercise chip strip following the selected exercise.
  useEffect(() => {
    const el = chipsRef.current?.children[safeIndex] as HTMLElement | undefined;
    el?.scrollIntoView({ block: 'nearest', inline: 'center' });
  }, [safeIndex]);

  useEffect(() => {
    setSelectedSetId(null);
  }, [safeIndex]);

  useEffect(() => {
    if (!prFlash) return;
    const id = window.setTimeout(() => setPrFlash(null), 4000);
    return () => window.clearTimeout(id);
  }, [prFlash]);

  const previous = useMemo(
    () => (current ? previousPerformance(state.history, current.exerciseId) : null),
    [state.history, current]
  );

  const activeSet: LoggedSet | null = useMemo(() => {
    if (!current) return null;
    if (selectedSetId) return current.sets.find((s) => s.id === selectedSetId) ?? null;
    return current.sets.find((s) => !s.done) ?? current.sets[current.sets.length - 1] ?? null;
  }, [current, selectedSetId]);

  const totals = useMemo(() => {
    const done = session.exercises.reduce((n, ex) => n + ex.sets.filter((s) => s.done).length, 0);
    const total = session.exercises.reduce((n, ex) => n + ex.sets.length, 0);
    return { done, total, volume: sessionVolume(session) };
  }, [session]);

  const completeSet = () => {
    if (!current || !activeSet) return;
    const wasDone = activeSet.done;
    dispatch({ type: 'toggleSet', loggedId: current.id, setId: activeSet.id, done: !wasDone });

    if (!wasDone) {
      if ('vibrate' in navigator) navigator.vibrate?.(18);
      timer.start(state.settings.defaultRest);

      const nextUndone = current.sets.find((s) => !s.done && s.id !== activeSet.id);
      setSelectedSetId(nextUndone ? nextUndone.id : null);
      // Keep the primary control clear of the rest timer that just appeared.
      window.setTimeout(() => {
        const rect = actionRef.current?.getBoundingClientRect();
        if (rect && rect.bottom > window.innerHeight - 150) {
          actionRef.current?.scrollIntoView({ block: 'center', behavior: 'smooth' });
        }
      }, 80);
      if (!nextUndone && safeIndex < session.exercises.length - 1) {
        window.setTimeout(() => setIndex((i) => Math.min(i + 1, session.exercises.length - 1)), 450);
      }
    } else {
      setSelectedSetId(activeSet.id);
    }
  };

  // Detect a freshly flagged PR so the banner appears right after the set is saved.
  useEffect(() => {
    if (!current) return;
    const latest = current.sets
      .filter((s) => s.done && s.pr && s.completedAt)
      .sort((a, b) => (b.completedAt ?? 0) - (a.completedAt ?? 0))[0];
    if (latest && Date.now() - (latest.completedAt ?? 0) < 1500) {
      setPrFlash(`${exerciseName(current.exerciseId)} — ${fmtWeight(latest.weight, unit)} × ${latest.reps}`);
    }
  }, [current, exerciseName, unit]);

  const finish = () => {
    const id = session.id;
    const hasSets = session.exercises.some((ex) => ex.sets.some((s) => s.done));
    dispatch({ type: 'finishSession' });
    timer.stop();
    navigate(hasSets ? `/history/${id}` : '/', { replace: true });
  };

  const addExercise = (exerciseId: string) => {
    const logged = buildLoggedExercise({ exerciseId, targetSets: 3, repMin: 8, repMax: 12 });
    dispatch({ type: 'addSessionExercise', exercise: logged });
    setIndex(session.exercises.length);
  };

  return (
    <Screen>
      <TopBar
        title={session.name}
        subtitle={`${fmtClock(elapsed / 1000)} · ${totals.done}/${totals.total} sets · ${fmtVolume(totals.volume, unit)}`}
        right={
          <button
            type="button"
            onClick={() => setFinishing(true)}
            className="btn btn-primary h-10 px-4 text-sm tracking-wide"
          >
            FINISH
          </button>
        }
      />

      {prFlash && (
        <div className="animate-pop mb-3 flex items-center gap-2.5 rounded-xl border border-pr/40 bg-pr/10 px-3.5 py-3 text-pr">
          <TrophyIcon size={20} />
          <div className="min-w-0">
            <div className="text-sm font-extrabold tracking-wide">NEW PR</div>
            <div className="truncate text-xs opacity-80">{prFlash}</div>
          </div>
        </div>
      )}

      {session.exercises.length === 0 ? (
        <EmptyState
          icon={<DumbbellIcon size={28} />}
          title="Empty workout"
          body="Add an exercise to start logging."
          action={
            <button type="button" onClick={() => setPicking(true)} className="btn btn-primary h-12 px-6">
              Add exercise
            </button>
          }
        />
      ) : (
        current && (
          <>
            <div ref={chipsRef} className="hide-scroll -mx-4 mb-3 flex gap-2 overflow-x-auto px-4 pb-1">
              {session.exercises.map((ex, i) => {
                const done = ex.sets.filter((s) => s.done).length;
                const complete = done >= ex.sets.length;
                return (
                  <button
                    key={ex.id}
                    type="button"
                    onClick={() => setIndex(i)}
                    className={`flex shrink-0 items-center gap-1.5 rounded-full px-3.5 py-2 text-xs font-bold whitespace-nowrap ${
                      i === safeIndex
                        ? 'bg-volt text-ink'
                        : complete
                          ? 'bg-surface-2 text-volt'
                          : 'bg-surface-2 text-muted'
                    }`}
                  >
                    {complete && <CheckIcon size={13} strokeWidth={3} />}
                    {exerciseName(ex.exerciseId)}
                    <span className="opacity-60">
                      {done}/{ex.sets.length}
                    </span>
                  </button>
                );
              })}
            </div>

            <Card>
              <div className="flex items-start justify-between gap-3">
                <div className="min-w-0">
                  <Link
                    to={`/progress/exercise/${current.exerciseId}`}
                    className="block truncate text-[1.4rem] leading-tight font-extrabold tracking-tight"
                  >
                    {exerciseName(current.exerciseId)}
                  </Link>
                  <p className="tnum mt-0.5 text-sm text-muted">
                    Target {current.targetSets} × {current.repMin}–{current.repMax}
                  </p>
                </div>
                <Link
                  to={`/progress/exercise/${current.exerciseId}`}
                  aria-label="Exercise history"
                  className="flex h-9 w-9 shrink-0 items-center justify-center rounded-full bg-surface-2 text-muted"
                >
                  <HistoryIcon size={17} />
                </Link>
              </div>

              {current.notes && <p className="mt-2 text-xs text-faint italic">{current.notes}</p>}

              <div className="mt-3 rounded-xl bg-surface-2 px-3.5 py-3">
                <div className="label-caps">
                  {previous ? `Last time · ${relativeDay(previous.date)}` : 'Last time'}
                </div>
                {previous ? (
                  <div className="tnum mt-1.5 flex flex-wrap gap-x-3 gap-y-1 text-sm font-semibold">
                    {previous.sets.map((s, i) => (
                      <span key={s.id ?? i}>
                        {s.weight} × {s.reps}
                      </span>
                    ))}
                  </div>
                ) : (
                  <p className="mt-1 text-sm text-faint">First time logging this — set the baseline.</p>
                )}
              </div>

              <div className="mt-4 flex flex-col gap-1.5">
                {current.sets.map((set, i) => {
                  const isActive = activeSet?.id === set.id;
                  return (
                    <button
                      key={set.id}
                      type="button"
                      onClick={() => setSelectedSetId(set.id)}
                      className={`flex items-center gap-3 rounded-xl border px-3 py-2.5 text-left transition-colors ${
                        isActive
                          ? 'border-volt/70 bg-volt/[0.08]'
                          : set.done
                            ? 'border-line bg-surface-2'
                            : 'border-line bg-transparent'
                      }`}
                    >
                      <span className="label-caps w-11 shrink-0 whitespace-nowrap">Set {i + 1}</span>
                      <span className="tnum flex-1 text-lg font-extrabold">
                        {set.weight}
                        <span className="ml-0.5 text-[0.6875rem] font-bold text-faint">{unit}</span>
                        <span className="mx-1.5 text-faint">×</span>
                        {set.reps}
                      </span>
                      {set.pr && set.done && (
                        <span className="flex items-center gap-1 rounded-full bg-pr/15 px-2 py-0.5 text-[0.625rem] font-extrabold text-pr">
                          PR
                        </span>
                      )}
                      <span
                        className={`flex h-7 w-7 shrink-0 items-center justify-center rounded-full ${
                          set.done ? 'bg-volt text-ink' : 'border border-line text-faint'
                        }`}
                      >
                        {set.done ? <CheckIcon size={15} strokeWidth={3} /> : ''}
                      </span>
                    </button>
                  );
                })}
              </div>

              <div className="mt-3 flex gap-2">
                <button
                  type="button"
                  onClick={() => dispatch({ type: 'addSet', loggedId: current.id })}
                  className="btn btn-ghost h-10 flex-1 text-xs"
                >
                  <PlusIcon size={15} /> Add set
                </button>
                {current.sets.length > 1 && activeSet && (
                  <button
                    type="button"
                    onClick={() => {
                      dispatch({ type: 'removeSet', loggedId: current.id, setId: activeSet.id });
                      setSelectedSetId(null);
                    }}
                    className="btn btn-ghost h-10 flex-1 text-xs"
                  >
                    <TrashIcon size={15} /> Remove set
                  </button>
                )}
              </div>
            </Card>

            {activeSet && (
              <div className="mt-3" ref={actionRef}>
                <div className="flex gap-3">
                  <NumberStepper
                    label="Weight"
                    suffix={unit}
                    value={activeSet.weight}
                    step={weightStep}
                    decimals
                    max={2000}
                    onChange={(weight) =>
                      dispatch({ type: 'updateSet', loggedId: current.id, setId: activeSet.id, patch: { weight } })
                    }
                  />
                  <NumberStepper
                    label="Reps"
                    value={activeSet.reps}
                    step={1}
                    max={200}
                    onChange={(reps) =>
                      dispatch({ type: 'updateSet', loggedId: current.id, setId: activeSet.id, patch: { reps } })
                    }
                  />
                </div>

                <button
                  type="button"
                  onClick={completeSet}
                  className={`btn mt-3 h-16 w-full text-lg tracking-wide ${
                    activeSet.done ? 'btn-secondary' : 'btn-primary'
                  }`}
                >
                  {activeSet.done ? (
                    'UNDO SET'
                  ) : (
                    <>
                      <CheckIcon size={22} strokeWidth={2.6} /> COMPLETE SET
                    </>
                  )}
                </button>
              </div>
            )}

            <div className="mt-3 flex items-center gap-2">
              <span className="text-faint">
                <TimerIcon size={17} />
              </span>
              <div className="hide-scroll flex flex-1 gap-1.5 overflow-x-auto">
                {state.settings.restPresets.map((secs) => (
                  <button
                    key={secs}
                    type="button"
                    onClick={() => timer.start(secs)}
                    className="shrink-0 rounded-lg bg-surface-2 px-3 py-2 text-xs font-bold text-muted active:bg-surface-3"
                  >
                    {secs < 120 ? `${secs}s` : `${secs / 60}m`}
                  </button>
                ))}
              </div>
            </div>

            <div className="mt-4 flex gap-2">
              <button
                type="button"
                disabled={safeIndex === 0}
                onClick={() => setIndex(safeIndex - 1)}
                className="btn btn-secondary h-12 flex-1 disabled:opacity-30"
              >
                <ChevronLeft size={18} /> Prev
              </button>
              <button
                type="button"
                disabled={safeIndex >= session.exercises.length - 1}
                onClick={() => setIndex(safeIndex + 1)}
                className="btn btn-secondary h-12 flex-1 disabled:opacity-30"
              >
                Next <ChevronRight size={18} />
              </button>
            </div>

            <div className="mt-3 flex gap-2">
              <button type="button" onClick={() => setPicking(true)} className="btn btn-ghost h-11 flex-1 text-xs">
                <PlusIcon size={15} /> Add exercise
              </button>
              <button
                type="button"
                onClick={() => {
                  dispatch({ type: 'removeSessionExercise', loggedId: current.id });
                  setIndex(Math.max(0, safeIndex - 1));
                }}
                className="btn btn-ghost h-11 flex-1 text-xs"
              >
                <TrashIcon size={15} /> Remove exercise
              </button>
            </div>
          </>
        )
      )}

      <ExercisePicker open={picking} onClose={() => setPicking(false)} onPick={addExercise} />

      <Sheet open={finishing} onClose={() => setFinishing(false)} title="Finish workout?">
        <div className="grid grid-cols-3 gap-2.5">
          <SummaryTile label="Sets" value={String(totals.done)} />
          <SummaryTile label="Volume" value={fmtVolume(totals.volume, unit)} />
          <SummaryTile label="Time" value={fmtClock(elapsed / 1000)} />
        </div>
        <p className="mt-4 text-sm text-muted">
          {totals.done > 0
            ? `${fmtDate(Date.now())} · Unfinished sets are dropped, completed sets are saved to your history.`
            : 'Nothing has been logged yet, so this workout will simply be discarded.'}
        </p>
        <button type="button" onClick={finish} className="btn btn-primary mt-5 h-14 w-full tracking-wide">
          {totals.done > 0 ? 'SAVE WORKOUT' : 'DISCARD'}
        </button>
        <button
          type="button"
          onClick={() => {
            dispatch({ type: 'discardSession' });
            timer.stop();
            setFinishing(false);
            navigate('/', { replace: true });
          }}
          className="btn btn-ghost mt-2.5 h-12 w-full text-danger"
        >
          Discard workout
        </button>
        <button type="button" onClick={() => setFinishing(false)} className="btn btn-ghost mt-2.5 h-12 w-full">
          Keep training
        </button>
      </Sheet>
    </Screen>
  );
}

function SummaryTile({ label, value }: { label: string; value: string }) {
  return (
    <div className="rounded-xl bg-surface-2 px-3 py-3 text-center">
      <div className="label-caps">{label}</div>
      <div className="stat-value mt-1 text-lg font-extrabold">{value}</div>
    </div>
  );
}
