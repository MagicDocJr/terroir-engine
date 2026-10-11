// River (from the engine demo): dark, glossy, slowly moving noise normals. Its edge fades over the last metres of depth
// (from the depth buffer), wider far away where the land under it is coarse, so the bank never shows as a hard line.
shader_type spatial;
render_mode cull_back, blend_mix, depth_draw_always;

uniform sampler2D wave_nrm : hint_normal, filter_linear_mipmap, repeat_enable;
uniform vec3 deep = vec3(0.012, 0.030, 0.032);
uniform vec3 shallow = vec3(0.045, 0.052, 0.040);   // silty water over the bank
uniform sampler2D depth_tex : hint_depth_texture, filter_linear, repeat_disable;
uniform vec2 banks = vec2(-1e6, 1e6);                // z of the near and the far bank (the water lies between)

float shore_h(float x) { return fract(sin(x * 127.1) * 43758.5453); }
float shore_n(float x) { float i = floor(x); float f = fract(x); f = f * f * (3.0 - 2.0 * f); return mix(shore_h(i), shore_h(i + 1.0), f); }

varying vec3 wpos;

void vertex() {
	wpos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

void fragment() {
	vec2 flow = vec2(TIME * 0.02, 0.0);
	vec3 n1 = texture(wave_nrm, wpos.xz / 18.0 + flow).rgb;
	vec3 n2 = texture(wave_nrm, wpos.xz / 7.0 - flow * 1.7).rgb;
	// water depth along the view ray: the scene behind minus the water surface (linear eye depth)
	float zs = texture(depth_tex, SCREEN_UV).r;
	vec4 sv = INV_PROJECTION_MATRIX * vec4(SCREEN_UV * 2.0 - 1.0, zs, 1.0);
	float scene_d = -sv.z / sv.w;
	float surf_d = -VERTEX.z;
	float under = max(scene_d - surf_d, 0.0);
	float far_k = smoothstep(40.0, 700.0, surf_d);
	float fade_w = mix(1.2, 14.0, far_k);                // metres of depth over which the bank dissolves
	float a = smoothstep(0.0, fade_w, under);
	// the shoreline itself: a wavy line (no straight edge), softened over more metres the farther it is
	float wig = (shore_n(wpos.x / 23.0) - 0.5) * 7.0 + (shore_n(wpos.x / 6.5 + 17.0) - 0.5) * 2.5;
	float into = min(wpos.z - banks.x, banks.y - wpos.z) + wig * (0.4 + 0.6 * far_k) - 1.5;
	a *= smoothstep(0.0, mix(1.5, 9.0, far_k), into);
	ALPHA = a;
	ALBEDO = mix(shallow, deep, smoothstep(0.0, fade_w * 1.5, under));
	NORMAL_MAP = normalize(n1 + n2 - 1.0) * 0.5 + 0.5;
	NORMAL_MAP_DEPTH = 0.35;
	ROUGHNESS = 0.03;
	SPECULAR = 0.5;
}
