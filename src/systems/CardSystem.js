/**
 * CardSystem - creates card instances and owns every valuation rule.
 * A card is plain data; nothing here touches the DOM.
 */
import { Data } from './DataService.js';
import { rng } from '../core/rng.js';

let counter = 0;
const uid = () => `C${Date.now().toString(36)}${(counter++).toString(36)}${Math.floor(Math.random() * 46656).toString(36)}`;

/** Cheap cards keep their cents; expensive ones round to the dollar. */
function round(v) {
  const x = Math.max(0.25, v);
  return x < 20 ? Math.round(x * 4) / 4 : Math.round(x);
}

/** Serial multiplier for a print run. */
function serialMultiplier(run) {
  if (!run) return 1;
  const table = Data.economy.value.serialMultipliers;
  return table[String(run)] ?? table.default;
}

/** Popularity maps onto a demand factor between floor and ceiling. */
function popularityFactor(pop) {
  const { floor, ceiling } = Data.economy.value.popularity;
  return floor + (Math.max(0, Math.min(100, pop)) / 100) * (ceiling - floor);
}

export const CardSystem = {
  /** Base dollar value of the underlying player, before any card treatment. */
  playerBase(player) {
    const v = Data.economy.value;
    const base = v.tierBase[Math.max(0, Math.min(4, player.tier - 1))];
    return base * (v.scale ?? 1) * popularityFactor(player.popularity) * (player.rookie ? v.rookieMultiplier : 1);
  },

  /**
   * Raw (ungraded) market value.
   *
   * Treatments do not all compound. A parallel's multiplier already prices in its
   * print run, so scarcity is counted once: parallels use their own multiplier,
   * while hits price off the hit multiplier and the hit's own serial run, with the
   * parallel contributing a damped, capped bonus on top.
   */
  rawValue(card) {
    const player = Data.player(card.playerId);
    if (!player) return 1;
    const cfg = Data.economy.value;
    const parallel = Data.parallel(card.parallel);
    const hit = card.hitType ? Data.hitType(card.hitType) : null;
    const insert = card.insertSet ? Data.insertSet(card.insertSet) : null;

    let v = this.playerBase(player);
    if (insert) v *= insert.value;

    if (hit) {
      v *= hit.value;
      if (card.serial) v *= serialMultiplier(card.serial.run);
      if (parallel.id !== 'none') {
        v *= Math.min(cfg.hitParallelCap, 1 + (parallel.value - 1) * cfg.hitParallelDamp);
      }
    } else {
      v *= parallel.value;
      // An unnumbered parallel on numbered stock still gets its scarcity from above.
      if (card.serial && !parallel.printRun) v *= serialMultiplier(card.serial.run);
    }

    return round(v);
  },

  /** Value the card would carry at each grade. */
  gradedValues(card) {
    const raw = card.baseValue ?? this.rawValue(card);
    const mult = Data.economy.grading.multipliers;
    const out = {};
    for (const g of Object.keys(mult)) out[g] = round(raw * mult[g]);
    return out;
  },

  /** Hidden condition, rolled once when the card is pulled and never re-rolled. */
  rollCondition(profileId, random = rng) {
    const g = Data.economy.grading;
    const quality = g.conditionQualityByProfile[profileId] ?? 90;
    const spread = g.conditionSpread ?? 5;
    const roll = (bias = 0, widen = 1) => Math.round(random.normal(quality + bias, spread * widen, 34, 100));
    return {
      centering: roll(-g.centeringPenalty, 1.5),
      corners: roll(0),
      edges: roll(-1),
      surface: roll(1),
    };
  },

  /** Rarity tier for a finished card: the highest of its parallel and its type. */
  rarityFor({ parallel, cardType, serial }) {
    const p = Data.parallel(parallel);
    const t = Data.cardType(cardType);
    let best = p.tier;
    if (t && Data.rarityOrder(t.baseTier) > Data.rarityOrder(best)) best = t.baseTier;
    if (serial?.run === 1) best = 'oneofone';
    else if (serial && serial.run <= 10 && Data.rarityOrder(best) < Data.rarityOrder('legendary')) best = 'legendary';
    return best;
  },

  /**
   * Build a card instance.
   * `spec` comes from PackSystem and describes what slot produced this card.
   */
  create(spec, random = rng) {
    const player = spec.player;
    const box = Data.box(spec.boxId);
    const team = Data.team(player.team);
    const cardType = spec.cardType || (player.rookie ? 'rookie' : 'base');
    const serial = spec.serial ?? null;
    const rarity = this.rarityFor({ parallel: spec.parallel, cardType, serial });
    const hit = spec.hitType ? Data.hitType(spec.hitType) : null;

    const card = {
      uid: uid(),
      id: `${player.sport}-${box.year}-${String(spec.cardNumber).padStart(3, '0')}`,
      playerId: player.id,
      player: player.name,
      teamId: team.id,
      team: `${team.city} ${team.nickname}`,
      sport: player.sport,
      position: player.position,
      jersey: player.jersey,
      year: box.year,
      setId: box.id,
      set: box.name,
      brand: box.brand,
      manufacturer: box.manufacturer,
      template: box.template,
      pose: player.pose,
      cardNumber: String(spec.cardNumber),
      cardType,
      parallel: spec.parallel || 'none',
      insertSet: spec.insertSet || null,
      hitType: spec.hitType || null,
      rarity,
      serial,
      autograph: !!(hit?.auto),
      memorabilia: !!(hit?.memorabilia),
      rookie: !!player.rookie,
      condition: this.rollCondition(box.profile, random),
      grade: null,
      pulledAt: Date.now(),
      pulledFrom: box.id,
      listed: false,
    };
    card.baseValue = this.rawValue(card);
    card.values = this.gradedValues(card);
    return card;
  },

  /** Current worth of an owned card, graded or raw, before market movement. */
  bookValue(card) {
    if (card.grade) return card.values[String(card.grade.grade)] ?? card.baseValue;
    return card.baseValue;
  },

  /** Short human label, e.g. "Silver Prizm Rookie Autograph /49". */
  label(card) {
    const bits = [];
    const p = Data.parallel(card.parallel);
    if (p.id !== 'none') bits.push(p.label);
    if (card.insertSet) bits.push(Data.insertSet(card.insertSet).label);
    const t = Data.cardType(card.cardType);
    if (t && t.id !== 'base') bits.push(t.label);
    if (!bits.length) bits.push('Base');
    if (card.serial) bits.push(`/${card.serial.run}`);
    return bits.join(' ');
  },

  isHit(card) { return !!card.hitType; },
  isNumbered(card) { return !!card.serial; },
};
