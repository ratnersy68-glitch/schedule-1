import { chromium } from 'playwright';
const b = await chromium.launch({ executablePath: '/opt/pw-browsers/chromium-1194/chrome-linux/chrome' });
const p = await b.newPage({ viewport: { width: 1500, height: 950 } });
const errors = [];
p.on('pageerror', (e) => errors.push(String(e)));
p.on('console', (m) => { if (m.type() === 'error') errors.push(m.text()); });
// Opened straight off disk with no server at all: if anything is still external,
// it cannot possibly load and the test will show it.
const target = process.argv[2] || 'file:///home/user/schedule-1/dist/breakroom.html';
await p.route('**/*', (route) => (route.request().url().startsWith('file://') ? route.continue() : route.abort()));
await p.goto(target, { waitUntil: 'domcontentloaded' });
await p.waitForTimeout(3000);
const state = await p.evaluate(() => ({
  booted: !document.getElementById('boot'),
  rail: document.querySelectorAll('.nav-item').length,
  boxes: window.BreakRoom ? window.BreakRoom.systems.Data.boxes.length : 0,
  assets: window.BreakRoom ? window.BreakRoom.systems.Assets.manifest.assets.length : 0,
  font: getComputedStyle(document.querySelector('.brand-name')).fontFamily,
}));
console.log('boot:', JSON.stringify(state));
await p.screenshot({ path: '/tmp/claude-0/-home-user-schedule-1/83c186ab-b15f-5930-b54c-de3439e08a7a/scratchpad/shots/bundle-home.png' });

// Full loop inside the bundle.
await p.click('text=Hobby Shop'); await p.waitForTimeout(1200);
await p.locator('.box-card:not(.is-locked) .btn-gold').first().click(); await p.waitForTimeout(700);
await p.click('text=Buy and break it'); await p.waitForTimeout(1600);
await p.screenshot({ path: '/tmp/claude-0/-home-user-schedule-1/83c186ab-b15f-5930-b54c-de3439e08a7a/scratchpad/shots/bundle-sealed.png' });
await p.click('.sealed-box'); await p.waitForTimeout(2400);
await p.click('.pack:not(.is-opened)'); await p.waitForTimeout(2200);
await p.screenshot({ path: '/tmp/claude-0/-home-user-schedule-1/83c186ab-b15f-5930-b54c-de3439e08a7a/scratchpad/shots/bundle-reveal.png' });
const skip = p.locator('button:has-text("Reveal the rest")');
if (await skip.count()) { await skip.click(); await p.waitForTimeout(2600); }
await p.click('text=Collection'); await p.waitForTimeout(2000);
await p.screenshot({ path: '/tmp/claude-0/-home-user-schedule-1/83c186ab-b15f-5930-b54c-de3439e08a7a/scratchpad/shots/bundle-collection.png' });
for (const nav of ['Marketplace', 'Grading', 'Ledger', 'Clubhouse']) { await p.click(`text=${nav}`); await p.waitForTimeout(1100); }
const after = await p.evaluate(() => ({ cards: window.BreakRoom.state().collection.length, cash: Math.round(window.BreakRoom.state().cash) }));
console.log('after loop:', JSON.stringify(after));
console.log(errors.length ? 'ERRORS:\n' + [...new Set(errors)].slice(0, 10).join('\n') : 'no page errors');
await b.close();
