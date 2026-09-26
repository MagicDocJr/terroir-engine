// Far terrain: vertex-colour landscape (forest, fields, rock, villages) with fine variation. COLOR.a marks
// vineyard parcels: soil with rows of canopy whose density follows the season (canopy 0 = bare wood).
shader_type spatial;

uniform sampler2D detail_nrm : hint_normal, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D detail_ao : hint_default_white, filter_linear_mipmap_anisotropic, repeat_enable;
uniform float row_spacing = 1.8;
uniform vec3 vine_soil = vec3(0.1, 0.1, 0.11);
uniform vec3 vine_canopy = vec3(0.06, 0.11, 0.035);
uniform float canopy = 1.0;
global uniform float wetness;

varying vec3 wpos;

void vertex() {
	wpos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

void fragment() {
	float m = texture(detail_ao, wpos.xz / 9.0 + vec2(0.6, 0.1)).r;
	float mm = texture(detail_ao, wpos.xz / 57.0 + vec2(0.1, 0.4)).r;
	float px = wpos.x / row_spacing;
	float fw = fwidth(px);
	float row = smoothstep(0.5 - 0.3 * canopy, 0.5 - 0.3 * canopy - 0.12, abs(fract(px) - 0.5));
	row = mix(row, 0.55 * canopy + 0.05, smoothstep(0.25, 0.7, fw));       // average out where rows would alias
	vec3 vine = mix(vine_soil, vine_canopy * mix(0.8, 1.2, mm), clamp(row * (0.25 + canopy), 0.0, 1.0));
	vec3 base = mix(COLOR.rgb, vine, step(0.5, COLOR.a));
	ALBEDO = base * mix(0.8, 1.15, m) * mix(0.85, 1.1, mm) * mix(1.0, 0.8, wetness);
	NORMAL_MAP = texture(detail_nrm, wpos.xz / 30.0).rgb;
	NORMAL_MAP_DEPTH = 1.5;
	ROUGHNESS = mix(0.95, 0.6, wetness);
}
