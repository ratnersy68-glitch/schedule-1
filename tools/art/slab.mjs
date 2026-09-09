/**
 * Grading slab furniture for the in-game grader, "Apex Grading Authority" (AGA).
 * Fictional grading company - no real grader's trade dress is used.
 */
import { el, svg, defs, g, linearGradient, radialGradient, roundRect, star, HEADLINE, DISPLAY, MONO, seeded } from './svg.mjs';

const W = 820;
const H = 1300;
export const SLAB_GEOMETRY = {
  width: W, height: H,
  label: { x: 44, y: 40, w: W - 88, h: 210 },
  window: { x: 60, y: 282, w: 700, h: 980 },
};

export function slabShell() {
  return svg({
    w: W, h: H, id: 'slab-shell',
    children: [
      defs([
        linearGradient('acr', [['0%', '#FFFFFF', 0.28], ['18%', '#FFFFFF', 0.06], ['46%', '#FFFFFF', 0.15], ['64%', '#FFFFFF', 0.03], ['100%', '#FFFFFF', 0.2]], { x1: '0%', y1: '0%', x2: '100%', y2: '30%' }),
        linearGradient('edge', [['0%', '#FFFFFF', 0.85], ['40%', '#B9C6D6', 0.35], ['100%', '#FFFFFF', 0.7]], { x1: '0%', y1: '0%', x2: '100%', y2: '100%' }),
        radialGradient('slabsh', [['0%', '#000000', 0.5], ['100%', '#000000', 0]]),
        el('mask', { id: 'shellMask' }, [
          el('path', { d: roundRect(8, 8, W - 16, H - 16, 34), fill: '#fff' }),
          el('path', { d: roundRect(SLAB_GEOMETRY.window.x, SLAB_GEOMETRY.window.y, SLAB_GEOMETRY.window.w, SLAB_GEOMETRY.window.h, 10), fill: '#000' }),
          el('path', { d: roundRect(SLAB_GEOMETRY.label.x, SLAB_GEOMETRY.label.y, SLAB_GEOMETRY.label.w, SLAB_GEOMETRY.label.h, 8), fill: '#000' }),
        ]),
      ]),
      g({ mask: 'url(#shellMask)' }, [
        el('path', { d: roundRect(8, 8, W - 16, H - 16, 34), fill: '#C3CEDC', 'fill-opacity': 0.14 }),
        el('path', { d: roundRect(8, 8, W - 16, H - 16, 34), fill: 'url(#acr)' }),
      ]),
      el('path', { d: roundRect(8, 8, W - 16, H - 16, 34), fill: 'none', stroke: 'url(#edge)', 'stroke-width': 5 }),
      el('path', { d: roundRect(22, 22, W - 44, H - 44, 26), fill: 'none', stroke: '#FFFFFF', 'stroke-width': 1.4, opacity: 0.32 }),
      el('path', { d: roundRect(SLAB_GEOMETRY.window.x - 8, SLAB_GEOMETRY.window.y - 8, SLAB_GEOMETRY.window.w + 16, SLAB_GEOMETRY.window.h + 16, 14), fill: 'none', stroke: '#FFFFFF', 'stroke-width': 2, opacity: 0.28 }),
      // moulded corner pips
      ...[[52, 52], [W - 52, 52], [52, H - 52], [W - 52, H - 52]].map(([cx, cy]) => el('circle', { cx, cy, r: 9, fill: '#FFFFFF', opacity: 0.16 })),
      // specular sweep across the plastic
      el('path', { d: `M${W * 0.1},0L${W * 0.42},0L${W * -0.1},${H}L${W * -0.3},${H}Z`, fill: '#FFFFFF', opacity: 0.07 }),
      el('path', { d: `M${W * 0.86},0L${W},0L${W * 0.6},${H}L${W * 0.46},${H}Z`, fill: '#FFFFFF', opacity: 0.05 }),
    ],
  });
}

const BANDS = {
  standard: { bg: '#F4F6F9', bar: '#0E2A5A', ink: '#0E1420', sub: '#54617A', rule: '#0E2A5A' },
  gold:     { bg: '#FBF3DE', bar: '#8A6A18', ink: '#241B05', sub: '#6B5A2A', rule: '#B08A24' },
  black:    { bg: '#15171C', bar: '#0A0B0E', ink: '#F4F5F8', sub: '#9AA4B6', rule: '#C9A45C' },
};

export function slabLabel(band = 'standard') {
  const c = BANDS[band];
  const { w, h } = SLAB_GEOMETRY.label;
  return svg({
    w, h, id: `slab-label-${band}`,
    children: [
      defs([
        linearGradient(`lb${band}`, [['0%', c.bg], ['100%', band === 'black' ? '#0C0D11' : '#E4E9F0']], { x1: '0%', y1: '0%', x2: '20%', y2: '100%' }),
        linearGradient(`lf${band}`, [['0%', '#FFFFFF', 0.5], ['50%', '#FFFFFF', 0], ['100%', '#FFFFFF', 0.22]], { x1: '0%', y1: '0%', x2: '100%', y2: '100%' }),
      ]),
      el('path', { d: roundRect(0, 0, w, h, 8), fill: `url(#lb${band})` }),
      el('path', { d: `M0,0h${w}v46H0Z`, fill: c.bar }),
      el('text', { x: 18, y: 32, 'font-family': HEADLINE, 'font-size': 25, 'font-weight': 900, fill: band === 'gold' ? '#F6E3A8' : '#FFFFFF', 'letter-spacing': 1 }, 'AGA'),
      el('text', { x: 76, y: 31, 'font-family': DISPLAY, 'font-size': 19, fill: band === 'gold' ? '#E8D49B' : '#C6D3E6', 'letter-spacing': 4 }, 'APEX GRADING AUTHORITY'),
      el('path', { d: `M0,${h - 4}h${w}v4H0Z`, fill: c.rule, opacity: 0.8 }),
      el('path', { d: `M${w - 168},52h164v${h - 60}h-164Z`, fill: c.rule, opacity: 0.1 }),
      el('path', { d: roundRect(0, 0, w, h, 8), fill: `url(#lf${band})` }),
      el('path', { d: roundRect(0, 0, w, h, 8), fill: 'none', stroke: c.rule, 'stroke-width': 1.5, opacity: 0.4 }),
    ],
  });
}

export function slabBarcode() {
  const w = 150; const h = 62;
  const r = seeded('barcode');
  let x = 2;
  const bars = [];
  while (x < w - 4) {
    const bw = 1 + Math.round(r() * 3);
    if (r() > 0.32) bars.push(el('rect', { x, y: 0, width: bw, height: h, fill: '#111318' }));
    x += bw + 1 + Math.round(r() * 2);
  }
  return svg({ w, h, id: 'slab-barcode', children: [el('rect', { width: w, height: h, fill: '#FFFFFF' }), g({}, bars)] });
}

export function slabQr() {
  const n = 21; const s = 6; const size = n * s;
  const r = seeded('qr');
  const cells = [];
  const finder = (ox, oy) => [
    el('rect', { x: ox * s, y: oy * s, width: 7 * s, height: 7 * s, fill: '#111318' }),
    el('rect', { x: (ox + 1) * s, y: (oy + 1) * s, width: 5 * s, height: 5 * s, fill: '#FFFFFF' }),
    el('rect', { x: (ox + 2) * s, y: (oy + 2) * s, width: 3 * s, height: 3 * s, fill: '#111318' }),
  ];
  for (let y = 0; y < n; y += 1) {
    for (let x = 0; x < n; x += 1) {
      const inFinder = (x < 8 && y < 8) || (x > n - 9 && y < 8) || (x < 8 && y > n - 9);
      if (!inFinder && r() > 0.52) cells.push(el('rect', { x: x * s, y: y * s, width: s, height: s, fill: '#111318' }));
    }
  }
  return svg({
    w: size, h: size, id: 'slab-qr',
    children: [el('rect', { width: size, height: size, fill: '#FFFFFF' }), g({}, cells), ...finder(0, 0), ...finder(n - 7, 0), ...finder(0, n - 7)],
  });
}

export function graderMark() {
  return svg({
    w: 300, h: 300, id: 'grader-mark',
    children: [
      defs([linearGradient('gm', [['0%', '#F6E3A8'], ['50%', '#C9A45C'], ['100%', '#7A5B22']], { x1: '0%', y1: '0%', x2: '80%', y2: '100%' })]),
      el('path', { d: 'M150,14L282,66v104c0,66 -54,104 -132,116C70,274 18,236 18,170V66Z', fill: '#0E2A5A' }),
      el('path', { d: 'M150,34L262,78v92c0,54 -46,86 -112,96C84,256 38,224 38,170V78Z', fill: 'none', stroke: 'url(#gm)', 'stroke-width': 5 }),
      el('path', { d: star(150, 96, 34, 14), fill: 'url(#gm)' }),
      el('text', { x: 150, y: 190, 'font-family': HEADLINE, 'font-size': 60, 'font-weight': 900, fill: 'url(#gm)', 'text-anchor': 'middle' }, 'AGA'),
      el('text', { x: 150, y: 224, 'font-family': DISPLAY, 'font-size': 17, fill: '#C6D3E6', 'text-anchor': 'middle', 'letter-spacing': 3 }, 'CERTIFIED'),
    ],
  });
}
