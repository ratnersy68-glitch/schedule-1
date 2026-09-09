/**
 * BreakSystem - the lifecycle of a sealed box.
 *
 * Contents are rolled at purchase and stored in the vault, so a box is the same
 * box whenever the player comes back to it. Packs are opened one at a time and
 * their cards land in the collection as they are revealed.
 */
import { store, S } from '../core/store.js';
import { Data } from './DataService.js';
import { BoxSystem } from './BoxSystem.js';
import { EconomySystem } from './EconomySystem.js';
import { InventorySystem } from './InventorySystem.js';
import { ProgressionSystem } from './ProgressionSystem.js';
import { bus, EVENTS } from '../core/events.js';

let seq = 0;

export const BreakSystem = {
  vault() { return S().vault; },
  sealed() { return S().vault.filter((v) => !v.finished); },
  find(id) { return S().vault.find((v) => v.id === id) ?? null; },

  /** Buy a box. Returns the vault entry, or null if it cannot be afforded. */
  purchase(boxId) {
    const box = Data.box(boxId);
    if (!box) return null;
    if (S().level < box.unlockLevel) return null;
    if (!EconomySystem.spend(`Bought ${box.name}`, box.price, 'purchase')) return null;

    const contents = BoxSystem.open(box);
    const entry = {
      id: `V${Date.now().toString(36)}${(seq += 1).toString(36)}`,
      boxId,
      purchasedAt: Date.now(),
      price: box.price,
      opened: false,
      finished: false,
      caseHit: contents.caseHit,
      packs: contents.packs.map((p) => ({ index: p.index, opened: false, hasHit: p.hasHit, cards: p.cards })),
    };
    store.update((s) => { s.vault.unshift(entry); });
    bus.emit(EVENTS.BOX_PURCHASED, { box, entry });
    return entry;
  },

  /** Break the seal. Does not reveal anything yet. */
  breakSeal(vaultId) {
    const entry = this.find(vaultId);
    if (!entry || entry.opened) return entry;
    store.update((s) => {
      const v = s.vault.find((x) => x.id === vaultId);
      if (v) v.opened = true;
      s.stats.boxesOpened += 1;
    });
    ProgressionSystem.awardForBox();
    bus.emit(EVENTS.BOX_OPENED, { entry });
    return this.find(vaultId);
  },

  /**
   * Open one pack: marks it opened, files the cards and awards XP.
   * Returns the cards in reveal order.
   */
  openPack(vaultId, packIndex) {
    const entry = this.find(vaultId);
    const pack = entry?.packs[packIndex];
    if (!entry || !pack || pack.opened) return null;

    store.update((s) => {
      const v = s.vault.find((x) => x.id === vaultId);
      const p = v?.packs[packIndex];
      if (p) p.opened = true;
      s.stats.packsOpened += 1;
    });

    InventorySystem.add(pack.cards);
    ProgressionSystem.awardForPack(pack.cards);
    bus.emit(EVENTS.PACK_OPENED, { entry, pack });

    if (this.find(vaultId).packs.every((p) => p.opened)) this.finish(vaultId);
    return pack.cards;
  },

  finish(vaultId) {
    store.update((s) => {
      const v = s.vault.find((x) => x.id === vaultId);
      if (v) v.finished = true;
      // Keep the vault tidy: finished boxes older than the last 12 are dropped.
      const finished = s.vault.filter((x) => x.finished);
      if (finished.length > 12) {
        const cut = new Set(finished.slice(12).map((x) => x.id));
        s.vault = s.vault.filter((x) => !cut.has(x.id));
      }
    });
  },

  /** Summary of everything pulled from a box, for the wrap-up screen. */
  summary(vaultId) {
    const entry = this.find(vaultId);
    if (!entry) return null;
    const opened = entry.packs.filter((p) => p.opened);
    const cards = opened.flatMap((p) => p.cards);
    const value = cards.reduce((a, c) => a + c.baseValue, 0);
    const best = cards.reduce((b, c) => (!b || c.baseValue > b.baseValue ? c : b), null);
    return {
      entry,
      box: Data.box(entry.boxId),
      packsOpened: opened.length,
      packsTotal: entry.packs.length,
      cards,
      value,
      best,
      hits: cards.filter((c) => c.hitType),
      numbered: cards.filter((c) => c.serial),
      profit: value - entry.price,
    };
  },

  /** The box the Break Room should show by default. */
  next() {
    const started = S().vault.find((v) => v.opened && !v.finished);
    return started ?? S().vault.find((v) => !v.opened) ?? null;
  },
};
