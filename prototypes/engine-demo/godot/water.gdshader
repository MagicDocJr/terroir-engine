// PROTOTYPE — river: dark, glossy, slowly moving noise normals.
shader_type spatial;
render_mode cull_back;

uniform sampler2D wave_nrm : hint_normal, filter_linear_mipmap, repeat_enable;
uniform vec3 deep = vec3(0.012, 0.030, 0.032);

varying vec3 wpos;

void vertex() {
	wpos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

void fragment() {
	vec2 flow = vec2(TIME * 0.02, 0.0);
	vec3 n1 = texture(wave_nrm, wpos.xz / 18.0 + flow).rgb;
	vec3 n2 = texture(wave_nrm, wpos.xz / 7.0 - flow * 1.7).rgb;
	ALBEDO = deep;
	NORMAL_MAP = normalize(n1 + n2 - 1.0) * 0.5 + 0.5;
	NORMAL_MAP_DEPTH = 0.35;
	ROUGHNESS = 0.03;
	SPECULAR = 0.5;
}
