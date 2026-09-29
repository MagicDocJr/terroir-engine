// Grass blades near the camera (vineyard.gd _grass_field): tapered blades, dark at the base and light at the tip,
// tinted by the season like the terrain's grass, swaying in the shared gusts, backlit, shrinking away at the edge of
// their range so chunks never pop. Look only.
shader_type spatial;
render_mode cull_disabled, diffuse_burley, specular_schlick_ggx;

global uniform float wind_strength;
global uniform vec2 wind_dir;
global uniform vec3 grass_tint;
global uniform float wetness;
uniform float fade_start = 17.0;
uniform float fade_end = 23.0;

varying float v_h;

// travelling gusts across the field (shared with leaf.gdshader)
float gust(vec2 p) {
	float t = TIME;
	float a = sin(dot(p, wind_dir) * 0.18 - t * 1.6) * 0.5 + 0.5;
	float b = sin(dot(p, vec2(-wind_dir.y, wind_dir.x)) * 0.07 + t * 0.37) * 0.5 + 0.5;
	return 0.45 + 0.55 * a * (0.6 + 0.4 * b);
}

void vertex() {
	v_h = UV.y;                                   // 0 at the root, 1 at the tip
	vec3 w = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	float d = length(w - CAMERA_POSITION_WORLD);
	float fade = 1.0 - smoothstep(fade_start, fade_end, d);
	VERTEX *= vec3(1.0, fade, 1.0);
	float g = gust(w.xz) * wind_strength;
	float bend = v_h * v_h * g * 0.09;
	vec3 wd = vec3(wind_dir.x, 0.0, wind_dir.y);
	VERTEX += (inverse(mat3(MODEL_MATRIX)) * wd) * bend + NORMAL * 0.004 * sin(TIME * 7.0 + w.x * 3.0 + w.z * 2.0) * v_h;
}

void fragment() {
	vec3 base = COLOR.rgb * grass_tint * vec3(0.40, 0.44, 0.30);   // the tint multiplies a texture on the terrain; blades need an absolute colour
	vec3 col = mix(base * 0.5, base * 1.15, v_h);
	ALBEDO = col * mix(1.0, 0.8, wetness);
	ROUGHNESS = mix(0.75, 0.3, wetness);
	SPECULAR = 0.35;
	BACKLIGHT = col * 0.45;
}
