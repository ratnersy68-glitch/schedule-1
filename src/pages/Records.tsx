import { useMemo } from 'react';
import { Link } from 'react-router-dom';
import { useStore } from '../state/store';
import { EmptyState, Screen, TopBar } from '../components/ui';
import { ChevronRight, TrophyIcon } from '../components/Icons';
import { fmtDate, fmtVolume } from '../lib/format';
import { personalRecords } from '../lib/stats';

export default function Records() {
  const { state, exerciseName } = useStore();
  const unit = state.settings.unit;
  const records = useMemo(() => personalRecords(state.history), [state.history]);

  return (
    <Screen>
      <TopBar
        title="Personal records"
        subtitle={records.length ? `${records.length} exercises` : undefined}
        back
      />

      {records.length === 0 ? (
        <EmptyState
          icon={<TrophyIcon size={28} />}
          title="No records yet"
          body="Every exercise you log gets a record. Beat it and Forge marks it automatically."
          action={
            <Link to="/workout" className="btn btn-primary h-12 px-6">
              Start a workout
            </Link>
          }
        />
      ) : (
        <div className="flex flex-col gap-2">
          {records.map((r) => (
            <Link
              key={r.exerciseId}
              to={`/progress/exercise/${r.exerciseId}`}
              className="card flex items-center gap-3 px-4 py-3.5 active:bg-surface-2"
            >
              <div className="min-w-0 flex-1">
                <div className="truncate font-bold">{exerciseName(r.exerciseId)}</div>
                <div className="stat-value mt-0.5 text-xl font-extrabold text-pr">
                  {r.weight} {unit} × {r.reps}
                </div>
                <div className="tnum mt-1 flex flex-wrap gap-x-3 text-[0.6875rem] text-faint">
                  <span>Est. 1RM {Math.round(r.e1rm)} {unit}</span>
                  <span>Heaviest {r.heaviest} {unit}</span>
                  <span>Best reps {r.bestReps}</span>
                  <span>{fmtVolume(r.totalVolume, unit)} total</span>
                  <span>{fmtDate(r.date)}</span>
                </div>
              </div>
              <span className="text-faint">
                <ChevronRight size={18} />
              </span>
            </Link>
          ))}
        </div>
      )}
    </Screen>
  );
}
