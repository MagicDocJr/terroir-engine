// Vine leaves (from the engine demo): vertex-colour albedo, double-sided, backlit translucency, wind,
// wetness with droplet beads. Bound to the simulation per Block (one material per Block) through:
//   leaf_state  = (downy mildew 0..1, lime chlorosis 0..1, autumn colour 0..1, leaves dropped 0..1)
//   leaf_state2 = (water stress 0..1, red variety 0/1, -, -)
// UV2 = (per-leaf random, position along the shoot: 0 base .. 1 tip).
// Leaves are cards: the outline, veins and relief come from the Variety's cell in the leaf atlas (build_leaf_atlas.py):
//   leaf_atlas RGB = albedo multiplier, A = coverage (alpha-tested); leaf_normal RG = normal, B = vein mask.
shader_type spatial;
render_mode cull_disabled, depth_draw_opaque;

uniform float roughness = 0.55;
uniform vec3 backlight_col = vec3(0.22, 0.32, 0.06);
uniform float wind = 1.0;
uniform sampler2D leaf_atlas : hint_default_white, filter_linear_mipmap_anisotropic, repeat_disable;
uniform sampler2D leaf_normal : hint_normal, filter_linear_mipmap_anisotropic, repeat_disable;
uniform int variety_cell = 0;                  // 0 Riesling, 1 Chardonnay, 2 Pinot Noir, 3 Cabernet Sauvignon
uniform float normal_strength = 0.45;
global uniform float wetness;
global uniform float wind_strength;
uniform vec4 leaf_state = vec4(0.0);
uniform vec4 leaf_state2 = vec4(0.0);

varying float v_id;
varying float v_frac;

float hash(vec2 p) { return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453); }
float vnoise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	return mix(mix(hash(i), hash(i + vec2(1.0, 0.0)), f.x), mix(hash(i + vec2(0.0, 1.0)), hash(i + vec2(1.0, 1.0)), f.x), f.y);
}

void vertex() {
	v_id = UV2.x;
	v_frac = UV2.y;
	// leaf fall: whole leaves collapse to a point (all vertices of a leaf share UV2.x), cheaper than discard
	if (v_id < leaf_state.w) {
		VERTEX = vec3(0.0, -10.0, 0.0);
	}
	vec3 w = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	float h = clamp(VERTEX.y - 0.6, 0.0, 1.5);
	float ph = dot(w.xz, vec2(0.7, 0.4));
	float ws = wind * wind_strength;
	VERTEX.x += ws * h * 0.012 * sin(TIME * (1.7 + ws * 0.6) + ph);
	VERTEX.z += ws * h * 0.008 * sin(TIME * (2.3 + ws * 0.8) + ph * 1.3);
	VERTEX += NORMAL * ws * 0.004 * sin(TIME * 6.0 + ph * 5.0);
	// severe water stress: blades hang (tip drops relative to the petiole)
	VERTEX.y -= leaf_state2.x * UV.y * UV.y * 0.05;
}

void fragment() {
	vec2 cuv = (clamp(UV, vec2(0.002), vec2(0.998)) + vec2(float(variety_cell % 2), float(variety_cell / 2))) * 0.5;
	vec4 det = texture(leaf_atlas, cuv);
	vec3 nt = texture(leaf_normal, cuv).rgb;
	// the silhouette: alpha test, a little lower threshold far away so thin mipped lobes don't vanish
	float mip = log2(max(length(fwidth(UV * 1024.0)), 1.0));
	ALPHA = det.a;
	ALPHA_SCISSOR_THRESHOLD = mix(0.5, 0.25, clamp(mip / 5.0, 0.0, 1.0));
	vec3 detail = det.rgb * 1.3;
	det.a = nt.b;                              // vein mask (for the chlorosis below)
	// relief: normal from the atlas in a derivative-built frame (the vine meshes carry no tangents)
	vec3 dp1 = dFdx(VERTEX);
	vec3 dp2 = dFdy(VERTEX);
	vec2 du1 = dFdx(UV);
	vec2 du2 = dFdy(UV);
	vec3 N = NORMAL;
	vec3 dp2p = cross(dp2, N);
	vec3 dp1p = cross(N, dp1);
	vec3 T = dp2p * du1.x + dp1p * du2.x;
	vec3 B = dp2p * du1.y + dp1p * du2.y;
	float inv = inversesqrt(max(max(dot(T, T), dot(B, B)), 1e-12));
	vec2 nxy = (nt.rg * 2.0 - 1.0) * normal_strength;
	NORMAL = normalize(N + (T * nxy.x + B * nxy.y) * inv);
	vec3 base = COLOR.rgb;
	// lime-induced chlorosis: young leaves turn yellow between the veins (veins stay green)
	float chl = leaf_state.y * mix(0.35, 1.0, smoothstep(0.35, 0.9, v_frac)) * (1.0 - det.a);
	base = mix(base, vec3(0.30, 0.30, 0.05), clamp(chl, 0.0, 0.9));
	// downy mildew: irregular translucent-yellow "oil spots" on a share of the leaves, necrotic brown when severe
	float sick = step(hash(vec2(v_id, 3.7)), leaf_state.x);
	vec2 g = UV * 3.2 + v_id * 17.0;
	float n = vnoise(g) * 0.65 + vnoise(g * 2.7 + 5.0) * 0.35;
	float spot = smoothstep(0.78 - 0.18 * leaf_state.x, 0.86 - 0.18 * leaf_state.x, n) * sick;
	vec3 oil = mix(vec3(0.30, 0.28, 0.05), vec3(0.13, 0.08, 0.03), smoothstep(0.55, 1.0, leaf_state.x) * smoothstep(0.9, 0.97, n));
	base = mix(base, oil, spot * 0.85);
	// water stress: paler, greyer canopy
	base = mix(base, vec3(dot(base, vec3(0.3, 0.59, 0.11))) * vec3(1.05, 1.1, 0.8) + 0.02, leaf_state2.x * 0.45);
	// autumn: leaves turn at different times; white varieties yellow, red varieties red-bronze, then brown
	float a = clamp(leaf_state.z * 1.7 - v_id * 0.7, 0.0, 1.0);
	vec3 autumn = leaf_state2.y > 0.5 ? mix(vec3(0.33, 0.07, 0.03), vec3(0.20, 0.03, 0.04), hash(vec2(v_id, 9.1)))
	                                  : mix(vec3(0.48, 0.36, 0.03), vec3(0.36, 0.30, 0.04), hash(vec2(v_id, 9.1)));
	autumn = mix(autumn, vec3(0.16, 0.09, 0.035), smoothstep(0.75, 1.0, a) * hash(vec2(v_id, 4.2)));
	base = mix(base, autumn, a);
	vec3 alb = base * detail * mix(1.0, 0.82, wetness);
	float rgh = mix(roughness, 0.2, wetness);
	float spec = mix(0.35, 0.55, wetness);
	vec2 gg = UV * vec2(26.0, 26.0);
	vec2 cc = floor(gg);
	vec2 f = fract(gg) - vec2(0.3 + 0.4 * hash(cc + 3.1), 0.3 + 0.4 * hash(cc + 7.7));
	float rr = 0.12 + 0.18 * hash(cc + 1.3);
	float fp = length(fwidth(gg));
	float near_fade = 1.0 - smoothstep(0.35, 0.9, fp);
	float bead = step(hash(cc), 0.2 * wetness) * smoothstep(rr, rr * 0.55, length(f)) * near_fade;
	if (bead > 0.01) {
		NORMAL_MAP = vec3(0.5 + f.x / rr * 0.45, 0.5 + f.y / rr * 0.45, 1.0);
		NORMAL_MAP_DEPTH = 2.0 * bead;
		rgh = mix(rgh, 0.05, bead);
		spec = mix(spec, 0.7, bead);
		alb = mix(alb, alb * 0.7 + vec3(0.02), bead);
	}
	ALBEDO = alb;
	ROUGHNESS = rgh;
	SPECULAR = spec;
	BACKLIGHT = mix(backlight_col, base * 1.2, max(a, spot * 0.6)) * detail * mix(1.0, 0.6, wetness);
}
