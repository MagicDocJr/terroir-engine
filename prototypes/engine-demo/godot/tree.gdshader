// PROTOTYPE — far-hill tree impostors: crossed cards sampling one cell of trees_atlas.png.
// INSTANCE_CUSTOM.x = atlas cell (0-3), .y = tint jitter. Lit with a soft, mostly-up normal so the
// forest takes the sun direction and time-of-day colour instead of the bake's lighting.
shader_type spatial;
render_mode cull_disabled, depth_draw_opaque;

uniform sampler2D atlas : source_color, filter_linear_mipmap, repeat_disable;
global uniform float wetness;
varying float cell;
varying float jitter;
varying vec3 wn;

void vertex() {
	cell = INSTANCE_CUSTOM.x;
	jitter = INSTANCE_CUSTOM.y;
	// sway a little at the top
	VERTEX.x += sin(TIME * 0.7 + MODEL_MATRIX[3].x * 0.05) * 0.02 * VERTEX.y;
	wn = normalize((MODEL_MATRIX * vec4(VERTEX.x, 0.35, VERTEX.z, 0.0)).xyz + vec3(0.0, 0.8, 0.0));
}

void fragment() {
	vec2 uv = vec2((clamp(UV.x, 0.002, 0.998) + cell) / 4.0, UV.y);
	vec4 c = texture(atlas, uv);
	ALPHA = c.a;
	ALPHA_SCISSOR_THRESHOLD = 0.45;
	ALBEDO = c.rgb * mix(0.75, 1.1, jitter) * mix(1.0, 0.75, wetness);
	NORMAL = normalize((VIEW_MATRIX * vec4(wn, 0.0)).xyz);
	ROUGHNESS = mix(0.95, 0.6, wetness);
	SPECULAR = 0.2;
	BACKLIGHT = vec3(0.12, 0.16, 0.05);
}
