import { assert, BASE, launch, onboard, SEED } from './lib.mjs';


const { browser, page, errors, shot } = await launch();
await onboard(page, { days: 3 });
await page.goto(BASE + '/settings');
await page.waitForTimeout(250);
await page.setInputFiles('input[type=file]', SEED);
await page.waitForTimeout(600);
const msg = await page.locator('body').innerText();
assert(/Imported 24 workouts/.test(msg), 'seed data imported');

await page.goto(BASE + '/');
await page.waitForTimeout(500);
await shot('50-home-full');
const home = (await page.locator('body').innerText()).replace(/\n/g, ' | ');
console.log('home:', home.slice(0, 420));

await page.goto(BASE + '/history');
await page.waitForTimeout(400);
await shot('51-history-full');
await page.locator('a[href^="/history/"]').first().click();
await page.waitForTimeout(400);
await shot('52-session-full');

await page.goto(BASE + '/progress');
await page.waitForTimeout(400);
await shot('53-progress-full');
await page.getByRole('button', { name: 'Est. 1RM' }).click();
await page.waitForTimeout(300);
await page.locator('svg[role="img"]').scrollIntoViewIfNeeded();
await shot('54-progress-chart');

await page.goto(BASE + '/records');
await page.waitForTimeout(400);
await shot('55-records-full');

await page.goto(BASE + '/progress/exercise/squat');
await page.waitForTimeout(400);
await shot('56-exercise-full');
const detail = (await page.locator('body').innerText()).replace(/\n/g, ' | ');
console.log('squat detail:', detail.slice(0, 300));

// tablet / desktop width sanity check
await page.setViewportSize({ width: 820, height: 1180 });
await page.goto(BASE + '/');
await page.waitForTimeout(400);
await shot('57-wide-home');

// small phone
await page.setViewportSize({ width: 320, height: 568 });
await page.goto(BASE + '/workout');
await page.waitForTimeout(300);
await page.getByText('Push Day', { exact: true }).click();
await page.waitForTimeout(400);
await shot('58-small-phone');
const overflow = await page.evaluate(() => document.documentElement.scrollWidth > window.innerWidth + 1);
assert(!overflow, 'no horizontal overflow on a 320px phone');

console.log('ERRORS:', errors);
await browser.close();
