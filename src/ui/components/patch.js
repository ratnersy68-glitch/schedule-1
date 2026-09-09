/** Memorabilia swatch: a multi-panel jersey patch built from franchise colours. */
import { shade, tint } from '../../core/color.js';

function seeded(seed) {
  let s = 0;
  for (let i = 0; i < seed.length; i += 1) s = (s * 31 + seed.charCodeAt(i)) >>> 0;
  return () => { s ^= s << 13; s >>>= 0; s ^= s >> 17; s ^= s << 5; s >>>= 0; return s / 4294967296; };
}

/** `prime` patches show more panels and a stripe seam - the ones collectors chase. */
export function patchSvg(card, colors, { prime = false } = {}) {
  const rand = seeded(card.uid + card.player);
  const { primary, secondary, accent } = colors;
  // Jersey material, not UI colour: saturated team tones plus the white of the
  // uniform. The near-white accent is kept for stitching so panels stay readable.
  const jersey = '#E6E9EF';
  const palette = prime
    ? [primary, secondary, jersey, shade(secondary, 0.35), shade(primary, 0.2), tint(primary, 0.2)]
    : [primary, shade(primary, 0.32), secondary];

  const W = 200; const H = 150;
  const panels = [];
  const cuts = prime ? 4 : 2;
  let y = 0;
  for (let i = 0; i <= cuts; i += 1) {
    const h = i === cuts ? H - y : (H / (cuts + 1)) * (0.6 + rand() * 0.9);
    const skew = (rand() - 0.5) * 26;
    panels.push(`<path d="M0,${y.toFixed(1)}L${W},${(y + skew).toFixed(1)}L${W},${(y + h + skew).toFixed(1)}L0,${(y + h).toFixed(1)}Z" fill="${palette[i % palette.length]}"/>`);
    y += h;
    if (y >= H) break;
  }

  const stitches = Array.from({ length: prime ? 5 : 3 }, (_, i) => {
    const sy = 18 + i * (H / (prime ? 5 : 3));
    const dash = Array.from({ length: 14 }, (_, k) => `M${k * 15 + 4},${(sy + Math.sin(k) * 2).toFixed(1)}h7`).join('');
    return `<path d="${dash}" stroke="${accent}" stroke-opacity=".7" stroke-width="2.4" fill="none"/>`;
  }).join('');

  // A slice of a letter or number, the way a prime patch cuts through a nameplate.
  const glyph = prime
    ? `<path d="M42,26h34v98H42Zm52,0h30l26,52 26,-52h30v98h-30V72l-26,50h-2l-26,-50v50H94Z" fill="${jersey}" fill-opacity=".9"/>`
    : '';

  return `<svg viewBox="0 0 ${W} ${H}" preserveAspectRatio="xMidYMid slice" aria-hidden="true">
    <defs>
      <linearGradient id="pl${card.uid}" x1="10%" y1="0%" x2="90%" y2="100%">
        <stop offset="0%" stop-color="#fff" stop-opacity=".26"/>
        <stop offset="46%" stop-color="#fff" stop-opacity="0"/>
        <stop offset="100%" stop-color="#000" stop-opacity=".4"/>
      </linearGradient>
      <pattern id="pw${card.uid}" width="6" height="6" patternUnits="userSpaceOnUse">
        <rect width="6" height="6" fill="none"/>
        <circle cx="1.5" cy="1.5" r="1.1" fill="#000" fill-opacity=".16"/>
        <circle cx="4.5" cy="4.5" r="1.1" fill="#fff" fill-opacity=".1"/>
      </pattern>
    </defs>
    ${panels.join('')}
    ${glyph}
    <rect width="${W}" height="${H}" fill="url(#pw${card.uid})"/>
    ${stitches}
    <rect width="${W}" height="${H}" fill="url(#pl${card.uid})"/>
  </svg>`;
}
