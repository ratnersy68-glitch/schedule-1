import { useEffect } from 'react';
import { useTimer } from '../state/timer';
import { fmtClock } from '../lib/format';

/** Floating rest timer that sits just above the bottom navigation. */
export default function RestTimerBar() {
  const { running, remaining, duration, finishedAt, stop, adjust, dismiss } = useTimer();
  const visible = running || finishedAt !== null;

  // Reserve room at the bottom of the page so the timer never covers a control.
  useEffect(() => {
    document.body.classList.toggle('timer-open', visible);
    return () => document.body.classList.remove('timer-open');
  }, [visible]);

  if (!visible) return null;

  if (finishedAt !== null) {
    return (
      <div className="fixed inset-x-0 bottom-[calc(var(--nav-height)+var(--safe-bottom))] z-40 px-3 pb-2">
        <button
          type="button"
          onClick={dismiss}
          className="animate-flash mx-auto flex w-full max-w-lg items-center justify-between rounded-2xl bg-volt px-4 py-3.5 text-ink shadow-lg"
        >
          <span className="text-base font-extrabold tracking-wide">REST COMPLETE — GO</span>
          <span className="text-sm font-bold opacity-70">Dismiss</span>
        </button>
      </div>
    );
  }

  const pct = duration > 0 ? Math.max(0, Math.min(1, remaining / duration)) : 0;

  return (
    <div className="fixed inset-x-0 bottom-[calc(var(--nav-height)+var(--safe-bottom))] z-40 px-3 pb-2">
      <div className="mx-auto w-full max-w-lg overflow-hidden rounded-2xl border border-line bg-surface-2 shadow-lg">
        <div className="flex items-center gap-3 px-3.5 py-2.5">
          <div className="min-w-0 flex-1">
            <div className="label-caps">Rest</div>
            <div className="stat-value text-2xl leading-none font-extrabold text-volt">{fmtClock(remaining)}</div>
          </div>
          <button
            type="button"
            onClick={() => adjust(30)}
            className="rounded-xl bg-surface-3 px-3 py-2 text-sm font-bold text-chalk active:opacity-70"
          >
            +30s
          </button>
          <button
            type="button"
            onClick={stop}
            className="rounded-xl bg-surface-3 px-3 py-2 text-sm font-bold text-muted active:opacity-70"
          >
            Skip
          </button>
        </div>
        <div className="h-1 w-full bg-surface-3">
          <div className="h-full bg-volt transition-[width] duration-200 ease-linear" style={{ width: `${pct * 100}%` }} />
        </div>
      </div>
    </div>
  );
}
