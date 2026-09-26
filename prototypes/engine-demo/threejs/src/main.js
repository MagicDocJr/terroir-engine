// PROTOTYPE — throwaway Three.js (WebGPU) half of the engine demo. See ../README.md for the shared spec.
import * as THREE from 'three/webgpu';
import {
  pass, mrt, output, normalView, vec3, vec4, float, mix, texture, uv, vertexColor, uniform,
  attribute, positionWorld, cameraPosition, normalize, dot, max, pow, time, sin, smoothstep,
  normalMap, luminance, clamp, renderOutput, positionLocal, reflector, vec2, screenUV,
} from 'three/tsl';
import { ao } from 'three/addons/tsl/display/GTAONode.js';
import { bloom } from 'three/addons/tsl/display/BloomNode.js';
import { smaa } from 'three/addons/tsl/display/SMAANode.js';
import { CSMShadowNode } from 'three/addons/csm/CSMShadowNode.js';
import { GLTFLoader } from 'three/addons/loaders/GLTFLoader.js';
import { HDRLoader } from 'three/addons/loaders/HDRLoader.js';

const params = new URLSearchParams(location.search);
const SHOT = params.has('shot');
const W = SHOT ? 1920 : innerWidth, Hh = SHOT ? 1080 : innerHeight;
const hud = document.getElementById('hud');
if (SHOT) document.getElementById('help').remove();

// ---------------------------------------------------------------- renderer / scene
const renderer = new THREE.WebGPURenderer({ antialias: false, powerPreference: 'high-performance' });
renderer.setPixelRatio(1);
renderer.setSize(W, Hh);
const TM = { agx: THREE.AgXToneMapping, aces: THREE.ACESFilmicToneMapping, neutral: THREE.NeutralToneMapping };
renderer.toneMapping = TM[params.get('tm') || 'aces'];
renderer.toneMappingExposure = parseFloat(params.get('exp') || '0.9');
renderer.shadowMap.enabled = true;
renderer.shadowMap.type = THREE.PCFShadowMap;
document.body.appendChild(renderer.domElement);
await renderer.init();

const scene = new THREE.Scene();
const camera = new THREE.PerspectiveCamera(62, W / Hh, 0.05, 6000);

const layout = await (await fetch('/models/layout.json')).json();
const heights = new Float32Array(await (await fetch('/models/heights.bin')).arrayBuffer());
const NEAR = layout.near;
function groundY(x, z) {
  const fx = Math.min(Math.max((x - NEAR.x0) / NEAR.step, 0), NEAR.nx - 1.001);
  const fz = Math.min(Math.max((z - NEAR.z0) / NEAR.step, 0), NEAR.nz - 1.001);
  const ix = Math.floor(fx), iz = Math.floor(fz), tx = fx - ix, tz = fz - iz;
  const h = (i, j) => heights[j * NEAR.nx + i];
  return (h(ix, iz) * (1 - tx) + h(ix + 1, iz) * tx) * (1 - tz) + (h(ix, iz + 1) * (1 - tx) + h(ix + 1, iz + 1) * tx) * tz;
}

// ---------------------------------------------------------------- sky + sun
const sunDir = new THREE.Vector3(...layout.sun.direction).normalize();
const sunColor = new THREE.Color(1.0, 0.85, 0.68);
const hdr = await new HDRLoader().loadAsync('/hdri/sky.hdr');
hdr.mapping = THREE.EquirectangularReflectionMapping;
// Rotate the sky so its baked-in sun (u=0.6002 in the equirect) lines up with layout.sun's azimuth.
const hdriSunAngle = (0.6002 - 0.5) * Math.PI * 2;
const ourSunAngle = Math.atan2(sunDir.z, sunDir.x);
const skyYaw = hdriSunAngle - ourSunAngle + (params.has('flipsky') ? 2 * (ourSunAngle - hdriSunAngle) : 0);
scene.background = hdr;
scene.environment = hdr;
scene.backgroundRotation.set(0, skyYaw, 0);
scene.environmentRotation.set(0, skyYaw, 0);
scene.backgroundIntensity = 1.0;
scene.environmentIntensity = 0.55;
scene.fog = new THREE.FogExp2(new THREE.Color(0.64, 0.72, 0.83), 0.0007);

const sun = new THREE.DirectionalLight(sunColor, 3.2);
sun.castShadow = true;
sun.shadow.mapSize.set(4096, 4096);
sun.shadow.bias = -0.0002;
sun.shadow.normalBias = 0.02;
sun.shadow.camera.near = 1; sun.shadow.camera.far = 600;
const csm = new CSMShadowNode(sun, { cascades: 4, maxFar: 150, mode: 'practical', lightMargin: 120 });
csm.fade = true;
sun.shadow.shadowNode = csm;
scene.add(sun, sun.target);
function placeSun() {                       // keep the light anchored around the viewer
  sun.target.position.copy(camera.position);
  sun.position.copy(camera.position).addScaledVector(sunDir, 300);
}

// ---------------------------------------------------------------- textures & materials
const tl = new THREE.TextureLoader();
async function tex(path, srgb) {
  const t = await tl.loadAsync(path);
  t.wrapS = t.wrapT = THREE.RepeatWrapping;
  t.anisotropy = 16;
  t.colorSpace = srgb ? THREE.SRGBColorSpace : THREE.NoColorSpace;
  return t;
}
const T = {};
for (const set of ['rock_ground', 'grass_ground', 'bark_willow_02'])
  T[set] = { diff: await tex(`/textures/${set}/diff.jpg`, true), nor: await tex(`/textures/${set}/nor_gl.jpg`),
             rough: await tex(`/textures/${set}/rough.jpg`), ao: await tex(`/textures/${set}/ao.jpg`) };

T.leaf = await tex('/models/leaf_detail.png', true);
T.farAlbedo = await tex('/models/far_albedo.jpg', true);
T.farAlbedo.wrapS = T.farAlbedo.wrapT = THREE.ClampToEdgeWrapping;
const uSun = uniform(sunDir);
const uSunCol = uniform(sunColor.clone());

function terrainMaterial() {
  const m = new THREE.MeshStandardNodeMaterial();
  const u0 = uv();
  const slate = texture(T.rock_ground.diff, u0).rgb.mul(vec3(0.62, 0.68, 0.80));            // cool Devonian slate tint
  const grass = texture(T.grass_ground.diff, u0.mul(1.4)).rgb.mul(vec3(0.78, 0.95, 0.55));
  const noiseish = texture(T.rock_ground.rough, u0.mul(0.37)).r;
  const w = smoothstep(0.35, 0.65, vertexColor().r.add(noiseish.sub(0.5).mul(0.5)));
  m.colorNode = mix(slate, grass, w);
  m.roughnessNode = mix(texture(T.rock_ground.rough, u0).r.mul(0.9), texture(T.grass_ground.rough, u0.mul(1.4)).r, w);
  m.aoNode = mix(texture(T.rock_ground.ao, u0).r, texture(T.grass_ground.ao, u0.mul(1.4)).r, w);
  m.normalNode = normalMap(mix(texture(T.rock_ground.nor, u0), texture(T.grass_ground.nor, u0.mul(1.4)), w), vec3(1.2).xy);
  return m;
}
const windOffset = (amp) => {                                   // sway grows with height above the vine base
  const h = clamp(attribute('position', 'vec3').y.sub(0.7), 0, 2);
  const ph = positionLocal.x.mul(0.9).add(positionLocal.z.mul(0.6));   // positionLocal is post-instancing here
  return vec3(sin(time.mul(1.6).add(ph)), 0, sin(time.mul(1.3).add(ph.mul(1.3)))).mul(h.mul(amp));
};
function leafMaterial() {
  const m = new THREE.MeshStandardNodeMaterial({ side: THREE.DoubleSide, roughness: 0.55 });
  const albedo = vertexColor().rgb.mul(texture(T.leaf, uv()).rgb).mul(1.45);   // vein texture mean ≈ 0.69
  m.colorNode = albedo;
  const viewDir = normalize(positionWorld.sub(cameraPosition));
  const back = pow(max(dot(viewDir, uSun), 0), 4.0);             // cheap backlit translucency
  m.emissiveNode = albedo.mul(uSunCol).mul(back.mul(0.45));
  m.positionNode = positionLocal.add(windOffset(0.012));
  return m;
}
const MATS = {
  vine_leaf: leafMaterial(),
  vine_berry: Object.assign(new THREE.MeshStandardNodeMaterial({ roughness: 0.38 }), { colorNode: vertexColor().rgb }),
  vine_bark: new THREE.MeshStandardMaterial({ map: T.bark_willow_02.diff, normalMap: T.bark_willow_02.nor,
    roughnessMap: T.bark_willow_02.rough, color: new THREE.Color(0.72, 0.6, 0.5) }),
  vine_wood: (() => {
    const m = new THREE.MeshStandardNodeMaterial({ normalMap: T.bark_willow_02.nor, roughness: 0.85 });
    m.colorNode = vec3(luminance(texture(T.bark_willow_02.diff, uv().mul(vec3(1, 0.3, 0).xy)).rgb)).mul(vec3(0.95, 0.88, 0.80));
    return m;
  })(),
  slate: (() => {
    const m = new THREE.MeshStandardNodeMaterial();
    const u2 = uv().mul(0.12);
    m.colorNode = texture(T.rock_ground.diff, u2).rgb.mul(vec3(0.30, 0.34, 0.42));
    m.roughnessNode = texture(T.rock_ground.rough, u2).r.mul(0.75);
    m.normalNode = normalMap(texture(T.rock_ground.nor, u2));
    return m;
  })(),
  grass: (() => {
    const m = new THREE.MeshStandardNodeMaterial({ side: THREE.DoubleSide, roughness: 0.8 });
    m.colorNode = vertexColor().rgb;
    m.positionNode = positionLocal.add(
      vec3(sin(time.mul(2.1).add(positionLocal.x.mul(1.7))), 0, sin(time.mul(1.7).add(positionLocal.z.mul(1.9))))
        .mul(attribute('position', 'vec3').y.mul(0.08)));
    return m;
  })(),
  terrain_near: terrainMaterial(),
  terrain_far: (() => {
    const m = new THREE.MeshStandardNodeMaterial({ roughness: 0.95 });
    const wxz = vec2(positionWorld.x, positionWorld.z);
    const crowns = texture(T.grass_ground.ao, wxz.div(7)).r;        // sub-texel canopy speckle when close
    m.colorNode = texture(T.farAlbedo, uv()).rgb.mul(crowns.mul(0.5).add(0.75));
    return m;
  })(),
  water: params.has('nowater') ? null : (() => {
    const refl = reflector({ resolutionScale: 0.5, bounces: false });
    refl.target.rotateX(-Math.PI / 2);
    scene.add(refl.target);
    const ripple = vec2(sin(positionWorld.x.mul(0.35).add(time.mul(0.9))).add(sin(positionWorld.z.mul(0.9).add(time.mul(1.3)))),
                        sin(positionWorld.z.mul(0.28).sub(time.mul(0.7))));
    refl.uvNode = refl.uvNode.add(ripple.mul(0.0025));
    const m = new THREE.MeshBasicNodeMaterial();
    const cosT = clamp(dot(normalize(cameraPosition.sub(positionWorld)), vec3(0, 1, 0)), 0, 1);
    const fres = float(0.02).add(float(0.98).mul(pow(float(1).sub(cosT), 5))).mul(0.85).add(0.1);
    m.colorNode = mix(vec3(0.010, 0.024, 0.026), refl.rgb, clamp(fres, 0, 1));
    return m;
  })(),
};
MATS.vine_bark.map.repeat.set(1, 1);

// ---------------------------------------------------------------- loading
const gltf = new GLTFLoader();
async function meshesOf(file) {
  const g = await gltf.loadAsync(`/models/${file}`);
  const out = [];
  g.scene.traverse((o) => { if (o.isMesh) out.push(o); });
  return out;
}
const NEAR_LAYER = 1;
camera.layers.enable(NEAR_LAYER);
async function addStatic(file, { cast = false, receive = true, near = true } = {}) {
  for (const m of await meshesOf(file)) {
    m.material = MATS[m.material.name] ?? m.material;
    m.castShadow = cast; m.receiveShadow = receive;
    if (near) m.layers.set(NEAR_LAYER);
    scene.add(m);
  }
}
await addStatic('terrain_near.glb', { cast: true });
await addStatic('terrain_far.glb', { near: false });
if (!params.has('nowater')) await addStatic('water.glb', { receive: false });

const _m = new THREE.Matrix4(), _q = new THREE.Quaternion(), _p = new THREE.Vector3(), _s = new THREE.Vector3(), _up = new THREE.Vector3(0, 1, 0);
async function instanced(file, capacity, { cast = false } = {}) {
  const parts = [];
  for (const m of await meshesOf(file)) {
    const im = new THREE.InstancedMesh(m.geometry, MATS[m.material.name] ?? m.material, capacity);
    im.castShadow = cast; im.receiveShadow = true; im.frustumCulled = false; im.count = 0;
    im.instanceMatrix.setUsage(THREE.DynamicDrawUsage);
    im.layers.set(NEAR_LAYER);
    scene.add(im); parts.push(im);
  }
  return parts;
}
function writeInstances(parts, matrices) {
  for (const im of parts) {
    matrices.forEach((mx, i) => im.setMatrixAt(i, mx));
    im.count = matrices.length;
    im.instanceMatrix.needsUpdate = true;
  }
}

// slate + grass (static)
for (const [kind, n] of [['slate', 5], ['grass', 3]]) {
  for (let v = 0; v < n; v++) {
    const items = layout[kind].items.filter((it) => it[0] === v);
    const parts = await instanced(`${kind}_${v}.glb`, items.length);
    writeInstances(parts, items.map((it) => {
      _p.set(it[1], it[2], it[3]);
      if (kind === 'slate') { _q.set(it[4], it[5], it[6], it[7]); _s.setScalar(it[8]); }
      else { _q.setFromAxisAngle(_up, it[4]); _s.setScalar(it[5]); }
      return new THREE.Matrix4().compose(_p, _q, _s);
    }));
  }
}

// neighbour vineyards: cheap canopy-column vines covering the rest of the slope
for (let v = 0; v < layout.neighbours.variants; v++) {
  const items = layout.neighbours.items.filter((it) => it[0] === v);
  const parts = await instanced(`vine_lod2_${v}.glb`, items.length, { cast: !params.has('nonbshadow') });
  writeInstances(parts, items.map((it) => new THREE.Matrix4().compose(new THREE.Vector3(it[1], it[2], it[3]),
    new THREE.Quaternion().setFromAxisAngle(_up, it[4]), new THREE.Vector3().setScalar(it[5]))));
}

// vines with distance LOD
const VINES = layout.vines.items.map((it) => ({
  variant: it[0], pos: new THREE.Vector3(it[1], it[2], it[3]),
  matrix: new THREE.Matrix4().compose(new THREE.Vector3(it[1], it[2], it[3]),
    new THREE.Quaternion().setFromAxisAngle(_up, it[4]), new THREE.Vector3().setScalar(it[5])),
}));
const vineSets = [];
const SHADOW_ONLY_LAYER = 2;             // seen by shadow cameras (enableAll), not by the main camera
for (let v = 0; v < 4; v++) {
  const cap = VINES.filter((x) => x.variant === v).length;
  const shadowProxy = await instanced(`vine_${v}_lod1.glb`, cap, { cast: true });   // near vines cast via cheap LOD1
  for (const im of shadowProxy) im.layers.set(SHADOW_ONLY_LAYER);
  vineSets.push({ lod0: await instanced(`vine_${v}.glb`, cap, { cast: false }), lod1: await instanced(`vine_${v}_lod1.glb`, cap, { cast: true }), shadowProxy });
}
const LOD_DIST = 20;
const lastLodPos = new THREE.Vector3(1e9, 0, 0);
function updateLod(force = false) {
  if (!force && camera.position.distanceTo(lastLodPos) < 1) return;
  lastLodPos.copy(camera.position);
  for (let v = 0; v < 4; v++) {
    const near = [], far = [];
    for (const vine of VINES) if (vine.variant === v) (vine.pos.distanceTo(camera.position) < LOD_DIST ? near : far).push(vine.matrix);
    writeInstances(vineSets[v].lod0, near);
    writeInstances(vineSets[v].shadowProxy, near);
    writeInstances(vineSets[v].lod1, far);
  }
}

// ---------------------------------------------------------------- post-processing
const pipeline = new THREE.RenderPipeline(renderer);
const scenePass = pass(scene, camera);
scenePass.setMRT(mrt({ output, normal: normalView }));
const sceneColor = scenePass.getTextureNode('output');
const aoPass = ao(scenePass.getTextureNode('depth'), scenePass.getTextureNode('normal'), camera);
aoPass.resolutionScale = 0.5;
aoPass.radius.value = 0.6;
aoPass.distanceExponent.value = 1.5;
const aoTerm = mix(float(1), aoPass.getTextureNode().r, 0.75);
const lit = vec4(sceneColor.rgb.mul(params.has('noao') ? float(1) : aoTerm), sceneColor.a);
const withBloom = lit.add(bloom(lit, 0.08, 0.35, 0.95));
pipeline.outputColorTransform = false;
pipeline.outputNode = smaa(renderOutput(withBloom));

// ---------------------------------------------------------------- camera presets & controls
const PRESETS = layout.cameras;
const PRESET_KEYS = ['row_downhill', 'uphill', 'valley_view', 'drone', 'vine_close'];
let yaw = 0, pitch = 0, flying = false;
function setPreset(name) {
  const c = PRESETS[name];
  camera.position.set(...c.position);
  const d = new THREE.Vector3(...c.target).sub(camera.position).normalize();
  yaw = Math.atan2(-d.x, -d.z); pitch = Math.asin(d.y);
  flying = name === 'drone' || name === 'vine_close';
  applyLook(); updateLod(true); placeSun();
}
function applyLook() { camera.quaternion.setFromEuler(new THREE.Euler(pitch, yaw, 0, 'YXZ')); }
const keys = new Set();
addEventListener('keydown', (e) => {
  keys.add(e.code);
  const n = parseInt(e.key, 10);
  if (n >= 1 && n <= 5) setPreset(PRESET_KEYS[n - 1]);
  if (e.code === 'KeyF') showFps = !showFps;
});
addEventListener('keyup', (e) => keys.delete(e.code));
renderer.domElement.addEventListener('click', () => renderer.domElement.requestPointerLock());
addEventListener('mousemove', (e) => {
  if (document.pointerLockElement !== renderer.domElement) return;
  yaw -= e.movementX * 0.0022; pitch = Math.max(-1.45, Math.min(1.45, pitch - e.movementY * 0.0022)); applyLook();
});
addEventListener('resize', () => {
  if (SHOT) return;
  renderer.setSize(innerWidth, innerHeight); camera.aspect = innerWidth / innerHeight; camera.updateProjectionMatrix();
  csm.updateFrustums();
});
function move(dt) {
  const f = (keys.has('KeyW') ? 1 : 0) - (keys.has('KeyS') ? 1 : 0);
  const s = (keys.has('KeyD') ? 1 : 0) - (keys.has('KeyA') ? 1 : 0);
  if (f || s) {
    flying = false;
    const sp = (keys.has('ShiftLeft') || keys.has('ShiftRight') ? 4.0 : 1.6) * dt;
    camera.position.x += (-Math.sin(yaw) * f + Math.cos(yaw) * s) * sp;
    camera.position.z += (-Math.cos(yaw) * f - Math.sin(yaw) * s) * sp;
  }
  if (!flying) camera.position.y = groundY(camera.position.x, camera.position.z) + 1.7;
}

// ---------------------------------------------------------------- loop, fps, shot API
let shadowLayersFixed = false;
sun.shadow.camera.layers.enableAll();
let showFps = SHOT, last = performance.now(), frameTimes = [], frameWaiters = [];
renderer.setAnimationLoop(() => {
  const now = performance.now(), dt = Math.min(0.1, (now - last) / 1000);
  frameTimes.push(now - last); if (frameTimes.length > 2000) frameTimes.shift();
  last = now;
  move(dt); updateLod(); placeSun();
  if (!shadowLayersFixed && csm.lights?.length) {
    for (const l of csm.lights) { l.shadow.camera.layers.enableAll(); l.shadow.autoUpdate = false; }
    shadowLayersFixed = true;
  }
  // Render shadow maps once per frame, not again for the water's reflection camera.
  if (shadowLayersFixed) for (const l of csm.lights) l.shadow.needsUpdate = true;
  pipeline.render();
  if (showFps && frameTimes.length % 15 === 0) {
    const recent = frameTimes.slice(-60), avg = recent.reduce((a, b) => a + b, 0) / recent.length;
    hud.textContent = `${(1000 / avg).toFixed(0)} fps  ${avg.toFixed(1)} ms  ${renderer.info.render.drawCalls ?? ''} draws`;
  } else if (!showFps) hud.textContent = '';
  frameWaiters = frameWaiters.filter((w) => --w.n > 0 || (w.resolve(), false));
});
window.demo = {
  presets: PRESET_KEYS,
  setPreset,
  frames: (n) => new Promise((resolve) => frameWaiters.push({ n, resolve })),
  async measure(seconds) {
    const start = frameTimes.length; await new Promise((r) => setTimeout(r, seconds * 1000));
    const ft = frameTimes.slice(start).sort((a, b) => a - b);
    const avg = ft.reduce((a, b) => a + b, 0) / ft.length;
    const p99 = ft[Math.floor(ft.length * 0.99)];
    return { avgFps: +(1000 / avg).toFixed(1), low1Fps: +(1000 / p99).toFixed(1), frames: ft.length };
  },
  info: () => ({ backend: renderer.backend.isWebGPUBackend ? 'WebGPU' : 'WebGL2', ...renderer.info.render }),
};
setPreset(params.get('preset') || 'row_downhill');
window.demoReady = true;
