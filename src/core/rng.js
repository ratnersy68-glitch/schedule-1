/** Deterministic-capable RNG plus the weighted-draw helpers the odds system needs. */

export function makeRng(seed = Date.now()) {
  let s = seed >>> 0 || 1;
  const next = () => {
    s ^= s << 13; s >>>= 0;
    s ^= s >> 17;
    s ^= s << 5; s >>>= 0;
    return s / 4294967296;
  };
  next.int = (min, max) => Math.floor(next() * (max - min + 1)) + min;
  next.range = (min, max) => next() * (max - min) + min;
  next.chance = (p) => next() < p;
  next.pick = (arr) => arr[Math.floor(next() * arr.length)];
  next.shuffle = (arr) => {
    const a = arr.slice();
    for (let i = a.length - 1; i > 0; i -= 1) {
      const j = Math.floor(next() * (i + 1));
      [a[i], a[j]] = [a[j], a[i]];
    }
    return a;
  };
  /** Box-Muller normal, clamped. */
  next.normal = (mean, sd, min = -Infinity, max = Infinity) => {
    const u = Math.max(next(), 1e-9);
    const v = next();
    const n = Math.sqrt(-2 * Math.log(u)) * Math.cos(2 * Math.PI * v);
    return Math.min(max, Math.max(min, mean + n * sd));
  };
  return next;
}

export const rng = makeRng();

/**
 * Weighted draw from `[{ id, w }]`. Weights need not sum to anything.
 * Returns the entry, not just the id, so callers keep any extra fields.
 */
export function weightedPick(table, random = rng) {
  let total = 0;
  for (const row of table) total += row.w ?? row.weight ?? 0;
  if (total <= 0) return table[0] ?? null;
  let roll = random() * total;
  for (const row of table) {
    roll -= row.w ?? row.weight ?? 0;
    if (roll <= 0) return row;
  }
  return table[table.length - 1];
}

/** Weighted index draw from a plain number array (e.g. player tier weights). */
export function weightedIndex(weights, random = rng) {
  const total = weights.reduce((a, b) => a + b, 0);
  let roll = random() * total;
  for (let i = 0; i < weights.length; i += 1) {
    roll -= weights[i];
    if (roll <= 0) return i;
  }
  return weights.length - 1;
}

/**
 * A chance that may exceed 1: the whole part is guaranteed, the remainder rolls.
 * Lets a product config say "1.6 parallels per pack" in one number.
 */
export function expectedCount(chance, random = rng) {
  const whole = Math.floor(chance);
  return whole + (random() < chance - whole ? 1 : 0);
}
