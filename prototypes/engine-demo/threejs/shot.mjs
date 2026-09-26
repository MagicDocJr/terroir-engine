// PROTOTYPE — captures the 5 presets + perf from Windows Chrome (real GPU) over CDP.
import { chromium } from 'playwright-core';
import { writeFileSync } from 'node:fs';
const browser = await chromium.connectOverCDP('http://127.0.0.1:9222');
const ctx = browser.contexts()[0] ?? await browser.newContext();
const page = await ctx.newPage();
const logs = [];
page.on('console', (m) => logs.push(`[${m.type()}] ${m.text()}`));
page.on('pageerror', (e) => logs.push(`[pageerror] ${e.message}`));
await page.setViewportSize({ width: 1920, height: 1080 });
await page.goto('http://127.0.0.1:5173/?shot=1' + (process.argv[2] ? '&' + process.argv[2] : ''));
try { await page.waitForFunction(() => window.demoReady === true, null, { timeout: 180000 }); }
catch (e) { console.log(logs.join('\n')); throw e; }
const only = process.env.PRESETS?.split(',');
const perf = { info: await page.evaluate(() => window.demo.info()) };
for (const p of (only ?? await page.evaluate(() => window.demo.presets))) {
  await page.evaluate(async (p) => { window.demo.setPreset(p); await window.demo.frames(90); }, p);
  await page.locator('canvas').screenshot({ path: `../shots/threejs_${p}.png` });
  if (!process.env.NOPERF) perf[p] = await page.evaluate(() => window.demo.measure(5));
  console.log(p, JSON.stringify(perf[p] ?? {}));
}
perf.drawInfo = await page.evaluate(() => window.demo.info());
if (!process.env.NOPERF) writeFileSync('../shots/threejs_perf.json', JSON.stringify(perf, null, 2));
console.log(logs.filter((l) => !l.includes('[debug]')).slice(0, 30).join('\n'));
await page.close();
await browser.close();
