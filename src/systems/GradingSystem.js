/**
 * GradingSystem - the Apex Grading Authority (AGA), a fictional grader.
 *
 * Hidden condition rolled at pull time drives four subgrades; the overall grade
 * is the lowest subgrade, with a single-point bump when the other three are
 * clearly stronger. Grader noise means a pristine card is never a guaranteed 10.
 */
import { store, S } from '../core/store.js';
import { Data } from './DataService.js';
import { InventorySystem } from './InventorySystem.js';
import { EconomySystem } from './EconomySystem.js';
import { CardSystem } from './CardSystem.js';
import { bus, EVENTS } from '../core/events.js';
import { rng } from '../core/rng.js';

const SUB_LABELS = { centering: 'Centering', corners: 'Corners', edges: 'Edges', surface: 'Surface' };

let certSeed = 0;
const cert = () => `${Date.now().toString().slice(-8)}${(certSeed++ % 100).toString().padStart(2, '0')}`;

export const GradingSystem = {
  tiers() { return Data.economy.grading.tiers; },

  tier(id) { return this.tiers().find((t) => t.id === id) ?? this.tiers()[0]; },

  /** Tiers a card is allowed into, based on declared value. */
  tiersFor(card) {
    const value = CardSystem.bookValue(card);
    return this.tiers().map((t) => ({ ...t, eligible: t.maxValue === null || value <= t.maxValue }));
  },

  turnaroundMs(tierId) {
    return this.tier(tierId).days * Data.economy.grading.dayMs;
  },

  subgrade(score) {
    for (const [threshold, grade] of Data.economy.grading.subgradeThresholds) {
      if (score >= threshold) return grade;
    }
    return 1;
  },

  /** Deterministic once rolled: the result is computed at submission time. */
  computeGrade(card, tierId, random = rng) {
    const tier = this.tier(tierId);
    const noise = 3.4 / tier.variance;
    const effective = {};
    for (const key of Object.keys(SUB_LABELS)) {
      effective[key] = Math.max(1, Math.min(100, card.condition[key] + random.normal(0, noise)));
    }
    const subs = {};
    for (const key of Object.keys(SUB_LABELS)) subs[key] = this.subgrade(effective[key]);

    // Overall is a weighted read of all four faces, dragged down by the worst one.
    const w = Data.economy.grading.compositeWeights;
    const composite = Object.keys(SUB_LABELS).reduce((a, k) => a + effective[k] * w[k], 0);
    const worst = Math.min(...Object.values(effective));
    const penalty = Math.max(0, composite - worst) * (Data.economy.grading.worstSubWeight ?? 0.5);
    let overall = this.subgrade(composite - penalty);
    // Graders are human: a flawless card is never an automatic ten.
    if (overall === 10 && random() < 0.14) overall = 9;
    return {
      grade: Math.max(1, Math.min(10, overall)),
      subs,
      effective,
      cert: cert(),
      tier: tier.id,
      gradedAt: null,
    };
  },

  /** Estimated outcome shown before the player commits. */
  preview(card, tierId) {
    const raw = CardSystem.bookValue(card);
    const fee = this.tier(tierId).fee;
    const values = card.values;
    // Rough expectation from the card's own condition, without revealing it.
    const mid = (card.condition.centering + card.condition.corners + card.condition.edges + card.condition.surface) / 4;
    return {
      raw,
      fee,
      turnaround: this.turnaroundMs(tierId),
      ten: values['10'],
      nine: values['9'],
      eight: values['8'],
      upside: values['10'] - raw - fee,
      downside: values['7'] - raw - fee,
      confidence: Math.max(0, Math.min(1, (mid - 62) / 34)),
    };
  },

  /** Submit one or more cards. Grades are decided now, revealed later. */
  submit(uids, tierId) {
    const list = (Array.isArray(uids) ? uids : [uids]).filter((u) => !InventorySystem.isPending(u));
    if (!list.length) return null;
    const tier = this.tier(tierId);
    const fee = tier.fee * list.length;
    if (!EconomySystem.canAfford(fee)) return null;

    const results = {};
    for (const uid of list) {
      const card = InventorySystem.find(uid);
      if (card) results[uid] = this.computeGrade(card, tierId);
    }

    const submission = {
      id: `SUB-${Date.now().toString(36)}`,
      cardUids: list,
      tier: tierId,
      fee,
      submittedAt: Date.now(),
      readyAt: Date.now() + this.turnaroundMs(tierId),
      results,
      collected: false,
    };

    EconomySystem.spend(`AGA ${tier.label} submission (${list.length})`, fee, 'grading');
    store.update((s) => { s.submissions.unshift(submission); });
    bus.emit(EVENTS.CARD_SUBMITTED, { submission });
    return submission;
  },

  pending() { return S().submissions.filter((s) => !s.collected); },
  ready() { return this.pending().filter((s) => Date.now() >= s.readyAt); },
  readyCount() { return this.ready().length; },

  /** Collect a finished submission and stamp the grades onto the cards. */
  collect(submissionId) {
    const sub = S().submissions.find((s) => s.id === submissionId);
    if (!sub || sub.collected || Date.now() < sub.readyAt) return null;

    const graded = [];
    for (const uid of sub.cardUids) {
      const card = InventorySystem.find(uid);
      const result = sub.results[uid];
      if (!card || !result) continue;
      const before = CardSystem.bookValue(card);
      InventorySystem.patch(uid, { grade: { ...result, gradedAt: Date.now() }, listed: false });
      const after = card.values[String(result.grade)] ?? before;
      graded.push({ card: InventorySystem.find(uid), before, after, grade: result.grade, feeShare: Math.round(sub.fee / sub.cardUids.length) });
    }

    store.update((s) => {
      const target = s.submissions.find((x) => x.id === submissionId);
      if (target) target.collected = true;
      s.stats.gradedCount += graded.length;
      s.stats.gemRate.graded += graded.length;
      for (const g of graded) {
        if (g.grade === 10) s.stats.gemRate.tens += 1;
        if (g.grade > s.stats.bestGrade) s.stats.bestGrade = g.grade;
      }
    });

    bus.emit(EVENTS.CARD_GRADED, { submission: sub, graded });
    return graded;
  },

  /** Label band drives which slab label art is used. */
  labelBand(grade) {
    if (grade === 10) return 'gold';
    if (grade >= 8) return 'standard';
    return 'black';
  },

  gradeName(grade) {
    return { 10: 'GEM MT', 9: 'MINT', 8: 'NM-MT', 7: 'NM', 6: 'EX-MT', 5: 'EX', 4: 'VG-EX', 3: 'VG', 2: 'GOOD', 1: 'POOR' }[grade] ?? '';
  },

  subLabels() { return SUB_LABELS; },
};
