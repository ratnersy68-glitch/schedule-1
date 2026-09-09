/** Parallel finish overlays. Composited over the card with blend modes. */
import { el, svg, defs, g, linearGradient, radialGradient, seeded } from './svg.mjs';

const W = 750;
const H = 1050;
const SPECTRUM = ['#FF4D6D', '#FF9F45', '#FFE066', '#5CE1A0', '#4CC9F0', '#9B7BFF', '#FF6FD8'];

function spectrumStops(offset = 0, op = 1) {
  return SPECTRUM.map((c, i) => [`${Math.round(((i + offset) / (SPECTRUM.length - 1)) * 100)}%`, c, op]);
}

const foils = {
  none: () => svg({ w: W, h: H, id: 'foil-none', children: [] }),

  holo: () => svg({
    w: W, h: H, id: 'foil-holo',
    children: [
      defs([
        linearGradient('hs', spectrumStops(0, 1), { x1: '0%', y1: '0%', x2: '100%', y2: '100%' }),
        el('filter', { id: 'wob' }, [
          el('feTurbulence', { type: 'fractalNoise', baseFrequency: '0.006 0.02', numOctaves: 2, seed: 7 }),
          el('feDisplacementMap', { in: 'SourceGraphic', scale: 90 }),
        ]),
      ]),
      el('rect', { width: W, height: H, fill: 'url(#hs)', filter: 'url(#wob)', opacity: 0.85 }),
    ],
  }),

  refractor: () => svg({
    w: W, h: H, id: 'foil-refractor',
    children: [
      defs([linearGradient('rs', spectrumStops(), { x1: '0%', y1: '0%', x2: '70%', y2: '100%' })]),
      el('rect', { width: W, height: H, fill: 'url(#rs)', opacity: 0.55 }),
      g({ opacity: 0.5 }, Array.from({ length: 90 }, (_, i) => el('path', {
        d: `M${-400 + i * 18},${H}L${100 + i * 18},0`, stroke: '#FFFFFF', 'stroke-width': i % 3 === 0 ? 3 : 1.2, opacity: i % 3 === 0 ? 0.5 : 0.22,
      }))),
    ],
  }),

  silver: () => svg({
    w: W, h: H, id: 'foil-silver',
    children: [
      defs([
        linearGradient('ss', [['0%', '#6E7A8C'], ['22%', '#E9EEF5'], ['38%', '#8D99AB'], ['54%', '#FFFFFF'], ['70%', '#7C8798'], ['88%', '#DFE6EF'], ['100%', '#5C6675']], { x1: '0%', y1: '0%', x2: '100%', y2: '80%' }),
      ]),
      el('rect', { width: W, height: H, fill: 'url(#ss)', opacity: 0.9 }),
      g({ opacity: 0.35 }, Array.from({ length: 130 }, (_, i) => {
        const r = seeded(`sv${i}`);
        return el('path', { d: `M${-300 + i * 12},${H}L${180 + i * 12},0`, stroke: '#FFFFFF', 'stroke-width': r() * 2.4, opacity: r() * 0.5 });
      })),
    ],
  }),

  tint: () => svg({
    w: W, h: H, id: 'foil-tint',
    children: [
      defs([
        linearGradient('ts', [['0%', '#FFFFFF', 0.5], ['30%', '#FFFFFF', 0.08], ['52%', '#FFFFFF', 0.42], ['74%', '#FFFFFF', 0.06], ['100%', '#FFFFFF', 0.34]], { x1: '0%', y1: '0%', x2: '90%', y2: '100%' }),
      ]),
      el('rect', { width: W, height: H, fill: 'url(#ts)' }),
      g({ opacity: 0.22 }, Array.from({ length: 46 }, (_, i) => el('path', {
        d: `M${-260 + i * 30},${H}L${180 + i * 30},0`, stroke: '#FFFFFF', 'stroke-width': 2.2,
      }))),
    ],
  }),

  metal: () => svg({
    w: W, h: H, id: 'foil-metal',
    children: [
      defs([
        linearGradient('ms', [['0%', '#3A2A08'], ['16%', '#F4DE9E'], ['32%', '#8A6A22'], ['48%', '#FFF7DC'], ['64%', '#7C5D1B'], ['82%', '#EBD08A'], ['100%', '#2E2206']], { x1: '0%', y1: '0%', x2: '100%', y2: '100%' }),
      ]),
      el('rect', { width: W, height: H, fill: 'url(#ms)', opacity: 0.92 }),
      g({ opacity: 0.4 }, Array.from({ length: 40 }, (_, i) => el('path', {
        d: `M0,${i * 28}H${W}`, stroke: '#FFFFFF', 'stroke-width': i % 2 ? 0.8 : 2, opacity: 0.3,
      }))),
    ],
  }),

  superfractor: () => svg({
    w: W, h: H, id: 'foil-superfractor',
    children: [
      defs([
        radialGradient('sfc', [['0%', '#FFFDF0'], ['26%', '#FFE9A3'], ['52%', '#F5C24B'], ['74%', '#C98A20'], ['100%', '#6B4508']], { cx: '50%', cy: '38%', r: '72%' }),
        linearGradient('sfs', spectrumStops(0, 0.6), { x1: '0%', y1: '0%', x2: '100%', y2: '60%' }),
      ]),
      el('rect', { width: W, height: H, fill: 'url(#sfc)' }),
      g({ opacity: 0.45 }, Array.from({ length: 72 }, (_, i) => {
        const a = (i / 72) * Math.PI * 2;
        return el('path', {
          d: `M${W / 2},${H * 0.38}L${W / 2 + Math.cos(a) * 1200},${H * 0.38 + Math.sin(a) * 1200}`,
          stroke: i % 2 ? '#FFFFFF' : '#FFE9A3', 'stroke-width': i % 5 === 0 ? 7 : 2, opacity: i % 5 === 0 ? 0.55 : 0.2,
        });
      })),
      el('rect', { width: W, height: H, fill: 'url(#sfs)', style: 'mix-blend-mode:overlay' }),
      g({}, Array.from({ length: 40 }, (_, i) => {
        const r = seeded(`sf${i}`);
        const x = r() * W; const y = r() * H; const s = 6 + r() * 22;
        return el('path', { d: `M${x},${y - s}L${x + s * 0.28},${y - s * 0.28}L${x + s},${y}L${x + s * 0.28},${y + s * 0.28}L${x},${y + s}L${x - s * 0.28},${y + s * 0.28}L${x - s},${y}L${x - s * 0.28},${y - s * 0.28}Z`, fill: '#FFFFFF', opacity: 0.5 + r() * 0.5 });
      })),
    ],
  }),
};

export function foilAssets() {
  const out = {};
  for (const [id, fn] of Object.entries(foils)) out[`foil-${id}`] = fn();
  return out;
}
export const FOIL_IDS = Object.keys(foils);
