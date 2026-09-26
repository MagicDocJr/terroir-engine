// PROTOTYPE — vine leaves: vertex-colour albedo, double-sided, backlit translucency, subtle wind.
shader_type spatial;
render_mode cull_disabled, depth_draw_opaque;

uniform float roughness = 0.55;
uniform vec3 backlight_col = vec3(0.22, 0.32, 0.06);
uniform float wind = 1.0;
uniform sampler2D leaf_detail : hint_default_white, filter_linear_mipmap_anisotropic, repeat_disable;

void vertex() {
	vec3 w = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	float h = clamp(VERTEX.y - 0.6, 0.0, 1.5);
	float ph = dot(w.xz, vec2(0.7, 0.4));
	VERTEX.x += wind * h * 0.012 * sin(TIME * 1.7 + ph);
	VERTEX.z += wind * h * 0.008 * sin(TIME * 2.3 + ph * 1.3);
	VERTEX += NORMAL * wind * 0.004 * sin(TIME * 6.0 + ph * 5.0);
}

void fragment() {
	// COLOR_0 arrives linear, as authored. leaf_detail: shared veins/mottling multiplier (mean ~0.69).
	vec3 detail = texture(leaf_detail, UV).rgb * 1.45;
	ALBEDO = COLOR.rgb * detail;
	ROUGHNESS = roughness;
	SPECULAR = 0.35;
	BACKLIGHT = backlight_col * detail;
}
