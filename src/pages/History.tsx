import { useMemo } from 'react';
import { Link } from 'react-router-dom';
import { useStore } from '../state/store';
import { EmptyState, Screen, TopBar } from '../components/ui';
import { ChevronRight, HistoryIcon, TrophyIcon } from '../components/Icons';
import { fmtDuration, fmtLongDate, fmtVolume, plural } from '../lib/format';
import { sessionDuration, sessionSetCount, sessionTime, sessionVolume } from '../lib/stats';

export default function History() {
  const { state } = useStore();
  const unit = state.settings.unit;

  const months = useMemo(() => {
    const groups = new Map<string, typeof state.history>();
    for (const session of state.history) {
      const d = new Date(sessionTime(session));
      const key = `${d.getFullYear()}-${d.getMonth()}`;
      const list = groups.get(key) ?? [];
      list.push(session);
      groups.set(key, list);
    }
    return [...groups.entries()].map(([key, sessions]) => {
      const [year, month] = key.split('-').map(Number);
      return {
        key,
        label: new Date(year, month, 1).toLocaleDateString(undefined, { month: 'long', year: 'numeric' }),
        sessions,
      };
    });
  }, [state.history]);

  return (
    <Screen>
      <TopBar
        title="History"
        subtitle={`${state.history.length} completed workout${state.history.length === 1 ? '' : 's'}`}
      />

      {state.history.length === 0 ? (
        <EmptyState
          icon={<HistoryIcon size={28} />}
          title="No workouts logged yet"
          body="Finish your first workout and it will show up here."
          action={
            <Link to="/workout" className="btn btn-primary h-12 px-6">
              Start a workout
            </Link>
          }
        />
      ) : (
        months.map((month) => (
          <section key={month.key} className="mb-6">
            <h2 className="label-caps mb-2.5">{month.label}</h2>
            <div className="flex flex-col gap-2">
              {month.sessions.map((session) => {
                const prs = session.exercises.reduce(
                  (n, ex) => n + ex.sets.filter((s) => s.pr).length,
                  0
                );
                return (
                  <Link
                    key={session.id}
                    to={`/history/${session.id}`}
                    className="card flex items-center gap-3 px-4 py-3.5 active:bg-surface-2"
                  >
                    <div className="min-w-0 flex-1">
                      <div className="flex items-center gap-2">
                        <span className="truncate font-bold">{session.name}</span>
                        {prs > 0 && (
                          <span className="flex shrink-0 items-center gap-0.5 rounded-full bg-pr/15 px-1.5 py-0.5 text-[0.5625rem] font-extrabold text-pr">
                            <TrophyIcon size={10} strokeWidth={2.6} /> {prs}
                          </span>
                        )}
                      </div>
                      <div className="mt-0.5 truncate text-xs text-muted">
                        {fmtLongDate(sessionTime(session))}
                      </div>
                      <div className="tnum mt-1 flex gap-2.5 text-[0.6875rem] text-faint">
                        <span>{plural(session.exercises.length, 'exercise')}</span>
                        <span>{plural(sessionSetCount(session), 'set')}</span>
                        <span>{fmtVolume(sessionVolume(session), unit)}</span>
                        <span>{fmtDuration(sessionDuration(session))}</span>
                      </div>
                    </div>
                    <span className="text-faint">
                      <ChevronRight size={18} />
                    </span>
                  </Link>
                );
              })}
            </div>
          </section>
        ))
      )}
    </Screen>
  );
}
