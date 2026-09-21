import type { Unit } from './types';

export const DAY_NAMES = ['Sunday', 'Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday'];
export const DAY_SHORT = ['Sun', 'Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat'];
export const DAY_LETTER = ['S', 'M', 'T', 'W', 'T', 'F', 'S'];

export function plural(n: number, word: string, suffix = 's'): string {
  return `${n} ${word}${n === 1 ? '' : suffix}`;
}

export function fmtWeight(weight: number, unit: Unit): string {
  const rounded = Math.round(weight * 100) / 100;
  return `${rounded} ${unit}`;
}

export function fmtNumber(n: number): string {
  return Math.round(n).toLocaleString();
}

export function fmtVolume(volume: number, unit: Unit): string {
  if (volume >= 1_000_000) return `${(volume / 1_000_000).toFixed(1)}M ${unit}`;
  if (volume >= 10_000) return `${(volume / 1000).toFixed(1)}k ${unit}`;
  return `${fmtNumber(volume)} ${unit}`;
}

export function fmtDate(ts: number): string {
  return new Date(ts).toLocaleDateString(undefined, { month: 'short', day: 'numeric' });
}

export function fmtLongDate(ts: number): string {
  const d = new Date(ts);
  const sameYear = d.getFullYear() === new Date().getFullYear();
  return d.toLocaleDateString(undefined, {
    weekday: 'short',
    month: 'long',
    day: 'numeric',
    ...(sameYear ? {} : { year: 'numeric' }),
  });
}

export function fmtClock(seconds: number): string {
  const s = Math.max(0, Math.round(seconds));
  const m = Math.floor(s / 60);
  const rest = s % 60;
  return `${m}:${String(rest).padStart(2, '0')}`;
}

export function fmtDuration(ms: number): string {
  const mins = Math.round(ms / 60000);
  if (mins < 60) return `${mins} min`;
  const h = Math.floor(mins / 60);
  const rest = mins % 60;
  return rest === 0 ? `${h}h` : `${h}h ${rest}m`;
}

export function relativeDay(ts: number): string {
  const day = 86_400_000;
  const startOf = (t: number) => {
    const d = new Date(t);
    d.setHours(0, 0, 0, 0);
    return d.getTime();
  };
  const diff = Math.round((startOf(Date.now()) - startOf(ts)) / day);
  if (diff === 0) return 'Today';
  if (diff === 1) return 'Yesterday';
  if (diff < 7) return `${diff} days ago`;
  return fmtDate(ts);
}
