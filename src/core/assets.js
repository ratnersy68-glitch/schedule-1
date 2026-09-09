/**
 * AssetRegistry - the single place that turns an asset key into pixels.
 *
 * Nothing else in the codebase writes an asset path. Art is resolved from
 * data/assets.manifest.json, optionally redirected by data/assets.overrides.json,
 * and returned either as an inline <svg> (so it can inherit franchise CSS tokens)
 * or an <img> for raster art.
 */

const RASTER = /\.(png|jpe?g|webp|avif|gif)$/i;

class AssetRegistry {
  #manifest = null;
  #byKey = new Map();
  #overrides = {};
  #inlineCache = new Map();
  #pending = new Map();
  base = '';

  async load(base = '') {
    this.base = base;
    const [manifest, overrides] = await Promise.all([
      fetch(`${base}data/assets.manifest.json`).then((r) => r.json()),
      fetch(`${base}data/assets.overrides.json`).then((r) => r.json()).catch(() => ({ overrides: {} })),
    ]);
    this.#manifest = manifest;
    this.#overrides = overrides.overrides || {};
    for (const a of manifest.assets) this.#byKey.set(a.key, a);
    return this;
  }

  get manifest() { return this.#manifest; }
  get card() { return this.#manifest.card; }
  get slab() { return this.#manifest.slab; }

  has(key) { return this.#byKey.has(key) || key in this.#overrides; }
  entry(key) { return this.#byKey.get(key) || null; }

  /** Resolved URL for a key, honouring overrides. Returns null for unknown keys. */
  url(key) {
    const override = this.#overrides[key];
    if (override) return `${this.base}${override}`;
    const entry = this.#byKey.get(key);
    return entry ? `${this.base}${entry.path}` : null;
  }

  isRaster(key) {
    const u = this.url(key);
    return !!u && RASTER.test(u);
  }

  /** Fetch an SVG's source text once and share it across every call site. */
  async source(key) {
    if (this.#inlineCache.has(key)) return this.#inlineCache.get(key);
    if (this.#pending.has(key)) return this.#pending.get(key);
    const url = this.url(key);
    if (!url) { console.warn(`[assets] unknown key "${key}"`); return null; }
    const p = fetch(url)
      .then((r) => (r.ok ? r.text() : Promise.reject(new Error(r.status))))
      .then((text) => { this.#inlineCache.set(key, text); this.#pending.delete(key); return text; })
      .catch((err) => { console.warn(`[assets] failed "${key}"`, err); this.#pending.delete(key); return null; });
    this.#pending.set(key, p);
    return p;
  }

  /**
   * Mount an asset into a host element.
   * Vector art is inlined so CSS custom properties (--tp, --ts, ...) resolve;
   * raster overrides become an <img> with the same object-fit contract.
   */
  async mount(host, key, { className = '', alt = '', preserveAspectRatio } = {}) {
    if (!host) return null;
    const url = this.url(key);
    if (!url) return null;
    if (this.isRaster(key)) {
      const img = document.createElement('img');
      img.src = url;
      img.alt = alt;
      img.decoding = 'async';
      img.loading = 'lazy';
      if (className) img.className = className;
      host.replaceChildren(img);
      return img;
    }
    const text = await this.source(key);
    if (!text) return null;
    host.innerHTML = text;
    const svg = host.querySelector('svg');
    if (svg) {
      svg.removeAttribute('width');
      svg.removeAttribute('height');
      if (className) svg.setAttribute('class', className);
      if (preserveAspectRatio) svg.setAttribute('preserveAspectRatio', preserveAspectRatio);
      svg.setAttribute('aria-hidden', 'true');
      svg.setAttribute('focusable', 'false');
    }
    return svg;
  }

  /** Synchronous inline markup for assets already warmed by preload(). */
  markupSync(key, { className = '' } = {}) {
    const text = this.#inlineCache.get(key);
    if (!text) return '';
    return text
      .replace('<svg', `<svg class="${className}" aria-hidden="true" focusable="false"`)
      .replace(/ width="[\d.]+"/, '')
      .replace(/ height="[\d.]+"/, '');
  }

  /** Warm the cache so first paint of a screen never pops. */
  async preload(keys) {
    await Promise.all(keys.filter((k) => this.has(k) && !this.isRaster(k)).map((k) => this.source(k)));
  }

  /** Every key under a prefix, e.g. keysWith('icon.') */
  keysWith(prefix) {
    return [...this.#byKey.keys()].filter((k) => k.startsWith(prefix));
  }
}

export const Assets = new AssetRegistry();

/* -------------------------------------------------------------- key builders */
/* Keeping key construction here means a manifest rename is a one-file change.  */

export const AssetKeys = {
  bg: (name) => `ui.bg-${name}`,
  icon: (name) => `ui.icon-${name}`,
  fx: (name) => `fx.${name}`,
  league: (sport) => `league.${sport}`,
  team: (teamId) => `team.${teamId}`,
  brand: (boxId) => `brand.${boxId}`,
  box: (boxId) => `box.${boxId}`,
  pack: (boxId) => `pack.${boxId}`,
  frameBg: (template) => `frame.${template}.bg`,
  frameFg: (template) => `frame.${template}.fg`,
  cardBack: (sport) => `cardback.${sport}`,
  pose: (pose) => `pose.${pose}`,
  foil: (foil) => `foil.${foil}`,
  insert: (art) => `insert.${art}`,
  slabShell: () => 'grading.shell',
  slabLabel: (band) => `grading.label.${band}`,
  slabBarcode: () => 'grading.barcode',
  slabQr: () => 'grading.qr',
  graderMark: () => 'grading.mark',
};
