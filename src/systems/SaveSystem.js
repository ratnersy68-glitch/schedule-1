/**
 * SaveSystem - localStorage persistence with versioned migration.
 * Everything the player earns survives a reload: cash, cards, slabs, pending
 * submissions, market state, ledger, statistics, level, challenges, settings.
 */
import { store, S, createState } from '../core/store.js';
import { bus, EVENTS } from '../core/events.js';

const KEY = 'breakroom.save';
let autosaveTimer = null;
const VERSION = 1;

const MIGRATIONS = {
  // 0 -> 1: initial shape. Future migrations append here.
};

export const SaveSystem = {
  load() {
    let raw;
    try { raw = localStorage.getItem(KEY); } catch { raw = null; }
    if (!raw) { store.replace(createState()); return { fresh: true }; }
    try {
      const data = JSON.parse(raw);
      const migrated = this.migrate(data);
      const merged = { ...createState(), ...migrated };
      merged.stats = { ...createState().stats, ...(migrated.stats || {}) };
      merged.settings = { ...createState().settings, ...(migrated.settings || {}) };
      merged.market = { ...createState().market, ...(migrated.market || {}) };
      merged.lastSeen = Date.now();
      store.replace(merged);
      return { fresh: false, at: data.savedAt };
    } catch (err) {
      console.error('[save] corrupt save, starting fresh', err);
      store.replace(createState());
      return { fresh: true, corrupt: true };
    }
  },

  migrate(data) {
    let d = data;
    for (let v = d.version ?? 0; v < VERSION; v += 1) {
      const fn = MIGRATIONS[v];
      if (fn) d = fn(d);
      d.version = v + 1;
    }
    return d;
  },

  save() {
    const payload = { ...S(), version: VERSION, savedAt: Date.now() };
    try {
      localStorage.setItem(KEY, JSON.stringify(payload));
      store.clean();
      return true;
    } catch (err) {
      console.error('[save] write failed', err);
      return false;
    }
  },

  /** Coalesce rapid state changes into one write. */
  autosave(delay = 900) {
    clearTimeout(autosaveTimer);
    autosaveTimer = setTimeout(() => this.save(), delay);
  },

  start() {
    bus.on(EVENTS.STATE_CHANGED, () => this.autosave());
    window.addEventListener('beforeunload', () => this.save());
    document.addEventListener('visibilitychange', () => { if (document.hidden) this.save(); });
    setInterval(() => { if (store.dirty) this.save(); }, 15_000);
  },

  reset() {
    try { localStorage.removeItem(KEY); } catch { /* ignore */ }
    store.replace(createState());
    this.save();
  },

  export() {
    return JSON.stringify({ ...S(), version: VERSION, savedAt: Date.now() }, null, 2);
  },

  import(json) {
    const data = JSON.parse(json);
    store.replace({ ...createState(), ...this.migrate(data) });
    this.save();
    return true;
  },
};
