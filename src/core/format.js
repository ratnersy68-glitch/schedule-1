/** Display formatting. Money never renders with a bare template literal elsewhere. */

const MONEY = new Intl.NumberFormat('en-US', { style: 'currency', currency: 'USD', maximumFractionDigits: 0 });
const MONEY_C = new Intl.NumberFormat('en-US', { style: 'currency', currency: 'USD', minimumFractionDigits: 2, maximumFractionDigits: 2 });
const NUM = new Intl.NumberFormat('en-US');

export function money(n, { cents = false, sign = false } = {}) {
  const v = Number(n) || 0;
  const body = cents || Math.abs(v) < 10 ? MONEY_C.format(Math.abs(v)) : MONEY.format(Math.abs(v));
  const prefix = v < 0 ? '-' : sign ? '+' : '';
  return `${prefix}${body}`;
}

export function compactMoney(n) {
  const v = Math.abs(Number(n) || 0);
  const sign = n < 0 ? '-' : '';
  if (v >= 1_000_000) return `${sign}$${(v / 1_000_000).toFixed(v >= 10_000_000 ? 0 : 1)}M`;
  if (v >= 10_000) return `${sign}$${(v / 1000).toFixed(v >= 100_000 ? 0 : 1)}K`;
  return money(n);
}

export const num = (n) => NUM.format(Math.round(Number(n) || 0));

export function pct(n, digits = 1) {
  const v = Number(n) || 0;
  return `${v > 0 ? '+' : ''}${v.toFixed(digits)}%`;
}

export function serial(card) {
  if (!card.serial) return null;
  return `${card.serial.num}/${card.serial.run}`;
}

/** "1 in 4,300" style odds copy from a probability. */
export function oneIn(p) {
  if (!p || p <= 0) return 'not in this box';
  const n = 1 / p;
  if (n < 2) return 'multiple per box';
  return `1 in ${num(n)}`;
}

export function relativeTime(ms) {
  const s = Math.max(0, Math.round(ms / 1000));
  if (s < 60) return `${s}s`;
  const m = Math.floor(s / 60);
  if (m < 60) return `${m}m ${s % 60}s`;
  const h = Math.floor(m / 60);
  if (h < 24) return `${h}h ${m % 60}m`;
  return `${Math.floor(h / 24)}d ${h % 24}h`;
}

export function timeAgo(ts) {
  const d = Date.now() - ts;
  if (d < 60_000) return 'just now';
  if (d < 3_600_000) return `${Math.floor(d / 60_000)}m ago`;
  if (d < 86_400_000) return `${Math.floor(d / 3_600_000)}h ago`;
  return `${Math.floor(d / 86_400_000)}d ago`;
}
