// PROTOTYPE — near terrain: Devonian slate soil blended with grass by COLOR.r (grass mask).
shader_type spatial;
render_mode blend_mix, cull_back, depth_draw_opaque;

uniform sampler2D rock_alb : source_color, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D rock_nrm : hint_normal, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D rock_rgh : hint_default_white, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D rock_ao : hint_default_white, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D grass_alb : source_color, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D grass_nrm : hint_normal, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D grass_rgh : hint_default_white, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D grass_ao : hint_default_white, filter_linear_mipmap_anisotropic, repeat_enable;
uniform vec3 slate_tint = vec3(0.70, 0.78, 0.95);
uniform vec3 grass_tint = vec3(0.78, 0.95, 0.55);
uniform float slate_desat = 0.65;
uniform float slate_bright = 1.0;

varying vec3 wpos;

void vertex() {
	wpos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

void fragment() {
	vec2 uv = wpos.xz / 3.0;
	vec2 uv2 = wpos.xz / 10.7 + vec2(0.37, 0.61);
	vec2 guv = wpos.xz / 2.3;
	vec3 ra = mix(texture(rock_alb, uv).rgb, texture(rock_alb, uv2).rgb, 0.35);
	float lum = dot(ra, vec3(0.299, 0.587, 0.114));
	float macro = mix(0.78, 1.18, texture(rock_ao, wpos.xz / 41.0).r);
	ra = mix(ra, vec3(lum), slate_desat) * slate_tint * slate_bright * macro;
	vec3 ga = texture(grass_alb, guv).rgb * grass_tint * mix(0.8, 1.1, texture(rock_ao, wpos.xz / 23.0).r);
	float mask = COLOR.r;
	float m = smoothstep(0.25, 0.75, mask + (texture(rock_rgh, uv * 0.37).r - 0.5) * 0.5);
	ALBEDO = mix(ra, ga, m);
	NORMAL_MAP = mix(texture(rock_nrm, uv).rgb, texture(grass_nrm, guv).rgb, m);
	ROUGHNESS = mix(texture(rock_rgh, uv).r, texture(grass_rgh, guv).r, m);
	AO = mix(texture(rock_ao, uv).r, texture(grass_ao, guv).r, m);
	AO_LIGHT_AFFECT = 0.6;
}
