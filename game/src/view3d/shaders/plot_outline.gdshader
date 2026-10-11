// The intro's line round the player's Plot (vineyard.gd _build_outline): a thin warm-gold line lying in the headland,
// drawn round the boundary as `reveal` goes 0 → 1 and faded with `fade`. Drawn over the ground (no depth test) so bumps
// and grass never break it; kept below the glow threshold so it reads as a line, not a light. UV.x = share of the way
// round, UV.y = across the line. Look only.
shader_type spatial;
render_mode unshaded, blend_mix, depth_draw_never, depth_test_disabled, cull_disabled;

uniform float reveal = 0.0;
uniform float fade = 1.0;
uniform vec3 col = vec3(0.95, 0.74, 0.36);

void fragment() {
	float across = 1.0 - abs(UV.y * 2.0 - 1.0);
	float core = smoothstep(0.0, 0.55, across);
	float drawn = 1.0 - smoothstep(reveal - 0.004, reveal, UV.x);
	float head = (1.0 - smoothstep(0.0, 0.025, abs(UV.x - reveal))) * step(0.001, reveal) * (1.0 - step(0.999, reveal));
	ALBEDO = col * (0.85 + 0.25 * head);
	ALPHA = core * max(drawn, head) * fade * 0.75;
}
