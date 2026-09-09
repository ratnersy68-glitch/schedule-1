/**
 * OddsSystem - the only place probabilities are resolved.
 *
 * Every product points at a profile in data/odds.json. Screens ask this module
 * for both the rolls and the published odds copy, so the numbers a player reads
 * in the store are literally the numbers the pull uses.
 */
import { Data } from './DataService.js';
import { rng, weightedPick, weightedIndex, expectedCount } from '../core/rng.js';

const clone = (o) => JSON.parse(JSON.stringify(o));

export const OddsSystem = {
  /** Merged profile for a product: named profile + per-product overrides. */
  profileFor(box) {
    const base = clone(Data.profile(box.profile));
    return Object.assign(base, box.oddsOverrides || {});
  },

  /** A player drawn from the product's tier weighting. */
  rollPlayer(box, { weights, rookieOnly = false, random = rng } = {}) {
    const profile = this.profileFor(box);
    const pool = Data.playersFor(box.sport);
    const tierWeights = weights || profile.playerTierWeights;
    for (let attempt = 0; attempt < 6; attempt += 1) {
      const tier = weightedIndex(tierWeights, random) + 1;
      const matches = pool.filter((p) => p.tier === tier && (!rookieOnly || p.rookie));
      if (matches.length) return matches[Math.floor(random() * matches.length)];
    }
    const fallback = rookieOnly ? pool.filter((p) => p.rookie) : pool;
    return fallback[Math.floor(random() * fallback.length)] ?? pool[0];
  },

  /** A parallel finish from the product's parallel table. */
  rollParallel(box, { random = rng, boost = 1 } = {}) {
    const profile = this.profileFor(box);
    const table = Data.parallelTable(profile.parallelTable);
    const weighted = boost === 1 ? table : table.map((r) => ({ ...r, w: r.w * (Data.parallel(r.id).value > 20 ? boost : 1) }));
    return Data.parallel(weightedPick(weighted, random).id);
  },

  /** A hit definition (auto / relic / booklet) from the product's hit table. */
  rollHit(box, { random = rng } = {}) {
    const profile = this.profileFor(box);
    return Data.hitType(weightedPick(Data.hitTable(profile.hitTable), random).id);
  },

  /** Serial number for a print run, or null for unnumbered stock. */
  rollSerial(run, random = rng) {
    if (!run) return null;
    return { num: Math.floor(random() * run) + 1, run };
  },

  /** How many upgrade slots of each kind this pack gets. */
  rollUpgrades(box, random = rng) {
    const profile = this.profileFor(box);
    const out = {};
    for (const up of profile.upgrades) out[up.kind] = expectedCount(up.chance, random);
    return out;
  },

  /* ------------------------------------------------------- published odds */

  /** Probability of a given parallel appearing on any one parallel slot. */
  parallelChance(box, parallelId) {
    const profile = this.profileFor(box);
    const table = Data.parallelTable(profile.parallelTable);
    const total = table.reduce((a, r) => a + r.w, 0);
    const row = table.find((r) => r.id === parallelId);
    return row ? row.w / total : 0;
  },

  hitChance(box, hitId) {
    const profile = this.profileFor(box);
    const table = Data.hitTable(profile.hitTable);
    const total = table.reduce((a, r) => a + r.w, 0);
    const row = table.find((r) => r.id === hitId);
    return row ? row.w / total : 0;
  },

  /** Expected parallel slots in a whole box. */
  parallelSlotsPerBox(box) {
    const profile = this.profileFor(box);
    const per = profile.upgrades.find((u) => u.kind === 'parallel')?.chance ?? 0;
    return per * box.packs;
  },

  /** Chance of at least one of a parallel across an entire box. */
  boxChanceOfParallel(box, parallelId) {
    const p = this.parallelChance(box, parallelId);
    const slots = this.parallelSlotsPerBox(box);
    return 1 - (1 - p) ** slots;
  },

  boxChanceOfHit(box, hitId) {
    const profile = this.profileFor(box);
    const p = this.hitChance(box, hitId);
    return 1 - (1 - p) ** profile.boxHits;
  },

  /** Table the store screen renders. Ordered rarest-last for readability. */
  publishedOdds(box) {
    const profile = this.profileFor(box);
    const rows = [];
    for (const par of Data.parallels) {
      if (par.id === 'none') continue;
      const chance = this.boxChanceOfParallel(box, par.id);
      if (chance > 0.00001) rows.push({ kind: 'parallel', id: par.id, label: par.label, run: par.printRun, tier: par.tier, chance });
    }
    for (const hit of Data.hitTypes) {
      const chance = this.boxChanceOfHit(box, hit.id);
      if (chance > 0.00001) rows.push({ kind: 'hit', id: hit.id, label: hit.label, tier: Data.cardType(hit.cardType).baseTier, chance });
    }
    rows.sort((a, b) => b.chance - a.chance);
    return { rows, profile, hitsPerBox: profile.boxHits, caseHitChance: profile.caseHitChance };
  },
};
