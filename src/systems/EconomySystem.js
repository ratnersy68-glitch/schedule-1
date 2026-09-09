/** Cash, the ledger and every lifetime statistic. */
import { store, S } from '../core/store.js';
import { bus, EVENTS } from '../core/events.js';
import { Data } from './DataService.js';

export const EconomySystem = {
  get cash() { return S().cash; },

  canAfford(amount) { return S().cash >= amount; },

  /** Positive credits, negative debits. Always goes through the ledger. */
  record(kind, label, amount) {
    store.update((s) => {
      s.cash = Math.round((s.cash + amount) * 100) / 100;
      s.ledger.unshift({ ts: Date.now(), kind, label, amount });
      if (s.ledger.length > 300) s.ledger.length = 300;
      if (amount < 0 && kind !== 'grading') s.stats.totalSpent += -amount;
      if (kind === 'grading') s.stats.gradingFees += -amount;
      if (kind === 'sale') s.stats.totalSales += amount;
    });
    bus.emit(EVENTS.CASH_CHANGED, { cash: S().cash, amount, label });
    return S().cash;
  },

  spend(label, amount, kind = 'purchase') {
    if (!this.canAfford(amount)) return false;
    this.record(kind, label, -Math.abs(amount));
    return true;
  },

  credit(label, amount, kind = 'sale') {
    this.record(kind, label, Math.abs(amount));
    return true;
  },

  /** Live worth of everything owned, graded values included. */
  collectionValue(marketIndexFor) {
    const s = S();
    let total = 0;
    for (const c of s.collection) {
      const book = c.grade ? (c.values[String(c.grade.grade)] ?? c.baseValue) : c.baseValue;
      total += marketIndexFor ? book * marketIndexFor(c.playerId) : book;
    }
    return total;
  },

  netWorth(marketIndexFor) { return S().cash + this.collectionValue(marketIndexFor); },

  profit() {
    const s = S();
    return s.stats.totalSales - s.stats.totalSpent - s.stats.gradingFees;
  },

  /** One free stipend per real-world day, so a wiped-out player can keep going. */
  claimDailyStipend() {
    const s = S();
    const today = new Date().toDateString();
    if (s.lastStipend === today) return 0;
    const amount = Data.economy.dailyStipend;
    store.update((st) => { st.lastStipend = today; });
    this.record('stipend', 'Daily shop credit', amount);
    return amount;
  },

  stipendAvailable() { return S().lastStipend !== new Date().toDateString(); },
};
