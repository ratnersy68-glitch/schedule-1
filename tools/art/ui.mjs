/** Backgrounds, icons, currency marks and reveal effects. */
import { el, svg, defs, g, linearGradient, radialGradient, roundRect, star, poly, HEADLINE, DISPLAY, seeded } from './svg.mjs';

/* ----------------------------------------------------------- backgrounds */

const BGW = 1920;
const BGH = 1200;

function bokeh(seed, count, colors, maxR = 190) {
  const r = seeded(seed);
  return Array.from({ length: count }, () => {
    const c = colors[Math.floor(r() * colors.length)];
    const rad = 40 + r() * maxR;
    return el('circle', { cx: r() * BGW, cy: r() * BGH, r: rad, fill: c, opacity: 0.04 + r() * 0.09 });
  });
}

const BACKGROUNDS = {
  hall: () => svg({
    w: BGW, h: BGH, id: 'bg-hall',
    children: [
      defs([
        linearGradient('hg', [['0%', '#141C2C'], ['46%', '#0C1220'], ['100%', '#06090F']], { x1: '20%', y1: '0%', x2: '80%', y2: '100%' }),
        radialGradient('hspot', [['0%', '#5E86C6', 0.22], ['100%', '#5E86C6', 0]], { cx: '50%', cy: '12%', r: '58%' }),
      ]),
      el('rect', { width: BGW, height: BGH, fill: 'url(#hg)' }),
      el('rect', { width: BGW, height: BGH, fill: 'url(#hspot)' }),
      // display-case shelving receding into the dark
      g({ opacity: 0.3 }, Array.from({ length: 5 }, (_, row) => g({}, [
        el('rect', { x: 0, y: 250 + row * 190, width: BGW, height: 4, fill: '#7C93B8', opacity: 0.35 }),
        ...Array.from({ length: 26 }, (_, i) => el('rect', {
          x: 30 + i * 74, y: 250 + row * 190 - 108, width: 54, height: 106, rx: 4,
          fill: ['#22304A', '#2A3A58', '#1B2740'][(i + row) % 3], opacity: 0.7,
        })),
      ]))),
      ...bokeh('hall', 26, ['#4E7FD1', '#C8963E', '#5FBF8F']),
      el('rect', { width: BGW, height: BGH, fill: '#05070C', opacity: 0.42 }),
    ],
  }),

  break: () => svg({
    w: BGW, h: BGH, id: 'bg-break',
    children: [
      defs([
        radialGradient('bstage', [['0%', '#2C3C58', 1], ['46%', '#101724', 1], ['100%', '#05070C', 1]], { cx: '50%', cy: '40%', r: '70%' }),
        linearGradient('bfloor', [['0%', '#0B1018', 0], ['100%', '#000000', 0.9]], { x1: '0%', y1: '0%', x2: '0%', y2: '100%' }),
      ]),
      el('rect', { width: BGW, height: BGH, fill: 'url(#bstage)' }),
      g({ opacity: 0.16 }, Array.from({ length: 30 }, (_, i) => el('path', {
        d: `M${BGW / 2},${-200}L${(i / 30) * BGW * 2 - BGW * 0.5},${BGH}`, stroke: '#9FC0F0', 'stroke-width': i % 3 ? 1 : 3,
      }))),
      el('ellipse', { cx: BGW / 2, cy: BGH * 0.62, rx: BGW * 0.42, ry: 240, fill: '#8FB4E8', opacity: 0.07 }),
      el('rect', { y: BGH * 0.66, width: BGW, height: BGH * 0.34, fill: 'url(#bfloor)' }),
    ],
  }),

  vault: () => svg({
    w: BGW, h: BGH, id: 'bg-vault',
    children: [
      defs([
        linearGradient('vg', [['0%', '#131A26'], ['100%', '#070A11']], { x1: '0%', y1: '0%', x2: '40%', y2: '100%' }),
      ]),
      el('rect', { width: BGW, height: BGH, fill: 'url(#vg)' }),
      g({ opacity: 0.2 }, [
        ...Array.from({ length: 24 }, (_, i) => el('path', { d: `M${i * 84},0V${BGH}`, stroke: '#6E86AC', 'stroke-width': 1 })),
        ...Array.from({ length: 15 }, (_, i) => el('path', { d: `M0,${i * 84}H${BGW}`, stroke: '#6E86AC', 'stroke-width': 1 })),
      ]),
      ...bokeh('vault', 18, ['#4E7FD1', '#8B5CF6']),
      el('rect', { width: BGW, height: BGH, fill: '#05070C', opacity: 0.4 }),
    ],
  }),

  market: () => svg({
    w: BGW, h: BGH, id: 'bg-market',
    children: [
      defs([
        linearGradient('mg', [['0%', '#0E1B1A'], ['54%', '#0A1219'], ['100%', '#05090C']], { x1: '10%', y1: '0%', x2: '90%', y2: '100%' }),
      ]),
      el('rect', { width: BGW, height: BGH, fill: 'url(#mg)' }),
      // ticker candlesticks
      g({ opacity: 0.28 }, Array.from({ length: 60 }, (_, i) => {
        const r = seeded(`mk${i}`);
        const h = 40 + r() * 300;
        const y = BGH * 0.5 + Math.sin(i / 6) * 180 - h / 2;
        const up = r() > 0.42;
        return g({}, [
          el('rect', { x: i * 32 + 8, y, width: 14, height: h, fill: up ? '#3FBF8F' : '#D9564E', opacity: 0.5 }),
          el('path', { d: `M${i * 32 + 15},${y - 26}V${y + h + 26}`, stroke: up ? '#3FBF8F' : '#D9564E', 'stroke-width': 2, opacity: 0.5 }),
        ]);
      })),
      el('rect', { width: BGW, height: BGH, fill: '#04070A', opacity: 0.5 }),
    ],
  }),

  grading: () => svg({
    w: BGW, h: BGH, id: 'bg-grading',
    children: [
      defs([
        linearGradient('gg', [['0%', '#101828'], ['100%', '#05070C']], { x1: '0%', y1: '0%', x2: '30%', y2: '100%' }),
        radialGradient('glight', [['0%', '#D8E4F8', 0.16], ['100%', '#D8E4F8', 0]], { cx: '50%', cy: '20%', r: '54%' }),
      ]),
      el('rect', { width: BGW, height: BGH, fill: 'url(#gg)' }),
      el('rect', { width: BGW, height: BGH, fill: 'url(#glight)' }),
      g({ opacity: 0.18 }, Array.from({ length: 9 }, (_, i) => el('path', {
        d: roundRect(120 + i * 200, 300 + (i % 3) * 120, 130, 200, 10), fill: 'none', stroke: '#9FB6D8', 'stroke-width': 2,
      }))),
      el('rect', { width: BGW, height: BGH, fill: '#05070C', opacity: 0.42 }),
    ],
  }),
};

/* ----------------------------------------------------------------- icons */

const S = 48;
const stroke = (d, extra = {}) => el('path', { d, fill: 'none', stroke: 'currentColor', 'stroke-width': 3.2, 'stroke-linecap': 'round', 'stroke-linejoin': 'round', ...extra });

const ICONS = {
  cash: () => [stroke('M6,14h36v20H6Z'), stroke('M24,18a6,6 0 1 0 0.01,0'), stroke('M12,20v8M36,20v8'), stroke('M10,38h28')],
  box: () => [stroke('M24,6l18,8v20l-18,8L6,34V14Z'), stroke('M6,14l18,8 18,-8M24,22v20')],
  cards: () => [stroke('M14,12h22v28H14Z'), stroke('M10,18v22h20')],
  grade: () => [stroke('M12,6h24v36H12Z'), stroke('M18,14h12M18,22h12M18,30h6')],
  market: () => [stroke('M8,34l10,-12 8,7 14,-17'), stroke('M32,12h8v8')],
  level: () => [stroke('M24,6l5,12 13,1 -10,9 3,13 -11,-7 -11,7 3,-13 -10,-9 13,-1Z')],
  trophy: () => [stroke('M16,8h16v10a8,8 0 0 1 -16,0Z'), stroke('M16,10H8v4a6,6 0 0 0 8,5M32,10h8v4a6,6 0 0 1 -8,5'), stroke('M20,26v8h8v-8M14,40h20')],
  chart: () => [stroke('M8,40V20M18,40V10M28,40V26M38,40V16')],
  filter: () => [stroke('M6,10h36l-14,16v14l-8,-4V26Z')],
  sell: () => [stroke('M26,6H42v16L24,40 8,24Z'), stroke('M35,14a1,1 0 1 0 0.01,0')],
  lock: () => [stroke('M12,22h24v18H12Z'), stroke('M17,22v-6a7,7 0 0 1 14,0v6')],
  star: () => [stroke('M24,7l5,11 12,2 -9,8 2,12 -10,-6 -10,6 2,-12 -9,-8 12,-2Z')],
  clock: () => [stroke('M24,6a18,18 0 1 0 0.01,0'), stroke('M24,14v11l7,5')],
  check: () => [stroke('M8,25l10,10 22,-24')],
  close: () => [stroke('M12,12l24,24M36,12L12,36')],
  chevron: () => [stroke('M18,10l14,14 -14,14')],
  plus: () => [stroke('M24,10v28M10,24h28')],
  search: () => [stroke('M22,6a14,14 0 1 0 0.01,0'), stroke('M32,32l10,10')],
  sort: () => [stroke('M14,10v28M8,32l6,6 6,-6'), stroke('M34,38V10M28,16l6,-6 6,6')],
  sparkle: () => [stroke('M24,6l4,12 12,4 -12,4 -4,12 -4,-12 -12,-4 12,-4Z'), stroke('M38,8l1.6,4.4L44,14l-4.4,1.6L38,20l-1.6,-4.4L32,14l4.4,-1.6Z')],
  flame: () => [stroke('M24,6c8,10 12,12 12,20a12,12 0 0 1 -24,0c0,-5 3,-8 6,-12 1,4 3,5 4,3 1,-3 0,-7 2,-11Z')],
  gift: () => [stroke('M8,20h32v20H8Z'), stroke('M6,14h36v6H6ZM24,14v26'), stroke('M24,14c-6,0 -10,-2 -10,-5s6,-3 10,5c4,-8 10,-8 10,-5s-4,5 -10,5')],
  shield: () => [stroke('M24,6l16,6v12c0,10 -7,15 -16,18 -9,-3 -16,-8 -16,-18V12Z'), stroke('M17,24l5,5 10,-11')],
  info: () => [stroke('M24,6a18,18 0 1 0 0.01,0'), stroke('M24,21v13M24,14v0.01')],
  bolt: () => [stroke('M26,6L12,27h10l-2,15 16,-22H26Z')],
};

/* --------------------------------------------------------------- effects */

const EFFECTS = {
  rays: () => svg({
    w: 1200, h: 1200, id: 'fx-rays',
    children: [
      defs([radialGradient('rf', [['0%', '#FFFFFF', 0.9], ['62%', '#FFFFFF', 0.12], ['100%', '#FFFFFF', 0]])]),
      g({}, Array.from({ length: 48 }, (_, i) => {
        const a = (i / 48) * Math.PI * 2;
        const wdt = i % 3 === 0 ? 0.05 : 0.014;
        return el('path', {
          d: `M600,600L${600 + Math.cos(a - wdt) * 900},${600 + Math.sin(a - wdt) * 900}L${600 + Math.cos(a + wdt) * 900},${600 + Math.sin(a + wdt) * 900}Z`,
          fill: '#FFFFFF', opacity: i % 3 === 0 ? 0.5 : 0.2,
        });
      })),
      el('circle', { cx: 600, cy: 600, r: 420, fill: 'url(#rf)' }),
    ],
  }),
  ring: () => svg({
    w: 600, h: 600, id: 'fx-ring',
    children: [
      defs([radialGradient('rg', [['62%', '#FFFFFF', 0], ['82%', '#FFFFFF', 0.8], ['100%', '#FFFFFF', 0]])]),
      el('circle', { cx: 300, cy: 300, r: 300, fill: 'url(#rg)' }),
    ],
  }),
  confetti: () => svg({
    w: 600, h: 600, id: 'fx-confetti',
    children: [g({}, Array.from({ length: 90 }, (_, i) => {
      const r = seeded(`cf${i}`);
      const c = ['#FF4D6D', '#FFC24D', '#5CE1A0', '#4CC9F0', '#9B7BFF', '#FFFFFF'][i % 6];
      return el('rect', { x: r() * 600, y: r() * 600, width: 5 + r() * 9, height: 3 + r() * 5, rx: 1.5, fill: c, opacity: 0.5 + r() * 0.5, transform: `rotate(${r() * 360} 300 300)` });
    }))],
  }),
  spark: () => svg({
    w: 200, h: 200, id: 'fx-spark',
    children: [
      el('path', { d: 'M100,4L116,84L196,100L116,116L100,196L84,116L4,100L84,84Z', fill: '#FFFFFF' }),
      el('path', { d: 'M100,44L108,92L156,100L108,108L100,156L92,108L44,100L92,92Z', fill: '#FFF6D8' }),
    ],
  }),
};

/* --------------------------------------------------------------- currency */

function currencyMark() {
  return svg({
    w: 96, h: 96, id: 'icon-currency',
    children: [
      defs([linearGradient('cg', [['0%', '#FFE9A8'], ['46%', '#E8B84B'], ['100%', '#9A6E14']], { x1: '10%', y1: '0%', x2: '90%', y2: '100%' })]),
      el('circle', { cx: 48, cy: 48, r: 44, fill: 'url(#cg)' }),
      el('circle', { cx: 48, cy: 48, r: 37, fill: 'none', stroke: '#7A5410', 'stroke-width': 3, opacity: 0.55 }),
      el('text', { x: 48, y: 66, 'font-family': HEADLINE, 'font-size': 46, 'font-weight': 900, fill: '#5C3F09', 'text-anchor': 'middle' }, '$'),
      el('path', { d: 'M22,20a44,44 0 0 1 34,-11', stroke: '#FFF6DC', 'stroke-width': 5, fill: 'none', 'stroke-linecap': 'round', opacity: 0.7 }),
    ],
  });
}

export function uiAssets() {
  const out = {};
  for (const [id, fn] of Object.entries(BACKGROUNDS)) out[`bg-${id}`] = fn();
  for (const [id, fn] of Object.entries(ICONS)) {
    out[`icon-${id}`] = svg({ w: S, h: S, id: `icon-${id}`, children: fn(), extra: { fill: 'none' } });
  }
  for (const [id, fn] of Object.entries(EFFECTS)) out[`fx-${id}`] = fn();
  out['icon-currency'] = currencyMark();
  return out;
}

export const ICON_IDS = [...Object.keys(ICONS), 'currency'];
export const BG_IDS = Object.keys(BACKGROUNDS);
export const FX_IDS = Object.keys(EFFECTS);
