/** Minimal declarative SVG builder. Keeps art modules readable. */

const SELF_CLOSING = new Set(['path', 'rect', 'circle', 'ellipse', 'line', 'polygon', 'polyline', 'use', 'stop', 'image', 'feGaussianBlur', 'feOffset', 'feFlood', 'feComposite', 'feColorMatrix', 'feTurbulence', 'feDisplacementMap', 'feBlend', 'feMorphology', 'animate', 'animateTransform', 'feMerge', 'feMergeNode', 'feSpecularLighting', 'fePointLight', 'feDistantLight']);

export function el(tag, attrs = {}, children = []) {
  const a = Object.entries(attrs)
    .filter(([, v]) => v !== undefined && v !== null && v !== false)
    .map(([k, v]) => ` ${k}="${String(v).replace(/"/g, '&quot;')}"`)
    .join('');
  const kids = (Array.isArray(children) ? children : [children]).filter(Boolean).join('');
  if (!kids && SELF_CLOSING.has(tag)) return `<${tag}${a}/>`;
  return `<${tag}${a}>${kids}</${tag}>`;
}

export function svg({ w, h, id = '', children, extra = {} }) {
  return el('svg', {
    xmlns: 'http://www.w3.org/2000/svg',
    'xmlns:xlink': 'http://www.w3.org/1999/xlink',
    viewBox: `0 0 ${w} ${h}`,
    width: w,
    height: h,
    role: 'img',
    'data-asset': id || undefined,
    ...extra,
  }, children);
}

export const defs = (children) => el('defs', {}, children);
export const g = (attrs, children) => el('g', attrs, children);

export function linearGradient(id, stops, { x1 = '0%', y1 = '0%', x2 = '0%', y2 = '100%', units } = {}) {
  return el('linearGradient', { id, x1, y1, x2, y2, gradientUnits: units }, stops.map(([o, c, op]) =>
    el('stop', { offset: o, 'stop-color': c, 'stop-opacity': op })));
}

export function radialGradient(id, stops, { cx = '50%', cy = '50%', r = '50%', fx, fy } = {}) {
  return el('radialGradient', { id, cx, cy, r, fx, fy }, stops.map(([o, c, op]) =>
    el('stop', { offset: o, 'stop-color': c, 'stop-opacity': op })));
}

/** Rounded-rect path with individually controllable corners. */
export function roundRect(x, y, w, h, r) {
  const [tl, tr, br, bl] = Array.isArray(r) ? r : [r, r, r, r];
  return `M${x + tl},${y}H${x + w - tr}A${tr},${tr} 0 0 1 ${x + w},${y + tr}V${y + h - br}A${br},${br} 0 0 1 ${x + w - br},${y + h}H${x + bl}A${bl},${bl} 0 0 1 ${x},${y + h - bl}V${y + tl}A${tl},${tl} 0 0 1 ${x + tl},${y}Z`;
}

/** Regular polygon path. */
export function poly(cx, cy, r, sides, rotation = -90) {
  const pts = [];
  for (let i = 0; i < sides; i += 1) {
    const a = ((rotation + (360 / sides) * i) * Math.PI) / 180;
    pts.push(`${(cx + Math.cos(a) * r).toFixed(2)},${(cy + Math.sin(a) * r).toFixed(2)}`);
  }
  return `M${pts.join('L')}Z`;
}

/** Star path. */
export function star(cx, cy, outer, inner, points = 5, rotation = -90) {
  const pts = [];
  for (let i = 0; i < points * 2; i += 1) {
    const r = i % 2 === 0 ? outer : inner;
    const a = ((rotation + (180 / points) * i) * Math.PI) / 180;
    pts.push(`${(cx + Math.cos(a) * r).toFixed(2)},${(cy + Math.sin(a) * r).toFixed(2)}`);
  }
  return `M${pts.join('L')}Z`;
}

export const HEADLINE = "'Archivo Black','Helvetica Neue',Impact,'Arial Narrow',sans-serif";
export const DISPLAY = "'Bebas Neue','Oswald','Arial Narrow',Impact,sans-serif";
export const BODY = "'Inter','Helvetica Neue',Arial,sans-serif";
export const MONO = "'JetBrains Mono','SF Mono',Menlo,monospace";

export function text(str, attrs = {}) {
  return el('text', {
    'font-family': attrs.font || BODY,
    'font-size': attrs.size || 16,
    'font-weight': attrs.weight || 700,
    fill: attrs.fill || '#fff',
    x: attrs.x || 0,
    y: attrs.y || 0,
    'text-anchor': attrs.anchor,
    'letter-spacing': attrs.tracking,
    opacity: attrs.opacity,
    transform: attrs.transform,
    style: attrs.style,
    ...(attrs.raw || {}),
  }, escapeText(str));
}

export function escapeText(s) {
  return String(s).replace(/&/g, '&amp;').replace(/</g, '&lt;').replace(/>/g, '&gt;');
}

/** Deterministic PRNG so regenerating assets never churns the diff. */
export function seeded(seed) {
  let s = 0;
  const str = String(seed);
  for (let i = 0; i < str.length; i += 1) s = (s * 31 + str.charCodeAt(i)) >>> 0;
  return () => {
    s ^= s << 13; s >>>= 0;
    s ^= s >> 17;
    s ^= s << 5; s >>>= 0;
    return s / 4294967296;
  };
}
