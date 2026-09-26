// PROTOTYPE — fermentation hall: morning sun through the roller door and windows with volumetric shafts,
// hanging lamps, brushed-stainless tanks reflecting an interior probe, live LCD readouts per tank.
import * as THREE from 'three/webgpu';
import { texture, uv, vec2, vec3, float, mix, normalMap, Fn, screenCoordinate, positionWorld, smoothstep } from 'three/tsl';
import { bayer16 } from 'three/addons/tsl/math/Bayer.js';
import { pbr, instancedFrom, compose, canvasTexture, lumensToCandela, loadGltf, lookFrom, hdri, params } from './common.js';
import { interiorPipeline, VOLUME_LAYER } from './post.js';

const P = (k, d) => (params.has(k) ? parseFloat(params.get(k)) : d);

function drawPanel(ctx, w, h, t, tick) {
  const g = ctx.createLinearGradient(0, 0, 0, h); g.addColorStop(0, '#07130f'); g.addColorStop(1, '#030806');
  ctx.fillStyle = g; ctx.fillRect(0, 0, w, h);
  ctx.strokeStyle = '#1d3a30'; ctx.lineWidth = 6; ctx.strokeRect(3, 3, w - 6, h - 6);
  const empty = !t.setC;
  const green = '#7dffb0', amber = '#ffc15e', dim = '#4f8f73';
  ctx.fillStyle = dim; ctx.font = '600 30px "Segoe UI", system-ui, sans-serif'; ctx.textBaseline = 'top';
  ctx.fillText(t.id, 24, 18);
  ctx.fillStyle = green; ctx.font = '600 32px "Segoe UI", system-ui';
  ctx.fillText(t.contents, 92, 16);
  ctx.fillStyle = dim; ctx.font = '26px "Segoe UI", system-ui';
  ctx.fillText(t.phase + (t.day ? ` · day ${t.day}` : ''), 24, 62);
  if (empty) { ctx.fillStyle = dim; ctx.font = '28px "Segoe UI"'; ctx.fillText('ready for next lot', 24, 150); return; }
  const temp = t.tempC + Math.sin(tick * 0.7 + t.day) * 0.08;
  const off = Math.abs(temp - t.setC) > 0.8;
  ctx.fillStyle = off ? amber : green; ctx.font = '700 84px "Consolas", ui-monospace, monospace';
  ctx.fillText(`${temp.toFixed(1)}°`, 22, 104);
  ctx.fillStyle = dim; ctx.font = '26px "Segoe UI"'; ctx.fillText(`set ${t.setC.toFixed(1)} °C`, 26, 196);
  const s = t.oe_series;
  if (s.length > 1) {
    const oe = s[s.length - 1] - (Math.sin(tick * 0.3) * 0.05 + 0.02 * (tick % 60));
    ctx.fillStyle = green; ctx.font = '700 60px "Consolas", ui-monospace';
    ctx.textAlign = 'right'; ctx.fillText(`${Math.max(0, oe).toFixed(1)}`, w - 150, 104);
    ctx.font = '26px "Segoe UI"'; ctx.fillStyle = dim; ctx.fillText('°Oe', w - 90, 128); ctx.textAlign = 'left';
    const x0 = 300, y0 = 180, cw = w - x0 - 30, ch = 70, mx = Math.max(...s), mn = Math.min(...s, 0);
    ctx.strokeStyle = '#1d3a30'; ctx.lineWidth = 2; ctx.beginPath(); ctx.moveTo(x0, y0 + ch); ctx.lineTo(x0 + cw, y0 + ch); ctx.stroke();
    ctx.strokeStyle = green; ctx.lineWidth = 4; ctx.beginPath();
    s.forEach((v, i) => { const x = x0 + (i / (s.length - 1)) * cw, y = y0 + ch - ((v - mn) / (mx - mn || 1)) * ch; i ? ctx.lineTo(x, y) : ctx.moveTo(x, y); });
    ctx.stroke();
  }
  if (t.note) { ctx.fillStyle = dim; ctx.font = '24px "Segoe UI"'; ctx.fillText(t.note, 24, h - 44); }
}

export async function build({ renderer, layout }) {
  const Hh = layout.hall;
  const scene = new THREE.Scene();
  const camera = new THREE.PerspectiveCamera(60, renderer.domElement.width / renderer.domElement.height, 0.05, 400);
  const [floor, wall] = await Promise.all([pbr('concrete_floor_worn_001'), pbr('grey_plaster_02')]);
  const sky = await hdri('/hdri/kloofendal_misty_morning_puresky.hdr');
  scene.background = sky; scene.backgroundIntensity = 1.2;

  const mats = {
    hall_floor: (() => { const m = new THREE.MeshStandardNodeMaterial(); const u = uv().mul(0.35);
      m.colorNode = texture(floor.diff, u).rgb.mul(0.8); m.roughnessNode = texture(floor.rough, u).r.mul(0.55).add(0.1);
      m.normalNode = normalMap(texture(floor.nor, u)); m.aoNode = texture(floor.ao, u).r; return m; })(),
    hall_wall: (() => { const m = new THREE.MeshStandardNodeMaterial(); const u = uv().mul(0.4);
      m.colorNode = texture(wall.diff, u).rgb.mul(0.85); m.roughnessNode = texture(wall.rough, u).r; m.normalNode = normalMap(texture(wall.nor, u)); return m; })(),
    hall_steel: new THREE.MeshStandardMaterial({ color: new THREE.Color(0.18, 0.19, 0.2), metalness: 0.8, roughness: 0.45, side: THREE.DoubleSide }),
    window_glass: new THREE.MeshBasicMaterial({ color: new THREE.Color(1.6, 1.7, 1.8), transparent: true, opacity: 0.35, side: THREE.DoubleSide }),
    grate: new THREE.MeshStandardMaterial({ color: new THREE.Color(0.12, 0.12, 0.12), metalness: 0.9, roughness: 0.5, side: THREE.DoubleSide }),
    tank_steel: new THREE.MeshPhysicalMaterial({ color: new THREE.Color(0.86, 0.86, 0.88), metalness: 1.0, roughness: 0.22, anisotropy: 0.7 }),
    tank_jacket: new THREE.MeshPhysicalMaterial({ color: new THREE.Color(0.8, 0.8, 0.82), metalness: 1.0, roughness: 0.34, anisotropy: 0.5 }),
    tank_dark: new THREE.MeshStandardMaterial({ color: new THREE.Color(0.05, 0.05, 0.05), roughness: 0.5, side: THREE.DoubleSide }),
  };
  const room = await loadGltf('/models_r2/' + (Hh.model ?? 'hall.glb'));
  room.scene.traverse((o) => { if (!o.isMesh) return; const n = o.material.name.replace(/\.\d+$/, '');
    o.material = mats[n] ?? o.material; o.castShadow = n !== 'window_glass'; o.receiveShadow = true; });
  scene.add(room.scene);

  // tanks
  const tankM = Hh.tanks.map((t) => compose(t.pos, t.yaw));
  for (const im of await instancedFrom('/models_r2/' + (Hh.tankModel ?? (typeof Hh.tank === 'string' ? Hh.tank : 'tank.glb')), tankM,
    { materialFor: (n) => { const m = mats[n]; return m; } })) {
    if (im.geometry.attributes.uv && im.geometry.index) im.geometry.computeTangents();
    scene.add(im);
  }
  // live readout panels + blinking controller LEDs
  const info = Hh.tankInfo, panels = [], leds = [];
  const ledMat = new THREE.MeshStandardMaterial({ color: 0x000000, emissive: new THREE.Color(0.2, 1.0, 0.4), emissiveIntensity: 8 });
  for (const t of Hh.tanks) {
    const ct = canvasTexture(768, 480, (ctx, w, h, tick = 0) => drawPanel(ctx, w, h, t, tick));
    const m = new THREE.MeshStandardMaterial({ color: 0x000000, emissive: 0xffffff, emissiveMap: ct, emissiveIntensity: 1.6, roughness: 0.25 });
    const mesh = new THREE.Mesh(new THREE.PlaneGeometry(info.panel.w, info.panel.h * 1.0), m);
    const mx = compose(t.pos, t.yaw).multiply(new THREE.Matrix4().makeTranslation(info.panel.x, info.panel.y + 0.12, info.panel.z + 0.01));
    mesh.applyMatrix4(mx); scene.add(mesh); panels.push(ct);
    const led = new THREE.Mesh(new THREE.SphereGeometry(0.012, 8, 6), ledMat.clone());
    led.applyMatrix4(compose(t.pos, t.yaw).multiply(new THREE.Matrix4().makeTranslation(...info.controllerLed))); scene.add(led); leds.push(led);
  }
  // hanging lamps
  const lampG = await loadGltf('/polyhaven_models/hanging_industrial_lamp/hanging_industrial_lamp.gltf');
  const lamp = lampG.scene;
  lamp.traverse((o) => { if (o.isMesh && o.material.emissiveMap) o.material.emissiveIntensity = 10; });
  for (const L of Hh.lights) {
    const l = lamp.clone(); l.position.set(L.pos[0], Hh.dims.h, L.pos[2]); scene.add(l);
    const pl = new THREE.PointLight(new THREE.Color(...L.color), lumensToCandela(L.lumens), 0, 2);
    pl.position.set(L.pos[0], Hh.dims.h - 1.2, L.pos[2]); scene.add(pl);
  }
  // props (crates, ladder)
  const byModel = {};
  for (const p of Hh.props) (byModel[p.model] ??= []).push(p);
  for (const [model, list] of Object.entries(byModel)) {
    const g = await loadGltf(`/polyhaven_models/${model}/${model}.gltf`);
    for (const p of list) { const o = g.scene.clone(); o.position.set(...p.pos); o.rotation.y = p.yaw ?? 0;
      o.traverse((c) => { if (c.isMesh) { c.castShadow = true; c.receiveShadow = true; } }); scene.add(o); }
  }
  // morning sun from the east (ESE, 22°) through the open roller door (+X) — shadowed, lights the haze
  const sun = new THREE.DirectionalLight(new THREE.Color(1.0, 0.86, 0.7), P('sun', 7));
  const sdir = new THREE.Vector3(0.93, 0.37, 0.15).normalize();
  sun.position.copy(sdir).multiplyScalar(40); sun.target.position.set(0, 0, 0);
  sun.castShadow = true; sun.shadow.mapSize.set(4096, 4096);
  Object.assign(sun.shadow.camera, { left: -16, right: 16, top: 16, bottom: -16, near: 1, far: 90 });
  sun.shadow.bias = -0.0004; sun.shadow.normalBias = 0.03;
  sun.layers.enable(VOLUME_LAYER);
  scene.add(sun, sun.target);
  const sky2 = new THREE.HemisphereLight(new THREE.Color(0.75, 0.82, 0.95), new THREE.Color(0.3, 0.28, 0.25), 0.25);
  scene.add(sky2);

  // interior reflection probe for the stainless tanks
  const pmrem = new THREE.PMREMGenerator(renderer);
  scene.environment = pmrem.fromScene(scene, 0.0, 0.1, 100, { position: new THREE.Vector3(0, 2.2, 0) }).texture;
  scene.environmentIntensity = P('env', 0.25);

  // volumetric haze
  const vol = new THREE.VolumeNodeMaterial();
  vol.steps = 20;
  vol.offsetNode = bayer16(screenCoordinate);
  vol.scatteringNode = Fn(() => float(P('dens', 0.004)));
  const d = Hh.dims;
  const volMesh = new THREE.Mesh(new THREE.BoxGeometry(d.x1 - d.x0, d.h, d.z1 - d.z0), vol);
  volMesh.position.set((d.x0 + d.x1) / 2, d.h / 2, (d.z0 + d.z1) / 2);
  volMesh.receiveShadow = true; volMesh.layers.disableAll(); volMesh.layers.enable(VOLUME_LAYER);
  scene.add(volMesh);

  renderer.toneMapping = THREE.ACESFilmicToneMapping;
  renderer.toneMappingExposure = P('exp', 0.22);
  const post = interiorPipeline(renderer, scene, camera, { volumeMaterial: vol, bloomStrength: 0.12, giIntensity: P('gi', 0.8), volumeIntensity: P('vol', 1.0), gi: !params.has('nogi') });

  const shots = Object.fromEntries(Object.entries(layout.shots).filter(([, s]) => s.scene === 'hall').map(([k, s]) => [k, s.camera]));
  lookFrom(camera, Object.values(shots)[0].position, Object.values(shots)[0].target);
  let acc = 0, tick = 0;
  return {
    scene, camera, pipeline: post.pipeline, shots, eye: 1.65,
    bounds: { x0: d.x0 + 0.5, x1: d.x1 - 0.5, z0: d.z0 + 0.5, z1: d.z1 - 0.5 },
    update(dt) {
      acc += dt;
      leds.forEach((l, i) => { l.material.emissiveIntensity = (Math.sin((acc + i * 0.37) * 3.2) > 0.3) ? 10 : 0.3; });
      if (acc - tick > 1.0) { tick = acc; panels.forEach((p) => p.redraw(tick)); }
    },
  };
}
