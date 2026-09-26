// PROTOTYPE — round 2 post-processing chains.
import * as THREE from 'three/webgpu';
import {
  pass, mrt, output, normalView, diffuseColor, velocity, packNormalToRGB, unpackRGBToNormal, sample,
  vec4, vec3, float, mix, renderOutput, uniform, screenUV,
} from 'three/tsl';
import { ssgi } from 'three/addons/tsl/display/SSGINode.js';
import { ao } from 'three/addons/tsl/display/GTAONode.js';
import { traa } from 'three/addons/tsl/display/TRAANode.js';
import { bloom } from 'three/addons/tsl/display/BloomNode.js';
import { smaa } from 'three/addons/tsl/display/SMAANode.js';
import { gaussianBlur } from 'three/addons/tsl/display/GaussianBlurNode.js';

export const VOLUME_LAYER = 10;

/**
 * Interior chain: SSGI (bounce light + AO) → optional low-res volumetric light pass → bloom → TRAA.
 * Volumetric meshes must live on VOLUME_LAYER only; their material gets `depthNode` wired to the scene depth.
 */
export function interiorPipeline(renderer, scene, camera, { volumeMaterial = null, gi = true, bloomStrength = 0.12,
  giIntensity = 1.0, volumeIntensity = 1.0, slices = 2, steps = 10 } = {}) {
  const pipeline = new THREE.RenderPipeline(renderer);
  const scenePass = pass(scene, camera);
  scenePass.setMRT(mrt({ output, diffuseColor, normal: packNormalToRGB(normalView), velocity }));
  const color = scenePass.getTextureNode('output');
  const diffuse = scenePass.getTextureNode('diffuseColor');
  const depth = scenePass.getTextureNode('depth');
  const normalTex = scenePass.getTextureNode('normal');
  const vel = scenePass.getTextureNode('velocity');
  scenePass.getTexture('normal').type = THREE.UnsignedByteType;
  scenePass.getTexture('diffuseColor').type = THREE.UnsignedByteType;
  const sceneNormal = sample((u) => unpackRGBToNormal(normalTex.sample(u)));

  let lit = color;
  const uGi = uniform(giIntensity);
  let giPass = null;
  if (gi) {
    giPass = ssgi(color, depth, sceneNormal, camera);
    giPass.sliceCount.value = slices;
    giPass.stepCount.value = steps;
    giPass.radius.value = 6;
    giPass.thickness.value = 0.6;
    lit = vec4(color.rgb.mul(giPass.a).add(diffuse.rgb.mul(giPass.rgb).mul(uGi)), color.a);
  }
  const uVol = uniform(volumeIntensity);
  if (volumeMaterial) {
    const volPass = pass(scene, camera, { depthBuffer: false });
    const layers = new THREE.Layers(); layers.disableAll(); layers.enable(VOLUME_LAYER);
    volPass.setLayers(layers);
    volPass.setResolutionScale(0.5);
    volumeMaterial.depthNode = depth.sample(screenUV);
    const volBlur = gaussianBlur(volPass, 3);
    lit = vec4(lit.rgb.add(volBlur.rgb.mul(uVol)), lit.a);
  }
  const withBloom = lit.add(bloom(lit, bloomStrength, 0.4, 0.9));
  const aa = traa(withBloom, depth, vel, camera);
  pipeline.outputNode = aa;
  return { pipeline, scenePass, depth, uGi, uVol, giPass };
}

/** Outdoor chain (round-1 style): GTAO + bloom + SMAA; volumetric/godray composite hooks. */
export function outdoorPipeline(renderer, scene, camera, { bloomStrength = 0.08, extra = null } = {}) {
  const pipeline = new THREE.RenderPipeline(renderer);
  const scenePass = pass(scene, camera);
  scenePass.setMRT(mrt({ output, normal: normalView }));
  const color = scenePass.getTextureNode('output');
  const depth = scenePass.getTextureNode('depth');
  const aoPass = ao(depth, scenePass.getTextureNode('normal'), camera);
  aoPass.resolutionScale = 0.5;
  aoPass.radius.value = 0.6;
  aoPass.distanceExponent.value = 1.5;
  let lit = vec4(color.rgb.mul(mix(float(1), aoPass.getTextureNode().r, 0.75)), color.a);
  if (extra) lit = extra(lit, { depth, color, scenePass });
  const withBloom = lit.add(bloom(lit, bloomStrength, 0.35, 0.95));
  pipeline.outputColorTransform = false;
  pipeline.outputNode = smaa(renderOutput(withBloom));
  return { pipeline, scenePass, depth };
}
