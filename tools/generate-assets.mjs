#!/usr/bin/env node
/**
 * Asset pipeline.
 *
 * Renders every image the game needs as vector artwork and writes the machine
 * readable manifest that the runtime AssetRegistry loads. Nothing in /src ever
 * builds a path by hand - it asks the registry for a key.
 *
 * Run: npm run assets
 */
import { mkdirSync, writeFileSync, readFileSync } from 'node:fs';
import { dirname, join } from 'node:path';
import { fileURLToPath } from 'node:url';

import { teamCrest, leagueMark, brandMark, insertArt } from './art/logos.mjs';
import { athleteAssets, POSE_SPORT } from './art/athletes.mjs';
import { frameAssets, cardBack, TEMPLATE_IDS } from './art/cardframes.mjs';
import { foilAssets } from './art/foils.mjs';
import { hobbyBox, packWrapper } from './art/packaging.mjs';
import { slabShell, slabLabel, slabBarcode, slabQr, graderMark, SLAB_GEOMETRY } from './art/slab.mjs';
import { uiAssets } from './art/ui.mjs';

const ROOT = join(dirname(fileURLToPath(import.meta.url)), '..');
const read = (p) => JSON.parse(readFileSync(join(ROOT, p), 'utf8'));

const teams = read('data/teams.json').teams;
const boxes = read('data/boxes.json').boxes;
const cardTypes = read('data/cardtypes.json');

const SPORT_DIR = { NFL: 'football', NBA: 'basketball', MLB: 'baseball' };

/** Every asset the game can reference, in manifest order. */
const entries = [];

function add({ key, folder, file, svg, usage, required = true, status = 'generated-vector' }) {
  const m = /viewBox="0 0 ([\d.]+) ([\d.]+)"/.exec(svg);
  entries.push({
    key,
    folder,
    file,
    path: `${folder}/${file}`,
    width: m ? Number(m[1]) : null,
    height: m ? Number(m[2]) : null,
    format: 'SVG',
    usage,
    required,
    status,
    svg,
  });
}

/* ------------------------------------------------------------------- UI */

const ui = uiAssets();
for (const [id, svg] of Object.entries(ui)) {
  if (id.startsWith('bg-')) {
    add({ key: `ui.${id}`, folder: 'assets/ui', file: `${id}.svg`, svg, usage: `Screen backdrop for the ${id.slice(3)} view.` });
  } else if (id.startsWith('icon-')) {
    add({ key: `ui.${id}`, folder: 'assets/icons', file: `${id}.svg`, svg, usage: `Interface icon "${id.slice(5)}".`, required: id === 'icon-currency' });
  } else {
    add({ key: `fx.${id.slice(3)}`, folder: 'assets/effects', file: `${id}.svg`, svg, usage: `Reveal effect layer "${id.slice(3)}".`, required: false });
  }
}

/* --------------------------------------------------------------- leagues */

for (const sport of ['NFL', 'NBA', 'MLB']) {
  add({
    key: `league.${sport}`, folder: 'assets/leagues', file: `league-${SPORT_DIR[sport]}.svg`,
    svg: leagueMark(sport), usage: `League mark stamped on ${sport} cards, box art and filters.`,
  });
}

/* ----------------------------------------------------------------- teams */

for (const team of teams) {
  add({
    key: `team.${team.id}`, folder: `assets/teams/${SPORT_DIR[team.sport]}`, file: `crest-${team.id.toLowerCase()}.svg`,
    svg: teamCrest(team), usage: `${team.city} ${team.nickname} franchise crest.`,
  });
}

/* ---------------------------------------------------------------- brands */

for (const box of boxes) {
  add({
    key: `brand.${box.id}`, folder: 'assets/brands', file: `brand-${box.id.toLowerCase()}.svg`,
    svg: brandMark(box), usage: `${box.name} product wordmark used on store tiles and card fronts.`,
  });
}

/* ------------------------------------------------------ boxes and packs */

for (const box of boxes) {
  add({
    key: `box.${box.id}`, folder: `assets/boxes/${SPORT_DIR[box.sport]}`, file: `${box.id.toLowerCase()}.svg`,
    svg: hobbyBox(box), usage: `Sealed hobby box packaging for ${box.name} (3/4 product shot).`,
  });
  add({
    key: `pack.${box.id}`, folder: `assets/packs/${SPORT_DIR[box.sport]}`, file: `${box.id.toLowerCase()}-pack.svg`,
    svg: packWrapper(box), usage: `Foil pack wrapper for ${box.name}.`,
  });
}

/* ----------------------------------------------------------------- cards */

for (const [id, svg] of Object.entries(frameAssets())) {
  const [, tpl, layer] = /^frame-(.+)-(bg|fg)$/.exec(id);
  add({
    key: `frame.${tpl}.${layer}`, folder: 'assets/cards/templates', file: `${id}.svg`, svg,
    usage: layer === 'bg' ? `Art field behind the athlete on ${tpl} cards.` : `Border, nameplate and foil furniture for ${tpl} cards.`,
  });
}

for (const sport of ['NFL', 'NBA', 'MLB']) {
  add({
    key: `cardback.${sport}`, folder: 'assets/cards/backs', file: `back-${SPORT_DIR[sport]}.svg`,
    svg: cardBack(sport), usage: `Reverse of every ${sport} card; shown before a reveal flip.`,
  });
}

for (const [id, svg] of Object.entries(athleteAssets())) {
  const pose = id.slice(5);
  add({
    key: `pose.${pose}`, folder: `assets/cards/poses/${SPORT_DIR[POSE_SPORT[pose]]}`, file: `${id}.svg`, svg,
    usage: `Athlete cutout, pose "${pose}". Recoloured per franchise at runtime.`,
  });
}

for (const [id, svg] of Object.entries(foilAssets())) {
  add({
    key: `foil.${id.slice(5)}`, folder: 'assets/cards/foils', file: `${id}.svg`, svg,
    usage: `Parallel finish overlay "${id.slice(5)}".`, required: id !== 'foil-none',
  });
}

for (const ins of cardTypes.insertSets) {
  if (!entries.some((e) => e.key === `insert.${ins.art}`)) {
    add({
      key: `insert.${ins.art}`, folder: 'assets/cards/inserts', file: `insert-${ins.art}.svg`,
      svg: insertArt(ins.art), usage: `Insert-set background art "${ins.art}".`,
    });
  }
}

/* --------------------------------------------------------------- grading */

add({ key: 'grading.shell', folder: 'assets/grading', file: 'slab-shell.svg', svg: slabShell(), usage: 'Acrylic slab case with transparent card and label windows.' });
for (const band of ['standard', 'gold', 'black']) {
  add({ key: `grading.label.${band}`, folder: 'assets/grading', file: `slab-label-${band}.svg`, svg: slabLabel(band), usage: `Slab label stock for the ${band} grade band.` });
}
add({ key: 'grading.barcode', folder: 'assets/grading', file: 'slab-barcode.svg', svg: slabBarcode(), usage: 'Certification barcode printed on the slab label.' });
add({ key: 'grading.qr', folder: 'assets/grading', file: 'slab-qr.svg', svg: slabQr(), usage: 'Certification QR block on the slab label.', required: false });
add({ key: 'grading.mark', folder: 'assets/grading', file: 'grader-mark.svg', svg: graderMark(), usage: 'Apex Grading Authority company mark.' });

/* ----------------------------------------------------------------- write */

let written = 0;
for (const e of entries) {
  const dir = join(ROOT, e.folder);
  mkdirSync(dir, { recursive: true });
  writeFileSync(join(dir, e.file), `${e.svg}\n`, 'utf8');
  written += 1;
}

const manifest = {
  $comment: 'Generated by tools/generate-assets.mjs. The runtime loads assets by key only - never by literal path. Drop a replacement file at the same path (or list an override in data/assets.overrides.json) to swap artwork.',
  generatedAt: null,
  slab: SLAB_GEOMETRY,
  card: { width: 750, height: 1050, aspect: 750 / 1050 },
  assets: entries.map(({ svg, ...rest }) => rest),
};
writeFileSync(join(ROOT, 'data/assets.manifest.json'), `${JSON.stringify(manifest, null, 2)}\n`, 'utf8');

console.log(`wrote ${written} assets across ${new Set(entries.map((e) => e.folder)).size} folders`);
console.log('manifest -> data/assets.manifest.json');
