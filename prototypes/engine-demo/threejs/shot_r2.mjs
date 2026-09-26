// PROTOTYPE — round 2 captures from Windows Chrome (real GPU) over CDP. SHOTS=a,b to limit; PERF=1 to measure (off by default).
import { chromium } from 'playwright-core';
import { writeFileSync, readFileSync } from 'node:fs';
const layout = JSON.parse(readFileSync('../assets/models_r2/layout_r2.json', 'utf8'));
const all = Object.keys(layout.shots);
const list = process.env.SHOTS ? process.env.SHOTS.split(',') : all;
const browser = await chromium.connectOverCDP('http://127.0.0.1:9222');
const ctx = browser.contexts()[0] ?? await browser.newContext();
const perf = {};
for (const name of list) {
  const page = await ctx.newPage();
  const logs = [];
  page.on('console', (m) => { if (m.type() === 'error' || m.type() === 'warning') logs.push(`[${m.type()}] ${m.text()}`.slice(0, 400)); });
  page.on('pageerror', (e) => logs.push(`[pageerror] ${e.message}`));
  await page.setViewportSize({ width: 1920, height: 1080 });
  const url = name === 'dashboard' ? 'http://127.0.0.1:5173/dashboard.html?capture=1' : `http://127.0.0.1:5173/r2.html?shot=${name}&capture=1${process.env.Q ? '&' + process.env.Q : ''}`;
  const t0 = Date.now();
  try {
    await page.goto(url, { timeout: 60000 });
    await page.waitForFunction(() => window.demoReady === true, null, { timeout: 240000 });
    if (name !== 'dashboard') await page.evaluate(async () => { await window.demo.frames(Number(new URLSearchParams(location.search).get('settle') ?? 150)); });
    else await page.waitForTimeout(800);
    await page.screenshot({ path: `../shots/r2/${process.env.TAG ? 'wip_' + process.env.TAG + '_' : 'threejs_'}${name}.png` });
    if (process.env.PERF && name !== 'dashboard') perf[name] = await page.evaluate(() => window.demo.measure(5));
    console.log(`${name}: ok in ${((Date.now() - t0) / 1000).toFixed(1)} s ${perf[name] ? JSON.stringify(perf[name]) : ''}`);
  } catch (e) {
    console.log(`${name}: FAILED ${e.message.split('\n')[0]}`);
  }
  const uniq = [...new Set(logs)].filter((l) => !l.includes('powerPreference'));
  if (uniq.length) console.log('  ' + uniq.slice(0, 12).join('\n  '));
  await page.close();
}
if (process.env.PERF) writeFileSync('../shots/r2/threejs_perf.json', JSON.stringify(perf, null, 2));
await browser.close();
