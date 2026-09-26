// PROTOTYPE — round 2 entry: ?shot=<name> or ?scene=vineyard|cellar|hall[&preset=…]; &capture=1 for 1920×1080 captures.
import * as THREE from 'three/webgpu';
import { params, CAPTURE, json, fpsControls, lookFrom } from './common.js';

const W = CAPTURE ? 1920 : innerWidth, H = CAPTURE ? 1080 : innerHeight;
const hud = document.getElementById('hud');
if (CAPTURE) { document.getElementById('help').remove(); document.getElementById('scenes').remove(); }

const renderer = new THREE.WebGPURenderer({ antialias: false, powerPreference: 'high-performance' });
renderer.setPixelRatio(1);
renderer.setSize(W, H);
renderer.shadowMap.enabled = true;
renderer.shadowMap.type = THREE.PCFShadowMap;
document.body.appendChild(renderer.domElement);
await renderer.init();

const layout = await json('/models_r2/layout_r2.json');
const shotName = params.get('shot');
const shot = shotName ? layout.shots[shotName] : null;
const sceneName = shot?.scene ?? params.get('scene') ?? 'cellar';
const mod = await import(`./${sceneName}.js`);
const S = await mod.build({ renderer, layout, shot, shotName, preset: shot?.preset ?? params.get('preset') });

function setShot(name) {
  const s = layout.shots[name];
  if (S.setShot) return S.setShot(name, s);
  const cam = S.shots[name];
  if (cam) lookFrom(S.camera, cam.position, cam.target);
  controls.sync();
}
const controls = fpsControls(S.camera, renderer.domElement, { ground: S.ground ?? null, eye: S.eye ?? 1.7, bounds: S.bounds ?? null });
if (shotName) setShot(shotName);

const shotKeys = Object.keys(S.shots ?? {});
let showFps = !CAPTURE && params.has('fps');
addEventListener('keydown', (e) => {
  const n = parseInt(e.key, 10);
  if (n >= 1 && n <= shotKeys.length) setShot(shotKeys[n - 1]);
  if (e.code === 'KeyF') showFps = !showFps;
  S.onKey?.(e.code);
});
addEventListener('resize', () => {
  if (CAPTURE) return;
  renderer.setSize(innerWidth, innerHeight); S.camera.aspect = innerWidth / innerHeight; S.camera.updateProjectionMatrix();
});

let last = performance.now(), t = 0;
const frameTimes = []; let waiters = [];
renderer.setAnimationLoop(() => {
  const now = performance.now(), dt = Math.min(0.1, (now - last) / 1000);
  frameTimes.push(now - last); if (frameTimes.length > 4000) frameTimes.shift();
  last = now; t += dt;
  if (controls.update(dt)) S.onMove?.();
  S.update?.(dt, t);
  S.pipeline.render();
  if (showFps && frameTimes.length % 15 === 0) {
    const r = frameTimes.slice(-60), a = r.reduce((x, y) => x + y, 0) / r.length;
    hud.textContent = `${(1000 / a).toFixed(0)} fps  ${a.toFixed(1)} ms  ${S.hud?.() ?? ''}`;
  } else if (!showFps) hud.textContent = '';
  waiters = waiters.filter((w) => --w.n > 0 || (w.resolve(), false));
});

window.demo = {
  shots: shotKeys, setShot,
  frames: (n) => new Promise((resolve) => waiters.push({ n, resolve })),
  async measure(seconds) {
    const start = frameTimes.length; await new Promise((r) => setTimeout(r, seconds * 1000));
    const ft = frameTimes.slice(start).sort((a, b) => a - b);
    const avg = ft.reduce((a, b) => a + b, 0) / ft.length;
    return { avgFps: +(1000 / avg).toFixed(1), low1Fps: +(1000 / ft[Math.floor(ft.length * 0.99)]).toFixed(1), frames: ft.length };
  },
  scene: S,
};
window.demoReady = true;
