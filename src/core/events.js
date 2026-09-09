/** Minimal synchronous event bus shared by every system. */
export class EventBus {
  #map = new Map();

  on(type, fn) {
    if (!this.#map.has(type)) this.#map.set(type, new Set());
    this.#map.get(type).add(fn);
    return () => this.off(type, fn);
  }

  once(type, fn) {
    const off = this.on(type, (...a) => { off(); fn(...a); });
    return off;
  }

  off(type, fn) { this.#map.get(type)?.delete(fn); }

  emit(type, payload) {
    for (const fn of this.#map.get(type) ?? []) {
      try { fn(payload); } catch (err) { console.error(`[events] ${type}`, err); }
    }
    for (const fn of this.#map.get('*') ?? []) {
      try { fn(type, payload); } catch (err) { console.error('[events] *', err); }
    }
  }
}

export const bus = new EventBus();

export const EVENTS = {
  STATE_CHANGED: 'state:changed',
  CASH_CHANGED: 'economy:cash',
  BOX_PURCHASED: 'box:purchased',
  BOX_OPENED: 'box:opened',
  PACK_OPENED: 'pack:opened',
  CARD_REVEALED: 'card:revealed',
  CARD_SOLD: 'card:sold',
  CARD_SUBMITTED: 'grading:submitted',
  CARD_GRADED: 'grading:graded',
  LEVEL_UP: 'player:levelup',
  CHALLENGE_DONE: 'challenge:done',
  TOAST: 'ui:toast',
  NAVIGATE: 'ui:navigate',
};
