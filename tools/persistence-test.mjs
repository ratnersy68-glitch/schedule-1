#!/usr/bin/env node
/** Verifies the save round-trips: cash, collection, vault, slabs, submissions, stats, settings. */
import { chromium } from 'playwright';

const browser = await chromium.launch({ executablePath: '/opt/pw-browsers/chromium-1194/chrome-linux/chrome' });
const page = await browser.newPage({ viewport: { width: 1400, height: 900 } });
const errors = [];
page.on('pageerror', (e) => errors.push(String(e)));
page.on('console', (m) => { if (m.type() === 'error') errors.push(m.text()); });

await page.goto('http://localhost:4173/', { waitUntil: 'networkidle' });
await page.waitForTimeout(1500);
await page.evaluate(() => localStorage.removeItem('breakroom.save'));
await page.reload({ waitUntil: 'networkidle' });
await page.waitForTimeout(1500);

// Build a state worth persisting.
const before = await page.evaluate(async () => {
  const BR = window.BreakRoom;
  const { BreakSystem } = await import('/src/systems/BreakSystem.js');
  const { GradingSystem } = await import('/src/systems/GradingSystem.js');
  const { InventorySystem } = await import('/src/systems/InventorySystem.js');
  BR.store.update((s) => { s.cash = 30000; s.level = 8; s.settings.fastReveal = true; s.settings.volume = 0.33; });
  const entry = BreakSystem.purchase('BOX-NBA-PRIZM-25');
  BreakSystem.breakSeal(entry.id);
  for (let i = 0; i < 4; i += 1) BreakSystem.openPack(entry.id, i);
  const sealed = BreakSystem.purchase('BOX-NFL-OPTIC-25');
  const picks = InventorySystem.gradable().slice(0, 3).map((c) => c.uid);
  GradingSystem.submit(picks, 'express');
  BR.systems.SaveSystem.save();
  const s = BR.state();
  return {
    cash: Math.round(s.cash), level: s.level, cards: s.collection.length,
    vault: s.vault.length, sealedUnopened: s.vault.filter((v) => !v.opened).length,
    openPacks: s.vault.find((v) => v.opened)?.packs.filter((p) => p.opened).length ?? 0,
    submissions: s.submissions.length, subCards: s.submissions[0]?.cardUids.length ?? 0,
    ledger: s.ledger.length, packsOpened: s.stats.packsOpened, cardsPulled: s.stats.cardsPulled,
    marketTick: s.market.tick, fastReveal: s.settings.fastReveal, volume: s.settings.volume,
    topCard: s.collection.map((c) => c.uid).sort().join('').length,
    sealedId: sealed.id,
  };
});

await page.reload({ waitUntil: 'networkidle' });
await page.waitForTimeout(1800);

const after = await page.evaluate(() => {
  const s = window.BreakRoom.state();
  return {
    cash: Math.round(s.cash), level: s.level, cards: s.collection.length,
    vault: s.vault.length, sealedUnopened: s.vault.filter((v) => !v.opened).length,
    openPacks: s.vault.find((v) => v.opened)?.packs.filter((p) => p.opened).length ?? 0,
    submissions: s.submissions.length, subCards: s.submissions[0]?.cardUids.length ?? 0,
    ledger: s.ledger.length, packsOpened: s.stats.packsOpened, cardsPulled: s.stats.cardsPulled,
    marketTick: s.market.tick, fastReveal: s.settings.fastReveal, volume: s.settings.volume,
    topCard: s.collection.map((c) => c.uid).sort().join('').length,
    sealedId: s.vault.find((v) => !v.opened)?.id,
  };
});

let fails = 0;
const skip = new Set(['marketTick']); // ticks forward on load by design
for (const key of Object.keys(before)) {
  const ok = skip.has(key) ? after[key] >= before[key] : JSON.stringify(before[key]) === JSON.stringify(after[key]);
  if (!ok) fails += 1;
  console.log(`${ok ? 'ok  ' : 'FAIL'}  ${key.padEnd(16)} before=${JSON.stringify(before[key])}  after=${JSON.stringify(after[key])}`);
}

// The reloaded session must still be able to open the sealed box it kept.
const canResume = await page.evaluate(async () => {
  const { BreakSystem } = await import('/src/systems/BreakSystem.js');
  const next = BreakSystem.next();
  if (!next) return false;
  const cards = BreakSystem.openPack(next.id, next.packs.findIndex((p) => !p.opened));
  return Array.isArray(cards) && cards.length > 0;
});
console.log(`${canResume ? 'ok  ' : 'FAIL'}  resume opening a restored box`);
if (!canResume) fails += 1;

if (errors.length) console.error('\nERRORS:\n' + [...new Set(errors)].slice(0, 8).join('\n'));
console.log(`\n${fails === 0 && errors.length === 0 ? 'PASS' : 'FAIL'} - ${fails} mismatch(es), ${errors.length} console error(s)`);
await browser.close();
process.exit(fails || errors.length ? 1 : 0);
