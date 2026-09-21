import { useMemo } from 'react';
import { Link, useNavigate } from 'react-router-dom';
import { useStore } from '../state/store';
import { Card, Screen, SectionTitle, Stat } from '../components/ui';
import {
  ChartIcon,
  ChevronRight,
  DumbbellIcon,
  EditIcon,
  FlameIcon,
  PlayIcon,
  SettingsIcon,
  TrophyIcon,
} from '../components/Icons';
import { DAY_LETTER, DAY_SHORT, fmtVolume } from '../lib/format';
import { dateKey, globalStats, nextScheduled, sessionTime, startOfWeek } from '../lib/stats';

export default function Home() {
  const navigate = useNavigate();
  const { state, exerciseName, buildSession, dispatch } = useStore();
  const { split, history, activeSession, settings } = state;

  const stats = useMemo(() => globalStats(history, split), [history, split]);
  const next = useMemo(() => nextScheduled(split), [split]);
  const today = new Date();

  const weekDays = useMemo(() => {
    const weekStart = startOfWeek(Date.now());
    const trained = new Set(
      history.filter((s) => sessionTime(s) >= weekStart).map((s) => dateKey(sessionTime(s)))
    );
    return Array.from({ length: 7 }, (_, i) => {
      const ts = weekStart + i * 86_400_000;
      const date = new Date(ts);
      const dow = date.getDay();
      return {
        ts,
        dow,
        letter: DAY_LETTER[dow],
        scheduled: Boolean(split?.days.some((d) => d.dayOfWeek === dow)),
        done: trained.has(dateKey(ts)),
        isToday: dateKey(ts) === dateKey(Date.now()),
      };
    });
  }, [history, split]);

  const todayDay = next && next.offset === 0 ? next.day : null;
  const upcoming = next && next.offset > 0 ? next : null;

  const startWorkout = (dayId: string | null) => {
    if (activeSession) {
      navigate('/workout');
      return;
    }
    const day = split?.days.find((d) => d.id === dayId) ?? null;
    dispatch({ type: 'startSession', session: buildSession(day) });
    navigate('/workout');
  };

  const activeProgress = activeSession
    ? {
        done: activeSession.exercises.reduce((n, ex) => n + ex.sets.filter((s) => s.done).length, 0),
        total: activeSession.exercises.reduce((n, ex) => n + ex.sets.length, 0),
      }
    : null;

  return (
    <Screen>
      <header className="pt-safe flex items-start justify-between pb-4">
        <div>
          <div className="flex items-center gap-2 text-volt">
            <DumbbellIcon size={20} strokeWidth={2.3} />
            <span className="text-[0.6875rem] font-extrabold tracking-[0.22em] uppercase">Forge</span>
          </div>
          <h1 className="mt-1.5 text-[1.65rem] leading-tight font-extrabold tracking-tight">
            {today.toLocaleDateString(undefined, { weekday: 'long' })}
          </h1>
          <p className="text-sm text-muted">
            {today.toLocaleDateString(undefined, { month: 'long', day: 'numeric' })}
            {split ? ` · ${split.name}` : ''}
          </p>
        </div>
        <Link
          to="/settings"
          aria-label="Settings"
          className="mt-1 flex h-10 w-10 items-center justify-center rounded-full bg-surface text-muted active:bg-surface-2"
        >
          <SettingsIcon size={20} />
        </Link>
      </header>

      <div className="card flex items-center justify-between px-3 py-3">
        {weekDays.map((d) => (
          <div key={d.ts} className="flex flex-1 flex-col items-center gap-1.5">
            <span className={`text-[0.6875rem] font-bold ${d.isToday ? 'text-chalk' : 'text-faint'}`}>
              {d.letter}
            </span>
            <span
              className={`flex h-7 w-7 items-center justify-center rounded-full text-[0.625rem] font-extrabold ${
                d.done
                  ? 'bg-volt text-ink'
                  : d.scheduled
                    ? 'border border-dashed border-line text-faint'
                    : 'text-faint/40'
              } ${d.isToday && !d.done ? 'ring-1 ring-volt/60' : ''}`}
            >
              {d.done ? '✓' : d.scheduled ? '·' : ''}
            </span>
          </div>
        ))}
      </div>

      {activeSession ? (
        <Card className="mt-4 border-volt/40 bg-volt/[0.07]">
          <span className="label-caps text-volt">Workout in progress</span>
          <h2 className="mt-1.5 text-2xl leading-tight font-extrabold tracking-tight">{activeSession.name}</h2>
          <p className="mt-1 text-sm text-muted">
            {activeProgress?.done} of {activeProgress?.total} sets logged
          </p>
          <button
            type="button"
            onClick={() => navigate('/workout')}
            className="btn btn-primary mt-4 h-14 w-full text-base tracking-wide"
          >
            <PlayIcon size={18} /> RESUME WORKOUT
          </button>
        </Card>
      ) : (
        <Card className="mt-4">
          <span className="label-caps">{todayDay ? "Today's workout" : 'Next workout'}</span>
          <h2 className="mt-1.5 text-2xl leading-tight font-extrabold tracking-tight">
            {todayDay?.name ?? upcoming?.day.name ?? 'Rest day'}
          </h2>
          <p className="mt-1 text-sm text-muted">
            {todayDay
              ? `${todayDay.exercises.length} exercise${todayDay.exercises.length === 1 ? '' : 's'}`
              : upcoming
                ? `${DAY_SHORT[upcoming.weekday]} · ${upcoming.day.exercises.length} exercises`
                : 'No days scheduled yet'}
          </p>

          {todayDay && todayDay.exercises.length > 0 && (
            <ul className="mt-3 flex flex-col gap-1 text-sm text-muted">
              {todayDay.exercises.slice(0, 4).map((x) => (
                <li key={x.id} className="flex justify-between gap-3">
                  <span className="truncate">{exerciseName(x.exerciseId)}</span>
                  <span className="tnum shrink-0 text-faint">
                    {x.targetSets} × {x.repMin}–{x.repMax}
                  </span>
                </li>
              ))}
              {todayDay.exercises.length > 4 && (
                <li className="text-faint">+{todayDay.exercises.length - 4} more</li>
              )}
            </ul>
          )}

          <button
            type="button"
            onClick={() => startWorkout(todayDay?.id ?? upcoming?.day.id ?? null)}
            className="btn btn-primary mt-4 h-14 w-full text-base tracking-wide"
          >
            <PlayIcon size={18} />
            {todayDay ? 'START WORKOUT' : upcoming ? `START ${upcoming.day.name.toUpperCase()}` : 'START A WORKOUT'}
          </button>
          {!todayDay && upcoming && (
            <p className="mt-2 text-center text-xs text-faint">
              Not a scheduled day — starting early is fine.
            </p>
          )}
        </Card>
      )}

      <SectionTitle>This week</SectionTitle>
      <div className="grid grid-cols-3 gap-2.5">
        <Stat
          label="Workouts"
          value={stats.thisWeek}
          suffix={stats.weeklyTarget ? `/ ${stats.weeklyTarget}` : undefined}
          accent
        />
        <Stat label="Streak" value={stats.streak} icon={<FlameIcon size={14} />} />
        <Stat label="All time" value={stats.total} />
      </div>

      <SectionTitle>Quick actions</SectionTitle>
      <div className="flex flex-col gap-2">
        <QuickLink to="/builder" icon={<EditIcon size={20} />} title="Edit split" subtitle={splitSummary(split?.days.length ?? 0)} />
        <QuickLink
          to="/progress"
          icon={<ChartIcon size={20} />}
          title="Progress"
          subtitle={`${fmtVolume(stats.totalVolume, settings.unit)} lifted all time`}
        />
        <QuickLink
          to="/records"
          icon={<TrophyIcon size={20} />}
          title="Personal records"
          subtitle={stats.prs > 0 ? `${stats.prs} PRs set` : 'No PRs yet — go get one'}
        />
      </div>
    </Screen>
  );
}

function splitSummary(dayCount: number) {
  return dayCount ? `${dayCount} training day${dayCount === 1 ? '' : 's'}` : 'No days yet';
}

function QuickLink({
  to,
  icon,
  title,
  subtitle,
}: {
  to: string;
  icon: React.ReactNode;
  title: string;
  subtitle: string;
}) {
  return (
    <Link to={to} className="card flex items-center gap-3.5 px-4 py-3.5 active:bg-surface-2">
      <span className="flex h-10 w-10 shrink-0 items-center justify-center rounded-xl bg-surface-2 text-volt">
        {icon}
      </span>
      <span className="min-w-0 flex-1">
        <span className="block font-bold">{title}</span>
        <span className="block truncate text-xs text-muted">{subtitle}</span>
      </span>
      <span className="text-faint">
        <ChevronRight size={18} />
      </span>
    </Link>
  );
}
