/** Hobby box packaging (3/4 view) and foil pack wrappers. */
import { el, svg, defs, g, linearGradient, radialGradient, roundRect, star, HEADLINE, DISPLAY, MONO, seeded } from './svg.mjs';
import { shade, tint, mix, ink, alpha } from './color.mjs';

/* ------------------------------------------------------------- hobby box */

const BW = 900;
const BH = 1000;

// 3/4 perspective cage
const FRONT = [[140, 330], [560, 300], [560, 910], [140, 940]];
const TOP = [[140, 330], [330, 232], [750, 205], [560, 300]];
const SIDE = [[560, 300], [750, 205], [750, 800], [560, 910]];
const pts = (p) => p.map((q) => q.join(',')).join(' ');

const PATTERN = {
  optic: (p) => Array.from({ length: 10 }, (_, i) => el('path', {
    d: `M${60 + i * 62},960L${180 + i * 62},240h34L${94 + i * 62},960Z`, fill: i % 2 ? p.accent : p.foil, opacity: i % 2 ? 0.3 : 0.12,
  })),
  select: (p) => [
    el('path', { d: 'M350,240L620,470v320L350,1000L80,790V470Z', fill: p.accent, opacity: 0.2 }),
    ...Array.from({ length: 14 }, (_, i) => el('path', { d: `M60,${260 + i * 52}H660`, stroke: p.foil, 'stroke-width': 1.6, opacity: 0.22 })),
  ],
  prizm: (p) => Array.from({ length: 30 }, (_, i) => {
    const a = (i / 30) * Math.PI - Math.PI / 2;
    return el('path', {
      d: `M350,1010L${350 + Math.cos(a - 0.03) * 1200},${1010 + Math.sin(a - 0.03) * 1200}L${350 + Math.cos(a + 0.03) * 1200},${1010 + Math.sin(a + 0.03) * 1200}Z`,
      fill: ['#FF5470', '#FFB35C', '#FFE45C', '#5CE1A0', '#4EA8FF', '#A970FF'][i % 6], opacity: 0.17,
    });
  }),
  treasures: (p) => [
    el('ellipse', { cx: 350, cy: 560, rx: 250, ry: 300, fill: p.accent, opacity: 0.16 }),
    ...Array.from({ length: 22 }, (_, i) => el('path', { d: `M${-60 + i * 44},1000L${180 + i * 44},220`, stroke: p.accent, 'stroke-width': 1.4, opacity: 0.2 })),
  ],
  flawless: (p) => [
    el('ellipse', { cx: 350, cy: 500, rx: 240, ry: 280, fill: p.accent, opacity: 0.14 }),
    ...Array.from({ length: 46 }, (_, i) => {
      const r = seeded(`fx${i}`);
      return el('circle', { cx: 60 + r() * 600, cy: 240 + r() * 720, r: r() * 2.6, fill: '#FFFFFF', opacity: r() * 0.7 });
    }),
  ],
  prospect: (p) => [
    el('path', { d: 'M60,980C180,760 420,660 660,420', stroke: p.accent, 'stroke-width': 16, fill: 'none', opacity: 0.55 }),
    el('path', { d: 'M60,1020C180,800 420,700 660,460', stroke: p.foil, 'stroke-width': 6, fill: 'none', opacity: 0.4 }),
  ],
  chrome: (p) => Array.from({ length: 16 }, (_, i) => el('path', {
    d: `M${50 + i * 42},240V980`, stroke: i % 3 === 0 ? p.accent : p.foil, 'stroke-width': i % 3 === 0 ? 5 : 1.6, opacity: 0.22,
  })),
  finest: (p) => Array.from({ length: 18 }, (_, i) => el('path', {
    d: `M${-200 + i * 62},1000L${240 + i * 62},220`, stroke: i % 2 ? p.accent : p.foil, 'stroke-width': i % 2 ? 14 : 4, opacity: i % 2 ? 0.22 : 0.13,
  })),
};

export function hobbyBox(box) {
  const p = box.palette;
  const id = box.id.replace(/[^A-Za-z0-9]/g, '');
  const words = box.shortName.toUpperCase().split(' ');
  const sportWord = { NFL: 'FOOTBALL', NBA: 'BASKETBALL', MLB: 'BASEBALL' }[box.sport];
  const pattern = (PATTERN[box.template] || PATTERN.chrome)(p);

  return svg({
    w: BW, h: BH, id: `box-${box.id}`,
    children: [
      defs([
        linearGradient(`f${id}`, [['0%', tint(p.base, 0.16)], ['46%', p.base], ['100%', shade(p.base, 0.5)]], { x1: '0%', y1: '0%', x2: '80%', y2: '100%' }),
        linearGradient(`t${id}`, [['0%', tint(p.base, 0.3)], ['100%', p.base]], { x1: '0%', y1: '0%', x2: '60%', y2: '100%' }),
        linearGradient(`s${id}`, [['0%', shade(p.base, 0.35)], ['100%', shade(p.base, 0.72)]], { x1: '0%', y1: '0%', x2: '100%', y2: '40%' }),
        linearGradient(`m${id}`, [['0%', tint(p.foil, 0.5)], ['26%', p.accent], ['50%', '#FFFFFF'], ['74%', p.accent], ['100%', shade(p.accent, 0.4)]], { x1: '0%', y1: '0%', x2: '100%', y2: '70%' }),
        linearGradient(`gl${id}`, [['0%', '#FFFFFF', 0.3], ['40%', '#FFFFFF', 0.04], ['100%', '#FFFFFF', 0]], { x1: '0%', y1: '0%', x2: '40%', y2: '100%' }),
        radialGradient(`sh${id}`, [['0%', '#000000', 0.55], ['100%', '#000000', 0]]),
        el('clipPath', { id: `cf${id}` }, el('polygon', { points: pts(FRONT) })),
        el('clipPath', { id: `cs${id}` }, el('polygon', { points: pts(SIDE) })),
      ]),

      el('ellipse', { cx: 450, cy: 946, rx: 330, ry: 44, fill: `url(#sh${id})` }),

      // top face
      el('polygon', { points: pts(TOP), fill: `url(#t${id})` }),
      g({ opacity: 0.55 }, [
        el('text', {
          x: 445, y: 278, 'font-family': HEADLINE, 'font-size': 34, 'font-weight': 900,
          fill: p.ink, 'text-anchor': 'middle', transform: 'rotate(-4 445 278) skewX(-16)', opacity: 0.8,
        }, `${box.year} ${words[0]}`),
      ]),

      // side face
      el('polygon', { points: pts(SIDE), fill: `url(#s${id})` }),
      g({ 'clip-path': `url(#cs${id})` }, [
        el('rect', { x: 560, y: 200, width: 200, height: 720, fill: p.accent, opacity: 0.12 }),
        el('text', {
          x: 0, y: 0, 'font-family': DISPLAY, 'font-size': 30, fill: p.ink, opacity: 0.72,
          'letter-spacing': 4, transform: 'translate(694,842) rotate(-70)',
        }, `${words[0]} ${box.year}`),
        el('text', {
          x: 0, y: 0, 'font-family': MONO, 'font-size': 17, fill: p.accent, opacity: 0.75,
          'letter-spacing': 3, transform: 'translate(724,842) rotate(-70)',
        }, `${sportWord} HOBBY`),
      ]),

      // front face
      el('polygon', { points: pts(FRONT), fill: `url(#f${id})` }),
      g({ 'clip-path': `url(#cf${id})` }, [
        ...pattern,
        el('polygon', { points: pts(FRONT), fill: `url(#gl${id})` }),
        el('path', { d: 'M140,700h420v14H140Z', fill: p.accent, opacity: 0.5 }),
        el('rect', { x: 140, y: 826, width: 420, height: 120, fill: '#000000', opacity: 0.45 }),
      ]),

      // front typography
      g({ transform: 'rotate(-4 350 560)' }, [
        el('text', { x: 350, y: 430, 'font-family': DISPLAY, 'font-size': 34, fill: p.ink, 'text-anchor': 'middle', 'letter-spacing': 10, opacity: 0.85 }, String(box.year)),
        el('text', { x: 350, y: 512, 'font-family': HEADLINE, 'font-size': words[0].length > 8 ? 62 : 76, 'font-weight': 900, fill: `url(#m${id})`, 'text-anchor': 'middle' }, words[0]),
        words[1] ? el('text', { x: 350, y: 574, 'font-family': DISPLAY, 'font-size': 46, fill: p.ink, 'text-anchor': 'middle', 'letter-spacing': 12 }, words.slice(1).join(' ')) : '',
        el('text', { x: 350, y: 646, 'font-family': DISPLAY, 'font-size': 30, fill: p.accent, 'text-anchor': 'middle', 'letter-spacing': 8 }, sportWord),
        el('text', { x: 350, y: 762, 'font-family': HEADLINE, 'font-size': 40, 'font-weight': 900, fill: p.ink, 'text-anchor': 'middle', 'letter-spacing': 6, opacity: 0.9 }, 'HOBBY BOX'),
        el('text', { x: 350, y: 878, 'font-family': DISPLAY, 'font-size': 30, fill: p.ink, 'text-anchor': 'middle', 'letter-spacing': 3, opacity: 0.9 }, `${box.packs} PACKS · ${box.cardsPerPack} CARDS PER PACK`),
        el('text', { x: 350, y: 918, 'font-family': MONO, 'font-size': 20, fill: p.accent, 'text-anchor': 'middle', 'letter-spacing': 2 }, box.manufacturer.toUpperCase()),
      ]),

      // foil seal
      g({ transform: 'translate(516,352) rotate(12)' }, [
        el('circle', { r: 66, fill: `url(#m${id})` }),
        el('circle', { r: 56, fill: 'none', stroke: shade(p.base, 0.4), 'stroke-width': 3, opacity: 0.6 }),
        el('text', { y: -10, 'font-family': HEADLINE, 'font-size': 23, 'font-weight': 900, fill: shade(p.base, 0.6), 'text-anchor': 'middle' }, 'FACTORY'),
        el('text', { y: 16, 'font-family': HEADLINE, 'font-size': 23, 'font-weight': 900, fill: shade(p.base, 0.6), 'text-anchor': 'middle' }, 'SEALED'),
        el('text', { y: 40, 'font-family': MONO, 'font-size': 12, fill: shade(p.base, 0.5), 'text-anchor': 'middle', 'letter-spacing': 1 }, 'HOBBY ONLY'),
      ]),

      // edges
      el('polygon', { points: pts(FRONT), fill: 'none', stroke: alpha(p.foil, 0.5), 'stroke-width': 3 }),
      el('polygon', { points: pts(TOP), fill: 'none', stroke: alpha(p.foil, 0.35), 'stroke-width': 2.5 }),
      el('polygon', { points: pts(SIDE), fill: 'none', stroke: alpha(p.foil, 0.25), 'stroke-width': 2.5 }),
    ],
  });
}

/* ---------------------------------------------------------- pack wrapper */

const PW = 540;
const PH = 780;

function crimp(y, dir = 1) {
  const teeth = 22;
  let d = `M30,${y}`;
  for (let i = 0; i < teeth; i += 1) {
    const x = 30 + ((PW - 60) / teeth) * (i + 1);
    d += `L${x - (PW - 60) / teeth / 2},${y + 13 * dir}L${x},${y}`;
  }
  return d;
}

export function packWrapper(box) {
  const p = box.palette;
  const id = box.id.replace(/[^A-Za-z0-9]/g, '');
  const words = box.shortName.toUpperCase().split(' ');
  return svg({
    w: PW, h: PH, id: `pack-${box.id}`,
    children: [
      defs([
        linearGradient(`pf${id}`, [['0%', tint(p.base, 0.22)], ['30%', p.base], ['56%', shade(p.base, 0.28)], ['78%', p.base], ['100%', shade(p.base, 0.5)]], { x1: '0%', y1: '0%', x2: '100%', y2: '20%' }),
        linearGradient(`pm${id}`, [['0%', tint(p.foil, 0.6)], ['30%', p.accent], ['50%', '#FFFFFF'], ['70%', p.accent], ['100%', shade(p.accent, 0.45)]], { x1: '0%', y1: '0%', x2: '100%', y2: '60%' }),
        linearGradient(`pg${id}`, [['0%', '#FFFFFF', 0.34], ['24%', '#FFFFFF', 0.02], ['52%', '#FFFFFF', 0.24], ['76%', '#FFFFFF', 0.02], ['100%', '#FFFFFF', 0.2]], { x1: '0%', y1: '0%', x2: '100%', y2: '10%' }),
        el('clipPath', { id: `pc${id}` }, el('path', { d: roundRect(30, 26, PW - 60, PH - 52, 10) })),
      ]),
      el('path', { d: roundRect(30, 26, PW - 60, PH - 52, 10), fill: `url(#pf${id})` }),
      g({ 'clip-path': `url(#pc${id})` }, [
        ...Array.from({ length: 14 }, (_, i) => el('path', {
          d: `M${-200 + i * 66},${PH}L${120 + i * 66},0`, stroke: p.accent, 'stroke-width': i % 2 ? 22 : 6, opacity: i % 2 ? 0.16 : 0.1,
        })),
        el('rect', { x: 30, y: 300, width: PW - 60, height: 190, fill: '#000000', opacity: 0.34 }),
        el('path', { d: roundRect(30, 26, PW - 60, PH - 52, 10), fill: `url(#pg${id})` }),
      ]),
      el('path', { d: crimp(58, 1), stroke: alpha(p.foil, 0.5), 'stroke-width': 2.5, fill: 'none' }),
      el('path', { d: crimp(PH - 58, -1), stroke: alpha(p.foil, 0.5), 'stroke-width': 2.5, fill: 'none' }),
      el('text', { x: PW / 2, y: 200, 'font-family': DISPLAY, 'font-size': 26, fill: p.ink, 'text-anchor': 'middle', 'letter-spacing': 9, opacity: 0.85 }, String(box.year)),
      el('text', { x: PW / 2, y: 372, 'font-family': HEADLINE, 'font-size': words[0].length > 8 ? 50 : 62, 'font-weight': 900, fill: `url(#pm${id})`, 'text-anchor': 'middle' }, words[0]),
      words[1] ? el('text', { x: PW / 2, y: 424, 'font-family': DISPLAY, 'font-size': 36, fill: p.ink, 'text-anchor': 'middle', 'letter-spacing': 10 }, words.slice(1).join(' ')) : '',
      el('text', { x: PW / 2, y: 476, 'font-family': DISPLAY, 'font-size': 22, fill: p.accent, 'text-anchor': 'middle', 'letter-spacing': 6 }, { NFL: 'FOOTBALL', NBA: 'BASKETBALL', MLB: 'BASEBALL' }[box.sport]),
      el('path', { d: roundRect(PW / 2 - 96, 590, 192, 52, 26), fill: p.accent, opacity: 0.92 }),
      el('text', { x: PW / 2, y: 626, 'font-family': HEADLINE, 'font-size': 26, 'font-weight': 900, fill: shade(p.base, 0.5), 'text-anchor': 'middle', 'letter-spacing': 1 }, `${box.cardsPerPack} CARDS`),
      el('text', { x: PW / 2, y: 690, 'font-family': MONO, 'font-size': 15, fill: p.ink, 'text-anchor': 'middle', 'letter-spacing': 2, opacity: 0.6 }, 'HOBBY EXCLUSIVE'),
      el('path', { d: roundRect(30, 26, PW - 60, PH - 52, 10), fill: 'none', stroke: alpha(p.foil, 0.45), 'stroke-width': 2.5 }),
    ],
  });
}
