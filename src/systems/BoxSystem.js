/**
 * BoxSystem - builds a whole sealed box: pack contents, guaranteed hits and the
 * rare case hit. Contents are generated at purchase and stored, so a box the
 * player walks away from is exactly the same box when they come back.
 */
import { Data } from './DataService.js';
import { OddsSystem } from './OddsSystem.js';
import { PackSystem } from './PackSystem.js';
import { rng } from '../core/rng.js';

function hitSpec(box, hit, random, { caseHit = false } = {}) {
  const profile = OddsSystem.profileFor(box);
  const rookieOnly = hit.cardType === 'rookieAuto';
  const player = OddsSystem.rollPlayer(box, { weights: profile.hitTierWeights, rookieOnly, random });
  const runs = hit.runs;
  let run = runs[Math.floor(random() * runs.length)];
  let parallel = 'none';

  if (caseHit) {
    // A case hit forces the scarcest print run and can land the 1/1.
    run = runs.filter(Boolean).sort((a, b) => a - b)[0] ?? 25;
    if (random() < 0.22) { run = 1; parallel = 'superfractor'; }
    else if (random() < 0.4) parallel = 'gold';
  } else if (random() < 0.3) {
    parallel = OddsSystem.rollParallel(box, { random }).id;
  }

  return {
    boxId: box.id,
    player,
    cardNumber: 1 + Math.floor(random() * 120),
    cardType: hit.cardType,
    hitType: hit.id,
    parallel,
    serial: run ? { num: Math.floor(random() * run) + 1, run } : null,
    caseHit,
  };
}

export const BoxSystem = {
  /** Full sealed-box contents. */
  open(box, random = rng) {
    const profile = OddsSystem.profileFor(box);
    const packCount = box.packs;

    // Allocate guaranteed hits into distinct packs where possible.
    const hits = [];
    for (let i = 0; i < profile.boxHits; i += 1) hits.push(hitSpec(box, OddsSystem.rollHit(box, { random }), random));

    const isCaseHit = random() < profile.caseHitChance;
    if (isCaseHit) {
      const big = Data.hitType(random() < 0.5 ? 'patchAuto' : 'booklet');
      hits.push(hitSpec(box, big, random, { caseHit: true }));
    }

    const slots = [...Array(packCount).keys()];
    const shuffled = random.shuffle(slots);
    const allocation = new Map();
    hits.forEach((h, i) => {
      const pack = shuffled[i % packCount];
      if (!allocation.has(pack)) allocation.set(pack, []);
      allocation.get(pack).push(h);
    });

    const packs = [];
    for (let i = 0; i < packCount; i += 1) {
      packs.push({
        index: i,
        opened: false,
        hasHit: allocation.has(i),
        cards: PackSystem.build(box, allocation.get(i) ?? [], random),
      });
    }

    const cards = packs.flatMap((p) => p.cards);
    return {
      boxId: box.id,
      openedAt: Date.now(),
      caseHit: isCaseHit,
      packs,
      totalCards: cards.length,
      totalValue: cards.reduce((a, c) => a + c.baseValue, 0),
      bestCard: cards.reduce((best, c) => (!best || c.baseValue > best.baseValue ? c : best), null),
    };
  },

  /** Products the player can see, with lock state resolved. */
  catalogue(level) {
    return Data.boxes.map((box) => ({ box, locked: box.unlockLevel > level }));
  },
};
