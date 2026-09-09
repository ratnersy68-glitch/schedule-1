/**
 * PackSystem - turns one product configuration into one pack of cards.
 *
 * Slots are structural, not "roll a rarity": every pack has a fixed number of
 * base slots, a configurable number of upgrade slots that convert base slots
 * into inserts or parallels, and any box-level hit that was allocated to it.
 */
import { Data } from './DataService.js';
import { OddsSystem } from './OddsSystem.js';
import { CardSystem } from './CardSystem.js';
import { rng } from '../core/rng.js';

let cardNumberSeed = 100;
const nextCardNumber = (random) => 1 + Math.floor(random() * 330);

function insertSetFor(box, random) {
  const pool = Data.insertSets.filter((i) => i.sport === 'any' || i.sport === box.sport);
  return pool[Math.floor(random() * pool.length)];
}

export const PackSystem = {
  /**
   * @param box          product definition
   * @param allocatedHits array of hit specs pre-assigned to this pack by BoxSystem
   */
  build(box, allocatedHits = [], random = rng) {
    const profile = OddsSystem.profileFor(box);
    const upgrades = OddsSystem.rollUpgrades(box, random);
    const total = box.cardsPerPack;

    // Hits and upgrades consume base slots; base cards fill whatever is left.
    const hitCount = allocatedHits.length;
    let insertCount = Math.min(upgrades.insert ?? 0, Math.max(0, total - hitCount));
    let parallelCount = Math.min(upgrades.parallel ?? 0, Math.max(0, total - hitCount - insertCount));
    const baseCount = Math.max(0, total - hitCount - insertCount - parallelCount);

    const specs = [];

    for (let i = 0; i < baseCount; i += 1) {
      const player = OddsSystem.rollPlayer(box, { random });
      specs.push({
        boxId: box.id, player, cardNumber: nextCardNumber(random),
        cardType: player.rookie && random() < profile.rookieChance ? 'rookie' : 'base',
        parallel: 'none',
      });
    }

    for (let i = 0; i < insertCount; i += 1) {
      const player = OddsSystem.rollPlayer(box, { random });
      const set = insertSetFor(box, random);
      specs.push({
        boxId: box.id, player, cardNumber: nextCardNumber(random),
        cardType: 'insert', parallel: 'none', insertSet: set.id,
      });
    }

    for (let i = 0; i < parallelCount; i += 1) {
      const parallel = OddsSystem.rollParallel(box, { random });
      const player = OddsSystem.rollPlayer(box, { random, rookieOnly: random() < profile.rookieChance * 0.8 });
      specs.push({
        boxId: box.id, player, cardNumber: nextCardNumber(random),
        cardType: player.rookie ? 'rookie' : 'base',
        parallel: parallel.id,
        serial: OddsSystem.rollSerial(parallel.printRun, random),
      });
    }

    for (const hitSpec of allocatedHits) specs.push(hitSpec);

    // Cards are revealed in ascending drama: base first, the hit last.
    const cards = specs.map((s) => CardSystem.create(s, random));
    cards.sort((a, b) => {
      const d = Data.rarityOrder(a.rarity) - Data.rarityOrder(b.rarity);
      return d !== 0 ? d : a.baseValue - b.baseValue;
    });
    return cards;
  },
};
