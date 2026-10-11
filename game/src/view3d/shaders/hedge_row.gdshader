// The neighbours' vineyards at a distance (vineyard.gd _build_hedges): each row a long, low prism of canopy that reads as
// a hedge of vines from 40 m to about a kilometre. Leafy, broken edges (alpha-tested noise), clumps of light and shade,
// darker deep in the canopy, translucent against the sun. The season shrinks it to a band of bare wood in winter and turns
// it in autumn; "bush" breaks the row into single staked vines (Mosel Einzelpfahl). Look only.
// Mesh: x across the row (-0.5..0.5), y up (0..1), z along the row (0..1); the instance scales it.
shader_type spatial;
render_mode cull_disabled, depth_draw_opaque;

uniform vec3 leaf_a = vec3(0.055, 0.120, 0.025);
uniform vec3 leaf_b = vec3(0.115, 0.190, 0.045);
uniform vec3 wood = vec3(0.16, 0.11, 0.07);
uniform float canopy = 1.0;          // 0 bare wood .. 1 full summer canopy
uniform float autumn = 0.0;          // 0 green .. 1 autumn colour
uniform float red = 0.0;             // red variety: autumn turns red-bronze, else yellow
uniform float bush = 0.0;            // 1: separate vines along the row (single stakes)
uniform float spacing = 1.2;         // m between vines along the row

varying vec3 wp;
varying vec2 lp;
varying float along;

float hash(vec2 p) { return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453); }
float vnoise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	return mix(mix(hash(i), hash(i + vec2(1.0, 0.0)), f.x), mix(hash(i + vec2(0.0, 1.0)), hash(i + vec2(1.0, 1.0)), f.x), f.y);
}

void vertex() {
	vec3 w0 = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	lp = VERTEX.xy;
	along = dot(w0.xz, normalize((MODEL_MATRIX * vec4(0.0, 0.0, 1.0, 0.0)).xz));
	float c = canopy;
	float lump = 1.0;
	if (bush > 0.5) {
		// each staked vine a rounded bush, the gaps between them narrower
		float s = 0.5 + 0.5 * cos(along / spacing * 6.2831853);
		lump = mix(0.45, 1.0, pow(s, 0.6));
	}
	// winter: a thin band of trunks and wood low down; summer: the full hedge
	VERTEX.x *= mix(0.10, 1.0, c) * lump;
	VERTEX.y = VERTEX.y * mix(0.30, 1.0, c) * mix(1.0, lump, 0.5);
	wp = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

void fragment() {
	float n1 = vnoise(vec2(along * 2.2, wp.y * 2.6) + wp.xz * 0.37);
	float n2 = vnoise(vec2(along * 7.5, wp.y * 8.0) + 13.0);
	float n3 = vnoise(vec2(along * 19.0, wp.y * 21.0) + 41.0);
	// leafy, broken outline: the top and the sides are cut where the leaf noise is thin
	float rim = max(smoothstep(0.62, 1.0, lp.y), smoothstep(0.30, 0.5, abs(lp.x)));
	float cut = rim * (0.75 - 0.55 * (n2 * 0.6 + n3 * 0.4));
	ALPHA = 1.0 - step(0.42, cut) * step(0.15, canopy);
	ALPHA_SCISSOR_THRESHOLD = 0.5;
	// clumps of leaves catching the light, darker deep inside and low down
	vec3 leaf = mix(leaf_a, leaf_b, smoothstep(0.25, 0.85, n1));
	leaf *= mix(0.55, 1.12, smoothstep(0.0, 0.9, lp.y)) * mix(0.78, 1.18, n2) * mix(0.9, 1.08, n3);
	vec3 aut = red > 0.5 ? mix(vec3(0.30, 0.06, 0.03), vec3(0.20, 0.035, 0.04), n1) : mix(vec3(0.45, 0.34, 0.035), vec3(0.32, 0.27, 0.04), n1);
	leaf = mix(leaf, aut * mix(0.7, 1.1, n2), clamp(autumn * 1.4 - n3 * 0.4, 0.0, 1.0));
	vec3 col = mix(wood * mix(0.8, 1.1, n2), leaf, smoothstep(0.1, 0.35, canopy));
	ALBEDO = col;
	ROUGHNESS = 0.85;
	SPECULAR = 0.25;
	// leaf-bumpy shading: the canopy's surface tilts with the clumps
	NORMAL = normalize(NORMAL + vec3(n2 - 0.5, n1 - 0.5, n3 - 0.5) * 0.9);
	BACKLIGHT = leaf * 0.55 * smoothstep(0.1, 0.4, canopy);
}
