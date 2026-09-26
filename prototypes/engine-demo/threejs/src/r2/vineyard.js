// PROTOTYPE — round-2 vineyard: round-1 slope + weather presets (P), time of day (T), GPU rain, wetness,
// height/valley fog with sun in-scatter, impostor forest. See README_r2.md §A.
import * as THREE from 'three/webgpu';
import {
  vec3, vec2, float, mix, texture, uv, vertexColor, uniform, attribute, positionWorld, positionView, cameraPosition,
  normalize, dot, max, pow, time, sin, smoothstep, normalMap, luminance, clamp, positionLocal, reflector, fog, exp,
  instancedBufferAttribute, fract, length, transformNormalToView,
} from 'three/tsl';
import { CSMShadowNode } from 'three/addons/csm/CSMShadowNode.js';
import { params, json, tex, hdri, meshesOf, lookFrom } from './common.js';
import { outdoorPipeline } from './post.js';

const LAT = 49.9 * Math.PI / 180, DECL = -1.3 * Math.PI / 180;       // 26 September
function solar(hour) {
  const h = (hour - 12) * 15 * Math.PI / 180;
  const el = Math.asin(Math.sin(LAT) * Math.sin(DECL) + Math.cos(LAT) * Math.cos(DECL) * Math.cos(h));
  const az = Math.atan2(Math.sin(h), Math.cos(h) * Math.sin(LAT) - Math.tan(DECL) * Math.cos(LAT)) + Math.PI;
  return { elevationDeg: el * 180 / Math.PI, azimuthDeg: az * 180 / Math.PI };
}
function sunVector(elDeg, azDeg) {
  const el = elDeg * Math.PI / 180, az = azDeg * Math.PI / 180;
  return new THREE.Vector3(Math.sin(az) * Math.cos(el), Math.sin(el), -Math.cos(az) * Math.cos(el)).normalize();
}

export async function build({ renderer, layout: L2 }) {
  const layout = await json('/models/layout.json');
  const heights = new Float32Array(await (await fetch('/models/heights.bin')).arrayBuffer());
  const NEAR = layout.near;
  const groundY = (x, z) => {
    const fx = Math.min(Math.max((x - NEAR.x0) / NEAR.step, 0), NEAR.nx - 1.001);
    const fz = Math.min(Math.max((z - NEAR.z0) / NEAR.step, 0), NEAR.nz - 1.001);
    const ix = Math.floor(fx), iz = Math.floor(fz), tx = fx - ix, tz = fz - iz;
    const h = (i, j) => heights[j * NEAR.nx + i];
    return (h(ix, iz) * (1 - tx) + h(ix + 1, iz) * tx) * (1 - tz) + (h(ix, iz + 1) * (1 - tx) + h(ix + 1, iz + 1) * tx) * tz;
  };
  const scene = new THREE.Scene();
  const camera = new THREE.PerspectiveCamera(62, renderer.domElement.width / renderer.domElement.height, 0.05, 6000);
  renderer.toneMapping = THREE.ACESFilmicToneMapping;

  // ------------------------------------------------ weather state (all tweens run on these numbers)
  const PRESETS = L2.vineyard_presets;
  const presetNames = Object.keys(PRESETS);
  const skies = {};
  for (const p of Object.values(PRESETS)) skies[p.sky] ??= await hdri('/' + p.sky);
  const U = {
    sunDir: uniform(new THREE.Vector3(0, 1, 0)), sunCol: uniform(new THREE.Color(1, 0.85, 0.68)),
    wet: uniform(0), rain: uniform(0), fogDensity: uniform(0.0007), valleyTop: uniform(-100), wind: uniform(1),
    fogCol: uniform(new THREE.Color(0.64, 0.72, 0.83)),
  };
  const state = { hour: 16.5, el: 20, az: 240, rain: 0, wet: 0, cloud: 0.1, fog: 0.0007, valley: -100, exposure: 0.9 };
  let tween = null, current = 'clear_afternoon';

  // ------------------------------------------------ sky, sun, fog
  scene.environmentIntensity = 0.55;
  const sun = new THREE.DirectionalLight(0xffffff, 3.2);
  sun.castShadow = true;
  sun.shadow.mapSize.set(4096, 4096); sun.shadow.bias = -0.0002; sun.shadow.normalBias = 0.02;
  const csm = new CSMShadowNode(sun, { cascades: 4, maxFar: 150, mode: 'practical', lightMargin: 120 });
  csm.fade = true; sun.shadow.shadowNode = csm;
  scene.add(sun, sun.target);
  const viewDir = normalize(positionWorld.sub(cameraPosition));
  const dist = length(positionView);
  const inscatter = pow(max(dot(viewDir, U.sunDir), 0), 6).mul(clamp(U.sunDir.y.mul(4).add(0.4), 0, 1));
  const fogColor = mix(U.fogCol, U.sunCol.mul(1.6), inscatter.mul(0.7));
  const densityFactor = float(1).sub(exp(dist.mul(U.fogDensity).negate()));
  const valleyFactor = float(1).sub(exp(dist.mul(0.035).negate())).mul(smoothstep(U.valleyTop.add(10), U.valleyTop.sub(8), positionWorld.y)).mul(0.92);
  scene.fogNode = fog(fogColor, max(densityFactor, valleyFactor));

  // ------------------------------------------------ textures & materials (round 1 + wetness)
  const T = {};
  for (const set of ['rock_ground', 'grass_ground', 'bark_willow_02'])
    T[set] = { diff: await tex(`/textures/${set}/diff.jpg`, { srgb: true }), nor: await tex(`/textures/${set}/nor_gl.jpg`),
      rough: await tex(`/textures/${set}/rough.jpg`), ao: await tex(`/textures/${set}/ao.jpg`) };
  T.leaf = await tex('/models/leaf_detail.png', { srgb: true });
  T.farAlbedo = await tex('/models/far_albedo.jpg', { srgb: true, repeat: false });
  T.trees = await tex('/models_r2/trees_atlas.png', { srgb: true, repeat: false });
  const wetDark = mix(float(1), float(0.55), U.wet);
  const wetRough = (r) => mix(r, r.mul(0.18), U.wet);
  const puddle = smoothstep(0.62, 0.72, texture(T.rock_ground.rough, positionWorld.xz.mul(0.045)).r).mul(smoothstep(0.6, 0.9, U.wet));

  const terrain = new THREE.MeshStandardNodeMaterial();
  {
    const u0 = uv();
    const slate = texture(T.rock_ground.diff, u0).rgb.mul(vec3(0.62, 0.68, 0.80));
    const grass = texture(T.grass_ground.diff, u0.mul(1.4)).rgb.mul(vec3(0.78, 0.95, 0.55));
    const w = smoothstep(0.35, 0.65, vertexColor().r.add(texture(T.rock_ground.rough, u0.mul(0.37)).r.sub(0.5).mul(0.5)));
    terrain.colorNode = mix(mix(slate, grass, w).mul(wetDark), vec3(0.03, 0.035, 0.04), puddle.mul(0.7));
    terrain.roughnessNode = mix(wetRough(mix(texture(T.rock_ground.rough, u0).r.mul(0.9), texture(T.grass_ground.rough, u0.mul(1.4)).r, w)), float(0.03), puddle);
    terrain.aoNode = mix(texture(T.rock_ground.ao, u0).r, texture(T.grass_ground.ao, u0.mul(1.4)).r, w);
    terrain.normalNode = normalMap(mix(texture(T.rock_ground.nor, u0), texture(T.grass_ground.nor, u0.mul(1.4)), w), mix(vec2(1.2), vec2(0.1), puddle));
  }
  const windOffset = (amp) => {
    const h = clamp(attribute('position', 'vec3').y.sub(0.7), 0, 2);
    const ph = positionLocal.x.mul(0.9).add(positionLocal.z.mul(0.6));
    return vec3(sin(time.mul(U.wind.mul(1.6)).add(ph)), 0, sin(time.mul(U.wind.mul(1.3)).add(ph.mul(1.3)))).mul(h.mul(amp).mul(U.wind));
  };
  const leaf = new THREE.MeshStandardNodeMaterial({ side: THREE.DoubleSide });
  {
    const albedo = vertexColor().rgb.mul(texture(T.leaf, uv()).rgb).mul(1.45);
    leaf.colorNode = albedo.mul(mix(float(1), float(0.8), U.wet));
    leaf.roughnessNode = mix(float(0.55), float(0.12), U.wet);            // wet leaves: glossy sheen
    const back = pow(max(dot(viewDir, U.sunDir), 0), 4.0);
    leaf.emissiveNode = albedo.mul(U.sunCol).mul(back.mul(0.45));
    leaf.positionNode = positionLocal.add(windOffset(0.012));
  }
  const MATS = {
    vine_leaf: leaf,
    vine_berry: Object.assign(new THREE.MeshStandardNodeMaterial(), { colorNode: vertexColor().rgb, roughnessNode: mix(float(0.38), float(0.08), U.wet) }),
    vine_bark: (() => { const m = new THREE.MeshStandardNodeMaterial({ normalMap: T.bark_willow_02.nor });
      m.colorNode = texture(T.bark_willow_02.diff, uv()).rgb.mul(vec3(0.72, 0.6, 0.5)).mul(wetDark);
      m.roughnessNode = wetRough(texture(T.bark_willow_02.rough, uv()).r); return m; })(),
    vine_wood: (() => { const m = new THREE.MeshStandardNodeMaterial({ normalMap: T.bark_willow_02.nor });
      m.colorNode = vec3(luminance(texture(T.bark_willow_02.diff, uv().mul(vec2(1, 0.3))).rgb)).mul(vec3(0.95, 0.88, 0.80)).mul(wetDark);
      m.roughnessNode = wetRough(float(0.85)); return m; })(),
    slate: (() => { const m = new THREE.MeshStandardNodeMaterial(); const u2 = uv().mul(0.12);
      m.colorNode = texture(T.rock_ground.diff, u2).rgb.mul(vec3(0.30, 0.34, 0.42)).mul(wetDark);
      m.roughnessNode = wetRough(texture(T.rock_ground.rough, u2).r.mul(0.75)); m.normalNode = normalMap(texture(T.rock_ground.nor, u2)); return m; })(),
    grass: (() => { const m = new THREE.MeshStandardNodeMaterial({ side: THREE.DoubleSide });
      m.colorNode = vertexColor().rgb.mul(wetDark); m.roughnessNode = wetRough(float(0.8));
      m.positionNode = positionLocal.add(vec3(sin(time.mul(2.1).add(positionLocal.x.mul(1.7))), 0, sin(time.mul(1.7).add(positionLocal.z.mul(1.9))))
        .mul(attribute('position', 'vec3').y.mul(0.08).mul(U.wind))); return m; })(),
    terrain_near: terrain,
    terrain_far: (() => { const m = new THREE.MeshStandardNodeMaterial({ roughness: 0.95 });
      m.colorNode = texture(T.farAlbedo, uv()).rgb.mul(texture(T.grass_ground.ao, positionWorld.xz.div(7)).r.mul(0.5).add(0.75)).mul(mix(float(1), float(0.8), U.wet)); return m; })(),
    water: (() => {
      const refl = reflector({ resolutionScale: 0.5, bounces: false });
      refl.target.rotateX(-Math.PI / 2); scene.add(refl.target);
      const rippleAmp = mix(float(0.0025), float(0.012), U.rain);
      const ripple = vec2(sin(positionWorld.x.mul(0.35).add(time.mul(0.9))).add(sin(positionWorld.z.mul(0.9).add(time.mul(1.3)))),
        sin(positionWorld.z.mul(0.28).sub(time.mul(0.7))).add(sin(positionWorld.x.mul(7.0).add(time.mul(9.0))).mul(U.rain)));
      refl.uvNode = refl.uvNode.add(ripple.mul(rippleAmp));
      const m = new THREE.MeshBasicNodeMaterial();
      const cosT = clamp(dot(normalize(cameraPosition.sub(positionWorld)), vec3(0, 1, 0)), 0, 1);
      const fres = float(0.02).add(float(0.98).mul(pow(float(1).sub(cosT), 5))).mul(0.85).add(0.1);
      m.colorNode = mix(vec3(0.010, 0.024, 0.026), refl.rgb, clamp(fres, 0, 1));
      return m;
    })(),
  };

  // ------------------------------------------------ geometry (same as round 1)
  const NEAR_LAYER = 1; camera.layers.enable(NEAR_LAYER);
  const add = async (file, { cast = false, receive = true, near = true } = {}) => {
    for (const m of await meshesOf(`/models/${file}`)) {
      m.material = MATS[m.material.name] ?? m.material; m.castShadow = cast; m.receiveShadow = receive;
      if (near) m.layers.set(NEAR_LAYER); scene.add(m);
    }
  };
  await add('terrain_near.glb', { cast: true });
  await add('terrain_far.glb', { near: false });
  await add('water.glb', { receive: false });
  const _up = new THREE.Vector3(0, 1, 0);
  const instanced = async (file, cap, { cast = false } = {}) => {
    const parts = [];
    for (const m of await meshesOf(`/models/${file}`)) {
      const im = new THREE.InstancedMesh(m.geometry, MATS[m.material.name] ?? m.material, cap);
      im.castShadow = cast; im.receiveShadow = true; im.frustumCulled = false; im.count = 0;
      im.instanceMatrix.setUsage(THREE.DynamicDrawUsage); im.layers.set(NEAR_LAYER); scene.add(im); parts.push(im);
    }
    return parts;
  };
  const write = (parts, mats) => { for (const im of parts) { mats.forEach((mx, i) => im.setMatrixAt(i, mx)); im.count = mats.length; im.instanceMatrix.needsUpdate = true; } };
  const mtx = (it) => new THREE.Matrix4().compose(new THREE.Vector3(it[1], it[2], it[3]), new THREE.Quaternion().setFromAxisAngle(_up, it[4]), new THREE.Vector3().setScalar(it[5]));
  for (const [kind, n] of [['slate', 5], ['grass', 3]]) for (let v = 0; v < n; v++) {
    const items = layout[kind].items.filter((it) => it[0] === v);
    write(await instanced(`${kind}_${v}.glb`, items.length), items.map((it) => kind === 'slate'
      ? new THREE.Matrix4().compose(new THREE.Vector3(it[1], it[2], it[3]), new THREE.Quaternion(it[4], it[5], it[6], it[7]), new THREE.Vector3().setScalar(it[8]))
      : mtx(it)));
  }
  for (let v = 0; v < layout.neighbours.variants; v++) {
    const items = layout.neighbours.items.filter((it) => it[0] === v);
    write(await instanced(`vine_lod2_${v}.glb`, items.length, { cast: true }), items.map(mtx));
  }
  const VINES = layout.vines.items.map((it) => ({ variant: it[0], pos: new THREE.Vector3(it[1], it[2], it[3]), matrix: mtx(it) }));
  const vineSets = [];
  for (let v = 0; v < 4; v++) {
    const cap = VINES.filter((x) => x.variant === v).length;
    const proxy = await instanced(`vine_${v}_lod1.glb`, cap, { cast: true });
    for (const im of proxy) im.layers.set(2);
    vineSets.push({ lod0: await instanced(`vine_${v}.glb`, cap), lod1: await instanced(`vine_${v}_lod1.glb`, cap, { cast: true }), proxy });
  }
  const lastLod = new THREE.Vector3(1e9, 0, 0);
  const updateLod = (force) => {
    if (!force && camera.position.distanceTo(lastLod) < 1) return;
    lastLod.copy(camera.position);
    for (let v = 0; v < 4; v++) {
      const near = [], far = [];
      for (const vine of VINES) if (vine.variant === v) (vine.pos.distanceTo(camera.position) < 20 ? near : far).push(vine.matrix);
      write(vineSets[v].lod0, near); write(vineSets[v].proxy, near); write(vineSets[v].lod1, far);
    }
  };

  // ------------------------------------------------ impostor forest (97k cards, one draw call)
  {
    const trees = (await json('/models_r2/trees.json')).items;
    const card = (await meshesOf('/models_r2/tree_card.glb'))[0];
    const geo = card.geometry.clone().applyMatrix4(card.matrixWorld);
    const variant = new THREE.InstancedBufferAttribute(new Float32Array(trees.map((t) => t[0])), 1);
    const m = new THREE.MeshStandardNodeMaterial({ side: THREE.DoubleSide, alphaTest: 0.45, roughness: 0.95 });
    const vAttr = instancedBufferAttribute(variant);
    const t = texture(T.trees, vec2(uv().x.add(vAttr).div(4), uv().y));
    m.colorNode = t.rgb.mul(1.25).mul(mix(float(1), float(0.8), U.wet));
    m.opacityNode = t.a;
    m.normalNode = transformNormalToView(vec3(0.0, 1.0, 0.0));   // lit like a canopy top, both card faces
    const im = new THREE.InstancedMesh(geo, m, trees.length);
    const q = new THREE.Quaternion(), p = new THREE.Vector3(), s = new THREE.Vector3();
    trees.forEach((tr, i) => { p.set(tr[1], tr[2], tr[3]); q.setFromAxisAngle(_up, tr[4]); s.setScalar(tr[5]); im.setMatrixAt(i, new THREE.Matrix4().compose(p, q, s)); });
    im.frustumCulled = false; im.receiveShadow = true;
    if (!params.has('notrees')) scene.add(im);
  }

  // ------------------------------------------------ GPU rain: instanced streaks animated entirely in the vertex stage
  {
    const N = 60000, box = new THREE.Vector3(28, 18, 28);
    const seeds = new Float32Array(N * 3);
    for (let i = 0; i < N * 3; i++) seeds[i] = Math.random();
    const seed = instancedBufferAttribute(new THREE.InstancedBufferAttribute(seeds, 3));
    const geo = new THREE.PlaneGeometry(0.012, 0.45);
    const m = new THREE.MeshBasicNodeMaterial({ transparent: true, depthWrite: false, blending: THREE.AdditiveBlending });
    const speed = float(8.5);
    const fall = fract(seed.y.sub(time.mul(speed).div(box.y)));
    const rel = vec3(seed.x.sub(0.5).mul(box.x), fall.sub(0.35).mul(box.y), seed.z.sub(0.5).mul(box.z));
    const center = cameraPosition.add(rel);
    const slant = vec3(0.18, 0, 0.06).mul(U.wind);
    const local = positionLocal;                                           // quad vertex (x across, y along streak)
    const toCam = normalize(vec3(cameraPosition.x.sub(center.x), 0, cameraPosition.z.sub(center.z)));
    const right = vec3(toCam.z, 0, toCam.x.negate());
    m.positionNode = center.add(right.mul(local.x)).add(vec3(0, local.y, 0)).add(slant.mul(local.y));
    const visible = clamp(U.rain.mul(1.3).sub(seed.x.mul(0.3)), 0, 1);   // denser rain lights up more streaks
    m.colorNode = vec3(0.55, 0.6, 0.66);
    m.opacityNode = visible.mul(0.22).mul(smoothstep(0.0, 3.0, length(rel)));
    const im = new THREE.InstancedMesh(geo, m, N);
    im.frustumCulled = false; im.layers.set(NEAR_LAYER);
    if (!params.has('norain')) scene.add(im);
  }

  // ------------------------------------------------ apply state → lights, sky, uniforms
  function applyState() {
    const dir = sunVector(state.el, state.az);
    U.sunDir.value.copy(dir);
    const low = THREE.MathUtils.clamp(state.el / 25, 0, 1);
    const col = new THREE.Color(1.0, 0.45 + 0.4 * low, 0.22 + 0.46 * low);
    U.sunCol.value.copy(col);
    const day = THREE.MathUtils.smoothstep(state.el, -3, 6);
    sun.color.copy(col);
    sun.intensity = 3.4 * day * (1 - 0.85 * state.cloud);
    scene.environmentIntensity = 0.35 + 0.5 * state.cloud;
    U.fogCol.value.setRGB(0.64, 0.72, 0.83).lerp(new THREE.Color(0.55, 0.58, 0.62), state.cloud).lerp(new THREE.Color(0.9, 0.62, 0.45), (1 - low) * 0.35 * (1 - state.cloud))
      .multiplyScalar(0.25 + 0.75 * THREE.MathUtils.smoothstep(state.el, -6, 12));
    U.wet.value = state.wet; U.rain.value = state.rain; U.fogDensity.value = state.fog; U.valleyTop.value = state.valley;
    U.wind.value = 1 + 1.4 * state.rain;
    renderer.toneMappingExposure = state.exposure;
  }
  function presetTarget(name) {
    const p = PRESETS[name];
    return { hour: p.timeOfDay, el: p.sun.elevationDeg, az: p.sun.azimuthDeg, rain: p.rain, wet: p.wetness, cloud: p.cloudCover,
      fog: p.fog.density, valley: p.fog.valleyFogTopY ?? -100, exposure: p.weather === 'rain' ? 1.05 : p.sun.elevationDeg < 6 ? 1.1 : 0.9 };
  }
  function setPreset(name, instant = false) {
    current = name;
    const p = PRESETS[name];
    scene.background = scene.environment = skies[p.sky];
    const yaw = p.sky === 'hdri/sky.hdr' ? ((0.6002 - 0.5) * Math.PI * 2 - Math.atan2(sunVector(p.sun.elevationDeg, p.sun.azimuthDeg).z, sunVector(p.sun.elevationDeg, p.sun.azimuthDeg).x)) : 0;
    scene.backgroundRotation.set(0, yaw, 0); scene.environmentRotation.set(0, yaw, 0);
    scene.backgroundIntensity = p.weather === 'rain' ? 0.8 : 1.0;
    const target = presetTarget(name);
    if (instant) { Object.assign(state, target); applyState(); tween = null; }
    else tween = { from: { ...state }, to: target, t: 0 };
  }
  const placeSun = () => { sun.target.position.copy(camera.position); sun.position.copy(camera.position).addScaledVector(U.sunDir.value, 300); };

  setPreset(params.get('preset') && PRESETS[params.get('preset')] ? params.get('preset') : 'clear_afternoon', true);
  const post = outdoorPipeline(renderer, scene, camera);
  let fixed = false;
  sun.shadow.camera.layers.enableAll();

  const cams = layout.cameras;
  const shots = Object.fromEntries(Object.entries(L2.shots).filter(([, s]) => s.scene === 'vineyard').map(([k, s]) => [k, { ...cams[s.camera], preset: s.preset }]));
  const fly = { drone: true, vine_close: true };
  let flying = false;
  const setCam = (name) => { const c = cams[name]; lookFrom(camera, c.position, c.target); flying = !!fly[name]; updateLod(true); placeSun(); };
  setCam('row_downhill');

  return {
    scene, camera, pipeline: post.pipeline, shots, eye: 1.7,
    get ground() { return flying ? null : groundY; },
    setShot(name, s) { setPreset(s.preset, true); setCam(s.camera); },
    onMove() { flying = false; },
    onKey(code) {
      if (code === 'KeyP') setPreset(presetNames[(presetNames.indexOf(current) + 1) % presetNames.length]);
      if (code === 'KeyT') {
        const target = { ...state, hour: (state.hour + 1) % 24 };
        const s = solar(target.hour); target.el = s.elevationDeg; target.az = s.azimuthDeg;
        target.exposure = s.elevationDeg < 6 ? 1.15 : 0.9;
        tween = { from: { ...state }, to: target, t: 0, dur: 1.5 };
      }
    },
    hud: () => `${current} · ${String(Math.floor(state.hour)).padStart(2, '0')}:${String(Math.round((state.hour % 1) * 60)).padStart(2, '0')} · sun ${state.el.toFixed(0)}°`,
    update(dt) {
      if (tween) {
        tween.t = Math.min(1, tween.t + dt / (tween.dur ?? 5));
        const k = tween.t * tween.t * (3 - 2 * tween.t);
        for (const key of Object.keys(tween.to)) state[key] = tween.from[key] + (tween.to[key] - tween.from[key]) * k;
        applyState();
        if (tween.t >= 1) tween = null;
      }
      updateLod(false); placeSun();
      if (!fixed && csm.lights?.length) { for (const l of csm.lights) { l.shadow.camera.layers.enableAll(); l.shadow.autoUpdate = false; } fixed = true; }
      if (fixed) for (const l of csm.lights) l.shadow.needsUpdate = true;
    },
  };
}
