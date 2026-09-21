import { useRef, useState } from 'react';
import { useNavigate } from 'react-router-dom';
import { useStore } from '../state/store';
import { Banner, Card, Screen, SectionTitle, Sheet, TopBar } from '../components/ui';
import { DownloadIcon, TrashIcon, UploadIcon } from '../components/Icons';
import { exportPayload, parseImport } from '../lib/storage';
import type { Unit } from '../lib/types';

const REST_OPTIONS = [30, 60, 90, 120, 180];

export default function Settings() {
  const navigate = useNavigate();
  const { state, dispatch } = useStore();
  const fileRef = useRef<HTMLInputElement>(null);
  const [message, setMessage] = useState<{ tone: 'volt' | 'danger'; text: string } | null>(null);
  const [customRest, setCustomRest] = useState(String(state.settings.defaultRest));
  const [confirmReset, setConfirmReset] = useState(false);

  const exportData = () => {
    const blob = new Blob([JSON.stringify(exportPayload(state), null, 2)], { type: 'application/json' });
    const url = URL.createObjectURL(blob);
    const a = document.createElement('a');
    const stamp = new Date().toISOString().slice(0, 10);
    a.href = url;
    a.download = `forge-workout-backup-${stamp}.json`;
    document.body.appendChild(a);
    a.click();
    a.remove();
    URL.revokeObjectURL(url);
    setMessage({ tone: 'volt', text: 'Backup downloaded.' });
  };

  const importData = async (file: File) => {
    try {
      const next = parseImport(await file.text());
      dispatch({ type: 'importState', state: next });
      setMessage({
        tone: 'volt',
        text: `Imported ${next.history.length} workouts and ${next.split?.days.length ?? 0} training days.`,
      });
    } catch (error) {
      setMessage({ tone: 'danger', text: error instanceof Error ? error.message : 'Could not read that file.' });
    }
  };

  const setUnit = (unit: Unit) => dispatch({ type: 'updateSettings', patch: { unit } });

  return (
    <Screen>
      <TopBar title="Settings" back />

      {message && (
        <div className="mb-3">
          <Banner tone={message.tone}>{message.text}</Banner>
        </div>
      )}

      <SectionTitle>Units</SectionTitle>
      <Card>
        <div className="flex gap-2">
          {(['lb', 'kg'] as Unit[]).map((u) => (
            <button
              key={u}
              type="button"
              onClick={() => setUnit(u)}
              className={`h-12 flex-1 rounded-xl text-sm font-extrabold tracking-wide uppercase ${
                state.settings.unit === u ? 'bg-volt text-ink' : 'bg-surface-2 text-muted'
              }`}
            >
              {u}
            </button>
          ))}
        </div>
        <p className="mt-2.5 text-xs text-faint">
          Changing units relabels your numbers — it does not convert existing logs.
        </p>
      </Card>

      <SectionTitle>Rest timer</SectionTitle>
      <Card>
        <div className="label-caps mb-2">Default rest after a set</div>
        <div className="flex flex-wrap gap-2">
          {REST_OPTIONS.map((secs) => (
            <button
              key={secs}
              type="button"
              onClick={() => {
                dispatch({ type: 'updateSettings', patch: { defaultRest: secs } });
                setCustomRest(String(secs));
              }}
              className={`h-11 min-w-16 flex-1 rounded-xl text-sm font-bold ${
                state.settings.defaultRest === secs ? 'bg-volt text-ink' : 'bg-surface-2 text-muted'
              }`}
            >
              {secs < 120 ? `${secs}s` : `${secs / 60}m`}
            </button>
          ))}
        </div>
        <div className="mt-3 flex items-end gap-2">
          <div className="flex-1">
            <label className="label-caps" htmlFor="custom-rest">
              Custom (seconds)
            </label>
            <input
              id="custom-rest"
              inputMode="numeric"
              value={customRest}
              onChange={(e) => setCustomRest(e.target.value.replace(/[^0-9]/g, ''))}
              className="field mt-1.5 tnum font-bold"
            />
          </div>
          <button
            type="button"
            onClick={() => {
              const secs = Math.min(3600, Math.max(5, parseInt(customRest, 10) || 90));
              setCustomRest(String(secs));
              dispatch({
                type: 'updateSettings',
                patch: {
                  defaultRest: secs,
                  restPresets: [...new Set([...REST_OPTIONS, secs])].sort((a, b) => a - b),
                },
              });
            }}
            className="btn btn-secondary h-12 px-5"
          >
            Set
          </button>
        </div>
        <label className="mt-4 flex items-center justify-between">
          <span className="text-sm font-semibold">Sound when rest ends</span>
          <input
            type="checkbox"
            checked={state.settings.soundOn}
            onChange={(e) => dispatch({ type: 'updateSettings', patch: { soundOn: e.target.checked } })}
            className="h-6 w-11 appearance-none rounded-full bg-surface-3 transition-colors checked:bg-volt relative before:absolute before:top-0.5 before:left-0.5 before:h-5 before:w-5 before:rounded-full before:bg-chalk before:transition-transform checked:before:translate-x-5 checked:before:bg-ink"
          />
        </label>
      </Card>

      <SectionTitle>Your data</SectionTitle>
      <Card>
        <p className="text-sm text-muted">
          Everything lives on this device only. Back it up before clearing your browser data or switching phones.
        </p>
        <div className="mt-3.5 flex flex-col gap-2">
          <button type="button" onClick={exportData} className="btn btn-secondary h-12 w-full">
            <DownloadIcon size={18} /> Export data (JSON)
          </button>
          <button type="button" onClick={() => fileRef.current?.click()} className="btn btn-secondary h-12 w-full">
            <UploadIcon size={18} /> Import data
          </button>
          <input
            ref={fileRef}
            type="file"
            accept="application/json,.json"
            className="hidden"
            onChange={(e) => {
              const file = e.target.files?.[0];
              if (file) void importData(file);
              e.target.value = '';
            }}
          />
        </div>
        <div className="tnum mt-3.5 flex flex-wrap gap-x-4 gap-y-1 text-[0.6875rem] text-faint">
          <span>{state.history.length} workouts</span>
          <span>{state.split?.days.length ?? 0} training days</span>
          <span>{state.customExercises.length} custom exercises</span>
        </div>
      </Card>

      {state.customExercises.length > 0 && (
        <>
          <SectionTitle>Custom exercises</SectionTitle>
          <div className="flex flex-col gap-2">
            {state.customExercises.map((ex) => (
              <div key={ex.id} className="card flex items-center gap-3 px-4 py-3">
                <span className="min-w-0 flex-1">
                  <span className="block truncate font-semibold">{ex.name}</span>
                  <span className="label-caps">{ex.group}</span>
                </span>
                <button
                  type="button"
                  aria-label={`Delete ${ex.name}`}
                  onClick={() => dispatch({ type: 'deleteCustomExercise', exerciseId: ex.id })}
                  className="flex h-9 w-9 items-center justify-center rounded-full text-faint active:bg-surface-2"
                >
                  <TrashIcon size={17} />
                </button>
              </div>
            ))}
          </div>
          <p className="mt-2 text-xs text-faint">
            Deleting a custom exercise keeps its logged history intact.
          </p>
        </>
      )}

      <SectionTitle>Danger zone</SectionTitle>
      <button type="button" onClick={() => setConfirmReset(true)} className="btn btn-ghost h-12 w-full text-danger">
        <TrashIcon size={18} /> Erase all data
      </button>

      <p className="mt-6 text-center text-[0.6875rem] text-faint">
        Forge Training Log · stored locally on this device
      </p>

      <Sheet open={confirmReset} onClose={() => setConfirmReset(false)} title="Erase everything?">
        <p className="text-sm text-muted">
          Your split, workout history, records and custom exercises will be deleted from this device. Export a
          backup first if you might want them back.
        </p>
        <div className="mt-5 flex gap-3">
          <button type="button" onClick={() => setConfirmReset(false)} className="btn btn-secondary h-12 flex-1">
            Cancel
          </button>
          <button
            type="button"
            onClick={() => {
              dispatch({ type: 'reset' });
              navigate('/setup', { replace: true });
            }}
            className="btn h-12 flex-1 bg-danger text-ink"
          >
            Erase
          </button>
        </div>
      </Sheet>
    </Screen>
  );
}
