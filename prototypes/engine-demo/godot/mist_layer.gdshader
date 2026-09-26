// PROTOTYPE — top surface of the valley fog sea: soft billows (two drifting noise octaves), lit by the sun
// colour, feathered where it meets the terrain (depth fade) so it never shows a hard edge.
shader_type spatial;
render_mode blend_mix, depth_draw_never, cull_disabled, shadows_disabled;

uniform sampler2D noise_tex : filter_linear_mipmap, repeat_enable;
uniform sampler2D depth_tex : hint_depth_texture, filter_linear_mipmap;
uniform float amount = 0.0;
uniform vec3 lit_color = vec3(1.0, 0.92, 0.85);
varying vec3 wpos;

void vertex() {
	wpos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

void fragment() {
	vec2 p = wpos.xz;
	float n = texture(noise_tex, p / 420.0 + vec2(TIME * 0.0015, 0.0)).r * 0.65
	        + texture(noise_tex, p / 130.0 - vec2(0.0, TIME * 0.003)).r * 0.35;
	float billow = smoothstep(0.25, 0.75, n);
	float scene_depth = texture(depth_tex, SCREEN_UV).r;
	vec4 world = INV_PROJECTION_MATRIX * vec4(SCREEN_UV * 2.0 - 1.0, scene_depth, 1.0);
	float scene_z = -world.z / world.w;
	float frag_z = -VERTEX.z;
	float feather = clamp((scene_z - frag_z) / 25.0, 0.0, 1.0);
	float dist_fade = smoothstep(40.0, 180.0, frag_z);
	ALBEDO = lit_color * mix(0.78, 1.0, billow);
	ROUGHNESS = 1.0;
	SPECULAR = 0.0;
	ALPHA = amount * mix(0.72, 0.98, billow) * feather * dist_fade;
}
