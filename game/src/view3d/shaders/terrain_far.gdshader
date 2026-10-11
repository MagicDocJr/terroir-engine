// Far terrain: vertex-colour landscape (forest, fields, rock, villages) with fine variation. COLOR.a marks
// vineyard parcels: soil with rows of canopy whose density follows the season (canopy 0 = bare wood).
shader_type spatial;

uniform sampler2D detail_nrm : hint_normal, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D detail_ao : hint_default_white, filter_linear_mipmap_anisotropic, repeat_enable;
uniform float row_spacing = 1.8;
uniform vec3 vine_soil = vec3(0.1, 0.1, 0.11);
uniform vec3 vine_canopy = vec3(0.06, 0.11, 0.035);
uniform float canopy = 1.0;
uniform vec3 sun_dir = vec3(0.3, 0.8, 0.5);    // towards the sun: the rows (along z) shade the alley on the far side
uniform float row_height = 1.3;
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
	// how much of the alley lies in the rows' shadow: shadow length across the rows over the open alley
	float across = abs(sun_dir.x) * row_height * (0.35 + 0.65 * canopy) / max(sun_dir.y, 0.06);
	float alley = row_spacing * (0.55 + 0.3 * (1.0 - canopy));
	float shade = clamp(across / max(alley, 0.1), 0.0, 0.85);
	vec3 soil = vine_soil * mix(1.0, 0.38, shade);
	vec3 vine = mix(soil, vine_canopy * mix(0.8, 1.2, mm), clamp(row * (0.25 + canopy), 0.0, 1.0));
	// seen from afar the rows blend: the canopy share of the ground grows as the shadow fills the alleys
	vine = mix(vine, mix(vine_canopy * 0.55, vine, 0.6), smoothstep(0.25, 0.7, fw) * shade);
	vec3 base = mix(COLOR.rgb, vine, step(0.5, COLOR.a));
	ALBEDO = base * mix(0.8, 1.15, m) * mix(0.85, 1.1, mm) * mix(1.0, 0.8, wetness);
	NORMAL_MAP = texture(detail_nrm, wpos.xz / 30.0).rgb;
	NORMAL_MAP_DEPTH = 1.5;
	ROUGHNESS = mix(0.95, 0.6, wetness);
}
