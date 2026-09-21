import { useMemo, useState } from 'react';
import { Link } from 'react-router-dom';
import { useStore } from '../state/store';
import { Card, EmptyState, Screen, SectionTitle, Stat, TopBar } from '../components/ui';
import Chart from '../components/Chart';
import { ChartIcon, ChevronDown, ChevronRight, FlameIcon, TrophyIcon } from '../components/Icons';
import { fmtVolume, plural } from '../lib/format';
import {
  exerciseEntries,
  globalStats,
  METRIC_LABEL,
  metricSeries,
  personalRecords,
  type Metric,
} from '../lib/stats';

const METRICS: Metric[] = ['weight', 'e1rm', 'volume', 'reps'];

export default function Progress() {
  const { state, exerciseName } = useStore();
  const unit = state.settings.unit;
  const stats = useMemo(() => globalStats(state.history, state.split), [state.history, state.split]);
  const records = useMemo(() => personalRecords(state.history), [state.history]);

  const [exerciseId, setExerciseId] = useState<string>(records[0]?.exerciseId ?? '');
  const [metric, setMetric] = useState<Metric>('weight');

  const selected = exerciseId || records[0]?.exerciseId || '';
  const entries = useMemo(() => exerciseEntries(state.history, selected), [state.history, selected]);
  const series = useMemo(() => metricSeries(entries, metric), [entries, metric]);

  const formatValue = (value: number) =>
    metric === 'reps'
      ? `${Math.round(value)}`
      : metric === 'volume'
        ? fmtVolume(value, unit)
        : `${Math.round(value * 10) / 10} ${unit}`;

  return (
    <Screen>
      <TopBar title="Progress" subtitle="Everything you've lifted so far" />

      <div className="grid grid-cols-3 gap-2.5">
        <Stat label="Total" value={stats.total} />
        <Stat label="Week" value={stats.thisWeek} accent />
        <Stat label="Month" value={stats.thisMonth} />
        <Stat label="Streak" value={stats.streak} icon={<FlameIcon size={14} />} />
        <Stat label="Sets" value={stats.totalSets} />
        <Stat label="PRs" value={stats.prs} icon={<TrophyIcon size={14} />} />
      </div>

      <Card className="mt-2.5">
        <div className="label-caps">Total volume lifted</div>
        <div className="stat-value mt-1.5 text-[2.25rem] leading-none font-extrabold text-volt">
          {fmtVolume(stats.totalVolume, unit)}
        </div>
        <p className="mt-1.5 text-xs text-muted">Weight × reps across every completed set.</p>
      </Card>

      <Link to="/records" className="card mt-2.5 flex items-center gap-3.5 px-4 py-3.5 active:bg-surface-2">
        <span className="flex h-10 w-10 items-center justify-center rounded-xl bg-surface-2 text-pr">
          <TrophyIcon size={20} />
        </span>
        <span className="min-w-0 flex-1">
          <span className="block font-bold">Personal records</span>
          <span className="block truncate text-xs text-muted">
            {records.length ? `${plural(records.length, 'exercise')} tracked` : 'No records yet'}
          </span>
        </span>
        <span className="text-faint">
          <ChevronRight size={18} />
        </span>
      </Link>

      <SectionTitle>Exercise progression</SectionTitle>

      {records.length === 0 ? (
        <EmptyState
          icon={<ChartIcon size={28} />}
          title="No data to chart yet"
          body="Log a few workouts and your progression graphs will appear here."
        />
      ) : (
        <Card>
          <label className="label-caps" htmlFor="exercise-select">
            Exercise
          </label>
          <div className="relative mt-2">
            <select
              id="exercise-select"
              value={selected}
              onChange={(e) => setExerciseId(e.target.value)}
              className="field appearance-none pr-10 font-bold"
            >
              {records.map((r) => (
                <option key={r.exerciseId} value={r.exerciseId}>
                  {exerciseName(r.exerciseId)}
                </option>
              ))}
            </select>
            <span className="pointer-events-none absolute top-1/2 right-3 -translate-y-1/2 text-faint">
              <ChevronDown size={18} />
            </span>
          </div>

          <div className="hide-scroll mt-3 mb-4 flex gap-1.5 overflow-x-auto">
            {METRICS.map((m) => (
              <button
                key={m}
                type="button"
                onClick={() => setMetric(m)}
                className={`shrink-0 rounded-lg px-3 py-2 text-xs font-bold ${
                  metric === m ? 'bg-volt text-ink' : 'bg-surface-2 text-muted'
                }`}
              >
                {METRIC_LABEL[m]}
              </button>
            ))}
          </div>

          <Chart points={series} formatValue={formatValue} />

          <Link
            to={`/progress/exercise/${selected}`}
            className="btn btn-secondary mt-4 h-11 w-full text-sm"
          >
            View full history
          </Link>
        </Card>
      )}
    </Screen>
  );
}
