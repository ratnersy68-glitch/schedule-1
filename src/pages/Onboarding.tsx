import { useMemo, useState } from 'react';
import { useNavigate } from 'react-router-dom';
import { useStore } from '../state/store';
import { buildSplit, TEMPLATE_META, WEEK_SLOTS } from '../lib/templates';
import type { Split, SplitTemplate } from '../lib/types';
import { DAY_LETTER, DAY_NAMES, DAY_SHORT } from '../lib/format';
import { CheckIcon, DumbbellIcon } from '../components/Icons';

const TEMPLATES: SplitTemplate[] = ['ppl', 'upper-lower', 'full-body', 'custom'];

export default function Onboarding() {
  const navigate = useNavigate();
  const { state, dispatch, exerciseName } = useStore();
  const [step, setStep] = useState(0);
  const [days, setDays] = useState(4);
  const [template, setTemplate] = useState<SplitTemplate>('upper-lower');
  const [draft, setDraft] = useState<Split | null>(null);

  const preview = useMemo(() => draft ?? buildSplit(template, days), [draft, template, days]);

  const goToReview = () => {
    setDraft(buildSplit(template, days));
    setStep(2);
  };

  const chooseTemplate = (t: SplitTemplate) => {
    setTemplate(t);
    setDraft(null);
  };

  const patchDay = (id: string, patch: { name?: string; dayOfWeek?: number | null }) => {
    setDraft((prev) =>
      prev ? { ...prev, days: prev.days.map((d) => (d.id === id ? { ...d, ...patch } : d)) } : prev
    );
  };

  const finish = () => {
    dispatch({ type: 'setSplit', split: preview });
    navigate('/', { replace: true });
  };

  return (
    <div className="mx-auto flex min-h-screen w-full max-w-lg flex-col px-5 pt-safe pb-safe">
      <div className="flex items-center gap-2.5 pt-6">
        <span className="text-volt">
          <DumbbellIcon size={26} strokeWidth={2.2} />
        </span>
        <span className="text-sm font-extrabold tracking-[0.2em] text-muted uppercase">Forge</span>
      </div>

      <div className="mt-5 mb-6 flex gap-1.5">
        {[0, 1, 2].map((i) => (
          <div key={i} className={`h-1 flex-1 rounded-full ${i <= step ? 'bg-volt' : 'bg-surface-3'}`} />
        ))}
      </div>

      {step === 0 && (
        <section className="flex-1">
          <h1 className="text-[2rem] leading-tight font-extrabold tracking-tight">
            How many days a week do you train?
          </h1>
          <p className="mt-2 text-muted">You can change this any time.</p>
          <div className="mt-7 grid grid-cols-4 gap-2.5">
            {[1, 2, 3, 4, 5, 6, 7].map((n) => (
              <button
                key={n}
                type="button"
                onClick={() => {
                  setDays(n);
                  setDraft(null);
                }}
                className={`flex h-20 flex-col items-center justify-center rounded-2xl border text-2xl font-extrabold transition-colors ${
                  days === n ? 'border-volt bg-volt text-ink' : 'border-line bg-surface text-chalk'
                }`}
              >
                {n}
                <span className="mt-0.5 text-[0.625rem] font-bold tracking-widest uppercase opacity-60">
                  {n === 1 ? 'day' : 'days'}
                </span>
              </button>
            ))}
          </div>
          <p className="mt-5 text-sm text-muted">
            Planned week: {(WEEK_SLOTS[days] ?? []).map((d) => DAY_SHORT[d]).join(' · ')}
          </p>
        </section>
      )}

      {step === 1 && (
        <section className="flex-1">
          <h1 className="text-[2rem] leading-tight font-extrabold tracking-tight">Pick your split</h1>
          <p className="mt-2 text-muted">
            {days} day{days === 1 ? '' : 's'} a week · we'll fill in exercises, edit anything later.
          </p>
          <div className="mt-6 flex flex-col gap-3">
            {TEMPLATES.map((t) => (
              <button
                key={t}
                type="button"
                onClick={() => chooseTemplate(t)}
                className={`flex items-center justify-between rounded-2xl border px-4 py-4 text-left transition-colors ${
                  template === t ? 'border-volt bg-volt/10' : 'border-line bg-surface'
                }`}
              >
                <span>
                  <span className="block text-lg font-extrabold tracking-tight">{TEMPLATE_META[t].label}</span>
                  <span className="mt-0.5 block text-sm text-muted">{TEMPLATE_META[t].blurb}</span>
                </span>
                {template === t && (
                  <span className="text-volt">
                    <CheckIcon size={22} strokeWidth={2.4} />
                  </span>
                )}
              </button>
            ))}
          </div>
        </section>
      )}

      {step === 2 && (
        <section className="flex-1 overflow-y-auto">
          <h1 className="text-[2rem] leading-tight font-extrabold tracking-tight">Name your days</h1>
          <p className="mt-2 text-muted">Tap a letter to set the weekday.</p>
          <div className="mt-6 flex flex-col gap-3">
            {preview.days.map((day, i) => (
              <div key={day.id} className="card p-3.5">
                <div className="flex items-center gap-2">
                  <span className="label-caps w-10 shrink-0">Day {i + 1}</span>
                  <input
                    value={day.name}
                    onChange={(e) => patchDay(day.id, { name: e.target.value })}
                    placeholder="Workout name"
                    className="field py-2 text-[0.95rem] font-semibold"
                  />
                </div>
                <div className="mt-3 flex gap-1.5">
                  {DAY_LETTER.map((letter, dow) => (
                    <button
                      key={dow}
                      type="button"
                      onClick={() => patchDay(day.id, { dayOfWeek: day.dayOfWeek === dow ? null : dow })}
                      className={`h-9 flex-1 rounded-lg text-sm font-bold transition-colors ${
                        day.dayOfWeek === dow ? 'bg-volt text-ink' : 'bg-surface-2 text-faint'
                      }`}
                      aria-label={DAY_NAMES[dow]}
                    >
                      {letter}
                    </button>
                  ))}
                </div>
                <p className="mt-2.5 truncate text-xs text-faint">
                  {day.exercises.length === 0
                    ? 'No exercises yet — add them next'
                    : `${day.exercises.length} exercises · ${day.exercises
                        .slice(0, 3)
                        .map((x) => exerciseName(x.exerciseId))
                        .join(', ')}${day.exercises.length > 3 ? '…' : ''}`}
                </p>
              </div>
            ))}
          </div>
          {state.history.length > 0 && (
            <p className="mt-4 text-xs text-faint">Your existing workout history is kept.</p>
          )}
        </section>
      )}

      <div className="sticky bottom-0 mt-6 flex gap-3 bg-gradient-to-t from-ink via-ink to-transparent pt-4 pb-5">
        {step > 0 && (
          <button type="button" onClick={() => setStep(step - 1)} className="btn btn-secondary h-14 px-6">
            Back
          </button>
        )}
        <button
          type="button"
          onClick={() => (step === 0 ? setStep(1) : step === 1 ? goToReview() : finish())}
          className="btn btn-primary h-14 flex-1 text-base tracking-wide"
        >
          {step === 2 ? 'START TRAINING' : 'CONTINUE'}
        </button>
      </div>
    </div>
  );
}
