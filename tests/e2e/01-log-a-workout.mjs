import { assert, BASE, launch, onboard, SEED } from './lib.mjs';

const { browser, page, errors, shot } = await launch();

console.log('— onboarding (3 days, PPL)');
await onboard(page, { days: 3 });
assert((await page.getByText('3 training days').count()) > 0, 'split has the 3 days the user chose');

console.log('— start today\'s workout');
await page.getByRole('button', { name: /START WORKOUT/ }).click();
await page.waitForURL('**/workout');
await page.waitForTimeout(300);
await shot('10-workout-start');

const weight = page.getByLabel('Weight', { exact: true });
const reps = page.getByLabel('Reps', { exact: true });
assert((await weight.inputValue()) === '0', 'first-ever set starts at 0 weight (no history)');
assert(await page.getByText('First time logging this — set the baseline.').isVisible(), 'shows first-time hint');

console.log('— log set 1');
await weight.fill('135');
await reps.fill('10');
await page.getByRole('button', { name: /COMPLETE SET/ }).click();
await page.waitForTimeout(300);
await shot('11-workout-set1');

assert(await page.locator('text=PR').first().isVisible(), 'first set is flagged as a PR');
assert(await page.getByText('NEW PR').isVisible(), 'NEW PR banner shown');
assert(await page.getByText('Rest', { exact: true }).isVisible(), 'rest timer started automatically');

console.log('— log sets 2 and 3');
assert((await weight.inputValue()) === '135', 'next set pre-filled with the same weight');
await reps.fill('9');
await page.getByRole('button', { name: /COMPLETE SET/ }).click();
await page.waitForTimeout(200);
await reps.fill('8');
await page.getByRole('button', { name: /COMPLETE SET/ }).click();
await page.waitForTimeout(800);
await shot('12-workout-advanced');

const heading = await page.locator('h1').first().innerText();
console.log('  workout heading:', heading);
const currentExercise = await page.locator('a[href^="/progress/exercise/"]').first().innerText();
console.log('  auto-advanced to:', currentExercise);
assert(currentExercise !== 'Bench Press', 'auto-advances to the next exercise when the last set is done');

console.log('— log remaining exercises quickly');
for (let i = 0; i < 4; i++) {
  for (let s = 0; s < 3; s++) {
    const btn = page.getByRole('button', { name: /COMPLETE SET/ });
    if (!(await btn.isVisible().catch(() => false))) break;
    await weight.fill(String(50 + i * 10));
    await reps.fill('10');
    await btn.click();
    await page.waitForTimeout(120);
  }
  await page.waitForTimeout(400);
}
await shot('13-workout-late');

console.log('— finish workout');
await page.getByRole('button', { name: 'FINISH' }).click();
await page.waitForTimeout(300);
await shot('14-finish-sheet');
await page.getByRole('button', { name: 'SAVE WORKOUT' }).click();
await page.waitForTimeout(400);
console.log('  url:', page.url());
assert(page.url().includes('/history/'), 'saving a workout opens its record');
await shot('15-session-detail');

console.log('— history list');
await page.goto(BASE + '/history');
await page.waitForTimeout(300);
await shot('16-history');
assert(await page.getByText('1 completed workout').isVisible(), 'history counts the workout');

console.log('ERRORS:', errors);
await browser.close();
