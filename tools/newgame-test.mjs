#!/usr/bin/env node
/**
 * First-hour simulation with no cheats: starting cash only, cheapest product,
 * sell the filler, buy again. Verifies the new-player economy actually sustains.
 */
import { chromium } from 'playwright';

const browser = await chromium.launch({ executablePath: '/opt/pw-browsers/chromium-1194/chrome-linux/chrome' });
const page = await browser.newPage({ viewport: { width: 1400, height: 900 } });
const errors = [];
page.on('pageerror', (e) => errors.push(String(e)));
page.on('console', (m) => { if (m.type() === 'error') errors.push(m.text()); });

await page.goto('http://localhost:4173/', { waitUntil: 'networkidle' });
await page.evaluate(() => localStorage.removeItem('breakroom.save'));
await page.reload({ waitUntil: 'networkidle' });
await page.waitForTimeout(1600);

const runs = await page.evaluate(async () => {
  const BR = window.BreakRoom;
  const { BreakSystem } = await import('/src/systems/BreakSystem.js');
  const { MarketSystem } = await import('/src/systems/MarketSystem.js');
  const { Data } = await import('/src/systems/DataService.js');
  const log = [];
  const cheapest = () => Data.boxes
    .filter((b) => b.unlockLevel <= BR.state().level && b.price <= BR.state().cash)
    .sort((a, b) => b.price - a.price)[0];

  for (let round = 1; round <= 14; round += 1) {
    const box = cheapest();
    if (!box) { log.push({ round, note: 'broke - could not afford any product' }); break; }
    const cashBefore = BR.state().cash;
    const entry = BreakSystem.purchase(box.id);
    BreakSystem.breakSeal(entry.id);
    for (const p of entry.packs) BreakSystem.openPack(entry.id, p.index);

    // A collector's habit: keep the hits and anything numbered, sell the rest.
    const keep = (c) => c.hitType || c.serial || c.baseValue >= 25;
    let sold = 0;
    for (const c of [...BR.state().collection]) {
      if (keep(c)) continue;
      const r = MarketSystem.sell(c.uid);
      if (r) sold += r.quote.net;
    }
    log.push({
      round, box: box.shortName, price: box.price,
      cashBefore: Math.round(cashBefore), sold: Math.round(sold),
      cashAfter: Math.round(BR.state().cash),
      kept: BR.state().collection.length,
      collection: Math.round(BR.systems.EconomySystem.collectionValue((id) => MarketSystem.index(id))),
      level: BR.state().level,
    });
  }
  return log;
});

const pad = (v, n) => String(v).padEnd(n);
const padL = (v, n) => String(v).padStart(n);
console.log(`\nFIRST-HOUR RUN (starting cash only)\n`);
console.log(`${pad('#', 4)}${pad('Product', 20)}${padL('Price', 7)}${padL('Cash in', 9)}${padL('Sold', 8)}${padL('Cash out', 10)}${padL('Kept', 6)}${padL('Coll.', 8)}${padL('Lv', 4)}`);
console.log('-'.repeat(76));
for (const r of runs) {
  if (r.note) { console.log(`${pad(r.round, 4)}${r.note}`); continue; }
  console.log(pad(r.round, 4) + pad(r.box, 20) + padL('$' + r.price, 7) + padL('$' + r.cashBefore, 9)
    + padL('$' + r.sold, 8) + padL('$' + r.cashAfter, 10) + padL(r.kept, 6) + padL('$' + r.collection, 8) + padL(r.level, 4));
}
const last = runs.filter((r) => !r.note).at(-1);
console.log(`\nAfter ${runs.filter((r) => !r.note).length} boxes: ${last ? `$${last.cashAfter} cash, $${last.collection} collection, level ${last.level}, ${last.kept} cards kept` : 'no runs'}`);
if (errors.length) console.error('\nERRORS:\n' + [...new Set(errors)].slice(0, 8).join('\n'));
await browser.close();
