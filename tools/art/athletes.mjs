/**
 * Athlete art. Broadcast-graphics "cutout" style: a dynamic figure rendered as a
 * layered duotone with rim light, jersey panel and sport equipment.
 *
 * Every fill references a CSS custom property so a single file re-colours itself
 * to any franchise when the SVG is inlined inside a card:
 *   --tp team primary, --ts team secondary, --ta team accent, --num jersey number
 */
import { el, svg, defs, g, linearGradient, radialGradient, DISPLAY, HEADLINE } from './svg.mjs';

const W = 600;
const H = 820;

const v = (name, fallback) => `var(${name},${fallback})`;
const TP = v('--tp', '#1B2A41');
const TPL = v('--tp-l', '#3C5678');
const TPD = v('--tp-d', '#080C13');
const TS = v('--ts', '#C8963E');
const TA = v('--ta', '#E9E4D8');

/* ---------------------------------------------------------------- rigging */

function capPath(from, to, k) {
  const dx = to[0] - from[0];
  const dy = to[1] - from[1];
  const len = Math.hypot(dx, dy) || 1;
  return [(dx / len) * k, (dy / len) * k];
}

/** Tapered limb with round caps, built from two cubics. */
function limb(p0, p1, w0, w1) {
  const dx = p1[0] - p0[0];
  const dy = p1[1] - p0[1];
  const len = Math.hypot(dx, dy) || 1;
  const nx = -dy / len;
  const ny = dx / len;
  const a = [p0[0] + nx * w0, p0[1] + ny * w0];
  const b = [p1[0] + nx * w1, p1[1] + ny * w1];
  const c = [p1[0] - nx * w1, p1[1] - ny * w1];
  const d = [p0[0] - nx * w0, p0[1] - ny * w0];
  const [fx, fy] = capPath(p0, p1, w1 * 1.34);
  const [bx, by] = capPath(p1, p0, w0 * 1.34);
  const n = (t) => t.map((q) => q.toFixed(1)).join(',');
  return `M${n(a)}L${n(b)}`
    + `C${(b[0] + fx).toFixed(1)},${(b[1] + fy).toFixed(1)} ${(c[0] + fx).toFixed(1)},${(c[1] + fy).toFixed(1)} ${n(c)}`
    + `L${n(d)}`
    + `C${(d[0] + bx).toFixed(1)},${(d[1] + by).toFixed(1)} ${(a[0] + bx).toFixed(1)},${(a[1] + by).toFixed(1)} ${n(a)}Z`;
}

function torso(sl, sr, hl, hr, waist = 0.9) {
  const mlx = (sl[0] + hl[0]) / 2 - 6;
  const mly = (sl[1] + hl[1]) / 2;
  const mrx = (sr[0] + hr[0]) / 2 + 6;
  const mry = (sr[1] + hr[1]) / 2;
  return `M${sl[0]},${sl[1]}`
    + `C${sl[0] + 14},${sl[1] - 12} ${sr[0] - 14},${sr[1] - 12} ${sr[0]},${sr[1]}`
    + `C${mrx},${mry} ${hr[0] + 10},${hr[1] - 30} ${hr[0]},${hr[1]}`
    + `C${hr[0] - 12},${hr[1] + 16 * waist} ${hl[0] + 12},${hl[1] + 16 * waist} ${hl[0]},${hl[1]}`
    + `C${hl[0] - 10},${hl[1] - 30} ${mlx},${mly} ${sl[0]},${sl[1]}Z`;
}

/* --------------------------------------------------------------- headgear */

function footballHelmet(p, rot = 0) {
  const [x, y] = p;
  return g({ transform: `rotate(${rot} ${x} ${y})` }, [
    // shell
    el('path', { d: `M${x - 46},${y + 10}a46,52 0 0 1 92,0c0,30 -12,50 -32,56l-28,0c-20,-6 -32,-26 -32,-56Z`, fill: 'url(#helm)' }),
    // crown highlight and franchise stripe
    el('path', { d: `M${x - 46},${y + 8}a46,52 0 0 1 92,0c0,7 -1,13 -2,19c-13,-19 -29,-28 -44,-28s-31,9 -44,28c-1,-6 -2,-12 -2,-19Z`, fill: TPL, opacity: 0.55 }),
    el('path', { d: `M${x - 5},${y - 42}c8,26 8,60 0,92`, stroke: TS, 'stroke-width': 11, fill: 'none', opacity: 0.85 }),
    // face opening
    el('path', { d: `M${x + 6},${y + 16}h40c6,18 3,38 -8,50h-34c10,-14 12,-32 2,-50Z`, fill: '#05070B', opacity: 0.72 }),
    // facemask cage
    el('path', { d: `M${x + 2},${y + 28}h46M${x + 6},${y + 44}h42M${x + 12},${y + 58}h32`, stroke: '#DDE4ED', 'stroke-width': 4.5, 'stroke-linecap': 'round', fill: 'none' }),
    el('path', { d: `M${x + 46},${y + 22}c5,16 3,32 -4,44`, stroke: '#DDE4ED', 'stroke-width': 4.5, fill: 'none', 'stroke-linecap': 'round' }),
    // chin strap
    el('path', { d: `M${x - 40},${y + 44}c4,20 18,30 34,32`, stroke: TA, 'stroke-width': 5, fill: 'none', opacity: 0.5, 'stroke-linecap': 'round' }),
    el('path', { d: `M${x - 46},${y + 10}a46,52 0 0 1 92,0`, fill: 'none', stroke: TA, 'stroke-width': 3, opacity: 0.35 }),
  ]);
}

function ballCap(p, rot = 0) {
  const [x, y] = p;
  return g({ transform: `rotate(${rot} ${x} ${y})` }, [
    el('path', { d: `M${x - 40},${y + 44}a40,44 0 0 1 80,0Z`, fill: 'url(#helm)' }),
    el('path', { d: `M${x - 40},${y + 42}a40,44 0 0 1 80,0c-8,-24 -22,-34 -40,-34s-32,10 -40,34Z`, fill: TA, opacity: 0.28 }),
    el('path', { d: `M${x - 46},${y + 44}c16,-10 66,-12 84,-2c6,4 4,10 -6,10h-72c-8,0 -12,-5 -6,-8Z`, fill: '#0B0E12', opacity: 0.65 }),
    el('circle', { cx: x, cy: y + 4, r: 5, fill: TS }),
  ]);
}

function bareHead(p, rot = 0) {
  const [x, y] = p;
  return g({ transform: `rotate(${rot} ${x} ${y})` }, [
    el('path', { d: `M${x - 34},${y + 6}a34,40 0 0 1 68,0c0,28 -14,46 -34,46s-34,-18 -34,-46Z`, fill: 'url(#helm)' }),
    el('path', { d: `M${x - 34},${y + 2}a34,40 0 0 1 68,0c0,4 0,8 -1,12c-10,-14 -20,-20 -33,-20s-23,6 -33,20c-1,-4 -1,-8 -1,-12Z`, fill: '#080A0D', opacity: 0.55 }),
    el('path', { d: `M${x + 22},${y + 8}c7,11 7,28 0,40`, stroke: TA, 'stroke-width': 5, fill: 'none', opacity: 0.5, 'stroke-linecap': 'round' }),
    el('path', { d: `M${x + 26},${y + 18}a9,11 0 1 1 0.1,0`, fill: TPD, opacity: 0.8 }),
    el('path', { d: `M${x - 12},${y + 40}q14,12 30,2`, stroke: TPD, 'stroke-width': 5, fill: 'none', opacity: 0.55, 'stroke-linecap': 'round' }),
  ]);
}

/* -------------------------------------------------------------- equipment */

function football(p, rot = -28) {
  const [x, y] = p;
  return g({ transform: `rotate(${rot} ${x} ${y})` }, [
    el('ellipse', { cx: x, cy: y, rx: 46, ry: 28, fill: 'url(#leather)' }),
    el('path', { d: `M${x - 46},${y}q46,-34 92,0q-46,34 -92,0Z`, fill: 'none', stroke: '#F3EDE2', 'stroke-width': 2.4, opacity: 0.5 }),
    el('path', { d: `M${x - 16},${y}h32`, stroke: '#F6F1E6', 'stroke-width': 5, 'stroke-linecap': 'round' }),
    el('path', { d: `M${x - 12},${y - 6}v12M${x - 3},${y - 7}v14M${x + 6},${y - 7}v14M${x + 15},${y - 6}v12`, stroke: '#F6F1E6', 'stroke-width': 3.4, 'stroke-linecap': 'round' }),
  ]);
}

function basketball(p, r = 42) {
  const [x, y] = p;
  return g({}, [
    el('circle', { cx: x, cy: y, r, fill: 'url(#leather)' }),
    el('circle', { cx: x, cy: y, r, fill: 'none', stroke: '#2A1408', 'stroke-width': 2.5, opacity: 0.6 }),
    el('path', { d: `M${x - r},${y}h${r * 2}M${x},${y - r}v${r * 2}`, stroke: '#2A1408', 'stroke-width': 3, opacity: 0.7 }),
    el('path', { d: `M${x - r * 0.72},${y - r * 0.72}q${r * 0.72},${r * 0.72} 0,${r * 1.44}M${x + r * 0.72},${y - r * 0.72}q${-r * 0.72},${r * 0.72} 0,${r * 1.44}`, stroke: '#2A1408', 'stroke-width': 3, fill: 'none', opacity: 0.7 }),
    el('circle', { cx: x - r * 0.34, cy: y - r * 0.38, r: r * 0.42, fill: '#FFFFFF', opacity: 0.14 }),
  ]);
}

function bat(p0, p1) {
  return g({}, [
    el('path', { d: limb(p0, p1, 7, 20), fill: 'url(#wood)' }),
    el('path', { d: limb(p0, [p0[0] + (p1[0] - p0[0]) * 0.18, p0[1] + (p1[1] - p0[1]) * 0.18], 8, 8), fill: '#1A1D22' }),
  ]);
}

function glove(p, rot = 0) {
  const [x, y] = p;
  return g({ transform: `rotate(${rot} ${x} ${y})` }, [
    el('path', { d: `M${x - 30},${y}a30,34 0 1 1 60,0c0,22 -14,34 -30,34s-30,-12 -30,-34Z`, fill: 'url(#leather)' }),
    el('path', { d: `M${x - 18},${y - 18}v34M${x - 4},${y - 22}v38M${x + 10},${y - 20}v36`, stroke: '#2A1408', 'stroke-width': 3, opacity: 0.5 }),
  ]);
}

/* ------------------------------------------------------------------ poses */

const POSES = {
  qb_throw: {
    sport: 'NFL', head: [300, 150], headRot: -6,
    sl: [252, 238], sr: [352, 226], hl: [272, 432], hr: [340, 428],
    arms: [[[352, 226], [424, 176], [452, 104]], [[252, 238], [204, 300], [244, 352]]],
    legs: [[[272, 432], [238, 566], [252, 714]], [[340, 428], [406, 548], [462, 668]]],
    gear: (o) => football([o.arms[0][2][0] + 18, o.arms[0][2][1] - 22], -34),
  },
  rb_stiffarm: {
    sport: 'NFL', head: [316, 176], headRot: 10,
    sl: [268, 262], sr: [366, 248], hl: [266, 448], hr: [336, 440],
    arms: [[[366, 248], [438, 268], [508, 246]], [[268, 262], [232, 336], [286, 384]]],
    legs: [[[266, 448], [216, 572], [244, 712]], [[336, 440], [402, 534], [386, 686]]],
    gear: (o) => football([o.arms[1][2][0] - 6, o.arms[1][2][1] + 6], 24),
  },
  wr_catch: {
    sport: 'NFL', head: [300, 168], headRot: -4,
    sl: [252, 252], sr: [352, 250], hl: [268, 452], hr: [338, 450],
    arms: [[[352, 250], [402, 178], [386, 96]], [[252, 252], [200, 182], [218, 100]]],
    legs: [[[268, 452], [238, 584], [258, 726]], [[338, 450], [388, 566], [378, 712]]],
    gear: () => football([302, 84], 12),
  },
  dl_rush: {
    sport: 'NFL', head: [310, 210], headRot: 14,
    sl: [258, 292], sr: [360, 276], hl: [270, 470], hr: [340, 462],
    arms: [[[360, 276], [438, 300], [498, 268]], [[258, 292], [206, 340], [236, 414]]],
    legs: [[[270, 470], [214, 578], [186, 706]], [[340, 462], [418, 546], [470, 662]]],
    gear: () => '',
  },
  dunk: {
    sport: 'NBA', head: [300, 186], headRot: -8,
    sl: [254, 268], sr: [352, 254], hl: [274, 452], hr: [342, 448],
    arms: [[[352, 254], [412, 178], [396, 84]], [[254, 268], [196, 320], [222, 394]]],
    legs: [[[274, 452], [232, 566], [268, 660]], [[342, 448], [428, 512], [468, 606]]],
    gear: () => basketball([394, 66], 44),
  },
  jumper: {
    sport: 'NBA', head: [300, 176], headRot: -3,
    sl: [254, 258], sr: [350, 256], hl: [272, 452], hr: [338, 450],
    arms: [[[350, 256], [372, 176], [332, 118]], [[254, 258], [216, 190], [262, 140]]],
    legs: [[[272, 452], [252, 588], [268, 722]], [[338, 450], [368, 588], [356, 724]]],
    gear: () => basketball([300, 96], 40),
  },
  drive: {
    sport: 'NBA', head: [318, 194], headRot: 12,
    sl: [268, 276], sr: [368, 262], hl: [272, 458], hr: [342, 452],
    arms: [[[368, 262], [430, 330], [420, 424]], [[268, 276], [206, 306], [172, 372]]],
    legs: [[[272, 458], [212, 566], [246, 706]], [[342, 452], [420, 528], [396, 672]]],
    gear: () => basketball([420, 486], 40),
  },
  block: {
    sport: 'NBA', head: [300, 158], headRot: 0,
    sl: [252, 244], sr: [350, 244], hl: [270, 444], hr: [336, 444],
    arms: [[[350, 244], [382, 164], [372, 76]], [[252, 244], [220, 164], [230, 76]]],
    legs: [[[270, 444], [250, 582], [262, 722]], [[336, 444], [358, 582], [350, 724]]],
    gear: () => basketball([372, 54], 34),
  },
  swing: {
    sport: 'MLB', head: [308, 186], headRot: 8,
    sl: [258, 268], sr: [356, 258], hl: [270, 456], hr: [340, 450],
    arms: [[[356, 258], [420, 226], [458, 178]], [[258, 268], [318, 216], [416, 190]]],
    legs: [[[270, 456], [222, 578], [252, 714]], [[340, 450], [412, 546], [452, 676]]],
    gear: (o) => bat([o.arms[0][2][0] - 8, o.arms[0][2][1] + 6], [176, 68]),
  },
  pitch: {
    sport: 'MLB', head: [300, 166], headRot: -6,
    sl: [256, 250], sr: [352, 240], hl: [278, 440], hr: [344, 436],
    arms: [[[352, 240], [428, 220], [452, 140]], [[256, 250], [206, 296], [242, 356]]],
    legs: [[[278, 440], [286, 560], [268, 700]], [[344, 436], [430, 400], [478, 460]]],
    gear: (o) => glove([o.arms[1][2][0] - 6, o.arms[1][2][1] + 14], -18),
  },
  field: {
    sport: 'MLB', head: [304, 224], headRot: 12,
    sl: [256, 302], sr: [354, 290], hl: [272, 468], hr: [342, 462],
    arms: [[[354, 290], [400, 372], [356, 444]], [[256, 302], [212, 372], [252, 438]]],
    legs: [[[272, 468], [206, 566], [180, 690]], [[342, 462], [418, 548], [452, 668]]],
    gear: (o) => glove([o.arms[0][2][0] + 4, o.arms[0][2][1] + 24], 12),
  },
  slide: {
    sport: 'MLB', head: [204, 320], headRot: -22,
    sl: [252, 372], sr: [286, 330], hl: [382, 428], hr: [400, 384],
    arms: [[[286, 330], [258, 250], [292, 182]], [[252, 372], [214, 420], [252, 470]]],
    legs: [[[382, 428], [470, 470], [548, 456]], [[400, 384], [478, 388], [534, 340]]],
    gear: () => ballCap([204, 320], -22),
  },
};

const HEADGEAR = { NFL: footballHelmet, NBA: bareHead, MLB: ballCap };

/* ----------------------------------------------------------------- render */

function figureDefs() {
  return defs([
    linearGradient('body', [['0%', TPL], ['46%', TP], ['100%', TPD]], { x1: '8%', y1: '0%', x2: '92%', y2: '100%' }),
    linearGradient('pants', [['0%', TP], ['48%', TPD], ['100%', '#0A0E15']], { x1: '8%', y1: '0%', x2: '92%', y2: '100%' }),
    linearGradient('jersey', [['0%', TPL], ['58%', TP], ['100%', TPD]], { x1: '20%', y1: '0%', x2: '85%', y2: '100%' }),
    linearGradient('helm', [['0%', TPL], ['55%', TP], ['100%', TPD]], { x1: '15%', y1: '0%', x2: '85%', y2: '100%' }),
    linearGradient('leather', [['0%', '#C9762F'], ['55%', '#8C4718'], ['100%', '#4A2109']], { x1: '20%', y1: '0%', x2: '80%', y2: '100%' }),
    linearGradient('wood', [['0%', '#E4C08A'], ['60%', '#B07C42'], ['100%', '#5C3A17']], { x1: '0%', y1: '0%', x2: '100%', y2: '0%' }),
    radialGradient('floor', [['0%', TS, 0.42], ['100%', TS, 0]]),
    radialGradient('backlight', [['0%', TS, 0.16], ['62%', TP, 0.08], ['100%', TP, 0]]),
    el('filter', { id: 'soft', x: '-20%', y: '-20%', width: '140%', height: '140%' }, [
      el('feGaussianBlur', { stdDeviation: 9 }),
    ]),
  ]);
}

function renderPose(id, pose) {
  // Broaden the frame: pose data stores a readable skeleton, the renderer gives it
  // athletic proportions (wide shoulders, tapered waist, heavy limbs).
  const sCx = (pose.sl[0] + pose.sr[0]) / 2;
  const hCx = (pose.hl[0] + pose.hr[0]) / 2;
  const widen = (p, cx, k) => [cx + (p[0] - cx) * k, p[1]];
  const SL = widen(pose.sl, sCx, 1.5);
  const SR = widen(pose.sr, sCx, 1.5);
  const HL = widen(pose.hl, hCx, 1.12);
  const HR = widen(pose.hr, hCx, 1.12);
  const arms = pose.arms.map((a, i) => [i === 0 ? SR : SL, a[1], a[2]]);
  const legs = [[HL, pose.legs[0][1], pose.legs[0][2]], [HR, pose.legs[1][1], pose.legs[1][2]]];
  const rim = TA;

  const leg = ([hip, knee, foot], i) => g({ opacity: i === 1 ? 0.84 : 1 }, [
    el('path', { d: limb(hip, knee, 40, 28), fill: 'url(#pants)' }),
    el('circle', { cx: knee[0], cy: knee[1], r: 27, fill: 'url(#pants)' }),
    el('path', { d: limb(knee, foot, 27, 17), fill: 'url(#body)' }),
    el('path', { d: limb(knee, foot, 12, 8), fill: TS, opacity: 0.28 }),
    el('path', { d: limb(foot, [foot[0] + (i === 0 ? -36 : 38), foot[1] + 17], 15, 9), fill: '#E6EBF2' }),
    el('path', { d: limb(foot, [foot[0] + (i === 0 ? -36 : 38), foot[1] + 17], 7, 4), fill: TS, opacity: 0.75 }),
  ]);

  const arm = ([sh, elb, hand], i) => g({ opacity: i === 1 ? 0.88 : 1 }, [
    el('path', { d: limb(sh, elb, 30, 21), fill: 'url(#body)' }),
    el('circle', { cx: elb[0], cy: elb[1], r: 20, fill: 'url(#body)' }),
    el('path', { d: limb(elb, hand, 20, 14), fill: 'url(#body)' }),
    el('circle', { cx: hand[0], cy: hand[1], r: 15, fill: 'url(#body)' }),
    // short sleeve in franchise secondary
    el('path', { d: limb(sh, [sh[0] + (elb[0] - sh[0]) * 0.3, sh[1] + (elb[1] - sh[1]) * 0.3], 31, 26), fill: TS, opacity: i === 0 ? 0.42 : 0.3 }),
  ]);

  const legPaths = legs.map(leg);
  const armPaths = arms.map(arm);
  const t = torso(SL, SR, HL, HR);
  const cx = (SL[0] + SR[0] + HL[0] + HR[0]) / 4;
  const cy = (SL[1] + SR[1] + HL[1] + HR[1]) / 4;
  const neck = [(SL[0] + SR[0]) / 2, (SL[1] + SR[1]) / 2 - 16];

  return svg({
    w: W, h: H, id: `athlete-${id}`,
    children: [
      figureDefs(),
      el('ellipse', { cx: 300, cy: 300, rx: 250, ry: 300, fill: 'url(#backlight)' }),
      el('ellipse', { cx: 300, cy: 760, rx: 200, ry: 42, fill: 'url(#floor)' }),
      g({ transform: 'translate(300,780) scale(1.06) translate(-300,-780)' }, [
        // cast shadow
        g({ transform: 'translate(22,14)', opacity: 0.2, filter: 'url(#soft)' }, [
          el('path', { d: t, fill: '#000' }), ...legPaths, ...armPaths,
        ]),
        legPaths[1],
        armPaths[1],
        el('path', { d: limb(neck, [neck[0], neck[1] + 46], 24, 30), fill: TPD }),
        legPaths[0],
        el('path', { d: t, fill: 'url(#jersey)' }),
        // lit edge down the jersey
        el('path', { d: `M${SL[0] + 6},${SL[1] + 10}C${SL[0] - 2},${(SL[1] + HL[1]) / 2} ${HL[0] - 2},${HL[1] - 40} ${HL[0] + 4},${HL[1] - 4}`, stroke: TPL, 'stroke-width': 7, fill: 'none', opacity: 0.5, 'stroke-linecap': 'round' }),
        // franchise side panels
        el('path', { d: `M${SL[0] + 16},${SL[1] + 22}L${HL[0] + 10},${HL[1] - 10}`, stroke: TS, 'stroke-width': 8, opacity: 0.75, 'stroke-linecap': 'round' }),
        el('path', { d: `M${SR[0] - 16},${SR[1] + 22}L${HR[0] - 10},${HR[1] - 10}`, stroke: TS, 'stroke-width': 8, opacity: 0.45, 'stroke-linecap': 'round' }),
        // collar
        el('path', { d: `M${cx - 30},${(SL[1] + SR[1]) / 2 + 2}Q${cx},${(SL[1] + SR[1]) / 2 + 30} ${cx + 30},${(SL[1] + SR[1]) / 2 + 2}`, stroke: TA, 'stroke-width': 6, fill: 'none', opacity: 0.6, 'stroke-linecap': 'round' }),
        el('text', {
          class: 'jersey-num', x: cx, y: cy + 30, 'font-family': HEADLINE, 'font-size': 84,
          'font-weight': 900, fill: TA, 'text-anchor': 'middle', opacity: 0.92,
        }, '00'),
        g({ transform: `translate(${pose.head[0]},${pose.head[1]}) scale(1.24) translate(${-pose.head[0]},${-pose.head[1]})` },
          HEADGEAR[pose.sport](pose.head, pose.headRot)),
        armPaths[0],
        pose.gear(pose) || '',
      ]),
    ],
  });
}

export function athleteAssets() {
  const out = {};
  for (const [id, pose] of Object.entries(POSES)) {
    out[`pose-${id}`] = renderPose(id, pose);
  }
  return out;
}

export const POSE_IDS = Object.keys(POSES);
export const POSE_SPORT = Object.fromEntries(Object.entries(POSES).map(([k, p]) => [k, p.sport]));
