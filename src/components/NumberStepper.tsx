import { useEffect, useRef, useState } from 'react';

interface Props {
  label: string;
  value: number;
  step?: number;
  min?: number;
  max?: number;
  suffix?: string;
  decimals?: boolean;
  onChange: (value: number) => void;
  disabled?: boolean;
}

/**
 * Big tap targets with a directly editable value — built for logging mid-set
 * without a keyboard when possible, with a numeric keypad when typing is faster.
 */
export default function NumberStepper({
  label,
  value,
  step = 1,
  min = 0,
  max = 9999,
  suffix,
  decimals,
  onChange,
  disabled,
}: Props) {
  const [text, setText] = useState(String(value));
  const focused = useRef(false);

  useEffect(() => {
    if (!focused.current) setText(String(value));
  }, [value]);

  const clamp = (n: number) => Math.min(max, Math.max(min, n));
  const round = (n: number) => Math.round(n * 100) / 100;

  const bump = (delta: number) => {
    if (disabled) return;
    const next = clamp(round(value + delta));
    onChange(next);
    setText(String(next));
    if ('vibrate' in navigator) navigator.vibrate?.(8);
  };

  const commit = (raw: string) => {
    const parsed = decimals ? parseFloat(raw) : parseInt(raw, 10);
    const next = Number.isFinite(parsed) ? clamp(round(parsed)) : min;
    onChange(next);
    setText(String(next));
  };

  return (
    <div className="flex-1">
      <div className="label-caps mb-1.5 text-center">{label}</div>
      <div className="flex items-stretch gap-1.5">
        <button
          type="button"
          aria-label={`Decrease ${label}`}
          disabled={disabled}
          onClick={() => bump(-step)}
          className="w-12 shrink-0 rounded-xl bg-surface-3 text-2xl leading-none font-bold text-chalk active:bg-surface-2 disabled:opacity-40"
        >
          −
        </button>
        <div className="relative flex-1">
          <input
            inputMode={decimals ? 'decimal' : 'numeric'}
            pattern={decimals ? '[0-9]*[.,]?[0-9]*' : '[0-9]*'}
            aria-label={label}
            disabled={disabled}
            value={text}
            onFocus={(e) => {
              focused.current = true;
              e.currentTarget.select();
            }}
            onChange={(e) => setText(e.target.value.replace(/[^0-9.]/g, ''))}
            onBlur={(e) => {
              focused.current = false;
              commit(e.target.value);
            }}
            onKeyDown={(e) => {
              if (e.key === 'Enter') e.currentTarget.blur();
            }}
            className="tnum h-14 w-full rounded-xl border border-line bg-surface-2 text-center text-[1.65rem] font-extrabold tracking-tight text-chalk outline-none focus:border-volt-dim disabled:opacity-60"
          />
          {suffix && (
            <span className="pointer-events-none absolute right-2.5 bottom-1.5 text-[0.625rem] font-bold text-faint">
              {suffix}
            </span>
          )}
        </div>
        <button
          type="button"
          aria-label={`Increase ${label}`}
          disabled={disabled}
          onClick={() => bump(step)}
          className="w-12 shrink-0 rounded-xl bg-surface-3 text-2xl leading-none font-bold text-chalk active:bg-surface-2 disabled:opacity-40"
        >
          +
        </button>
      </div>
    </div>
  );
}
