import { assert, BASE, launch, onboard, SEED } from './lib.mjs';

const { browser, page, errors, shot } = await launch();

console.log('— onboarding');
await onboard(page, { days: 3 });

console.log('— open the builder');
await page.getByText('Edit split').click();
await page.waitForURL('**/builder');
await page.waitForTimeout(300);
await shot('30-builder');
const dayNames = await page.locator('a[href^="/builder/day/"]').allInnerTexts();
console.log('  days:', JSON.stringify(dayNames.map((d) => d.split('\n')[0])));

console.log('— reorder days by dragging');
const handles = page.locator('button[aria-label^="Reorder"]');
const first = await handles.first().boundingBox();
await page.mouse.move(first.x + first.width / 2, first.y + first.height / 2);
await page.mouse.down();
for (let i = 1; i <= 8; i++) await page.mouse.move(first.x + first.width / 2, first.y + first.height / 2 + i * 14);
await page.mouse.up();
await page.waitForTimeout(400);
const afterDrag = (await page.locator('a[href^="/builder/day/"]').allInnerTexts()).map((d) => d.split('\n')[0]);
console.log('  after drag:', JSON.stringify(afterDrag));
assert(afterDrag[0] === 'Pull Day' && afterDrag[1] === 'Push Day', 'dragging reorders the split days');

console.log('— edit a day');
await page.getByRole('link', { name: /Push Day/ }).click();
await page.waitForURL('**/builder/day/**');
await page.waitForTimeout(300);
await page.locator('#day-name').fill('Chest & Triceps');
await page.locator('#day-name').blur();
await page.waitForTimeout(200);
await page.getByRole('button', { name: 'Wednesday' }).click();
await page.waitForTimeout(200);
await shot('31-day-editor');

console.log('— add a catalog exercise');
await page.getByRole('button', { name: /^Add exercise$/ }).click();
await page.waitForTimeout(300);
await page.getByPlaceholder('Search or type a new exercise').fill('pec');
await page.waitForTimeout(250);
await shot('32-picker');
await page.getByRole('button', { name: 'Pec Deck' }).click();
await page.waitForTimeout(300);
let list = await page.locator('button:has(span.label-caps), li').allInnerTexts();
assert((await page.getByText('Pec Deck').count()) > 0, 'catalog exercise added to the day');

console.log('— create a custom exercise');
await page.getByRole('button', { name: /^Add exercise$/ }).click();
await page.waitForTimeout(300);
await page.getByPlaceholder('Search or type a new exercise').fill('Landmine Press');
await page.waitForTimeout(250);
await page.getByRole('button', { name: 'Add custom exercise' }).click();
await page.waitForTimeout(350);
assert((await page.getByText('Landmine Press').count()) > 0, 'custom exercise created and added');
await shot('33-day-with-custom');

console.log('— edit sets, reps and notes');
await page.getByText('Landmine Press').click();
await page.waitForTimeout(300);
await page.getByLabel('Increase Target sets').click();
await page.getByLabel('Max reps', { exact: true }).fill('15');
await page.getByLabel('Max reps', { exact: true }).blur();
await page.locator('#ex-notes').fill('Left side first');
await page.waitForTimeout(200);
await shot('34-edit-exercise');
await page.getByRole('button', { name: 'Done' }).click();
await page.waitForTimeout(300);
const rowText = await page.locator('button', { hasText: 'Landmine Press' }).first().innerText();
console.log('  row:', JSON.stringify(rowText.replace(/\n/g, ' ')));
assert(/4 sets/.test(rowText) && /15 reps/.test(rowText) && /Left side first/.test(rowText), 'exercise edits saved');

console.log('— reorder exercises');
const exHandles = page.locator('button[aria-label="Reorder exercise"]');
const before = (await page.locator('button:has-text("Bench Press")').first().innerText()).trim();
const h = await exHandles.first().boundingBox();
await page.mouse.move(h.x + h.width / 2, h.y + h.height / 2);
await page.mouse.down();
for (let i = 1; i <= 10; i++) await page.mouse.move(h.x + h.width / 2, h.y + h.height / 2 + i * 12);
await page.mouse.up();
await page.waitForTimeout(400);
const order = (await page.locator('a[href^="/builder/day/"], li').allInnerTexts()).slice(0, 3);
console.log('  first rows now:', JSON.stringify(order.map((t) => t.split('\n')[1])));
assert(!order[0].includes('Bench Press'), 'dragging reorders exercises within a day');
await shot('35-reordered');

console.log('— delete an exercise');
await page.getByText('Pec Deck').click();
await page.waitForTimeout(300);
await page.getByRole('button', { name: /Remove exercise/ }).click();
await page.waitForTimeout(300);
assert((await page.getByText('Pec Deck').count()) === 0, 'exercise removed from the day');

console.log('— resume an unfinished workout after a reload');
await page.goto(BASE + '/workout');
await page.waitForTimeout(250);
await page.getByText('Chest & Triceps', { exact: true }).click();
await page.waitForTimeout(350);
await page.getByLabel('Weight', { exact: true }).fill('95');
await page.getByLabel('Reps', { exact: true }).fill('12');
await page.getByRole('button', { name: /COMPLETE SET/ }).click();
await page.waitForTimeout(300);
await page.goto(BASE + '/');
await page.waitForTimeout(300);
assert((await page.getByText('WORKOUT IN PROGRESS').count()) > 0, 'home shows the workout in progress');
await shot('36-home-in-progress');
await page.reload();
await page.waitForTimeout(500);
await page.getByRole('button', { name: /RESUME WORKOUT/ }).click();
await page.waitForTimeout(400);
const resumed = await page.locator('body').innerText();
assert(/95\s*lb\s*×\s*12/.test(resumed.replace(/\n/g, ' ')), 'the logged set survived a full reload');
await shot('37-resumed');

console.log('ERRORS:', errors);
await browser.close();
