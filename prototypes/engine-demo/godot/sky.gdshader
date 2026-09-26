// PROTOTYPE — HDRI sky rotated so the baked sun matches layout.sun; radiance pass clamped
// so the HDRI sun does not become a second light direction (the DirectionalLight3D is the key light).
shader_type sky;

uniform sampler2D panorama : filter_linear, repeat_enable;
uniform float rot_y = 0.0;
uniform float energy = 1.0;
uniform float radiance_clamp = 4.0;

void sky() {
	float c = cos(rot_y);
	float s = sin(rot_y);
	vec3 d = EYEDIR;
	vec3 r = vec3(d.x * c + d.z * s, d.y, -d.x * s + d.z * c);
	vec2 uv = vec2(atan(r.x, -r.z) + PI, acos(clamp(r.y, -1.0, 1.0))) / vec2(2.0 * PI, PI);
	vec3 col = textureLod(panorama, uv, 0.0).rgb;
	if (AT_CUBEMAP_PASS) {
		col = min(col, vec3(radiance_clamp));
	}
	COLOR = col * energy;
}
