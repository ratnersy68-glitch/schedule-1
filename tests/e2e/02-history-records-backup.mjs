import { readFileSync } from 'node:fs';
import { assert, BASE, launch, onboard, SEED } from './lib.mjs';

const { browser, page, errors, shot } = await launch();
const weight = page.getByLabel('Weight', { exact: true });
const reps = page.getByLabel('Reps', { exact: true });
const completeBtn = page.getByRole('button', { name: /COMPLETE SET/ });

async function logBench(w, repList) {
  await page.goto(BASE + '/workout');
  await page.waitForTimeout(250);
  await page.getByText('Push Day', { exact: true }).click();
  await page.waitForTimeout(350);
  const shown = await page.locator('a[href^="/progress/exercise/"]').first().innerText();
  assert(shown === 'Bench Press', 'workout opens on the first exercise');
  const lastTime = await page.locator('text=LAST TIME').locator('..').innerText();
  console.log('  last time block:', JSON.stringify(lastTime.replace(/\n/g, ' ')));
  const prefill = await weight.inputValue();
  for (const r of repList) {
    await weight.fill(String(w));
    await reps.fill(String(r));
    await completeBtn.click();
    await page.waitForTimeout(180);
  }
  await page.waitForTimeout(400);
  await page.getByRole('button', { name: 'FINISH' }).click();
  await page.waitForTimeout(250);
  await page.getByRole('button', { name: 'SAVE WORKOUT' }).click();
  await page.waitForTimeout(400);
  return { prefill, lastTime };
}

console.log('— onboarding');
await onboard(page, { days: 3 });

console.log('— workout 1: bench 135');
const w1 = await logBench(135, [10, 9, 8]);
assert(w1.prefill === '0', 'no prefill before any history exists');

console.log('— workout 2: bench 140 (should prefill 135 and set a PR)');
const w2 = await logBench(140, [10, 9]);
assert(w2.prefill === '135', 'weight pre-filled from the previous workout');
assert(/135 × 10/.test(w2.lastTime), 'previous sets are shown before training');

console.log('— history');
await page.goto(BASE + '/history');
await page.waitForTimeout(300);
assert((await page.getByText('2 completed workouts').count()) > 0, 'both workouts are in history');
await shot('20-history-two');

console.log('— records');
await page.goto(BASE + '/records');
await page.waitForTimeout(300);
const recordText = await page.locator('body').innerText();
assert(/140 lb × 10/.test(recordText), 'personal record updated to the heavier lift');
await shot('21-records');

console.log('— progress + chart');
await page.goto(BASE + '/progress');
await page.waitForTimeout(300);
assert((await page.locator('svg[role="img"]').count()) === 1, 'progression chart rendered');
await shot('22-progress');
await page.getByRole('button', { name: 'Est. 1RM' }).click();
await page.waitForTimeout(200);
await page.getByRole('button', { name: 'Volume' }).click();
await page.waitForTimeout(200);
await shot('23-progress-volume');
assert((await page.locator('svg[role="img"]').count()) === 1, 'chart survives metric switching');

console.log('— exercise detail');
await page.getByRole('link', { name: 'View full history' }).click();
await page.waitForTimeout(350);
const detail = await page.locator('body').innerText();
assert(/HEAVIEST/i.test(detail) && /140 lb/.test(detail), 'exercise detail shows records');
assert((detail.match(/SET 1/g) || []).length === 2, 'both sessions listed in exercise history');
await shot('24-exercise-detail');

console.log('— export');
await page.goto(BASE + '/settings');
await page.waitForTimeout(250);
const [download] = await Promise.all([
  page.waitForEvent('download'),
  page.getByRole('button', { name: /Export data/ }).click(),
]);
const path = await download.path();
const backup = JSON.parse(readFileSync(path, 'utf8'));
assert(download.suggestedFilename().startsWith('forge-workout-backup-'), 'backup file is named for Forge');
assert(backup.data.history.length === 2, 'backup contains both workouts');
console.log('  backup file:', download.suggestedFilename(), Object.keys(backup).join(','));

console.log('— erase, then import the backup');
await page.getByRole('button', { name: /Erase all data/ }).click();
await page.waitForTimeout(250);
await page.getByRole('button', { name: 'Erase', exact: true }).click();
await page.waitForURL('**/setup');
assert(page.url().includes('/setup'), 'erasing returns to setup');

await onboard(page, { days: 2, template: 'Upper / Lower' });
await page.goto(BASE + '/settings');
await page.waitForTimeout(250);
await page.setInputFiles('input[type=file]', path);
await page.waitForTimeout(400);
await shot('25-imported');
const settingsText = await page.locator('body').innerText();
assert(/Imported 2 workouts/.test(settingsText), 'import reports what it restored');

await page.goto(BASE + '/history');
await page.waitForTimeout(300);
assert((await page.getByText('2 completed workouts').count()) > 0, 'imported history is back');

console.log('— reload persistence');
await page.reload();
await page.waitForTimeout(500);
assert((await page.getByText('2 completed workouts').count()) > 0, 'data survives a refresh');

console.log('ERRORS:', errors);
await browser.close();
