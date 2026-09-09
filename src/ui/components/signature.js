/**
 * Deterministic signature generator.
 *
 * An autograph card needs the player's own hand, so the stroke is derived from
 * the name: same player, same signature, every time, without shipping 60 files.
 */

function hash(str) {
  let h = 2166136261;
  for (let i = 0; i < str.length; i += 1) { h ^= str.charCodeAt(i); h = Math.imul(h, 16777619); }
  return h >>> 0;
}

function seeded(seed) {
  let s = seed || 1;
  return () => { s ^= s << 13; s >>>= 0; s ^= s >> 17; s ^= s << 5; s >>>= 0; return s / 4294967296; };
}

/** SVG path data for a flowing signature across a 300 x 90 box. */
export function signaturePath(name) {
  const rand = seeded(hash(name));
  const words = name.split(/\s+/).filter(Boolean);
  const glyphs = words.join('').length;
  const width = 296;
  const baseline = 62;
  const advance = Math.min(20, Math.max(9, (width - 24) / Math.max(6, glyphs)));

  let x = 8;
  let d = '';
  const segments = [];

  words.forEach((word, wi) => {
    // Capital: a tall entry loop that sets the character of the hand.
    const capH = 34 + rand() * 22;
    const capW = advance * (1.5 + rand());
    segments.push(`M${x.toFixed(1)},${baseline.toFixed(1)}`
      + `C${(x - 6).toFixed(1)},${(baseline - capH * 0.55).toFixed(1)} `
      + `${(x + capW * 0.15).toFixed(1)},${(baseline - capH).toFixed(1)} `
      + `${(x + capW * 0.5).toFixed(1)},${(baseline - capH * 0.82).toFixed(1)}`
      + `C${(x + capW * 0.86).toFixed(1)},${(baseline - capH * 0.64).toFixed(1)} `
      + `${(x + capW * 0.2).toFixed(1)},${(baseline - capH * 0.1).toFixed(1)} `
      + `${(x + capW).toFixed(1)},${(baseline + (rand() - 0.5) * 5).toFixed(1)}`);
    x += capW;

    const rest = word.length - 1;
    for (let i = 0; i < rest; i += 1) {
      const r = rand();
      const w = advance * (0.7 + r * 0.7);
      const h = 12 + r * 22;
      const dip = rand() > 0.78 ? 14 : 0; // descender
      if (rand() > 0.72) {
        // small loop
        segments.push(`C${(x + w * 0.1).toFixed(1)},${(baseline - h).toFixed(1)} `
          + `${(x + w * 0.9).toFixed(1)},${(baseline - h * 1.15).toFixed(1)} `
          + `${(x + w * 0.55).toFixed(1)},${(baseline - h * 0.2).toFixed(1)}`
          + `C${(x + w * 0.3).toFixed(1)},${(baseline + 4).toFixed(1)} `
          + `${(x + w * 0.8).toFixed(1)},${(baseline + dip).toFixed(1)} `
          + `${(x + w).toFixed(1)},${(baseline + (rand() - 0.5) * 4).toFixed(1)}`);
      } else {
        segments.push(`C${(x + w * 0.2).toFixed(1)},${(baseline - h).toFixed(1)} `
          + `${(x + w * 0.7).toFixed(1)},${(baseline - h * 0.7).toFixed(1)} `
          + `${(x + w).toFixed(1)},${(baseline + dip * 0.4 + (rand() - 0.5) * 5).toFixed(1)}`);
      }
      x += w;
    }

    if (wi < words.length - 1) {
      const gap = advance * 0.8;
      segments.push(`C${(x + gap * 0.3).toFixed(1)},${(baseline - 10).toFixed(1)} `
        + `${(x + gap * 0.6).toFixed(1)},${(baseline - 4).toFixed(1)} `
        + `${(x + gap).toFixed(1)},${baseline.toFixed(1)}`);
      x += gap;
    }
  });

  d = segments.join('');

  // Trailing flourish underlining the whole hand.
  const end = Math.min(x, width);
  const flourish = `M${end.toFixed(1)},${(baseline + 2).toFixed(1)}`
    + `C${(end + 14).toFixed(1)},${(baseline - 16).toFixed(1)} `
    + `${(end - 30).toFixed(1)},${(baseline + 26).toFixed(1)} `
    + `${(end * 0.36).toFixed(1)},${(baseline + 20).toFixed(1)}`
    + `C${(end * 0.16).toFixed(1)},${(baseline + 17).toFixed(1)} `
    + `${(end * 0.5).toFixed(1)},${(baseline + 9).toFixed(1)} `
    + `${(end * 0.86).toFixed(1)},${(baseline + 13).toFixed(1)}`;

  return { d, flourish, viewBox: `0 0 ${width} 90` };
}

export function signatureSvg(name, { className = '', dual = false } = {}) {
  const { d, flourish, viewBox } = signaturePath(name);
  const second = dual ? signaturePath(`${name} II`) : null;
  return `<svg class="${className}" viewBox="${viewBox}" preserveAspectRatio="xMidYMid meet" aria-hidden="true">`
    + (second
      ? `<g transform="translate(6,-16) rotate(-5 148 45) scale(.8)" opacity=".92">`
        + `<path d="${second.d}"/><path d="${second.flourish}" opacity=".8" stroke-width="1.8"/></g>`
        + `<g transform="translate(-4,18) rotate(3 148 45) scale(.82)">`
        + `<path d="${d}"/><path d="${flourish}" opacity=".8" stroke-width="1.8"/></g>`
      : `<g transform="rotate(-2.5 148 45)"><path d="${d}"/><path d="${flourish}" opacity=".8" stroke-width="1.8"/></g>`)
    + `</svg>`;
}
