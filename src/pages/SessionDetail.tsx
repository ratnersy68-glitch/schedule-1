import { useState } from 'react';
import { Link, Navigate, useNavigate, useParams } from 'react-router-dom';
import { useStore } from '../state/store';
import { Card, Screen, Sheet, TopBar } from '../components/ui';
import { TrashIcon, TrophyIcon } from '../components/Icons';
import { fmtDuration, fmtLongDate, fmtVolume } from '../lib/format';
import { e1rm, sessionDuration, sessionSetCount, sessionTime, sessionVolume } from '../lib/stats';

export default function SessionDetail() {
  const { sessionId = '' } = useParams();
  const navigate = useNavigate();
  const { state, dispatch, exerciseName } = useStore();
  const [confirm, setConfirm] = useState(false);
  const session = state.history.find((s) => s.id === sessionId);
  const unit = state.settings.unit;

  if (!session) return <Navigate to="/history" replace />;

  const prs = session.exercises.reduce((n, ex) => n + ex.sets.filter((s) => s.pr).length, 0);

  return (
    <Screen>
      <TopBar
        title={session.name}
        subtitle={fmtLongDate(sessionTime(session))}
        back
        onBack={() => navigate('/history')}
        right={
          <button
            type="button"
            aria-label="Delete workout"
            onClick={() => setConfirm(true)}
            className="flex h-10 w-10 items-center justify-center rounded-full text-faint active:bg-surface-2"
          >
            <TrashIcon size={19} />
          </button>
        }
      />

      <div className="grid grid-cols-4 gap-2">
        <Tile label="Exercises" value={String(session.exercises.length)} />
        <Tile label="Sets" value={String(sessionSetCount(session))} />
        <Tile label="Volume" value={fmtVolume(sessionVolume(session), unit)} />
        <Tile label="Time" value={fmtDuration(sessionDuration(session))} />
      </div>

      {prs > 0 && (
        <div className="mt-3 flex items-center gap-2 rounded-xl border border-pr/30 bg-pr/10 px-3.5 py-2.5 text-pr">
          <TrophyIcon size={18} />
          <span className="text-sm font-bold">
            {prs} personal record{prs === 1 ? '' : 's'} in this workout
          </span>
        </div>
      )}

      <div className="mt-4 flex flex-col gap-2.5">
        {session.exercises.map((ex) => {
          const best = ex.sets.reduce((m, s) => Math.max(m, e1rm(s.weight, s.reps)), 0);
          const volume = ex.sets.reduce((sum, s) => sum + s.weight * s.reps, 0);
          return (
            <Card key={ex.id}>
              <div className="flex items-baseline justify-between gap-3">
                <Link
                  to={`/progress/exercise/${ex.exerciseId}`}
                  className="truncate font-extrabold tracking-tight"
                >
                  {exerciseName(ex.exerciseId)}
                </Link>
                <span className="tnum shrink-0 text-xs text-faint">{fmtVolume(volume, unit)}</span>
              </div>
              <div className="mt-2.5 flex flex-col gap-1">
                {ex.sets.map((set, i) => (
                  <div key={set.id} className="flex items-center gap-3 text-sm">
                    <span className="label-caps w-11 shrink-0 whitespace-nowrap">Set {i + 1}</span>
                    <span className="tnum flex-1 font-bold">
                      {set.weight} {unit} × {set.reps}
                    </span>
                    {set.pr && (
                      <span className="rounded-full bg-pr/15 px-2 py-0.5 text-[0.5625rem] font-extrabold text-pr">
                        PR
                      </span>
                    )}
                  </div>
                ))}
              </div>
              <div className="tnum mt-2 text-[0.6875rem] text-faint">Best est. 1RM {Math.round(best)} {unit}</div>
            </Card>
          );
        })}
      </div>

      <Sheet open={confirm} onClose={() => setConfirm(false)} title="Delete this workout?">
        <p className="text-sm text-muted">
          This removes the workout from your history and recalculates your records. It cannot be undone.
        </p>
        <div className="mt-5 flex gap-3">
          <button type="button" onClick={() => setConfirm(false)} className="btn btn-secondary h-12 flex-1">
            Cancel
          </button>
          <button
            type="button"
            onClick={() => {
              dispatch({ type: 'deleteSession', sessionId: session.id });
              navigate('/history', { replace: true });
            }}
            className="btn h-12 flex-1 bg-danger text-ink"
          >
            Delete
          </button>
        </div>
      </Sheet>
    </Screen>
  );
}

function Tile({ label, value }: { label: string; value: string }) {
  return (
    <div className="card px-2 py-2.5 text-center">
      <div className="label-caps">{label}</div>
      <div className="stat-value mt-1 text-base font-extrabold">{value}</div>
    </div>
  );
}
