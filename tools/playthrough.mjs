#!/usr/bin/env node
/** Scripted playthrough: drives the real UI and captures each beat for review. */
import { chromium } from 'playwright';
import { mkdirSync } from 'node:fs';

const OUT = process.argv[2] || '/tmp/shots';
mkdirSync(OUT, { recursive: true });
const browser = await chromium.launch({ executablePath: '/opt/pw-browsers/chromium-1194/chrome-linux/chrome' });
const page = await browser.newPage({ viewport: { width: 1600, height: 1000 } });
const errors = [];
page.on('console', (m) => { if (m.type() === 'error') errors.push(m.text()); });
page.on('pageerror', (e) => errors.push(String(e)));

const shot = async (name, wait = 500) => { await page.waitForTimeout(wait); await page.screenshot({ path: `${OUT}/${name}.png` }); console.log('  ->', name); };

await page.goto('http://localhost:4173/', { waitUntil: 'networkidle' });
await page.waitForTimeout(1800);

// A pre-seeded bankroll so the run reaches the premium products.
await page.evaluate(() => {
  const raw = JSON.parse(localStorage.getItem('breakroom.save') || '{}');
  raw.cash = 20000; raw.level = 9; raw.version = 1;
  localStorage.setItem('breakroom.save', JSON.stringify(raw));
});
await page.reload({ waitUntil: 'networkidle' });
await page.waitForTimeout(1600);

console.log('store');
await page.click('text=Hobby Shop');
await shot('01-store', 1400);

console.log('buy');
const buys = page.locator('.box-card:not(.is-locked) .btn-gold');
await buys.nth(2).click();
await shot('02-confirm', 900);
await page.click('text=Buy and break it');
await shot('03-sealed', 1600);

console.log('break seal');
await page.click('.sealed-box');
await shot('04-packs', 2200);

console.log('rip pack');
await page.click('.pack:not(.is-opened)');
await page.waitForTimeout(1500);
await shot('05-reveal', 1200);
for (let i = 0; i < 6; i += 1) {
  const next = page.locator('button:has-text("Next card")');
  if (await next.count() && await next.isEnabled().catch(() => false)) { await next.click().catch(() => {}); await page.waitForTimeout(900); }
}
await shot('06-reveal-late', 900);
const skip = page.locator('button:has-text("Reveal the rest")');
if (await skip.count()) { await skip.click().catch(() => {}); await page.waitForTimeout(2600); }
await shot('07-pack-summary', 1200);

console.log('rip everything');
const back = page.locator('button:has-text("Back to packs")');
if (await back.count()) await back.click();
await page.waitForTimeout(700);
const all = page.locator('button:has-text("Rip everything")');
if (await all.count()) { await all.click(); await page.waitForTimeout(4200); }
await shot('08-box-summary', 1400);

console.log('collection');
await page.click('text=Collection');
await shot('09-collection', 2000);
console.log('market');
await page.click('text=Marketplace');
await shot('10-market', 1600);
console.log('grading');
await page.click('text=Grading');
await shot('11-grading', 1600);
console.log('ledger');
await page.click('text=Ledger');
await shot('12-ledger', 1400);

if (errors.length) console.error('\nPAGE ERRORS:\n' + [...new Set(errors)].slice(0, 15).join('\n'));
else console.log('\nno page errors');
await browser.close();
