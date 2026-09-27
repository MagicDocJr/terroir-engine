// Field workers (one MultiMesh for every person in the view; workers.gd sets the transforms). The pose is done here:
// UV2.x = part code from game/tools/blender/build_winery.py (build_workers):
//   1/2 left/right leg, 3/4 left/right arm, 5 torso/head/hat, 6 bucket, 7 backpack sprayer.
// INSTANCE_CUSTOM = (bend 0..1, walk phase 0..1, walk amount 0..1, item: 0 none, 1 bucket on the ground,
// 2 bucket carried, 3 backpack sprayer). Colours: `kind` picks the part's palette; each person gets its own
// shirt/hat/skin/trousers from INSTANCE_ID.
shader_type spatial;
render_mode cull_back;

uniform int kind = 1;              // 0 skin, 1 shirt, 2 trousers, 3 hat, 4 gear

varying flat int v_id;
varying float v_part;

vec3 rot_x(vec3 p, float py, float a) {
	float y = p.y - py;
	return vec3(p.x, py + y * cos(a) - p.z * sin(a), y * sin(a) + p.z * cos(a));
}

void vertex() {
	v_id = INSTANCE_ID;
	float part = floor(UV2.x + 0.5);
	v_part = part;
	vec4 c = INSTANCE_CUSTOM;
	float item = floor(c.a + 0.5);
	bool hide = (part == 6.0 && (item < 0.5 || item > 2.5)) || (part == 7.0 && abs(item - 3.0) > 0.5);
	float sw = sin(c.g * TAU) * c.b;
	vec3 v = VERTEX;
	vec3 n = NORMAL;
	if (part == 1.0 || part == 2.0) {
		float a = (part == 1.0 ? 1.0 : -1.0) * sw * 0.45;
		v = rot_x(v, 0.92, a);
		n = rot_x(n, 0.0, a);
	}
	if (part == 3.0 || part == 4.0) {
		float a = (part == 3.0 ? -1.0 : 1.0) * sw * 0.4 - c.r * 0.5;     // swing when walking, reach when bending
		if (part == 4.0 && item > 1.5 && item < 2.5) a = 0.0;          // the bucket arm hangs straight
		v = rot_x(v, 1.42, a);
		n = rot_x(n, 0.0, a);
	}
	if (part == 6.0 && item > 1.5) {
		v += vec3(-0.06, 0.47, 0.0);                                    // bucket lifted into the right hand
	}
	if (part >= 3.0 && part != 6.0) {
		float a = -c.r * 1.15;                                         // bend forward at the hips
		v = rot_x(v, 0.92, a);
		n = rot_x(n, 0.0, a);
	}
	if (hide) {
		v = vec3(0.0, 0.9, 0.0);
	}
	VERTEX = v;
	NORMAL = n;
}

float h1(int i, float s) { return fract(sin(float(i) * 12.9898 + s) * 43758.5453); }

void fragment() {
	vec3 col;
	float rgh = 0.85;
	if (kind == 0) {
		col = mix(vec3(0.55, 0.36, 0.25), vec3(0.30, 0.18, 0.11), h1(v_id, 1.7));
		rgh = 0.6;
	} else if (kind == 1) {
		int k = int(h1(v_id, 3.1) * 6.0);
		col = k == 0 ? vec3(0.62, 0.12, 0.08) : k == 1 ? vec3(0.12, 0.25, 0.48) : k == 2 ? vec3(0.75, 0.70, 0.60)
			: k == 3 ? vec3(0.20, 0.35, 0.18) : k == 4 ? vec3(0.85, 0.45, 0.08) : vec3(0.35, 0.35, 0.38);
	} else if (kind == 2) {
		col = mix(vec3(0.10, 0.13, 0.22), vec3(0.28, 0.24, 0.18), step(0.6, h1(v_id, 5.3)));
	} else if (kind == 3) {
		int k = int(h1(v_id, 7.9) * 3.0);
		col = k == 0 ? vec3(0.72, 0.62, 0.36) : k == 1 ? vec3(0.10, 0.18, 0.40) : vec3(0.65, 0.12, 0.10);
	} else {
		col = vec3(0.06, 0.06, 0.065);
		rgh = 0.55;
		if (v_part > 5.5 && v_part < 6.5) { col = mix(vec3(0.75, 0.55, 0.05), vec3(0.55, 0.1, 0.07), step(0.5, h1(v_id, 2.2))); rgh = 0.5; }   // picking bucket
		if (v_part > 6.5) { col = vec3(0.8, 0.78, 0.7); rgh = 0.45; }                                                                       // sprayer tank
	}
	ALBEDO = col;
	ROUGHNESS = rgh;
}
