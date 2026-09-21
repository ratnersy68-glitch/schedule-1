import { chromium } from 'playwright';
import { mkdirSync } from 'node:fs';
import { dirname, resolve } from 'node:path';
import { fileURLToPath } from 'node:url';

const here = dirname(fileURLToPath(import.meta.url));

export const BASE = process.env.FORGE_BASE_URL ?? 'http://127.0.0.1:4173';
export const OUT = process.env.FORGE_SHOTS ?? resolve(here, '../../.screenshots');
export const SEED = resolve(here, 'seed.json');

export async function launch() {
  mkdirSync(OUT, { recursive: true });
  const browser = await chromium.launch(
    process.env.FORGE_CHROME ? { executablePath: process.env.FORGE_CHROME } : {}
  );
  const ctx = await browser.newContext({
    viewport: { width: 390, height: 844 },
    deviceScaleFactor: 2,
    isMobile: true,
    hasTouch: true,
    acceptDownloads: true,
  });
  const page = await ctx.newPage();
  const errors = [];
  page.on('console', (m) => {
    if (m.type() === 'error') errors.push(m.text());
  });
  page.on('pageerror', (e) => errors.push('PAGEERROR: ' + e.message));
  const shot = async (name) => {
    await page.screenshot({ path: `${OUT}/${name}.png` });
  };
  return { browser, ctx, page, errors, shot };
}

export function assert(cond, msg) {
  if (!cond) throw new Error('ASSERT FAILED: ' + msg);
  console.log('  ✓ ' + msg);
}

export async function onboard(page, { days = 3, template = 'Push / Pull / Legs' } = {}) {
  await page.goto(BASE);
  await page.waitForURL('**/setup');
  await page.locator('button').filter({ hasText: new RegExp(`^${days}\\s*DAYS?$`, 'i') }).first().click();
  await page.getByRole('button', { name: 'CONTINUE' }).click();
  await page.getByText(template, { exact: true }).click();
  await page.getByRole('button', { name: 'CONTINUE' }).click();
  await page.getByRole('button', { name: 'START TRAINING' }).click();
  await page.waitForURL(BASE + '/');
  await page.getByText('QUICK ACTIONS').waitFor();
}
