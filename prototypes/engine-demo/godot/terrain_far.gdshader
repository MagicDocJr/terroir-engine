// PROTOTYPE — far terrain: painted albedo (far_albedo.jpg, UV0) with a little fine-scale variation.
shader_type spatial;

uniform sampler2D far_albedo : source_color, filter_linear_mipmap_anisotropic, repeat_disable;
uniform sampler2D detail_nrm : hint_normal, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D detail_ao : hint_default_white, filter_linear_mipmap_anisotropic, repeat_enable;

varying vec3 wpos;

void vertex() {
	wpos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

void fragment() {
	vec3 base = texture(far_albedo, UV).rgb;
	float m = texture(detail_ao, wpos.xz / 9.0 + vec2(0.6, 0.1)).r;
	ALBEDO = base * mix(0.8, 1.15, m);
	NORMAL_MAP = texture(detail_nrm, wpos.xz / 30.0).rgb;
	NORMAL_MAP_DEPTH = 1.5;
	ROUGHNESS = 0.95;
}
