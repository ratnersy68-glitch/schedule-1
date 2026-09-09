/** Central mutable game state with change notification and dirty tracking. */
import { bus, EVENTS } from './events.js';

export function createState() {
  return {
    version: 1,
    createdAt: Date.now(),
    lastSeen: Date.now(),
    cash: 900,
    xp: 0,
    level: 1,
    collection: [],          // Card[]
    submissions: [],         // GradingSubmission[]
    ledger: [],              // { ts, kind, label, amount }
    pulls: [],               // recent pull digest for the dashboard
    market: { index: {}, tick: 0, lastTick: Date.now(), news: [] },
    stats: {
      boxesOpened: 0, packsOpened: 0, cardsPulled: 0,
      totalSpent: 0, totalSales: 0, gradingFees: 0,
      hits: 0, numbered: 0, autos: 0, oneOfOnes: 0,
      bestPullUid: null, bestPullValue: 0, bestGrade: 0,
      gradedCount: 0, gemRate: { tens: 0, graded: 0 },
      bySport: { NFL: 0, NBA: 0, MLB: 0 },
    },
    challenges: { day: null, list: [] },
    settings: { sfx: true, music: false, fastReveal: false, reduceMotion: false, volume: 0.7 },
  };
}

class Store {
  state = createState();
  #dirty = false;

  replace(next) {
    this.state = next;
    this.touch();
  }

  /** Mutate then notify. `mutator` receives the live state object. */
  update(mutator, meta = {}) {
    mutator(this.state);
    this.touch(meta);
  }

  touch(meta = {}) {
    this.#dirty = true;
    bus.emit(EVENTS.STATE_CHANGED, { state: this.state, ...meta });
  }

  get dirty() { return this.#dirty; }
  clean() { this.#dirty = false; }
}

export const store = new Store();
export const S = () => store.state;
