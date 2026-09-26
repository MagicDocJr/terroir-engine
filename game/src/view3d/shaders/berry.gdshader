// Grape berries / inflorescences. Colour comes from the simulation per Block (one material per Block):
//   berry_col    = (ripe colour rgb, ripening progress 0..1 since véraison)
//   berry_state  = (fraction of bunches still hanging, grey rot, powdery mildew, sunburn) — fractions 0..1
//   berry_state2 = (flowering 0/1, noble rot 0..1, red variety 0/1, bunch closure 0..1)
// Vertex colour: R = bunch tone, G = per-berry random. UV2.x = per-bunch random.
shader_type spatial;
render_mode cull_back;

global uniform float wetness;
uniform vec4 berry_col = vec4(0.3, 0.36, 0.07, 0.0);
uniform vec4 berry_state = vec4(1.0, 0.0, 0.0, 0.0);
uniform vec4 berry_state2 = vec4(0.0);

varying float v_bunch;

float h1(float x) { return fract(sin(x * 91.7 + 3.1) * 43758.5453); }

void vertex() {
	v_bunch = UV2.x;
	if (v_bunch >= berry_state.x) {              // picked (or never set): bunch disappears
		VERTEX = vec3(0.0, -10.0, 0.0);
	}
}

void fragment() {
	float r = COLOR.g;
	float tone = COLOR.r;
	vec3 green = mix(vec3(0.24, 0.33, 0.06), vec3(0.34, 0.40, 0.09), tone);
	// véraison is uneven: each berry changes colour at its own moment
	float t = smoothstep(r * 0.55, r * 0.55 + 0.45, berry_col.a);
	vec3 col = mix(green, berry_col.rgb * mix(0.85, 1.12, tone), t);
	float rgh = mix(0.32, berry_state2.z > 0.5 ? 0.55 : 0.38, t);     // red grapes carry a matte bloom
	float spec = 0.5;
	if (berry_state2.x > 0.5) {                  // flowering: cream-green caps and anthers
		col = mix(vec3(0.42, 0.44, 0.16), vec3(0.55, 0.50, 0.22), r);
		rgh = 0.85; spec = 0.2;
	}
	float pick = h1(r * 13.0 + v_bunch * 7.0);
	if (pick < berry_state.y) { col = mix(vec3(0.12, 0.10, 0.08), vec3(0.30, 0.28, 0.25), h1(r * 3.0)); rgh = 0.95; spec = 0.1; }      // grey rot: collapsed, grey fur
	else if (pick < berry_state.y + berry_state.z) { col = mix(col, vec3(0.52, 0.52, 0.49), 0.75); rgh = 0.95; spec = 0.15; }         // powdery: white dusting
	else if (pick < berry_state.y + berry_state.z + berry_state.w) { col = vec3(0.24, 0.14, 0.05); rgh = 0.7; }                     // sunburn: brown, shrivelling
	else if (pick < berry_state.y + berry_state.z + berry_state.w + berry_state2.y) { col = vec3(0.17, 0.09, 0.07); rgh = 0.8; }    // noble rot: brown-violet
	ALBEDO = col * mix(1.0, 0.85, wetness);
	ROUGHNESS = mix(rgh, 0.12, wetness);
	SPECULAR = spec;
	BACKLIGHT = berry_state2.z > 0.5 ? col * 0.15 : col * 0.55;   // white grapes glow when backlit
}
