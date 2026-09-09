/**
 * AnimationSystem - timing, easing and the reveal choreography table.
 *
 * The reveal ladder lives here so a designer can retune drama without touching
 * the opening screen. Every duration collapses when the player asks for fast
 * reveals or the OS asks for reduced motion.
 */
import { S } from '../core/store.js';

export const EASE = {
  out: 'cubic-bezier(.16,1,.3,1)',
  inOut: 'cubic-bezier(.65,0,.35,1)',
  back: 'cubic-bezier(.34,1.56,.64,1)',
  snap: 'cubic-bezier(.22,1.4,.36,1)',
};

/** Per-rarity reveal recipe. Times in ms, before speed scaling. */
const CHOREOGRAPHY = {
  common:    { build: 0,    flip: 340, settle: 140, glow: 0,    shake: 0,  rays: false, particles: 0,  banner: null,          takeover: false },
  uncommon:  { build: 90,   flip: 380, settle: 200, glow: 0.25, shake: 0,  rays: false, particles: 0,  banner: null,          takeover: false },
  rare:      { build: 260,  flip: 440, settle: 300, glow: 0.5,  shake: 2,  rays: false, particles: 8,  banner: 'PARALLEL',    takeover: false },
  epic:      { build: 560,  flip: 520, settle: 420, glow: 0.75, shake: 5,  rays: true,  particles: 22, banner: 'HIT',         takeover: false },
  legendary: { build: 980,  flip: 620, settle: 620, glow: 1,    shake: 9,  rays: true,  particles: 46, banner: 'CASE HIT',    takeover: true },
  mythic:    { build: 1320, flip: 700, settle: 760, glow: 1,    shake: 12, rays: true,  particles: 70, banner: 'CASE HIT',    takeover: true },
  oneofone:  { build: 1900, flip: 820, settle: 1100, glow: 1,   shake: 16, rays: true,  particles: 110, banner: 'ONE OF ONE', takeover: true },
};

export const AnimationSystem = {
  /** Global speed multiplier from settings. */
  scale() {
    const s = S().settings;
    if (s.reduceMotion) return 0.25;
    return s.fastReveal ? 0.45 : 1;
  },

  ms(v) { return Math.round(v * this.scale()); },

  /** Reveal recipe for a card, with times already scaled. */
  choreography(rarityId, card) {
    const base = CHOREOGRAPHY[rarityId] ?? CHOREOGRAPHY.common;
    const recipe = { ...base };
    // Numbered cards always earn the numbering beat, even at lower tiers.
    if (card?.serial && recipe.build < 380) { recipe.build = 380; recipe.banner = `SERIAL ${card.serial.num}/${card.serial.run}`; }
    if (card?.autograph) recipe.banner = card.memorabilia ? 'PATCH AUTOGRAPH' : 'AUTOGRAPH';
    else if (card?.memorabilia) recipe.banner = 'MEMORABILIA';
    if (card?.serial?.run === 1) recipe.banner = 'ONE OF ONE';
    for (const k of ['build', 'flip', 'settle']) recipe[k] = this.ms(recipe[k]);
    if (S().settings.reduceMotion) { recipe.shake = 0; recipe.particles = Math.min(recipe.particles, 10); }
    return recipe;
  },

  /** Promise-based tween on an element using the Web Animations API. */
  animate(el, keyframes, options = {}) {
    const duration = this.ms(options.duration ?? 300);
    const anim = el.animate(keyframes, {
      duration,
      easing: options.easing ?? EASE.out,
      fill: options.fill ?? 'both',
      delay: this.ms(options.delay ?? 0),
      iterations: options.iterations ?? 1,
    });
    return anim.finished.catch(() => {});
  },

  /** Camera shake on a container. */
  shake(el, magnitude = 6, duration = 420) {
    if (!magnitude || S().settings.reduceMotion) return Promise.resolve();
    const frames = [];
    const steps = 10;
    for (let i = 0; i <= steps; i += 1) {
      const decay = 1 - i / steps;
      frames.push({
        transform: `translate3d(${(Math.random() * 2 - 1) * magnitude * decay}px, ${(Math.random() * 2 - 1) * magnitude * decay}px, 0)`,
      });
    }
    return this.animate(el, frames, { duration, easing: 'linear' });
  },

  /** White flash overlay used at the top of a big reveal. */
  flash(host, { color = '#ffffff', peak = 0.85, duration = 420 } = {}) {
    const el = document.createElement('div');
    el.className = 'fx-flash';
    el.style.background = color;
    host.append(el);
    return this.animate(el, [{ opacity: 0 }, { opacity: peak, offset: 0.12 }, { opacity: 0 }], { duration })
      .then(() => el.remove());
  },

  /** Stagger helper for grids of cards. */
  stagger(nodes, keyframes, { duration = 420, step = 55, easing = EASE.out } = {}) {
    return Promise.all([...nodes].map((n, i) => this.animate(n, keyframes, { duration, delay: i * step, easing })));
  },
};
