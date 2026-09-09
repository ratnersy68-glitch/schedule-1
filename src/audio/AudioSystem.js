/**
 * AudioSystem - modular sound.
 *
 * Each cue is a named recipe. Cues synthesise through WebAudio by default so the
 * game ships with no binary audio, but any cue can be replaced by dropping a file
 * at assets/audio/<cue>.(mp3|ogg|wav) and listing it in SAMPLE_OVERRIDES - the
 * sampler is preferred whenever a file loads.
 */

const SAMPLE_OVERRIDES = {
  // 'ultra': 'assets/audio/ultra.mp3',
};

/** Voice recipes: shape, frequency envelope, filter and gain envelope. */
const CUES = {
  click:     { type: 'square',   f: [420, 300],   dur: 0.05, gain: 0.10, filter: 1800, decay: 3 },
  hover:     { type: 'sine',     f: [660, 700],   dur: 0.04, gain: 0.04, filter: 3000, decay: 4 },
  back:      { type: 'triangle', f: [300, 200],   dur: 0.08, gain: 0.09, filter: 1400, decay: 3 },
  error:     { type: 'sawtooth', f: [180, 110],   dur: 0.22, gain: 0.12, filter: 900,  decay: 2 },
  cash:      { type: 'triangle', f: [880, 1320],  dur: 0.16, gain: 0.13, filter: 5200, decay: 3, chime: [1320, 1760] },
  purchase:  { type: 'triangle', f: [520, 780],   dur: 0.26, gain: 0.15, filter: 4200, decay: 2, chime: [1040, 1560] },
  boxOpen:   { type: 'sawtooth', f: [120, 60],    dur: 0.6,  gain: 0.16, filter: 700,  decay: 1.6, noise: 0.4 },
  packRip:   { type: 'noise',    dur: 0.42, gain: 0.22, filter: 3400, sweep: [4200, 700], decay: 1.4 },
  cardFlip:  { type: 'noise',    dur: 0.13, gain: 0.10, filter: 2600, sweep: [3000, 1400], decay: 3 },
  common:    { type: 'sine',     f: [520, 620],   dur: 0.10, gain: 0.07, filter: 2600, decay: 3 },
  insert:    { type: 'triangle', f: [660, 880],   dur: 0.20, gain: 0.11, filter: 4000, decay: 2.4, chime: [1320] },
  foil:      { type: 'triangle', f: [740, 1180],  dur: 0.34, gain: 0.13, filter: 5200, decay: 2, chime: [1480, 1976] },
  numbered:  { type: 'triangle', f: [520, 1040],  dur: 0.5,  gain: 0.15, filter: 5200, decay: 1.8, chime: [1560, 2080], shimmer: true },
  auto:      { type: 'sine',     f: [392, 784],   dur: 0.7,  gain: 0.17, filter: 6000, decay: 1.5, chime: [1176, 1568], shimmer: true },
  relic:     { type: 'triangle', f: [330, 494],   dur: 0.6,  gain: 0.16, filter: 3200, decay: 1.6, noise: 0.25, chime: [988] },
  ultra:     { type: 'sawtooth', f: [220, 880],   dur: 1.5,  gain: 0.2,  filter: 7000, decay: 1.1, chime: [1320, 1760, 2640], shimmer: true, riser: true },
  oneofone:  { type: 'sawtooth', f: [174, 1046],  dur: 2.2,  gain: 0.22, filter: 8000, decay: 0.9, chime: [1046, 1568, 2093, 3136], shimmer: true, riser: true },
  submit:    { type: 'triangle', f: [440, 330],   dur: 0.3,  gain: 0.12, filter: 2600, decay: 2.2 },
  gradeReveal:{ type: 'sine',    f: [294, 587],   dur: 0.9,  gain: 0.16, filter: 5200, decay: 1.4, chime: [880, 1174], shimmer: true },
  gem:       { type: 'sine',     f: [523, 1046],  dur: 1.6,  gain: 0.2,  filter: 9000, decay: 1.0, chime: [1568, 2093, 3136], shimmer: true, riser: true },
  sell:      { type: 'triangle', f: [700, 440],   dur: 0.24, gain: 0.13, filter: 3800, decay: 2.2, chime: [880] },
  levelUp:   { type: 'triangle', f: [392, 659],   dur: 1.0,  gain: 0.18, filter: 6000, decay: 1.4, chime: [784, 988, 1319], shimmer: true },
  challenge: { type: 'triangle', f: [587, 880],   dur: 0.4,  gain: 0.14, filter: 4600, decay: 2, chime: [1174] },
  whoosh:    { type: 'noise',    dur: 0.3,  gain: 0.09, filter: 1200, sweep: [400, 2600], decay: 2 },
};

/** Rarity tier -> reveal cue. Rarer pulls sound obviously different. */
const RARITY_CUE = {
  common: 'common', uncommon: 'insert', rare: 'foil',
  epic: 'auto', legendary: 'ultra', mythic: 'ultra', oneofone: 'oneofone',
};

class Audio {
  ctx = null;
  master = null;
  #buffers = new Map();
  #enabled = true;
  #volume = 0.7;
  #noiseBuffer = null;

  init(settings = {}) {
    this.#enabled = settings.sfx !== false;
    this.#volume = settings.volume ?? 0.7;
    const resume = () => {
      this.#ensureContext();
      if (this.ctx?.state === 'suspended') this.ctx.resume();
      window.removeEventListener('pointerdown', resume);
      window.removeEventListener('keydown', resume);
    };
    window.addEventListener('pointerdown', resume);
    window.addEventListener('keydown', resume);
    this.#preloadSamples();
  }

  setEnabled(on) { this.#enabled = on; }
  setVolume(v) { this.#volume = v; if (this.master) this.master.gain.value = v; }

  #ensureContext() {
    if (this.ctx) return this.ctx;
    const Ctx = window.AudioContext || window.webkitAudioContext;
    if (!Ctx) return null;
    this.ctx = new Ctx();
    this.master = this.ctx.createGain();
    this.master.gain.value = this.#volume;
    this.master.connect(this.ctx.destination);
    return this.ctx;
  }

  async #preloadSamples() {
    for (const [cue, path] of Object.entries(SAMPLE_OVERRIDES)) {
      try {
        const buf = await fetch(path).then((r) => r.arrayBuffer());
        const ctx = this.#ensureContext();
        if (ctx) this.#buffers.set(cue, await ctx.decodeAudioData(buf));
      } catch { /* fall back to synthesis */ }
    }
  }

  #noise() {
    if (this.#noiseBuffer) return this.#noiseBuffer;
    const ctx = this.#ensureContext();
    const len = ctx.sampleRate * 2;
    const buf = ctx.createBuffer(1, len, ctx.sampleRate);
    const d = buf.getChannelData(0);
    for (let i = 0; i < len; i += 1) d[i] = Math.random() * 2 - 1;
    this.#noiseBuffer = buf;
    return buf;
  }

  play(cue, { rate = 1, gain = 1 } = {}) {
    if (!this.#enabled) return;
    const ctx = this.#ensureContext();
    if (!ctx || ctx.state === 'suspended') return;
    const recipe = CUES[cue];
    if (!recipe) return;

    if (this.#buffers.has(cue)) {
      const src = ctx.createBufferSource();
      src.buffer = this.#buffers.get(cue);
      src.playbackRate.value = rate;
      const g = ctx.createGain();
      g.gain.value = gain;
      src.connect(g).connect(this.master);
      src.start();
      return;
    }

    const t = ctx.currentTime;
    const out = ctx.createGain();
    out.gain.value = 0;
    out.connect(this.master);

    const filter = ctx.createBiquadFilter();
    filter.type = 'lowpass';
    filter.frequency.setValueAtTime(recipe.filter ?? 4000, t);
    if (recipe.sweep) {
      filter.frequency.setValueAtTime(recipe.sweep[0], t);
      filter.frequency.exponentialRampToValueAtTime(Math.max(60, recipe.sweep[1]), t + recipe.dur);
    }
    filter.connect(out);

    if (recipe.type === 'noise' || recipe.noise) {
      const src = ctx.createBufferSource();
      src.buffer = this.#noise();
      const ng = ctx.createGain();
      ng.gain.value = recipe.type === 'noise' ? 1 : recipe.noise;
      src.connect(ng).connect(filter);
      src.start(t);
      src.stop(t + recipe.dur);
    }

    if (recipe.f) {
      const osc = ctx.createOscillator();
      osc.type = recipe.type === 'noise' ? 'sine' : recipe.type;
      osc.frequency.setValueAtTime(recipe.f[0] * rate, t);
      osc.frequency.exponentialRampToValueAtTime(Math.max(30, recipe.f[1] * rate), t + recipe.dur);
      osc.connect(filter);
      osc.start(t);
      osc.stop(t + recipe.dur + 0.05);
      if (recipe.riser) {
        const sub = ctx.createOscillator();
        sub.type = 'sine';
        sub.frequency.setValueAtTime(recipe.f[0] / 2, t);
        sub.frequency.exponentialRampToValueAtTime(recipe.f[1] / 2, t + recipe.dur);
        const sg = ctx.createGain();
        sg.gain.value = 0.5;
        sub.connect(sg).connect(filter);
        sub.start(t); sub.stop(t + recipe.dur + 0.05);
      }
    }

    for (const [i, freq] of (recipe.chime ?? []).entries()) {
      const osc = ctx.createOscillator();
      osc.type = 'sine';
      osc.frequency.value = freq * rate;
      const g = ctx.createGain();
      const start = t + i * (recipe.shimmer ? 0.11 : 0.05);
      g.gain.setValueAtTime(0, start);
      g.gain.linearRampToValueAtTime(0.28 * (recipe.gain ?? 0.1) * gain, start + 0.012);
      g.gain.exponentialRampToValueAtTime(0.0001, start + recipe.dur * 0.9);
      osc.connect(g).connect(this.master);
      osc.start(start);
      osc.stop(start + recipe.dur);
    }

    const peak = (recipe.gain ?? 0.12) * gain;
    out.gain.setValueAtTime(0, t);
    out.gain.linearRampToValueAtTime(peak, t + 0.012);
    out.gain.exponentialRampToValueAtTime(0.0001, t + recipe.dur * (1 / (recipe.decay ?? 2)) + 0.08);
  }

  /** Reveal cue chosen from the card's rarity tier. */
  reveal(card, rarityId) {
    if (card?.serial?.run === 1) return this.play('oneofone');
    if (card?.autograph && card?.memorabilia) return this.play('ultra');
    if (card?.autograph) return this.play('auto');
    if (card?.memorabilia) return this.play('relic');
    if (card?.serial) return this.play('numbered');
    return this.play(RARITY_CUE[rarityId] ?? 'common');
  }

  cues() { return Object.keys(CUES); }
}

export const AudioSystem = new Audio();
