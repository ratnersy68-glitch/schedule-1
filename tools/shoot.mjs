#!/usr/bin/env node
/** Visual QA: screenshots a page (or an asset contact sheet) for review. */
import { chromium } from 'playwright';
import { mkdirSync } from 'node:fs';

const [, , url, out, w = '1600', h = '1000', wait = '600'] = process.argv;
mkdirSync(out.replace(/\/[^/]+$/, ''), { recursive: true });
const browser = await chromium.launch({ executablePath: '/opt/pw-browsers/chromium-1194/chrome-linux/chrome' });
const page = await browser.newPage({ viewport: { width: Number(w), height: Number(h) }, deviceScaleFactor: 1 });
const errors = [];
page.on('console', (m) => { if (m.type() === 'error') errors.push(m.text()); });
page.on('pageerror', (e) => errors.push(String(e)));
await page.goto(url, { waitUntil: 'networkidle' });
await page.waitForTimeout(Number(wait));
await page.screenshot({ path: out, fullPage: false });
if (errors.length) console.error('PAGE ERRORS:\n' + errors.slice(0, 12).join('\n'));
await browser.close();
console.log('shot ->', out);
