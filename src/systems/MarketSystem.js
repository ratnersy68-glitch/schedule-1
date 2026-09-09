/**
 * MarketSystem - a simulated price index per athlete.
 *
 * Prices are not random per card. Each player carries an index that mean-reverts
 * toward a popularity-derived anchor, drifts on a random walk, drops when the
 * player floods the market with sales, and jumps on generated news events.
 * A card's sale price is its book value multiplied by that index.
 */
import { store, S } from '../core/store.js';
import { Data } from './DataService.js';
import { CardSystem } from './CardSystem.js';
import { EconomySystem } from './EconomySystem.js';
import { InventorySystem } from './InventorySystem.js';
import { bus, EVENTS } from '../core/events.js';
import { rng } from '../core/rng.js';

const HEADLINES = [
  ['{p} goes off for a career night', 'up'],
  ['{p} named player of the week', 'up'],
  ['{p} signs a franchise-record extension', 'up'],
  ['{p} trends after a viral highlight', 'up'],
  ['Breakers report a hot streak on {p} autos', 'up'],
  ['{p} listed as day-to-day', 'down'],
  ['{p} in a shooting slump', 'down'],
  ['Case break floods the market with {p}', 'down'],
  ['{p} benched in the fourth', 'down'],
  ['Print run rumours cool {p} demand', 'down'],
];

export const MarketSystem = {
  anchorFor(player) { return 0.82 + (player.popularity / 100) * 0.5; },

  index(playerId) {
    const m = S().market;
    if (m.index[playerId] === undefined) {
      const p = Data.player(playerId);
      m.index[playerId] = p ? this.anchorFor(p) : 1;
    }
    return m.index[playerId];
  },

  indexFor(playerId) { return this.index(playerId); },

  /** Advance the simulation for however much real time has passed. */
  tick(force = false) {
    const cfg = Data.economy.market;
    const m = S().market;
    const elapsed = Date.now() - (m.lastTick || 0);
    const steps = force ? 1 : Math.min(24, Math.floor(elapsed / cfg.tickMs));
    if (steps <= 0) return 0;

    store.update((s) => {
      const mk = s.market;
      for (let i = 0; i < steps; i += 1) {
        for (const p of Data.players) {
          const anchor = this.anchorFor(p);
          const cur = mk.index[p.id] ?? anchor;
          const noise = rng.normal(0, cfg.drift);
          const pull = (anchor - cur) * cfg.reversion;
          const next = cur + noise + pull;
          mk.index[p.id] = Math.min(cfg.indexCeiling, Math.max(cfg.indexFloor, next));
        }
        if (rng() < cfg.newsChance) {
          const p = Data.players[Math.floor(rng() * Data.players.length)];
          const [tpl, dir] = HEADLINES[Math.floor(rng() * HEADLINES.length)];
          const mag = rng.range(cfg.newsMagnitude[0], cfg.newsMagnitude[1]) * (dir === 'up' ? 1 : -1);
          mk.index[p.id] = Math.min(cfg.indexCeiling, Math.max(cfg.indexFloor, (mk.index[p.id] ?? 1) * (1 + mag)));
          mk.news.unshift({ ts: Date.now(), playerId: p.id, headline: tpl.replace('{p}', p.name), change: mag });
          if (mk.news.length > 24) mk.news.length = 24;
        }
        mk.tick += 1;
      }
      mk.lastTick = Date.now();
    });
    return steps;
  },

  /** What the marketplace will actually pay for a specific card right now. */
  quote(card) {
    const cfg = Data.economy.market;
    const book = CardSystem.bookValue(card);
    const idx = this.index(card.playerId);
    const noise = 1 + rng.normal(0, cfg.saleNoise);
    const gross = Math.max(1, book * idx * noise);
    const fee = gross * Data.economy.sellFeeRate;
    return {
      book,
      index: idx,
      gross: Math.round(gross),
      fee: Math.round(fee),
      net: Math.max(1, Math.round(gross - fee)),
    };
  },

  /** Sell a card. Removes it from the collection and nudges that player's index down. */
  sell(uid) {
    const card = InventorySystem.find(uid);
    if (!card) return null;
    const q = this.quote(card);
    InventorySystem.remove(uid);
    EconomySystem.credit(`Sold ${card.player} ${CardSystem.label(card)}`, q.net, 'sale');
    store.update((s) => {
      const cfg = Data.economy.market;
      const cur = s.market.index[card.playerId] ?? 1;
      s.market.index[card.playerId] = Math.max(cfg.indexFloor, cur * (1 - cfg.supplyImpact));
    });
    bus.emit(EVENTS.CARD_SOLD, { card, quote: q });
    return { card, quote: q };
  },

  /** Movers for the marketplace dashboard. */
  movers(limit = 6) {
    const rows = Data.players.map((p) => {
      const idx = this.index(p.id);
      return { player: p, index: idx, change: (idx / this.anchorFor(p) - 1) * 100 };
    });
    rows.sort((a, b) => b.change - a.change);
    return { up: rows.slice(0, limit), down: rows.slice(-limit).reverse() };
  },

  news(limit = 8) { return S().market.news.slice(0, limit); },
};
