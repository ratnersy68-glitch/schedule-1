import { useMemo, useState } from 'react';
import { useParams } from 'react-router-dom';
import { useStore } from '../state/store';
import { Card, EmptyState, Screen, SectionTitle, TopBar } from '../components/ui';
import Chart from '../components/Chart';
import { ChartIcon, TrophyIcon } from '../components/Icons';
import { fmtLongDate, fmtVolume, plural, relativeDay } from '../lib/format';
import { exerciseEntries, METRIC_LABEL, metricSeries, statsFor, type Metric } from '../lib/stats';

const METRICS: Metric[] = ['weight', 'e1rm', 'volume', 'reps'];

export default function ExerciseDetail() {
  const { exerciseId = '' } = useParams();
  const { state, exerciseName, exerciseGroup } = useStore();
  const unit = state.settings.unit;
  const [metric, setMetric] = useState<Metric>('weight');

  const entries = useMemo(() => exerciseEntries(state.history, exerciseId), [state.history, exerciseId]);
  const stats = useMemo(() => statsFor(state.history, exerciseId), [state.history, exerciseId]);
  const series = useMemo(() => metricSeries(entries, metric), [entries, metric]);

  const formatValue = (value: number) =>
    metric === 'reps'
      ? `${Math.round(value)}`
      : metric === 'volume'
        ? fmtVolume(value, unit)
        : `${Math.round(value * 10) / 10} ${unit}`;

  return (
    <Screen>
      <TopBar
        title={exerciseName(exerciseId)}
        subtitle={`${exerciseGroup(exerciseId)}${stats.lastPerformed ? ` · last ${relativeDay(stats.lastPerformed)}` : ''}`}
        back
      />

      {entries.length === 0 ? (
        <EmptyState
          icon={<ChartIcon size={28} />}
          title="No history for this exercise"
          body="Log it in a workout and your progression appears here."
        />
      ) : (
        <>
          <div className="grid grid-cols-2 gap-2.5">
            <RecordTile
              label="Heaviest"
              value={stats.heaviest ? `${stats.heaviest.weight} ${unit}` : '—'}
              sub={stats.heaviest ? `× ${stats.heaviest.reps} reps` : undefined}
            />
            <RecordTile
              label="Best est. 1RM"
              value={stats.bestE1rm ? `${Math.round(stats.bestE1rm.e1rm)} ${unit}` : '—'}
              sub={stats.bestE1rm ? `${stats.bestE1rm.weight} × ${stats.bestE1rm.reps}` : undefined}
              accent
            />
            <RecordTile
              label="Best reps"
              value={stats.bestReps ? String(stats.bestReps.reps) : '—'}
              sub={stats.bestReps ? `at ${stats.bestReps.weight} ${unit}` : undefined}
            />
            <RecordTile
              label="Total volume"
              value={fmtVolume(stats.totalVolume, unit)}
              sub={`${plural(stats.totalSets, 'set')} · ${plural(stats.sessions, 'session')}`}
            />
          </div>

          <Card className="mt-2.5">
            <div className="hide-scroll mb-4 flex gap-1.5 overflow-x-auto">
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
          </Card>

          <SectionTitle>Recent workouts</SectionTitle>
          <div className="flex flex-col gap-2">
            {entries.map((entry) => (
              <Card key={`${entry.sessionId}-${entry.date}`}>
                <div className="flex items-baseline justify-between gap-3">
                  <span className="truncate text-sm font-bold">{fmtLongDate(entry.date)}</span>
                  <span className="tnum shrink-0 text-[0.6875rem] text-faint">
                    {fmtVolume(entry.volume, unit)}
                  </span>
                </div>
                <div className="mt-2 flex flex-col gap-1">
                  {entry.sets.map((set, i) => (
                    <div key={set.id ?? i} className="flex items-center gap-3 text-sm">
                      <span className="label-caps w-11 shrink-0 whitespace-nowrap">Set {i + 1}</span>
                      <span className="tnum flex-1 font-bold">
                        {set.weight} {unit} × {set.reps}
                      </span>
                      {set.pr && (
                        <span className="flex items-center gap-1 rounded-full bg-pr/15 px-2 py-0.5 text-[0.5625rem] font-extrabold text-pr">
                          <TrophyIcon size={10} strokeWidth={2.6} /> PR
                        </span>
                      )}
                    </div>
                  ))}
                </div>
                <div className="mt-1.5 text-[0.6875rem] text-faint">{entry.sessionName}</div>
              </Card>
            ))}
          </div>
        </>
      )}
    </Screen>
  );
}

function RecordTile({
  label,
  value,
  sub,
  accent,
}: {
  label: string;
  value: string;
  sub?: string;
  accent?: boolean;
}) {
  return (
    <div className="card px-3.5 py-3">
      <div className="label-caps">{label}</div>
      <div className={`stat-value mt-1 text-xl font-extrabold ${accent ? 'text-volt' : 'text-chalk'}`}>
        {value}
      </div>
      {sub && <div className="tnum mt-0.5 text-[0.6875rem] text-faint">{sub}</div>}
    </div>
  );
}
