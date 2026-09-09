#!/usr/bin/env node
/** Captures the top-end reveal: buys until a one-of-one is in the box, then rips it. */
import { chromium } from 'playwright';
import { mkdirSync } from 'node:fs';

const OUT = process.argv[2] || '/tmp/reveal';
mkdirSync(OUT, { recursive: true });
const browser = await chromium.launch({ executablePath: '/opt/pw-browsers/chromium-1194/chrome-linux/chrome' });
const page = await browser.newPage({ viewport: { width: 1600, height: 1000 } });
const errors = [];
page.on('pageerror', (e) => errors.push(String(e)));
page.on('console', (m) => { if (m.type() === 'error') errors.push(m.text()); });
const shot = async (n, w = 400) => { await page.waitForTimeout(w); await page.screenshot({ path: `${OUT}/${n}.png` }); console.log('  ->', n); };

await page.goto('http://localhost:4173/', { waitUntil: 'networkidle' });
await page.waitForTimeout(1600);

// Buy Flawless boxes until one holds a 1/1, then keep only that box.
const found = await page.evaluate(async () => {
  const BR = window.BreakRoom;
  BR.store.update((s) => { s.cash = 5_000_000; s.level = 12; s.vault = []; });
  const { BreakSystem } = await import('/src/systems/BreakSystem.js');
  for (let i = 0; i < 260; i += 1) {
    const entry = BreakSystem.purchase('BOX-NBA-FLAWLESS-25');
    if (!entry) break;
    const hit = entry.packs.flatMap((p) => p.cards).find((c) => c.serial?.run === 1);
    if (hit) {
      BR.store.update((s) => { s.vault = [entry]; });
      return { player: hit.player, label: hit.parallel, attempts: i + 1 };
    }
    BR.store.update((s) => { s.vault = s.vault.filter((v) => v.id !== entry.id); });
  }
  return null;
});
console.log('  one-of-one:', found);

await page.evaluate(() => window.BreakRoom.navigate('open'));
await page.waitForTimeout(1400);
await shot('01-sealed', 600);
await page.click('.sealed-box');
await page.waitForTimeout(2400);
await shot('02-packs', 400);

// Rip the pack holding the 1/1.
const packIndex = await page.evaluate(() => {
  const v = window.BreakRoom.state().vault[0];
  return v.packs.findIndex((p) => p.cards.some((c) => c.serial?.run === 1));
});
console.log('  pack index:', packIndex);
await page.locator('.pack').nth(packIndex).click();
await page.waitForTimeout(1600);

for (let i = 0; i < 24; i += 1) {
  const isOne = await page.evaluate(() => !!document.querySelector('.card[data-rarity="oneofone"]'));
  if (isOne) { await shot('03-oneofone', 250); await shot('04-oneofone-settled', 900); break; }
  const banner = await page.locator('.reveal-banner.is-on').count();
  if (banner) await shot(`b-${i}`, 120);
  const next = page.locator('button:has-text("Next card")');
  if (await next.count() && await next.isEnabled().catch(() => false)) { await next.click().catch(() => {}); }
  await page.waitForTimeout(700);
}
await shot('05-after', 1200);

if (errors.length) console.error('\nERRORS:\n' + [...new Set(errors)].slice(0, 10).join('\n'));
else console.log('\nno page errors');
await browser.close();
