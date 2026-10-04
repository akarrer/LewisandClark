shader_type spatial;
render_mode cull_disabled, unshaded, blend_mix, depth_draw_never;
// The rings a rising fish leaves: a train of two or three that widen and thin
// away. Water shows a ripple as a catch of sky on one side of it and a shadow
// on the other, not as a lit hoop -- one bright additive annulus read as a
// marker painted on the river.

uniform float fade = 1.0;
uniform vec3 tint : source_color = vec3(0.68, 0.72, 0.70);
uniform vec3 shade : source_color = vec3(0.16, 0.13, 0.09);

float hash(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

void fragment() {
	vec2 q = UV - vec2(0.5);
	float d = length(q) * 2.0;
	// Broken a little along its length: a ring on moving water is never whole.
	float a = atan(q.y, q.x);
	float seg = floor((a + PI) * 5.0);
	float wobble = mix(hash(vec2(seg, 3.0)), hash(vec2(seg + 1.0, 3.0)), fract((a + PI) * 5.0));
	d += (wobble - 0.5) * 0.03;
	float lit = 0.0;
	float dark = 0.0;
	for (int i = 0; i < 3; i++) {
		float r = 0.92 - float(i) * 0.2;
		float w = 0.045 * (1.0 - float(i) * 0.25);
		float k = 1.0 - float(i) * 0.38;
		// The outer face of each crest catches the sky, the trough inside it the bed.
		lit += smoothstep(r - w, r, d) * (1.0 - smoothstep(r, r + w * 0.6, d)) * k;
		dark += smoothstep(r - w * 2.6, r - w, d) * (1.0 - smoothstep(r - w, r - w * 0.4, d)) * k;
	}
	float edge = 1.0 - smoothstep(0.96, 1.0, d);
	lit *= edge;
	dark *= edge;
	ALBEDO = mix(shade, tint, lit / max(lit + dark, 0.001));
	ALPHA = clamp(lit * 0.42 + dark * 0.22, 0.0, 1.0) * fade;
}
