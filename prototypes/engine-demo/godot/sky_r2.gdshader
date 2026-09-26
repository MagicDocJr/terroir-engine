// PROTOTYPE — round 2 sky: cross-fade of two HDRI panoramas, each rotated so its baked sun sits at the
// DirectionalLight's azimuth. Radiance pass is clamped so the HDRI sun never becomes a second key light.
shader_type sky;

uniform sampler2D pano_a : filter_linear, repeat_enable;
uniform sampler2D pano_b : filter_linear, repeat_enable;
uniform float rot_a = 0.0;
uniform float rot_b = 0.0;
uniform float energy_a = 1.0;
uniform float energy_b = 1.0;
uniform float blend = 0.0;
uniform vec3 tint = vec3(1.0);
uniform float radiance_clamp = 3.0;

vec3 pano(sampler2D p, float rot, vec3 d) {
	float c = cos(rot), s = sin(rot);
	vec3 r = vec3(d.x * c + d.z * s, d.y, -d.x * s + d.z * c);
	vec2 uv = vec2(atan(r.x, -r.z) + PI, acos(clamp(r.y, -1.0, 1.0))) / vec2(2.0 * PI, PI);
	return textureLod(p, uv, 0.0).rgb;
}

void sky() {
	vec3 a = pano(pano_a, rot_a, EYEDIR) * energy_a;
	vec3 b = pano(pano_b, rot_b, EYEDIR) * energy_b;
	vec3 col = mix(a, b, blend) * tint;
	if (AT_CUBEMAP_PASS) {
		col = min(col, vec3(radiance_clamp));
	}
	COLOR = col;
}
