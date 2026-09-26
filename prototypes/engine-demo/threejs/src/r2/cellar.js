// PROTOTYPE — vaulted Mosel slate cellar: barriques + Fuder, chalk labels, caged sconces with shadowed point
// lights, SSGI bounce light, interior reflection probe, volumetric haze in the light cones.
import * as THREE from 'three/webgpu';
import {
  texture, uv, vec2, vec3, vec4, float, mix, smoothstep, vertexColor, attribute, positionWorld, length, clamp,
  normalMap, Fn, time, screenCoordinate, positionLocal, sin, luminance,
} from 'three/tsl';
import { mergeGeometries } from 'three/addons/utils/BufferGeometryUtils.js';
import { bayer16 } from 'three/addons/tsl/math/Bayer.js';
import { pbr, instancedFrom, compose, canvasTexture, lumensToCandela, loadGltf, lookFrom, params } from './common.js';
const P = (k, d) => (params.has(k) ? parseFloat(params.get(k)) : d);
import { interiorPipeline, VOLUME_LAYER } from './post.js';

const M = '/models_r2/';

async function materials() {
  const [wall, floor, oak, rust] = await Promise.all([pbr('castle_wall_slates'), pbr('cobblestone_floor_04'), pbr('oak_veneer_01'), pbr('rusty_metal_02')]);
  const wallMat = new THREE.MeshStandardNodeMaterial();
  {
    const u = uv().mul(0.42);
    const damp = smoothstep(0.0, 1.1, positionWorld.y);                    // damp, darker base of the walls
    const mould = smoothstep(0.55, 0.8, texture(wall.rough, uv().mul(0.07)).r).mul(0.35);
    const d0 = texture(wall.diff, u).rgb;
    const slateTone = mix(vec3(luminance(d0)), d0, 0.6).mul(vec3(0.42, 0.44, 0.50));   // darker, cooler Devonian slate
    wallMat.colorNode = slateTone.mul(d0.mul(1.6)).mul(mix(0.5, 1.0, damp)).mul(float(1).sub(mould));
    wallMat.normalNode = normalMap(texture(wall.nor, u), vec2(1.4));
    wallMat.roughnessNode = texture(wall.rough, u).r.mul(mix(0.6, 0.9, damp)).add(0.12);
    wallMat.aoNode = texture(wall.ao, u).r;
  }
  const floorMat = new THREE.MeshStandardNodeMaterial();
  {
    const u = uv().mul(0.55);
    floorMat.colorNode = texture(floor.diff, u).rgb.mul(0.72);
    floorMat.normalNode = normalMap(texture(floor.nor, u), vec2(1.2));
    floorMat.roughnessNode = texture(floor.rough, u).r.mul(0.62);            // damp sheen
    floorMat.aoNode = texture(floor.ao, u).r;
  }
  const oakMat = (dark = 1.0) => {
    const m = new THREE.MeshStandardNodeMaterial();
    const p = attribute('position', 'vec3');
    const u = uv().mul(vec2(1.0, 0.8));
    const stain = smoothstep(0.26, 0.33, p.y).mul(float(1).sub(smoothstep(0.05, 0.22, length(vec2(p.x, p.z.mul(0.7))))));
    const drip = smoothstep(0.1, 0.33, p.y).mul(float(1).sub(smoothstep(0.0, 0.06, p.x.abs()))).mul(0.6);
    const wine = clamp(stain.add(drip.mul(texture(oak.rough, u.mul(3)).r)), 0, 1);
    const base = texture(oak.diff, u).rgb.mul(vec3(0.34, 0.235, 0.17)).mul(vertexColor().rgb).mul(dark);
    m.colorNode = mix(base, vec3(0.16, 0.035, 0.05), wine.mul(0.85));
    m.roughnessNode = mix(texture(oak.rough, u).r.mul(0.9).add(0.1), float(0.35), wine);
    m.normalNode = normalMap(texture(oak.nor, u), vec2(0.6));
    return m;
  };
  const hoop = new THREE.MeshStandardNodeMaterial({ metalness: 0.75 });
  hoop.colorNode = mix(vec3(0.035, 0.035, 0.037), texture(rust.diff, uv().mul(vec2(3, 0.5))).rgb.mul(0.6), 0.35);
  hoop.roughnessNode = texture(rust.rough, uv().mul(vec2(3, 0.5))).r.mul(0.5).add(0.3);
  const bung = new THREE.MeshStandardMaterial({ color: new THREE.Color(0.8, 0.8, 0.76), roughness: 0.55 });
  const rack = new THREE.MeshStandardNodeMaterial({ side: THREE.DoubleSide });
  rack.colorNode = texture(oak.diff, uv().mul(vec2(0.25, 1))).rgb.mul(vec3(0.28, 0.2, 0.14));
  rack.roughness = 0.8;
  const door = new THREE.MeshStandardNodeMaterial();
  door.colorNode = texture(oak.diff, uv().mul(vec2(1, 2.2))).rgb.mul(vec3(0.35, 0.24, 0.16));
  door.roughness = 0.7;
  return { wall: wallMat, floor: floorMat, oak: oakMat(1.0), oakHead: oakMat(0.92), oakFuder: oakMat(0.8), hoop, bung, rack, door };
}

// ------------------------------------------------------------------ chalk labels (one atlas, one draw call)
function chalkAtlas(labels) {
  const cols = 16, cell = 256, rows = Math.ceil(labels.length / cols);
  const tex = canvasTexture(cols * cell, rows * cell, (ctx, w, h) => {
    ctx.clearRect(0, 0, w, h);
    labels.forEach((lines, i) => {
      const x = (i % cols) * cell, y = Math.floor(i / cols) * cell;
      ctx.save(); ctx.beginPath(); ctx.rect(x + 4, y + 4, cell - 8, cell - 8); ctx.clip();
      ctx.translate(x + cell / 2, y + cell / 2); ctx.rotate(((i * 37) % 11 - 5) * 0.012);
      ctx.fillStyle = 'rgba(242,240,232,0.95)'; ctx.textAlign = 'center'; ctx.textBaseline = 'middle';
      lines.forEach((ln, k) => {
        const size = k === 0 ? 48 : 23;
        ctx.font = `${k === 0 ? 700 : 400} ${size}px "Segoe Print", "Bradley Hand", "Comic Sans MS", cursive`;
        ctx.fillText(ln, 0, -58 + (k === 0 ? 0 : 34 + k * 34));
      });
      ctx.restore();
    });
    const img = ctx.getImageData(0, 0, w, h), d = img.data;           // chalk grain
    for (let p = 0; p < d.length; p += 4) {
      if (!d[p + 3]) continue;
      const n = Math.random();
      d[p + 3] = n < 0.18 ? d[p + 3] * 0.15 : d[p + 3] * (0.65 + 0.35 * n);
    }
    ctx.putImageData(img, 0, 0);
  });
  tex.wrapS = tex.wrapT = THREE.ClampToEdgeWrapping;
  return { tex, cols, rows };
}

function labelGeometry(items, atlas, size) {
  const geos = items.map(({ matrix, index, s }) => {
    const g = new THREE.PlaneGeometry(s ?? size, s ?? size);
    const u0 = (index % atlas.cols) / atlas.cols, v0 = 1 - (Math.floor(index / atlas.cols) + 1) / atlas.rows;
    const uvA = g.attributes.uv;
    for (let i = 0; i < uvA.count; i++) uvA.setXY(i, u0 + uvA.getX(i) / atlas.cols, v0 + uvA.getY(i) / atlas.rows);
    g.applyMatrix4(matrix);
    return g;
  });
  return mergeGeometries(geos);
}

// ------------------------------------------------------------------ build
export async function build({ renderer, layout }) {
  const C = layout.cellar;
  const scene = new THREE.Scene();
  scene.background = new THREE.Color(0, 0, 0);
  const camera = new THREE.PerspectiveCamera(60, renderer.domElement.width / renderer.domElement.height, 0.05, 80);
  const mats = await materials();

  // room
  const room = await loadGltf(M + C.model);
  room.scene.traverse((o) => {
    if (!o.isMesh) return;
    const n = o.material.name;
    o.material = n.startsWith('cellar_wall') ? mats.wall : n.startsWith('cellar_floor') ? mats.floor
      : n.startsWith('rack') ? mats.rack : n.startsWith('cellar_door') ? mats.door : o.material;
    o.castShadow = true; o.receiveShadow = true;
  });
  scene.add(room.scene);

  // barrels
  const barrelMat = (name) => ({ barrel_oak: mats.oak, barrel_head: mats.oakHead, barrel_hoop: mats.hoop, barrel_bung: mats.bung, rack_wood: mats.rack })[name];
  const bqM = C.barriques.map((b) => compose(b.pos, b.yaw, 1, b.roll, 'z'));
  for (const im of await instancedFrom(M + (C.barriqueModel ?? (typeof C.barrique === 'string' ? C.barrique : 'barrique.glb')), bqM, { materialFor: barrelMat })) scene.add(im);
  const fdM = C.fuder.map((b) => compose(b.pos, b.yaw, 1, 0, 'z'));
  const fuderMat = (name) => (name === 'barrel_oak' || name === 'barrel_head' ? mats.oakFuder : barrelMat(name));
  for (const im of await instancedFrom(M + (C.fuderModel ?? 'fuder.glb'), fdM, { materialFor: fuderMat })) scene.add(im);

  // chalk labels on the aisle-facing head (local -z) of every cask
  const labels = [
    ...C.barriques.map(({ label: l }) => [`Fass ${l.fass}`, `${l.lot.replace(' (Steillage)', '').replace('Spätburgunder', 'Spätburg.')} ${l.vintage}`, `${l.oak} · ${l.toast}`, l.fill]),
    ...C.fuder.map(({ label: l }) => [`Fuder ${l.fuder}`, `${l.lot}`, `${l.vintage} · ${l.litres} L`]),
  ];
  const atlas = chalkAtlas(labels);
  const headOffset = (L) => L / 2 - 0.035 + 0.004;
  const items = [
    ...C.barriques.map((b, i) => ({ index: i, matrix: compose(b.pos, b.yaw).multiply(new THREE.Matrix4().makeRotationY(Math.PI).setPosition(0, 0, -headOffset(0.95))) })),
    ...C.fuder.map((b, i) => ({ index: C.barriques.length + i, s: 0.62, matrix: compose(b.pos, b.yaw).multiply(new THREE.Matrix4().makeRotationY(Math.PI).setPosition(0, -0.05, -headOffset(1.22) - 0.012)) })),
  ];
  const chalkMat = new THREE.MeshStandardNodeMaterial({ map: atlas.tex, alphaTest: 0.25, polygonOffset: true, polygonOffsetFactor: -2, roughness: 0.95 });
  chalkMat.color = new THREE.Color(0.8, 0.79, 0.74);
  const chalk = new THREE.Mesh(labelGeometry(items, atlas, 0.34), chalkMat);
  chalk.receiveShadow = true;
  scene.add(chalk);

  // lamps: caged sconce model (variant "a") + emissive bulb + shadowed point light
  const sconce = await loadGltf('/polyhaven_models/industrial_caged_sconce/industrial_caged_sconce.gltf');
  const sconceMesh = sconce.scene.getObjectByName('industrial_caged_sconce_a');
  sconceMesh.position.set(0, 0, 0);
  sconceMesh.material.emissiveIntensity = 6;
  const bulbMat = new THREE.MeshStandardNodeMaterial({ emissive: new THREE.Color(1.0, 0.62, 0.3), emissiveIntensity: 30, color: 0x111111 });
  const lights = [];
  for (const L of C.lights) {
    const col = new THREE.Color(...L.color);
    const pos = new THREE.Vector3(...L.pos);
    let lightPos = pos.clone();
    if (L.type === 'sconce') {
      const s = sconceMesh.clone();
      const f = new THREE.Vector3(...L.facing);
      s.position.copy(pos).addScaledVector(f, -0.02);
      s.rotation.y = Math.atan2(f.x, f.z);
      s.castShadow = false;
      scene.add(s);
      lightPos = pos.clone().addScaledVector(f, 0.13).add(new THREE.Vector3(0, 0.02, 0));
    } else {
      const cord = new THREE.Mesh(new THREE.CylinderGeometry(0.004, 0.004, 6 - pos.y), new THREE.MeshStandardMaterial({ color: 0x111111 }));
      cord.position.set(pos.x, (6 + pos.y) / 2 + 0.05, pos.z); scene.add(cord);
      lightPos = pos.clone();
    }
    const bulb = new THREE.Mesh(new THREE.SphereGeometry(0.03, 16, 12), bulbMat);
    bulb.position.copy(lightPos); scene.add(bulb);
    const pl = new THREE.PointLight(col, lumensToCandela(L.lumens), 0, 2);
    pl.position.copy(lightPos).add(new THREE.Vector3(0, 0, 0));
    pl.castShadow = true;
    pl.shadow.mapSize.set(1024, 1024);
    pl.shadow.bias = -0.002;
    pl.shadow.normalBias = 0.02;
    pl.shadow.camera.near = 0.05;
    pl.shadow.camera.far = 25;
    pl.layers.enable(VOLUME_LAYER);
    scene.add(pl);
    lights.push(pl);
  }
  // faint cool spill from the door crack (so the far end is not pitch black)
  const spill = new THREE.PointLight(new THREE.Color(0.7, 0.8, 1.0), 2.0, 0, 2);
  spill.position.set(-10.7, 1.2, 0); spill.layers.enable(VOLUME_LAYER); scene.add(spill);

  // interior reflection/irradiance probe (rendered once from the aisle)
  const pmrem = new THREE.PMREMGenerator(renderer);
  const probe = pmrem.fromScene(scene, 0.0, 0.1, 60, { position: new THREE.Vector3(0, 1.4, 0) });
  scene.environment = probe.texture;
  scene.environmentIntensity = P('env', 0.06);

  // volumetric haze (low-res raymarch lit by the shadowed point lights)
  const vol = new THREE.VolumeNodeMaterial();
  vol.steps = 16;
  vol.offsetNode = bayer16(screenCoordinate);
  vol.scatteringNode = Fn(({ positionRay }) => {
    const n = sin(positionRay.x.mul(1.3).add(time.mul(0.07))).mul(sin(positionRay.z.mul(1.7).sub(time.mul(0.05)))).mul(0.5).add(0.5);
    return mix(float(0.55), float(1.0), n).mul(0.05);
  });
  const volMesh = new THREE.Mesh(new THREE.BoxGeometry(C.dims.L, C.dims.wall_h + C.dims.W / 2, C.dims.W), vol);
  volMesh.position.y = (C.dims.wall_h + C.dims.W / 2) / 2;
  volMesh.receiveShadow = true;
  volMesh.layers.disableAll(); volMesh.layers.enable(VOLUME_LAYER);
  scene.add(volMesh);

  renderer.toneMapping = ({ agx: THREE.AgXToneMapping, aces: THREE.ACESFilmicToneMapping, neutral: THREE.NeutralToneMapping })[params.get('tm') || 'aces'];
  renderer.toneMappingExposure = P('exp', 0.45);
  const post = interiorPipeline(renderer, scene, camera, { volumeMaterial: vol, bloomStrength: 0.18, giIntensity: P('gi', 0.7), volumeIntensity: P('vol', 0.7), gi: !params.has('nogi') });

  const shots = Object.fromEntries(Object.entries(layout.shots).filter(([, s]) => s.scene === 'cellar').map(([k, s]) => [k, s.camera]));
  const first = Object.values(shots)[0];
  lookFrom(camera, first.position, first.target);
  return {
    scene, camera, pipeline: post.pipeline,
    bounds: { x0: -10.6, x1: 10.6, z0: -0.9, z1: 0.9 }, eye: 1.65,
    shots,
    update() {},
    tune: post,
  };
}
