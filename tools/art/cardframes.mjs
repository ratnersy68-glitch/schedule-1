/**
 * Card templates. Every product template ships two layers:
 *   frame-<id>-bg  full-bleed art field that sits behind the athlete
 *   frame-<id>-fg  border, nameplate and foil furniture that sits in front
 * Both are team-recoloured at runtime through --tp / --tp-l / --tp-d / --ts / --ta.
 */
import { el, svg, defs, g, linearGradient, radialGradient, roundRect, star, DISPLAY, HEADLINE, MONO, seeded } from './svg.mjs';

const W = 750;
const H = 1050;
/* Franchise tokens colour the art field; product tokens colour the furniture, so a
   Treasures card reads as Treasures whichever franchise is printed on it. */
const TP = 'var(--tp,#1B2A41)';
const TPL = 'var(--tp-l,#3C5678)';
const TPD = 'var(--tp-d,#080C13)';
const TS = 'var(--ts,#C8963E)';
const TA = 'var(--ta,#E9E4D8)';
const PS = 'var(--ps,#C8963E)';   // product accent
const PF = 'var(--pf,#F0DCA6)';   // product foil highlight
const PI = 'var(--pi,#F3F6FB)';   // product ink

const noise = (id, freq = 0.9, oct = 3) => el('filter', { id }, [
  el('feTurbulence', { type: 'fractalNoise', baseFrequency: freq, numOctaves: oct, stitchTiles: 'stitch' }),
  el('feColorMatrix', { type: 'saturate', values: '0' }),
]);

const commonDefs = (extra = []) => defs([
  linearGradient('fieldG', [['0%', TPL], ['46%', TP], ['100%', TPD]], { x1: '10%', y1: '0%', x2: '90%', y2: '100%' }),
  linearGradient('deepG', [['0%', TPD], ['100%', '#05070A']], { x1: '0%', y1: '0%', x2: '0%', y2: '100%' }),
  linearGradient('sheen', [['0%', '#FFFFFF', 0], ['42%', '#FFFFFF', 0.24], ['52%', '#FFFFFF', 0.5], ['62%', '#FFFFFF', 0.18], ['100%', '#FFFFFF', 0]], { x1: '0%', y1: '0%', x2: '100%', y2: '30%' }),
  linearGradient('metal', [['0%', PF], ['22%', PS], ['48%', '#FFFFFF'], ['70%', PS], ['100%', PF]], { x1: '0%', y1: '0%', x2: '100%', y2: '100%' }),
  radialGradient('vignette', [['52%', '#000000', 0], ['100%', '#000000', 0.62]], { cx: '50%', cy: '42%', r: '78%' }),
  radialGradient('spot', [['0%', TA, 0.3], ['100%', TA, 0]], { cx: '50%', cy: '34%', r: '54%' }),
  noise('grain'),
  ...extra,
]);

const vignette = () => el('rect', { width: W, height: H, fill: 'url(#vignette)' });
const grain = (op = 0.05) => el('rect', { width: W, height: H, filter: 'url(#grain)', opacity: op, style: 'mix-blend-mode:overlay' });

/* --------------------------------------------------------------- templates */

const BG = {
  optic: () => [
    commonDefs(),
    el('rect', { width: W, height: H, fill: 'url(#fieldG)' }),
    el('rect', { width: W, height: H, fill: 'url(#spot)' }),
    g({ opacity: 0.5 }, Array.from({ length: 9 }, (_, i) => el('path', {
      d: `M${-160 + i * 118},${H}L${60 + i * 118},0h58L${-102 + i * 118},${H}Z`,
      fill: i % 2 ? TS : TA, opacity: i % 2 ? 0.16 : 0.07,
    }))),
    el('path', { d: `M0,${H * 0.62}L${W},${H * 0.44}V${H}H0Z`, fill: TPD, opacity: 0.55 }),
    el('rect', { width: W, height: H, fill: 'url(#sheen)', opacity: 0.4 }),
    vignette(), grain(),
  ],
  select: () => [
    commonDefs(),
    el('rect', { width: W, height: H, fill: 'url(#fieldG)' }),
    g({ opacity: 0.32 }, Array.from({ length: 22 }, (_, i) => el('path', {
      d: `M0,${i * 52}H${W}`, stroke: TA, 'stroke-width': i % 4 === 0 ? 3 : 1,
    }))),
    el('path', { d: `M${W / 2},0L${W},${H * 0.3}V${H * 0.78}L${W / 2},${H}L0,${H * 0.78}V${H * 0.3}Z`, fill: TS, opacity: 0.14 }),
    el('rect', { width: W, height: H, fill: 'url(#spot)' }),
    vignette(), grain(),
  ],
  prizm: () => [
    commonDefs(),
    el('rect', { width: W, height: H, fill: 'url(#deepG)' }),
    g({ opacity: 0.62 }, Array.from({ length: 40 }, (_, i) => {
      const a = (i / 40) * Math.PI - Math.PI / 2;
      const hue = ['#FF5470', '#FFB35C', '#FFE45C', '#5CE1A0', '#4EA8FF', '#A970FF'][i % 6];
      return el('path', {
        d: `M${W / 2},${H * 1.02}L${W / 2 + Math.cos(a - 0.024) * 1500},${H * 1.02 + Math.sin(a - 0.024) * 1500}L${W / 2 + Math.cos(a + 0.024) * 1500},${H * 1.02 + Math.sin(a + 0.024) * 1500}Z`,
        fill: hue, opacity: 0.2,
      });
    })),
    el('rect', { width: W, height: H, fill: TP, opacity: 0.42, style: 'mix-blend-mode:multiply' }),
    el('rect', { width: W, height: H, fill: 'url(#sheen)', opacity: 0.5 }),
    vignette(), grain(0.06),
  ],
  treasures: () => [
    commonDefs(),
    el('rect', { width: W, height: H, fill: '#0B0907' }),
    el('rect', { width: W, height: H, fill: 'url(#fieldG)', opacity: 0.66 }),
    g({ opacity: 0.14 }, Array.from({ length: 30 }, (_, i) => el('path', {
      d: `M${-200 + i * 60},0L${100 + i * 60},${H}`, stroke: TS, 'stroke-width': 1.5,
    }))),
    el('path', { d: `M0,0H${W}V${H}H0Z`, fill: 'url(#spot)' }),
    ...Array.from({ length: 7 }, (_, i) => el('path', {
      d: `M${W / 2},${H * 0.12 + i * 26}L${W - 60 - i * 18},${H * 0.5}L${W / 2},${H * 0.88 - i * 26}L${60 + i * 18},${H * 0.5}Z`,
      fill: 'none', stroke: TS, 'stroke-width': 1.6, opacity: 0.16,
    })),
    vignette(), grain(0.07),
  ],
  flawless: () => [
    commonDefs(),
    el('rect', { width: W, height: H, fill: '#050506' }),
    el('ellipse', { cx: W / 2, cy: H * 0.36, rx: W * 0.5, ry: H * 0.34, fill: TP, opacity: 0.78 }),
    el('ellipse', { cx: W / 2, cy: H * 0.34, rx: W * 0.34, ry: H * 0.24, fill: TPL, opacity: 0.3 }),
    g({ opacity: 0.5 }, Array.from({ length: 60 }, (_, i) => {
      const r = seeded(`fl${i}`);
      return el('circle', { cx: r() * W, cy: r() * H, r: r() * 2.2 + 0.5, fill: '#FFFFFF', opacity: r() * 0.5 });
    })),
    el('rect', { width: W, height: H, fill: 'url(#sheen)', opacity: 0.24 }),
    vignette(), grain(0.04),
  ],
  prospect: () => [
    commonDefs(),
    el('rect', { width: W, height: H, fill: 'url(#fieldG)' }),
    el('path', { d: `M0,${H}C${W * 0.2},${H * 0.66} ${W * 0.62},${H * 0.5} ${W},${H * 0.2}V${H}Z`, fill: TPD, opacity: 0.7 }),
    el('path', { d: `M0,${H * 0.96}C${W * 0.22},${H * 0.62} ${W * 0.64},${H * 0.46} ${W},${H * 0.16}`, stroke: TS, 'stroke-width': 8, fill: 'none', opacity: 0.7 }),
    el('rect', { width: W, height: H, fill: 'url(#sheen)', opacity: 0.45 }),
    vignette(), grain(),
  ],
  chrome: () => [
    commonDefs(),
    el('rect', { width: W, height: H, fill: 'url(#fieldG)' }),
    el('rect', { y: 0, width: W, height: 120, fill: TPD, opacity: 0.7 }),
    g({ opacity: 0.28 }, Array.from({ length: 16 }, (_, i) => el('path', {
      d: `M${i * 50},0V${H}`, stroke: TA, 'stroke-width': i % 3 === 0 ? 2.5 : 1,
    }))),
    el('path', { d: `M0,${H * 0.72}Q${W / 2},${H * 0.58} ${W},${H * 0.74}V${H}H0Z`, fill: TPD, opacity: 0.72 }),
    el('rect', { width: W, height: H, fill: 'url(#sheen)', opacity: 0.44 }),
    vignette(), grain(),
  ],
  finest: () => [
    commonDefs(),
    el('rect', { width: W, height: H, fill: 'url(#deepG)' }),
    g({ opacity: 0.4 }, Array.from({ length: 26 }, (_, i) => el('path', {
      d: `M${-300 + i * 70},${H}L${180 + i * 70},0`, stroke: i % 2 ? TS : TA, 'stroke-width': i % 2 ? 16 : 5, opacity: i % 2 ? 0.2 : 0.12,
    }))),
    el('path', { d: `M0,0L${W},0L0,${H}Z`, fill: TP, opacity: 0.4 }),
    el('rect', { width: W, height: H, fill: 'url(#sheen)', opacity: 0.55 }),
    vignette(), grain(0.06),
  ],
};

/** Nameplate + border furniture. Transparent through the photo window. */
const FG = {
  optic: () => [
    commonDefs(),
    el('path', { d: `M0,872L${W},828V${H}H0Z`, fill: TPD, opacity: 0.9 }),
    el('path', { d: `M0,872L${W},828v14L0,886Z`, fill: 'url(#metal)' }),
    el('path', { d: `M0,${H - 16}L${W},${H - 16}v16H0Z`, fill: PS, opacity: 0.85 }),
    frameEdge(PS, 10),
  ],
  select: () => [
    commonDefs(),
    el('path', { d: roundRect(26, 26, W - 52, H - 52, 14), fill: 'none', stroke: 'url(#metal)', 'stroke-width': 7 }),
    el('path', { d: roundRect(44, 44, W - 88, H - 88, 8), fill: 'none', stroke: PI, 'stroke-width': 2, opacity: 0.35 }),
    el('path', { d: `M60,860h${W - 120}v138H60Z`, fill: TPD, opacity: 0.88 }),
    el('path', { d: `M60,860h${W - 120}v8H60Z`, fill: 'url(#metal)' }),
    el('path', { d: `M${W / 2 - 120},26l40,44h-80Z`, fill: PS, opacity: 0.8 }),
    frameEdge(PI, 6, 0.22),
  ],
  prizm: () => [
    commonDefs(),
    el('path', { d: roundRect(18, 18, W - 36, H - 36, 10), fill: 'none', stroke: '#FFFFFF', 'stroke-width': 14, 'stroke-opacity': 0.94 }),
    el('path', { d: `M40,884h${W - 80}v128H40Z`, fill: TPD, opacity: 0.86 }),
    el('path', { d: `M40,884h${W - 80}v6H40Z`, fill: 'url(#metal)' }),
    frameEdge(PS, 5, 0.5),
  ],
  treasures: () => [
    commonDefs(),
    el('path', { d: roundRect(16, 16, W - 32, H - 32, 6), fill: 'none', stroke: 'url(#metal)', 'stroke-width': 15 }),
    el('path', { d: roundRect(46, 46, W - 92, H - 92, 4), fill: 'none', stroke: PS, 'stroke-width': 3, opacity: 0.75 }),
    ...[[46, 46, 1, 1], [W - 46, 46, -1, 1], [46, H - 46, 1, -1], [W - 46, H - 46, -1, -1]].map(([x, y, sx, sy]) => el('path', {
      d: `M${x},${y}l${44 * sx},0q${-30 * sx},${16 * sy} ${-30 * sx},${44 * sy}Z`, fill: PS, opacity: 0.85,
    })),
    el('path', { d: `M70,842h${W - 140}v166H70Z`, fill: '#0A0806', opacity: 0.92 }),
    el('path', { d: `M70,842h${W - 140}v5H70Z`, fill: 'url(#metal)' }),
    el('path', { d: `M70,1008h${W - 140}v-5H70Z`, fill: 'url(#metal)' }),
  ],
  flawless: () => [
    commonDefs(),
    el('path', { d: roundRect(22, 22, W - 44, H - 44, 4), fill: 'none', stroke: 'url(#metal)', 'stroke-width': 3.5 }),
    el('path', { d: roundRect(34, 34, W - 68, H - 68, 2), fill: 'none', stroke: '#FFFFFF', 'stroke-width': 1, opacity: 0.24 }),
    ...[[22, 22], [W - 22, 22], [22, H - 22], [W - 22, H - 22]].map(([x, y]) => g({}, [
      el('path', { d: star(x, y, 22, 8, 4, 0), fill: '#FFFFFF', opacity: 0.85 }),
      el('circle', { cx: x, cy: y, r: 5, fill: '#FFFFFF' }),
    ])),
    el('path', { d: `M0,900h${W}v150H0Z`, fill: '#050506', opacity: 0.85 }),
    el('path', { d: `M56,900h${W - 112}v1.5H56Z`, fill: 'url(#metal)' }),
  ],
  prospect: () => [
    commonDefs(),
    el('path', { d: roundRect(20, 20, W - 40, H - 40, 16), fill: 'none', stroke: PI, 'stroke-width': 8, 'stroke-opacity': 0.85 }),
    el('path', { d: `M44,868h${W - 88}v146H44Z`, fill: TPD, opacity: 0.88 }),
    el('path', { d: 'M44,258h168l-30,58H44Z', fill: PS, opacity: 0.92 }),
    el('text', { x: 72, y: 300, 'font-family': HEADLINE, 'font-size': 38, 'font-weight': 900, fill: '#0B0E13' }, '1ST'),
    frameEdge(PS, 5, 0.4),
  ],
  chrome: () => [
    commonDefs(),
    el('path', { d: roundRect(14, 14, W - 28, H - 28, 8), fill: 'none', stroke: PI, 'stroke-width': 9, 'stroke-opacity': 0.9 }),
    el('path', { d: `M14,880Q${W / 2},844 ${W - 14},884V${H - 14}H14Z`, fill: TPD, opacity: 0.9 }),
    el('path', { d: `M14,880Q${W / 2},844 ${W - 14},884`, stroke: 'url(#metal)', 'stroke-width': 7, fill: 'none' }),
    frameEdge(PS, 4, 0.35),
  ],
  finest: () => [
    commonDefs(),
    el('path', { d: `M14,14H${W - 90}L${W - 14},90V${H - 14}H90L14,${H - 90}Z`, fill: 'none', stroke: 'url(#metal)', 'stroke-width': 10 }),
    el('path', { d: `M50,876h${W - 100}v132H50Z`, fill: TPD, opacity: 0.9 }),
    el('path', { d: `M50,876h${W - 100}v6H50Z`, fill: 'url(#metal)' }),
    el('path', { d: `M${W - 128},640l80,80M${W - 48},640l-80,80`, stroke: PS, 'stroke-width': 5, opacity: 0.22 }),
  ],
};

function frameEdge(color, width, opacity = 0.6) {
  return el('rect', { x: width / 2, y: width / 2, width: W - width, height: H - width, rx: 12, fill: 'none', stroke: color, 'stroke-width': width, opacity });
}

/* ------------------------------------------------------------- card backs */

export function cardBack(sport) {
  const r = seeded(`back-${sport}`);
  return svg({
    w: W, h: H, id: `back-${sport}`,
    children: [
      defs([
        linearGradient('bk', [['0%', '#1C2432'], ['48%', '#111823'], ['100%', '#080B11']], { x1: '12%', y1: '0%', x2: '88%', y2: '100%' }),
        linearGradient('bkfoil', [['0%', '#8C6B2E'], ['30%', '#E7CE8C'], ['52%', '#FFF6DC'], ['74%', '#C9A45C'], ['100%', '#7A5B22']], { x1: '0%', y1: '0%', x2: '100%', y2: '60%' }),
        radialGradient('bkglow', [['0%', '#4C6A9A', 0.4], ['100%', '#4C6A9A', 0]], { cx: '50%', cy: '30%', r: '62%' }),
        noise('bgrain'),
      ]),
      el('rect', { width: W, height: H, fill: 'url(#bk)' }),
      el('rect', { width: W, height: H, fill: 'url(#bkglow)' }),
      g({ opacity: 0.1 }, Array.from({ length: 26 }, (_, i) => el('path', { d: `M${-200 + i * 56},${H}L${140 + i * 56},0`, stroke: '#9FB4D4', 'stroke-width': 2 }))),
      el('path', { d: roundRect(28, 28, W - 56, H - 56, 14), fill: 'none', stroke: '#C9A55A', 'stroke-width': 4, opacity: 0.7 }),
      el('rect', { x: 62, y: 300, width: W - 124, height: 2, fill: '#9FB4D4', opacity: 0.25 }),
      ...Array.from({ length: 9 }, (_, i) => g({}, [
        el('rect', { x: 62, y: 340 + i * 46, width: (W - 200) * (0.35 + r() * 0.6), height: 10, rx: 5, fill: '#9FB4D4', opacity: 0.16 }),
        el('rect', { x: W - 168, y: 340 + i * 46, width: 96, height: 10, rx: 5, fill: '#C9A55A', opacity: 0.2 }),
      ])),
      el('rect', { x: 62, y: 782, width: W - 124, height: 2, fill: '#9FB4D4', opacity: 0.25 }),
      el('text', { x: W / 2, y: 200, 'font-family': HEADLINE, 'font-size': 74, 'font-weight': 900, fill: '#E8DCB8', 'text-anchor': 'middle', 'letter-spacing': 4, opacity: 0.92 }, sport === 'NFL' ? 'GRIDIRON' : sport === 'NBA' ? 'HARDWOOD' : 'DIAMOND'),
      el('text', { x: W / 2, y: 248, 'font-family': DISPLAY, 'font-size': 26, fill: '#9FB4D4', 'text-anchor': 'middle', 'letter-spacing': 12 }, 'COLLECTORS SERIES'),
      el('text', { x: W / 2, y: 848, 'font-family': MONO, 'font-size': 19, fill: '#7E8CA3', 'text-anchor': 'middle', 'letter-spacing': 2 }, 'THE BREAK ROOM · FICTIONAL LICENSE'),
      el('text', { x: W / 2, y: 890, 'font-family': MONO, 'font-size': 17, fill: '#5F6B80', 'text-anchor': 'middle', 'letter-spacing': 1 }, 'ALL PLAYERS, TEAMS AND BRANDS ARE FICTIONAL'),
      g({ transform: `translate(${W / 2 - 90},930)` }, Array.from({ length: 30 }, (_, i) => el('rect', {
        x: i * 6, y: 0, width: r() > 0.5 ? 3.4 : 1.8, height: 44, fill: '#C6D2E4', opacity: 0.6,
      }))),
      el('rect', { width: W, height: H, filter: 'url(#bgrain)', opacity: 0.06, style: 'mix-blend-mode:overlay' }),
    ],
  });
}

export function frameAssets() {
  const out = {};
  for (const id of Object.keys(BG)) {
    out[`frame-${id}-bg`] = svg({ w: W, h: H, id: `frame-${id}-bg`, children: BG[id]() });
    out[`frame-${id}-fg`] = svg({ w: W, h: H, id: `frame-${id}-fg`, children: FG[id]() });
  }
  return out;
}

export const TEMPLATE_IDS = Object.keys(BG);
