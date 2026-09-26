// Near terrain (from the engine demo's terrain_near): regional soil blended with grass. Grass cover comes from
// the vertex colour (R) outside the vineyard and from ground_map inside it (R = cover between rows / on paths,
// G = soil brightness per Block, B = 1 inside the mapped rectangle). Wet soil darkens, puddles ripple in rain.
shader_type spatial;
render_mode blend_mix, cull_back, depth_draw_opaque;

uniform sampler2D soil_alb : source_color, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D soil_nrm : hint_normal, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D soil_rgh : hint_default_white, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D soil_ao : hint_default_white, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D grass_alb : source_color, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D grass_nrm : hint_normal, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D grass_rgh : hint_default_white, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D grass_ao : hint_default_white, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D ground_map : hint_default_black, filter_linear, repeat_disable;
uniform vec4 map_rect = vec4(0.0, 0.0, 1.0, 1.0);     // x0, z0, width, depth (metres)
uniform vec3 soil_tint = vec3(0.70, 0.78, 0.95);
uniform float soil_desat = 0.65;
uniform float soil_bright = 1.0;
uniform float soil_scale = 3.0;
uniform vec3 grass_tint = vec3(0.78, 0.95, 0.55);

global uniform float wetness;
global uniform float rain_amount;
varying vec3 wpos;
varying vec3 wnrm;

void vertex() {
	wpos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	wnrm = normalize((MODEL_MATRIX * vec4(NORMAL, 0.0)).xyz);
}

float h21(vec2 p) { return fract(sin(dot(p, vec2(41.3, 289.1))) * 43758.5453); }
vec2 ripples(vec2 p, float t) {
	vec2 acc = vec2(0.0);
	for (int layer = 0; layer < 2; layer++) {
		vec2 q = p * (layer == 0 ? 3.0 : 4.7) + float(layer) * 13.1;
		vec2 id = floor(q);
		vec2 f = fract(q) - vec2(h21(id + 1.7), h21(id + 5.3)) * 0.6 - 0.2;
		float ph = fract(t * 1.4 + h21(id));
		float d = length(f);
		float ring = sin((d - ph * 0.55) * 60.0) * smoothstep(0.08, 0.0, abs(d - ph * 0.55)) * (1.0 - ph);
		acc += (d > 0.0001 ? f / d : vec2(0.0)) * ring;
	}
	return acc;
}

void fragment() {
	vec2 uv = wpos.xz / soil_scale;
	vec2 uv2 = wpos.xz / (soil_scale * 3.57) + vec2(0.37, 0.61);
	vec2 guv = wpos.xz / 2.3;
	vec2 muv = (wpos.xz - map_rect.xy) / map_rect.zw;
	vec4 gm = texture(ground_map, muv);
	float inside = gm.b * step(0.0, muv.x) * step(muv.x, 1.0) * step(0.0, muv.y) * step(muv.y, 1.0);
	vec3 ra = mix(texture(soil_alb, uv).rgb, texture(soil_alb, uv2).rgb, 0.35);
	float lum = dot(ra, vec3(0.299, 0.587, 0.114));
	float macro = mix(0.78, 1.18, texture(soil_ao, wpos.xz / 41.0).r);
	float block_b = mix(1.0, mix(0.75, 1.25, gm.g), inside);
	ra = mix(ra, vec3(lum), soil_desat) * soil_tint * soil_bright * macro * block_b;
	vec3 ga = texture(grass_alb, guv).rgb * grass_tint * mix(0.8, 1.1, texture(soil_ao, wpos.xz / 23.0).r);
	ga *= mix(vec3(1.0), vec3(0.42, 0.55, 0.36), COLOR.b * (1.0 - inside));        // scrub on fallow slopes
	float mask = mix(COLOR.r, gm.r, inside);
	float m = smoothstep(0.25, 0.75, mask + (texture(soil_rgh, uv * 0.37).r - 0.5) * 0.5);
	vec3 alb = mix(ra, ga, m);
	vec3 nm = mix(texture(soil_nrm, uv).rgb, texture(grass_nrm, guv).rgb, m);
	float rgh = mix(texture(soil_rgh, uv).r, texture(grass_rgh, guv).r, m);
	float ao = mix(texture(soil_ao, uv).r, texture(grass_ao, guv).r, m);
	float wet = wetness * mix(1.0, 0.6, m);
	alb *= mix(1.0, mix(0.42, 0.62, m), wet);
	rgh = mix(rgh, mix(0.14, 0.35, m), wet);
	float hollow = 1.0 - texture(soil_ao, wpos.xz / 13.0 + vec2(0.2, 0.7)).r;
	float flat_ = smoothstep(0.84, 0.97, wnrm.y);
	float pud = wetness * smoothstep(0.52, 0.62, hollow * 0.7 + flat_ * 0.45 + (1.0 - ao) * 0.25) * (1.0 - m * 0.8);
	if (pud > 0.001) {
		vec2 rp = ripples(wpos.xz, TIME) * rain_amount;
		nm = mix(nm, vec3(0.5 + rp.x * 0.35, 0.5 + rp.y * 0.35, 1.0), pud);
		rgh = mix(rgh, 0.02, pud);
		alb = mix(alb, alb * 0.35 + vec3(0.004, 0.005, 0.006), pud);
	}
	ALBEDO = alb;
	NORMAL_MAP = nm;
	ROUGHNESS = rgh;
	SPECULAR = mix(0.5, 0.65, max(wet, pud));
	AO = ao;
	AO_LIGHT_AFFECT = 0.6;
}
