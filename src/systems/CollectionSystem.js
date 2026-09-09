/** Filtering, sorting and faceting for the collection screen. */
import { S } from '../core/store.js';
import { Data } from './DataService.js';
import { CardSystem } from './CardSystem.js';
import { MarketSystem } from './MarketSystem.js';

export const SORTS = {
  newest: { label: 'Newest', fn: (a, b) => b.pulledAt - a.pulledAt },
  value: { label: 'Value', fn: (a, b) => CardSystem.bookValue(b) - CardSystem.bookValue(a) },
  rarity: { label: 'Rarity', fn: (a, b) => Data.rarityOrder(b.rarity) - Data.rarityOrder(a.rarity) || CardSystem.bookValue(b) - CardSystem.bookValue(a) },
  player: { label: 'Player', fn: (a, b) => a.player.localeCompare(b.player) },
  grade: { label: 'Grade', fn: (a, b) => (b.grade?.grade ?? -1) - (a.grade?.grade ?? -1) },
  serial: { label: 'Print run', fn: (a, b) => (a.serial?.run ?? 1e9) - (b.serial?.run ?? 1e9) },
};

export const emptyFilters = () => ({
  search: '', sport: 'all', team: 'all', set: 'all', rarity: 'all',
  year: 'all', status: 'all', grade: 'all', minValue: 0, sort: 'newest',
});

export const CollectionSystem = {
  /** Facet counts for the filter rail, computed from the unfiltered collection. */
  facets() {
    const cards = S().collection;
    const count = (fn) => cards.reduce((m, c) => { const k = fn(c); m[k] = (m[k] ?? 0) + 1; return m; }, {});
    return {
      total: cards.length,
      sport: count((c) => c.sport),
      team: count((c) => c.teamId),
      set: count((c) => c.setId),
      rarity: count((c) => c.rarity),
      year: count((c) => c.year),
      status: {
        raw: cards.filter((c) => !c.grade).length,
        graded: cards.filter((c) => c.grade).length,
        auto: cards.filter((c) => c.autograph).length,
        relic: cards.filter((c) => c.memorabilia).length,
        numbered: cards.filter((c) => c.serial).length,
        rookie: cards.filter((c) => c.rookie).length,
      },
      grade: count((c) => (c.grade ? c.grade.grade : 'none')),
    };
  },

  apply(filters) {
    const f = { ...emptyFilters(), ...filters };
    const q = f.search.trim().toLowerCase();
    let out = S().collection.filter((c) => {
      if (f.sport !== 'all' && c.sport !== f.sport) return false;
      if (f.team !== 'all' && c.teamId !== f.team) return false;
      if (f.set !== 'all' && c.setId !== f.set) return false;
      if (f.rarity !== 'all' && c.rarity !== f.rarity) return false;
      if (f.year !== 'all' && String(c.year) !== String(f.year)) return false;
      if (f.grade !== 'all' && String(c.grade?.grade ?? 'none') !== String(f.grade)) return false;
      if (f.status === 'raw' && c.grade) return false;
      if (f.status === 'graded' && !c.grade) return false;
      if (f.status === 'auto' && !c.autograph) return false;
      if (f.status === 'relic' && !c.memorabilia) return false;
      if (f.status === 'numbered' && !c.serial) return false;
      if (f.status === 'rookie' && !c.rookie) return false;
      if (f.minValue && CardSystem.bookValue(c) < f.minValue) return false;
      if (q) {
        const hay = `${c.player} ${c.team} ${c.set} ${c.brand} ${CardSystem.label(c)} ${c.cardNumber}`.toLowerCase();
        if (!hay.includes(q)) return false;
      }
      return true;
    });
    out = out.slice().sort((SORTS[f.sort] ?? SORTS.newest).fn);
    return out;
  },

  summary(cards = S().collection) {
    const value = cards.reduce((a, c) => a + CardSystem.bookValue(c) * MarketSystem.index(c.playerId), 0);
    return {
      count: cards.length,
      value,
      hits: cards.filter((c) => c.hitType).length,
      numbered: cards.filter((c) => c.serial).length,
      graded: cards.filter((c) => c.grade).length,
      best: cards.reduce((b, c) => (!b || CardSystem.bookValue(c) > CardSystem.bookValue(b) ? c : b), null),
    };
  },

  /** Set-completion style progress per product the player has opened. */
  setProgress() {
    const bySet = new Map();
    for (const c of S().collection) {
      if (!bySet.has(c.setId)) bySet.set(c.setId, { set: Data.box(c.setId), cards: 0, hits: 0, value: 0 });
      const row = bySet.get(c.setId);
      row.cards += 1;
      if (c.hitType) row.hits += 1;
      row.value += CardSystem.bookValue(c);
    }
    return [...bySet.values()].sort((a, b) => b.value - a.value);
  },
};
