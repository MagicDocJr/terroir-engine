// PROTOTYPE — round 2 shared helpers (Three.js r186, WebGPU). See ../../../README_r2.md.
import * as THREE from 'three/webgpu';
import { GLTFLoader } from 'three/addons/loaders/GLTFLoader.js';
import { HDRLoader } from 'three/addons/loaders/HDRLoader.js';

export const params = new URLSearchParams(location.search);
export const CAPTURE = params.has('capture');

const gltf = new GLTFLoader();
const tl = new THREE.TextureLoader();
const hdrLoader = new HDRLoader();
const texCache = new Map();

export async function json(path) { return (await fetch(path)).json(); }

export async function tex(path, { srgb = false, repeat = true, aniso = 16 } = {}) {
  const key = path + srgb;
  if (texCache.has(key)) return texCache.get(key);
  const p = tl.loadAsync(path).then((t) => {
    if (repeat) t.wrapS = t.wrapT = THREE.RepeatWrapping;
    t.anisotropy = aniso;
    t.colorSpace = srgb ? THREE.SRGBColorSpace : THREE.NoColorSpace;
    return t;
  });
  texCache.set(key, p);
  return p;
}

/** Poly Haven style PBR set: {diff, nor, rough, ao} (missing maps resolve to null). */
export async function pbr(set) {
  const get = (m, srgb) => tex(`/textures/${set}/${m}.jpg`, { srgb }).catch(() => null);
  const [diff, nor, rough, ao] = await Promise.all([get('diff', true), get('nor_gl'), get('rough'), get('ao')]);
  return { diff, nor, rough, ao };
}

export async function hdri(path) {
  const t = await hdrLoader.loadAsync(path);
  t.mapping = THREE.EquirectangularReflectionMapping;
  return t;
}

export async function loadGltf(path) { return gltf.loadAsync(path); }

export async function meshesOf(path) {
  const g = await loadGltf(path);
  const out = [];
  g.scene.updateMatrixWorld(true);
  g.scene.traverse((o) => { if (o.isMesh) out.push(o); });
  return out;
}

/** Instanced copies of every sub-mesh in a glb. `materialFor(name, original)` may swap materials. */
export async function instancedFrom(path, matrices, { materialFor = null, cast = true, receive = true } = {}) {
  const parts = [];
  for (const m of await meshesOf(path)) {
    const mat = materialFor ? materialFor(m.material.name.replace(/\.\d+$/, ''), m.material) : m.material;
    const geo = m.geometry.clone().applyMatrix4(m.matrixWorld);
    const im = new THREE.InstancedMesh(geo, mat, matrices.length);
    matrices.forEach((mx, i) => im.setMatrixAt(i, mx));
    im.castShadow = cast; im.receiveShadow = receive;
    im.computeBoundingSphere();
    parts.push(im);
  }
  return parts;
}

export function compose(pos, yaw = 0, scale = 1, roll = 0, rollAxis = 'z') {
  const q = new THREE.Quaternion().setFromEuler(new THREE.Euler(rollAxis === 'x' ? roll : 0, yaw, rollAxis === 'z' ? roll : 0, 'YXZ'));
  return new THREE.Matrix4().compose(new THREE.Vector3(...pos), q, new THREE.Vector3().setScalar(scale));
}

/** Draws into a canvas and returns a CanvasTexture; `draw(ctx, w, h)` is re-callable via `.redraw()`. */
export function canvasTexture(w, h, draw, { srgb = true } = {}) {
  const c = document.createElement('canvas'); c.width = w; c.height = h;
  const ctx = c.getContext('2d');
  const t = new THREE.CanvasTexture(c);
  t.colorSpace = srgb ? THREE.SRGBColorSpace : THREE.NoColorSpace;
  t.anisotropy = 8;
  t.redraw = (...a) => { draw(ctx, w, h, ...a); t.needsUpdate = true; };
  t.redraw();
  return t;
}

export function lumensToCandela(lm) { return lm / (4 * Math.PI); }

export function lookFrom(camera, position, target) {
  camera.position.set(...position);
  camera.lookAt(new THREE.Vector3(...target));
}

/** First-person controls shared by all scenes (WASD + mouse look, Shift run). `ground(x,z)` optional. */
export function fpsControls(camera, dom, { ground = null, eye = 1.7, bounds = null } = {}) {
  const keys = new Set();
  const e = new THREE.Euler().setFromQuaternion(camera.quaternion, 'YXZ');
  let yaw = e.y, pitch = e.x;
  addEventListener('keydown', (ev) => keys.add(ev.code));
  addEventListener('keyup', (ev) => keys.delete(ev.code));
  dom.addEventListener('click', () => dom.requestPointerLock());
  addEventListener('mousemove', (ev) => {
    if (document.pointerLockElement !== dom) return;
    yaw -= ev.movementX * 0.0022; pitch = Math.max(-1.45, Math.min(1.45, pitch - ev.movementY * 0.0022));
    camera.quaternion.setFromEuler(new THREE.Euler(pitch, yaw, 0, 'YXZ'));
  });
  return {
    sync() { const q = new THREE.Euler().setFromQuaternion(camera.quaternion, 'YXZ'); yaw = q.y; pitch = q.x; },
    update(dt) {
      const f = (keys.has('KeyW') ? 1 : 0) - (keys.has('KeyS') ? 1 : 0);
      const s = (keys.has('KeyD') ? 1 : 0) - (keys.has('KeyA') ? 1 : 0);
      if (!f && !s) return false;
      const sp = (keys.has('ShiftLeft') || keys.has('ShiftRight') ? 4 : 1.6) * dt;
      camera.position.x += (-Math.sin(yaw) * f + Math.cos(yaw) * s) * sp;
      camera.position.z += (-Math.cos(yaw) * f - Math.sin(yaw) * s) * sp;
      if (bounds) {
        camera.position.x = Math.min(bounds.x1, Math.max(bounds.x0, camera.position.x));
        camera.position.z = Math.min(bounds.z1, Math.max(bounds.z0, camera.position.z));
      }
      if (ground) camera.position.y = ground(camera.position.x, camera.position.z) + eye;
      else camera.position.y = eye;
      return true;
    },
    keys,
  };
}
