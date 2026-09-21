shader_type spatial;
render_mode cull_disabled, unshaded, blend_add, depth_draw_never;
// The ring a rising fish leaves: a bright circle that widens and thins away.

uniform float fade = 1.0;
uniform vec3 tint : source_color = vec3(0.68, 0.72, 0.70);

void fragment() {
	float d = length(UV - vec2(0.5)) * 2.0;
	// A thin annulus, sharper inside than out, as the ripple runs outward.
	float ring = smoothstep(0.72, 0.92, d) * (1.0 - smoothstep(0.92, 1.0, d));
	ALBEDO = tint * ring * fade * 1.4;
	ALPHA = ring * fade;
}
