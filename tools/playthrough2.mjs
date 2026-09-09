#!/usr/bin/env node
/** Deep flow test: inspector, grading submission, slab reveal, market sale. */
import { chromium } from 'playwright';
import { mkdirSync } from 'node:fs';

const OUT = process.argv[2] || '/tmp/shots2';
mkdirSync(OUT, { recursive: true });
const browser = await chromium.launch({ executablePath: '/opt/pw-browsers/chromium-1194/chrome-linux/chrome' });
const page = await browser.newPage({ viewport: { width: 1600, height: 1000 } });
const errors = [];
page.on('console', (m) => { if (m.type() === 'error') errors.push(m.text()); });
page.on('pageerror', (e) => errors.push(String(e)));
const shot = async (n, w = 600) => { await page.waitForTimeout(w); await page.screenshot({ path: `${OUT}/${n}.png` }); console.log('  ->', n); };

await page.goto('http://localhost:4173/', { waitUntil: 'networkidle' });
await page.waitForTimeout(1500);
await page.evaluate(() => {
  window.BreakRoom.store.update((s) => { s.cash = 60000; s.level = 9; });
});
await page.waitForTimeout(600);

// Buy and instantly empty a premium box so there is real inventory.
await page.click('text=Hobby Shop');
await page.waitForTimeout(1000);
const cards = page.locator('.box-card:not(.is-locked)');
const n = await cards.count();
await cards.nth(n - 1).locator('.btn-gold').click();
await page.waitForTimeout(600);
await page.click('text=Buy and break it');
await page.waitForTimeout(1400);
await page.click('.sealed-box');
await page.waitForTimeout(2200);
const all = page.locator('button:has-text("Rip everything")');
if (await all.count()) { await all.click(); await page.waitForTimeout(5000); }
await shot('01-premium-box', 1200);

console.log('inspector');
await page.click('text=Collection');
await page.waitForTimeout(1600);
await page.locator('.coll-toolbar select').selectOption('value');
await page.waitForTimeout(900);
await page.locator('.card-grid .card-tile').first().click();
await shot('02-inspector', 1800);

console.log('submit to grading');
const send = page.locator('button:has-text("Send to Apex")');
if (await send.count()) {
  await send.click();
  await shot('03-submit', 1500);
  await page.click('.modal-foot button:has-text("Submit")');
  await page.waitForTimeout(1200);
}

console.log('bulk grading');
await page.click('text=Grading');
await page.waitForTimeout(1400);
for (let i = 0; i < 4; i += 1) {
  const row = page.locator('aside.panel .sell-row').nth(i);
  if (await row.count()) { await row.click(); await page.waitForTimeout(220); }
}
await page.click('button:has-text("Submit to Apex")');
await page.waitForTimeout(900);
await page.click('.modal-foot button:has-text("Submit")');
await shot('04-pending', 1600);

console.log('fast-forward the grader');
const readyCount = await page.evaluate(() => window.BreakRoom.fastForwardGrading());
console.log('   ready submissions:', readyCount);
await page.click('text=Collection');
await page.waitForTimeout(700);
await page.click('text=Grading');
await page.waitForTimeout(1500);
await shot('05-ready', 900);
const openAll = page.locator('button:has-text("Open all")');
if (await openAll.count()) {
  await openAll.click();
  await shot('06-slab-reveal', 2600);
  for (let i = 0; i < 6; i += 1) {
    const nx = page.locator('.grade-reveal button');
    if (await nx.count()) { await nx.first().click(); await page.waitForTimeout(1500); } else break;
  }
}
await shot('07-slab-case', 1800);

console.log('market');
await page.click('text=Marketplace');
await page.waitForTimeout(1500);
await shot('08-market', 900);
const sellAll = page.locator('.panel-head + .row button, button:has-text("Sell all")').first();
if (await sellAll.count()) {
  await page.locator('.chip:has-text("Under $5")').click();
  await page.waitForTimeout(700);
  await page.locator('button:has-text("Sell all")').click();
  await page.waitForTimeout(700);
  await shot('09-bulk-sell', 800);
  await page.click('button:has-text("Confirm sale")');
  await page.waitForTimeout(1400);
}
await shot('10-after-sell', 1000);
await page.click('text=Clubhouse');
await shot('11-clubhouse', 2200);
await page.click('text=Ledger');
await shot('12-ledger', 1600);

if (errors.length) console.error('\nPAGE ERRORS:\n' + [...new Set(errors)].slice(0, 15).join('\n'));
else console.log('\nno page errors');
await browser.close();
