// PROTOTYPE — vine leaves: vertex-colour albedo, double-sided, backlit translucency, wind (weather-scaled),
// round 2: wetness (glossier, darker) with droplet beads that catch the light.
shader_type spatial;
render_mode cull_disabled, depth_draw_opaque;

uniform float roughness = 0.55;
uniform vec3 backlight_col = vec3(0.22, 0.32, 0.06);
uniform float wind = 1.0;
uniform sampler2D leaf_detail : hint_default_white, filter_linear_mipmap_anisotropic, repeat_disable;
global uniform float wetness;
global uniform float wind_strength;

float hash(vec2 p) { return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453); }

void vertex() {
	vec3 w = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	float h = clamp(VERTEX.y - 0.6, 0.0, 1.5);
	float ph = dot(w.xz, vec2(0.7, 0.4));
	float ws = wind * wind_strength;
	VERTEX.x += ws * h * 0.012 * sin(TIME * (1.7 + ws * 0.6) + ph);
	VERTEX.z += ws * h * 0.008 * sin(TIME * (2.3 + ws * 0.8) + ph * 1.3);
	VERTEX += NORMAL * ws * 0.004 * sin(TIME * 6.0 + ph * 5.0);
}

void fragment() {
	// COLOR_0 arrives linear, as authored. leaf_detail: shared veins/mottling multiplier (mean ~0.69).
	vec3 detail = texture(leaf_detail, UV).rgb * 1.45;
	vec3 alb = COLOR.rgb * detail * mix(1.0, 0.82, wetness);
	float rgh = mix(roughness, 0.2, wetness);
	float spec = mix(0.35, 0.55, wetness);
	// droplets: small beads in leaf UV space, only when wet
	vec2 g = UV * vec2(26.0, 26.0);
	vec2 cid = floor(g);
	vec2 f = fract(g) - vec2(0.3 + 0.4 * hash(cid + 3.1), 0.3 + 0.4 * hash(cid + 7.7));
	float rr = 0.12 + 0.18 * hash(cid + 1.3);
	// fewer, varied beads; fade them out with distance (UV footprint) so far leaves don't sparkle-alias
	float fp = length(fwidth(g));
	float near_fade = 1.0 - smoothstep(0.35, 0.9, fp);
	float bead = step(hash(cid), 0.2 * wetness) * smoothstep(rr, rr * 0.55, length(f)) * near_fade;
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
	BACKLIGHT = backlight_col * detail * mix(1.0, 0.6, wetness);
}
