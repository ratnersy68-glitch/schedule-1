/** Daily challenges. Progress is measured against a snapshot taken at rollover. */
import { store, S } from '../core/store.js';
import { Data } from './DataService.js';
import { EconomySystem } from './EconomySystem.js';
import { ProgressionSystem } from './ProgressionSystem.js';
import { bus, EVENTS } from '../core/events.js';
import { rng } from '../core/rng.js';

const today = () => new Date().toDateString();

/** Trim plural nouns when a target happens to be one. */
function plural(label, n) {
  if (n !== 1) return label;
  return label
    .replace(/\bboxes\b/, 'box')
    .replace(/\bpacks\b/, 'pack')
    .replace(/\bcards\b/, 'card')
    .replace(/\bautographs or relics\b/, 'autograph or relic')
    .replace(/\bnumbered cards\b/, 'numbered card');
}

export const ChallengeSystem = {
  ensureToday() {
    const s = S();
    if (s.challenges.day === today() && s.challenges.list.length) return s.challenges.list;

    const cfg = Data.economy.challenges;
    const pool = rng.shuffle(cfg.pool).slice(0, cfg.slots);
    const level = s.level;
    const difficulty = Math.min(2, Math.floor((level - 1) / 3));

    const list = pool.map((def) => {
      const target = def.targets[difficulty];
      return {
        key: def.id,
        label: plural(def.label.replace('{n}', def.money ? `$${target.toLocaleString()}` : String(target)), target),
        metric: def.metric,
        target,
        start: this.metricValue(def.metric),
        reward: def.reward[difficulty],
        xp: def.xp,
        claimed: false,
      };
    });

    store.update((st) => { st.challenges = { day: today(), list }; });
    return list;
  },

  metricValue(metric) {
    const st = S().stats;
    return Number(st[metric] ?? 0);
  },

  list() {
    this.ensureToday();
    return S().challenges.list.map((c) => {
      const done = Math.max(0, this.metricValue(c.metric) - c.start);
      return { ...c, done: Math.min(done, c.target), complete: done >= c.target, pct: Math.min(1, done / c.target) };
    });
  },

  claimable() { return this.list().filter((c) => c.complete && !c.claimed); },

  claim(key) {
    const row = this.list().find((c) => c.key === key);
    if (!row || !row.complete || row.claimed) return null;
    store.update((s) => {
      const target = s.challenges.list.find((c) => c.key === key);
      if (target) target.claimed = true;
    });
    EconomySystem.credit(`Challenge: ${row.label}`, row.reward, 'bonus');
    ProgressionSystem.award(row.xp, 'challenge');
    bus.emit(EVENTS.CHALLENGE_DONE, row);
    return row;
  },
};
