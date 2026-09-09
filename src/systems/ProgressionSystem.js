/** XP, levels and the product unlocks they gate. */
import { store, S } from '../core/store.js';
import { Data } from './DataService.js';
import { EconomySystem } from './EconomySystem.js';
import { bus, EVENTS } from '../core/events.js';

export const ProgressionSystem = {
  xpForLevel(level) {
    const { base, growth } = Data.economy.progression.curve;
    return Math.round(base * growth ** (level - 1));
  },

  /** Cumulative XP required to have reached `level`. */
  totalXpForLevel(level) {
    let total = 0;
    for (let l = 1; l < level; l += 1) total += this.xpForLevel(l);
    return total;
  },

  progress() {
    const s = S();
    const floor = this.totalXpForLevel(s.level);
    const need = this.xpForLevel(s.level);
    const into = Math.max(0, s.xp - floor);
    return { level: s.level, into, need, pct: Math.max(0, Math.min(1, into / need)) };
  },

  award(amount, reason = '') {
    if (amount <= 0) return null;
    let levelled = null;
    store.update((s) => { s.xp += amount; });
    while (S().xp >= this.totalXpForLevel(S().level + 1)) {
      store.update((s) => { s.level += 1; });
      const level = S().level;
      const reward = Data.economy.progression.levelRewards[String(level)] ?? Math.round(1200 * 1.4 ** (level - 10));
      EconomySystem.credit(`Level ${level} bonus`, reward, 'bonus');
      levelled = { level, reward, unlocked: Data.boxes.filter((b) => b.unlockLevel === level) };
      bus.emit(EVENTS.LEVEL_UP, levelled);
    }
    return levelled;
  },

  /** XP for a finished pack, scaled by what came out of it. */
  awardForPack(cards) {
    const p = Data.economy.progression;
    let xp = p.xpPerPack;
    for (const c of cards) {
      if (c.hitType) xp += p.xpPerHit;
      if (c.serial) xp += p.xpPerNumbered;
    }
    return this.award(xp, 'pack');
  },

  awardForBox() { return this.award(Data.economy.progression.xpPerBox, 'box'); },

  awardForGrades(graded) {
    const p = Data.economy.progression;
    let xp = 0;
    for (const g of graded) xp += g.grade === 10 ? p.xpPerGem : p.xpPerGrade;
    return this.award(xp, 'grading');
  },

  unlockedBoxes() { return Data.boxes.filter((b) => b.unlockLevel <= S().level); },
  nextUnlock() {
    return Data.boxes
      .filter((b) => b.unlockLevel > S().level)
      .sort((a, b) => a.unlockLevel - b.unlockLevel)[0] ?? null;
  },
};
