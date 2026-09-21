import { assert, BASE, launch, onboard, SEED } from './lib.mjs';

const { browser, page, errors, shot } = await launch();

console.log('— onboarding');
await onboard(page, { days: 3 });

console.log('— set a 5 second rest timer and watch it finish');
await page.goto(BASE + '/settings');
await page.waitForTimeout(300);
await page.locator('#custom-rest').fill('5');
await page.getByRole('button', { name: 'Set', exact: true }).click();
await page.waitForTimeout(200);
await shot('40-settings');

await page.goto(BASE + '/workout');
await page.waitForTimeout(250);
await page.getByText('Push Day', { exact: true }).click();
await page.waitForTimeout(350);
await page.getByLabel('Weight', { exact: true }).fill('100');
await page.getByRole('button', { name: /COMPLETE SET/ }).click();
await page.waitForTimeout(600);
assert((await page.getByText('REST', { exact: false }).count()) > 0, 'rest timer runs after a set');
await page.waitForTimeout(5200);
await shot('41-rest-complete');
assert((await page.getByText('REST COMPLETE — GO').count()) > 0, 'timer finish is clearly announced');
await page.getByText('REST COMPLETE — GO').click();
await page.waitForTimeout(300);
assert((await page.getByText('REST COMPLETE — GO').count()) === 0, 'the finish banner can be dismissed');

console.log('— rest presets are one tap away during a workout');
await page.getByRole('button', { name: '2m' }).click();
await page.waitForTimeout(300);
assert((await page.locator('text=2:00').count()) > 0, 'preset starts a 2 minute rest');

console.log('— discard the workout');
await page.getByRole('button', { name: 'FINISH' }).click();
await page.waitForTimeout(250);
await page.getByRole('button', { name: 'Discard workout' }).click();
await page.waitForTimeout(400);
assert(page.url() === BASE + '/', 'discarding returns home');

console.log('— a day that is not today shows the next workout');
await page.goto(BASE + '/builder');
await page.waitForTimeout(300);
for (const name of ['Push Day', 'Pull Day', 'Leg Day']) {
  await page.getByRole('link', { name: new RegExp(name) }).click();
  await page.waitForURL('**/builder/day/**');
  await page.waitForTimeout(250);
  const active = page.locator('button[aria-label]:not([aria-label*=" "])');
  // unschedule whatever day is set, then pin everything to Saturday
  await page.getByRole('button', { name: 'Saturday' }).click();
  await page.waitForTimeout(150);
  const sub = await page.locator('header p').innerText();
  if (sub !== 'Sat') await page.getByRole('button', { name: 'Saturday' }).click();
  await page.waitForTimeout(150);
  void active;
  await page.goto(BASE + '/builder');
  await page.waitForTimeout(250);
}
await page.goto(BASE + '/');
await page.waitForTimeout(400);
await shot('42-next-workout');
const home = await page.locator('body').innerText();
console.log('  home says:', home.split('\n').slice(3, 9).join(' | '));
assert(/NEXT WORKOUT/.test(home), 'home shows the next scheduled workout on a rest day');
assert(/Not a scheduled day/.test(home), 'home explains that starting early is fine');

console.log('— freestyle workout');
await page.goto(BASE + '/workout');
await page.waitForTimeout(250);
await page.getByRole('button', { name: /Freestyle workout/ }).click();
await page.waitForTimeout(350);
assert((await page.getByText('Empty workout').count()) > 0, 'freestyle starts empty');
await page.getByRole('button', { name: /^Add exercise$/ }).click();
await page.waitForTimeout(300);
await page.getByPlaceholder('Search or type a new exercise').fill('squat');
await page.waitForTimeout(250);
await page.getByRole('button', { name: 'Squat', exact: true }).click();
await page.waitForTimeout(350);
await shot('43-freestyle');
assert((await page.getByRole('button', { name: /COMPLETE SET/ }).count()) === 1, 'exercise added mid-workout is loggable');

console.log('— kilograms');
await page.goto(BASE + '/settings');
await page.waitForTimeout(250);
await page.getByRole('button', { name: 'kg', exact: true }).click();
await page.goto(BASE + '/workout');
await page.waitForTimeout(350);
const unitText = await page.locator('body').innerText();
assert(/kg/.test(unitText), 'unit switch reaches the workout screen');

console.log('— service worker + manifest');
const swState = await page.evaluate(async () => {
  const reg = await navigator.serviceWorker.getRegistration();
  return { registered: Boolean(reg), scope: reg?.scope ?? null };
});
console.log('  sw:', JSON.stringify(swState));
assert(swState.registered, 'service worker registered for offline use');
const manifest = await page.evaluate(async () => {
  const res = await fetch('/manifest.webmanifest');
  return res.ok ? await res.json() : null;
});
assert(manifest && manifest.name === 'Forge Training Log', 'web app manifest is served');
assert(manifest.icons.length === 3, 'manifest ships install icons');

console.log('ERRORS:', errors);
await browser.close();
