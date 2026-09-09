/** Owns the collection array: adding pulls, removing sales, mutating grades. */
import { store, S } from '../core/store.js';
import { CardSystem } from './CardSystem.js';

export const InventorySystem = {
  all() { return S().collection; },
  count() { return S().collection.length; },
  find(uid) { return S().collection.find((c) => c.uid === uid) ?? null; },

  add(cards) {
    const list = Array.isArray(cards) ? cards : [cards];
    store.update((s) => {
      s.collection.unshift(...list);
      s.stats.cardsPulled += list.length;
      for (const c of list) {
        s.stats.bySport[c.sport] = (s.stats.bySport[c.sport] ?? 0) + 1;
        if (c.hitType) s.stats.hits += 1;
        if (c.serial) s.stats.numbered += 1;
        if (c.autograph) s.stats.autos += 1;
        if (c.serial?.run === 1) s.stats.oneOfOnes += 1;
        if (c.baseValue > s.stats.bestPullValue) {
          s.stats.bestPullValue = c.baseValue;
          s.stats.bestPullUid = c.uid;
        }
        s.pulls.unshift({ uid: c.uid, ts: c.pulledAt, value: c.baseValue, rarity: c.rarity, label: `${c.player} - ${CardSystem.label(c)}` });
      }
      if (s.pulls.length > 40) s.pulls.length = 40;
    });
    return list;
  },

  remove(uid) {
    let removed = null;
    store.update((s) => {
      const i = s.collection.findIndex((c) => c.uid === uid);
      if (i >= 0) [removed] = s.collection.splice(i, 1);
    });
    return removed;
  },

  patch(uid, patch) {
    store.update((s) => {
      const c = s.collection.find((x) => x.uid === uid);
      if (c) Object.assign(c, patch);
    });
    return this.find(uid);
  },

  /** Best card by book value, used on the dashboard hero slot. */
  crownJewel() {
    let best = null;
    for (const c of S().collection) {
      const v = CardSystem.bookValue(c);
      if (!best || v > CardSystem.bookValue(best)) best = c;
    }
    return best;
  },

  graded() { return S().collection.filter((c) => c.grade); },
  raw() { return S().collection.filter((c) => !c.grade); },

  /** Cards eligible for grading: raw, not already submitted. */
  gradable() {
    const pending = new Set(S().submissions.flatMap((s) => s.cardUids));
    return S().collection.filter((c) => !c.grade && !pending.has(c.uid));
  },

  isPending(uid) {
    return S().submissions.some((s) => s.cardUids.includes(uid));
  },
};
