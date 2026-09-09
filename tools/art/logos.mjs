/** League marks, franchise crests and product wordmarks. */
import { el, svg, defs, g, linearGradient, radialGradient, roundRect, star, poly, HEADLINE, DISPLAY, text } from './svg.mjs';
import { shade, tint, mix, ink, alpha } from './color.mjs';

/* ------------------------------------------------------------ crest shapes */

const SHAPES = {
  shield: (s) => `M${s * 0.5},${s * 0.06}L${s * 0.94},${s * 0.22}V${s * 0.55}C${s * 0.94},${s * 0.78} ${s * 0.74},${s * 0.9} ${s * 0.5},${s * 0.97}C${s * 0.26},${s * 0.9} ${s * 0.06},${s * 0.78} ${s * 0.06},${s * 0.55}V${s * 0.22}Z`,
  circle: (s) => `M${s * 0.5},${s * 0.04}A${s * 0.46},${s * 0.46} 0 1 1 ${s * 0.4999},${s * 0.04}Z`,
  chevron: (s) => `M${s * 0.5},${s * 0.05}L${s * 0.96},${s * 0.3}V${s * 0.62}L${s * 0.5},${s * 0.96}L${s * 0.04},${s * 0.62}V${s * 0.3}Z`,
  wing: (s) => `M${s * 0.5},${s * 0.05}C${s * 0.8},${s * 0.05} ${s * 0.97},${s * 0.26} ${s * 0.95},${s * 0.5}C${s * 0.92},${s * 0.8} ${s * 0.72},${s * 0.96} ${s * 0.5},${s * 0.96}C${s * 0.28},${s * 0.96} ${s * 0.08},${s * 0.8} ${s * 0.05},${s * 0.5}C${s * 0.03},${s * 0.26} ${s * 0.2},${s * 0.05} ${s * 0.5},${s * 0.05}Z`,
  bolt: (s) => `M${s * 0.5},${s * 0.03}L${s * 0.95},${s * 0.34}L${s * 0.78},${s * 0.97}H${s * 0.22}L${s * 0.05},${s * 0.34}Z`,
  star: (s) => poly(s * 0.5, s * 0.52, s * 0.47, 5, -90),
  mountain: (s) => `M${s * 0.06},${s * 0.2}H${s * 0.94}V${s * 0.72}C${s * 0.94},${s * 0.86} ${s * 0.76},${s * 0.96} ${s * 0.5},${s * 0.97}C${s * 0.24},${s * 0.96} ${s * 0.06},${s * 0.86} ${s * 0.06},${s * 0.72}Z`,
};

const EMBLEMS = {
  shield: (s, c) => el('path', { d: `M${s * 0.5},${s * 0.22}L${s * 0.72},${s * 0.34}L${s * 0.62},${s * 0.68}H${s * 0.38}L${s * 0.28},${s * 0.34}Z`, fill: 'none', stroke: c, 'stroke-width': s * 0.045, 'stroke-linejoin': 'round' }),
  circle: (s, c) => g({}, [
    el('circle', { cx: s * 0.5, cy: s * 0.5, r: s * 0.3, fill: 'none', stroke: c, 'stroke-width': s * 0.045 }),
    el('path', { d: `M${s * 0.2},${s * 0.5}h${s * 0.6}`, stroke: c, 'stroke-width': s * 0.045 }),
  ]),
  chevron: (s, c) => el('path', { d: `M${s * 0.26},${s * 0.56}L${s * 0.5},${s * 0.3}L${s * 0.74},${s * 0.56}M${s * 0.26},${s * 0.72}L${s * 0.5},${s * 0.46}L${s * 0.74},${s * 0.72}`, fill: 'none', stroke: c, 'stroke-width': s * 0.05, 'stroke-linecap': 'round', 'stroke-linejoin': 'round' }),
  wing: (s, c) => el('path', { d: `M${s * 0.2},${s * 0.44}q${s * 0.3},${-s * 0.16} ${s * 0.6},${s * 0.02}q${-s * 0.22},${s * 0.06} ${-s * 0.34},${s * 0.14}q${s * 0.22},${-s * 0.02} ${s * 0.3},${s * 0.04}q${-s * 0.24},${s * 0.12} ${-s * 0.56},${-s * 0.2}Z`, fill: c }),
  bolt: (s, c) => el('path', { d: `M${s * 0.56},${s * 0.2}L${s * 0.34},${s * 0.54}H${s * 0.5}L${s * 0.44},${s * 0.82}L${s * 0.68},${s * 0.46}H${s * 0.52}Z`, fill: c }),
  star: (s, c) => el('path', { d: star(s * 0.5, s * 0.5, s * 0.24, s * 0.1), fill: c }),
  mountain: (s, c) => el('path', { d: `M${s * 0.2},${s * 0.7}L${s * 0.4},${s * 0.38}L${s * 0.52},${s * 0.54}L${s * 0.62},${s * 0.36}L${s * 0.82},${s * 0.7}Z`, fill: c }),
};

export function teamCrest(team, size = 256) {
  const s = size;
  const { primary, secondary, accent } = team.colors;
  const shape = SHAPES[team.crest] || SHAPES.shield;
  const emblem = EMBLEMS[team.crest] || EMBLEMS.shield;
  const id = team.id.replace(/[^A-Za-z0-9]/g, '');
  return svg({
    w: s, h: s, id: `crest-${team.id}`,
    children: [
      defs([
        linearGradient(`gf${id}`, [['0%', tint(primary, 0.24)], ['48%', primary], ['100%', shade(primary, 0.55)]], { x1: '15%', y1: '0%', x2: '85%', y2: '100%' }),
        linearGradient(`gr${id}`, [['0%', tint(secondary, 0.5)], ['40%', secondary], ['100%', shade(secondary, 0.42)]], { x1: '0%', y1: '0%', x2: '70%', y2: '100%' }),
        radialGradient(`gl${id}`, [['0%', '#FFFFFF', 0.34], ['62%', '#FFFFFF', 0.04], ['100%', '#FFFFFF', 0]], { cx: '34%', cy: '22%', r: '62%' }),
      ]),
      el('path', { d: shape(s), fill: `url(#gr${id})` }),
      g({ transform: `translate(${s * 0.5},${s * 0.5}) scale(0.9) translate(${-s * 0.5},${-s * 0.5})` }, [
        el('path', { d: shape(s), fill: `url(#gf${id})` }),
      ]),
      emblem(s, alpha(accent, 0.5)),
      el('text', {
        x: s * 0.5, y: s * 0.63, 'font-family': HEADLINE, 'font-size': s * 0.27, 'font-weight': 900,
        fill: accent, 'text-anchor': 'middle', 'letter-spacing': s * 0.005,
        stroke: shade(primary, 0.6), 'stroke-width': s * 0.012, 'paint-order': 'stroke',
      }, team.abbr),
      el('path', { d: shape(s), fill: `url(#gl${id})` }),
      el('path', { d: shape(s), fill: 'none', stroke: alpha(accent, 0.55), 'stroke-width': s * 0.012 }),
    ],
  });
}

/* ------------------------------------------------------------ league marks */


export function leagueMark(sport) {
  const meta = { NFL: { name: 'GRIDIRON', c: '#D8DEE8', bg: '#111A2C' }, NBA: { name: 'HARDWOOD', c: '#F0E4D4', bg: '#2A1520' }, MLB: { name: 'DIAMOND', c: '#E6EFF6', bg: '#0F2030' } }[sport];
  const W = 320; const H = 200;
  const glyph = {
    NFL: g({}, [
      el('ellipse', { cx: 160, cy: 76, rx: 44, ry: 26, fill: 'none', stroke: meta.c, 'stroke-width': 7 }),
      el('path', { d: 'M144,76h32M150,68v16M160,66v20M170,68v16', stroke: meta.c, 'stroke-width': 5, 'stroke-linecap': 'round' }),
    ]),
    NBA: g({}, [
      el('circle', { cx: 160, cy: 76, r: 34, fill: 'none', stroke: meta.c, 'stroke-width': 7 }),
      el('path', { d: 'M126,76h68M160,42v68M136,52q24,24 0,48M184,52q-24,24 0,48', stroke: meta.c, 'stroke-width': 4.5, fill: 'none' }),
    ]),
    MLB: g({}, [
      el('path', { d: 'M160,42L196,66V104L160,120L124,104V66Z', fill: 'none', stroke: meta.c, 'stroke-width': 7, 'stroke-linejoin': 'round' }),
      el('path', { d: 'M142,62q18,20 0,42M178,62q-18,20 0,42', stroke: meta.c, 'stroke-width': 4.5, fill: 'none' }),
    ]),
  }[sport];
  return svg({
    w: W, h: H, id: `league-${sport}`,
    children: [
      defs([linearGradient('lg', [['0%', tint(meta.bg, 0.16)], ['100%', shade(meta.bg, 0.4)]], { x1: '0%', y1: '0%', x2: '60%', y2: '100%' })]),
      el('path', { d: `M160,6L306,44V116C306,158 240,186 160,196C80,186 14,158 14,116V44Z`, fill: 'url(#lg)', stroke: meta.c, 'stroke-width': 4, 'stroke-opacity': 0.6 }),
      glyph,
      el('text', { x: 160, y: 152, 'font-family': HEADLINE, 'font-size': 30, 'font-weight': 900, fill: meta.c, 'text-anchor': 'middle', 'letter-spacing': 3 }, meta.name),
      el('text', { x: 160, y: 174, 'font-family': DISPLAY, 'font-size': 15, fill: meta.c, 'text-anchor': 'middle', 'letter-spacing': 7, opacity: 0.66 }, 'PRO LEAGUE'),
    ],
  });
}

/* ------------------------------------------------------- product wordmarks */

export function brandMark(box) {
  const W = 520; const H = 150;
  const p = box.palette;
  const words = box.shortName.toUpperCase().split(' ');
  const id = box.id.replace(/[^A-Za-z0-9]/g, '');
  return svg({
    w: W, h: H, id: `brand-${box.id}`,
    children: [
      defs([
        linearGradient(`bm${id}`, [['0%', tint(p.accent, 0.55)], ['42%', p.accent], ['58%', p.foil], ['100%', shade(p.accent, 0.35)]], { x1: '0%', y1: '0%', x2: '25%', y2: '100%' }),
      ]),
      el('path', { d: `M8,${H / 2 - 2}h${W * 0.2}`, stroke: p.accent, 'stroke-width': 3, opacity: 0.6 }),
      el('path', { d: `M${W - 8},${H / 2 - 2}h-${W * 0.2}`, stroke: p.accent, 'stroke-width': 3, opacity: 0.6 }),
      el('text', {
        x: W / 2, y: words.length > 1 ? 62 : 88, 'font-family': HEADLINE, 'font-size': words.length > 1 ? 46 : 62,
        'font-weight': 900, fill: `url(#bm${id})`, 'text-anchor': 'middle', 'letter-spacing': 1,
      }, words[0]),
      words[1] ? el('text', {
        x: W / 2, y: 116, 'font-family': DISPLAY, 'font-size': 44, fill: p.ink,
        'text-anchor': 'middle', 'letter-spacing': 10, opacity: 0.9,
      }, words.slice(1).join(' ')) : '',
    ],
  });
}

/* ------------------------------------------------------------- insert art */

export function insertArt(kind) {
  const W = 600; const H = 820;
  const pieces = {
    burst: Array.from({ length: 26 }, (_, i) => el('path', {
      d: `M300,410L${300 + Math.cos((i / 26) * 6.283) * 620},${410 + Math.sin((i / 26) * 6.283) * 620}`,
      stroke: 'var(--ts,#C8963E)', 'stroke-width': i % 2 ? 10 : 26, opacity: i % 2 ? 0.16 : 0.3,
    })),
    skyline: [
      el('path', { d: 'M0,820V560l40-90 34 90 46-160 42 160 56-120 44 120 60-190 46 190 58-110 44 110 46-70 44 70v260Z', fill: 'var(--tp,#1B2A41)', opacity: 0.5 }),
      ...Array.from({ length: 40 }, (_, i) => el('rect', { x: 20 + (i % 10) * 58, y: 600 + Math.floor(i / 10) * 46, width: 14, height: 20, fill: 'var(--ts,#C8963E)', opacity: 0.35 })),
    ],
    splash: Array.from({ length: 14 }, (_, i) => el('ellipse', {
      cx: 300 + Math.cos(i * 2.4) * (60 + i * 16), cy: 400 + Math.sin(i * 1.7) * (70 + i * 18),
      rx: 90 - i * 3, ry: 62 - i * 2, fill: i % 3 === 0 ? 'var(--ts,#C8963E)' : 'var(--ta,#E9E4D8)',
      opacity: 0.14, transform: `rotate(${i * 24} 300 400)`,
    })),
    banner: [
      el('path', { d: 'M110,60h380v560l-190-96-190 96Z', fill: 'none', stroke: 'var(--ts,#C8963E)', 'stroke-width': 8, opacity: 0.45 }),
      el('path', { d: 'M150,100h300v470l-150-76-150 76Z', fill: 'var(--tp,#1B2A41)', opacity: 0.28 }),
    ],
    grid: [
      ...Array.from({ length: 13 }, (_, i) => el('path', { d: `M${i * 50},0V820`, stroke: 'var(--ta,#E9E4D8)', 'stroke-width': 2, opacity: 0.12 })),
      ...Array.from({ length: 17 }, (_, i) => el('path', { d: `M0,${i * 50}H600`, stroke: 'var(--ta,#E9E4D8)', 'stroke-width': 2, opacity: 0.12 })),
      el('rect', { x: 90, y: 180, width: 420, height: 460, fill: 'none', stroke: 'var(--ts,#C8963E)', 'stroke-width': 10, opacity: 0.5 }),
    ],
  }[kind] || [];
  return svg({ w: W, h: H, id: `insert-${kind}`, children: [g({}, pieces)] });
}
