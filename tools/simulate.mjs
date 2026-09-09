#!/usr/bin/env node
/**
 * Balance harness. Opens every product thousands of times and reports the real
 * expected value, hit rates and chase-card frequency, then writes the measured
 * estimatedValue back into data/boxes.json.
 *
 *   node tools/simulate.mjs           report only
 *   node tools/simulate.mjs --write   report and persist estimatedValue
 */
import { readFileSync, writeFileSync } from 'node:fs';
import { join, dirname } from 'node:path';
import { fileURLToPath } from 'node:url';

const ROOT = join(dirname(fileURLToPath(import.meta.url)), '..');

// Serve data/*.json to the browser-shaped DataService.
globalThis.fetch = async (url) => {
  const path = join(ROOT, String(url).replace(/^\.?\//, ''));
  const body = readFileSync(path, 'utf8');
  return { ok: true, json: async () => JSON.parse(body), text: async () => body };
};
globalThis.window = { addEventListener() {} };
globalThis.document = { addEventListener() {} };
globalThis.localStorage = { getItem: () => null, setItem() {}, removeItem() {} };

const { Data } = await import('../src/systems/DataService.js');
const { BoxSystem } = await import('../src/systems/BoxSystem.js');
const { OddsSystem } = await import('../src/systems/OddsSystem.js');
const { GradingSystem } = await import('../src/systems/GradingSystem.js');
const { CardSystem } = await import('../src/systems/CardSystem.js');
const { makeRng } = await import('../src/core/rng.js');

await Data.load('');

const RUNS = Number(process.env.RUNS || 4000);
const WRITE = process.argv.includes('--write');
const random = makeRng(20260909);

const pad = (s, n) => String(s).padEnd(n);
const padL = (s, n) => String(s).padStart(n);
const pctS = (v) => `${(v * 100).toFixed(2)}%`;

console.log(`\nBOX EXPECTED VALUE  (${RUNS.toLocaleString()} boxes each)\n`);
console.log(`${pad('Product', 30)}${padL('Price', 8)}${padL('EV', 9)}${padL('EV/price', 10)}${padL('p50', 8)}${padL('p90', 9)}${padL('Top1%', 10)}${padL('Hits', 7)}${padL('1/1', 8)}`);
console.log('-'.repeat(91));

const results = [];
for (const box of Data.boxes) {
  const totals = [];
  let hits = 0; let oneOfOnes = 0; let numbered = 0; let cards = 0;
  for (let i = 0; i < RUNS; i += 1) {
    const opened = BoxSystem.open(box, random);
    totals.push(opened.totalValue);
    for (const p of opened.packs) {
      for (const c of p.cards) {
        cards += 1;
        if (c.hitType) hits += 1;
        if (c.serial) numbered += 1;
        if (c.serial?.run === 1) oneOfOnes += 1;
      }
    }
  }
  totals.sort((a, b) => a - b);
  const ev = totals.reduce((a, b) => a + b, 0) / RUNS;
  const p = (q) => totals[Math.floor(totals.length * q)];
  const top1 = totals.slice(Math.floor(totals.length * 0.99)).reduce((a, b) => a + b, 0) / Math.max(1, totals.length - Math.floor(totals.length * 0.99));
  results.push({ box, ev, median: p(0.5), p90: p(0.9), ratio: ev / box.price, oneOfOnes: oneOfOnes / RUNS });
  console.log(
    pad(box.shortName + ' ' + box.sport, 30)
    + padL('$' + box.price, 8)
    + padL('$' + Math.round(ev), 9)
    + padL((ev / box.price).toFixed(2), 10)
    + padL('$' + Math.round(p(0.5)), 8)
    + padL('$' + Math.round(p(0.9)), 9)
    + padL('$' + Math.round(top1), 10)
    + padL((hits / RUNS).toFixed(1), 7)
    + padL(pctS(oneOfOnes / RUNS), 8),
  );
}

console.log('\nPUBLISHED ODDS SPOT CHECK\n');
for (const id of ['BOX-NFL-OPTIC-25', 'BOX-NFL-PRIZM-25', 'BOX-NFL-FLAWLESS-25']) {
  const box = Data.box(id);
  const { rows, hitsPerBox } = OddsSystem.publishedOdds(box);
  console.log(`${box.name}  (${hitsPerBox} guaranteed hits/box)`);
  for (const r of rows.slice(0, 5)) console.log(`   ${pad(r.label + (r.run ? ` /${r.run}` : ''), 24)} ${padL(pctS(r.chance), 9)} per box`);
  const sf = rows.find((r) => r.id === 'superfractor');
  if (sf) console.log(`   ${pad('Superfractor 1/1', 24)} ${padL(pctS(sf.chance), 9)} per box`);
  console.log('');
}

console.log('GRADING DISTRIBUTION  (10,000 cards per product tier)\n');
console.log(`${pad('Profile', 12)}${['10', '9', '8', '7', '6', '<=5'].map((g) => padL('PSA ' + g, 9)).join('')}`);
console.log('-'.repeat(66));
for (const profile of ['entry', 'prizm', 'treasures', 'flawless']) {
  const box = Data.boxes.find((b) => b.profile === profile);
  const counts = { 10: 0, 9: 0, 8: 0, 7: 0, 6: 0, low: 0 };
  for (let i = 0; i < 10000; i += 1) {
    const card = { condition: CardSystem.rollCondition(profile, random) };
    const g = GradingSystem.computeGrade(card, 'express', random).grade;
    if (g >= 6) counts[g] = (counts[g] ?? 0) + 1; else counts.low += 1;
  }
  console.log(pad(profile, 12) + [10, 9, 8, 7, 6, 'low'].map((k) => padL(pctS(counts[k] / 10000), 9)).join(''));
}

if (WRITE) {
  const file = join(ROOT, 'data/boxes.json');
  const data = JSON.parse(readFileSync(file, 'utf8'));
  const targets = Data.odds.$evTargets || {};
  const nice = (n) => (n < 400 ? Math.round(n / 5) * 5 : n < 2000 ? Math.round(n / 25) * 25 : Math.round(n / 50) * 50);
  for (const r of results) {
    const target = data.boxes.find((b) => b.id === r.box.id);
    if (!target) continue;
    target.estimatedValue = Math.round(r.ev);
    const ratio = targets[r.box.profile] ?? 0.85;
    target.price = nice(r.ev / ratio);
  }
  writeFileSync(file, `${JSON.stringify(data, null, 2)}\n`, 'utf8');
  console.log('\nprice + estimatedValue written to data/boxes.json');
}
console.log('');
