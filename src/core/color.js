/** Runtime colour maths. Mirrors tools/art/color.mjs so art and UI stay in step. */

export function hexToRgb(hex) {
  const h = String(hex).replace('#', '');
  const v = h.length === 3 ? h.split('').map((c) => c + c).join('') : h;
  return [parseInt(v.slice(0, 2), 16), parseInt(v.slice(2, 4), 16), parseInt(v.slice(4, 6), 16)];
}

const clamp = (n) => Math.max(0, Math.min(255, Math.round(n)));
export const rgbToHex = (r, g, b) => `#${[r, g, b].map((n) => clamp(n).toString(16).padStart(2, '0')).join('')}`;

export function mix(a, b, t) {
  const [r1, g1, b1] = hexToRgb(a);
  const [r2, g2, b2] = hexToRgb(b);
  return rgbToHex(r1 + (r2 - r1) * t, g1 + (g2 - g1) * t, b1 + (b2 - b1) * t);
}

export const shade = (hex, t) => mix(hex, '#000000', t);
export const tint = (hex, t) => mix(hex, '#ffffff', t);

export function luminance(hex) {
  const [r, g, b] = hexToRgb(hex).map((v) => {
    const s = v / 255;
    return s <= 0.03928 ? s / 12.92 : ((s + 0.055) / 1.055) ** 2.4;
  });
  return 0.2126 * r + 0.7152 * g + 0.0722 * b;
}

export const isLight = (hex) => luminance(hex) > 0.45;
export const alpha = (hex, a) => { const [r, g, b] = hexToRgb(hex); return `rgba(${r},${g},${b},${a})`; };

/** The five franchise tokens every inlined art file reads. */
export function teamTokens(team) {
  const { primary, secondary, accent } = team.colors;
  return {
    '--tp': primary,
    '--tp-l': tint(primary, 0.34),
    '--tp-d': shade(primary, 0.55),
    '--ts': secondary,
    '--ta': accent,
  };
}
