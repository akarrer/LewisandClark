shader_type spatial;
render_mode cull_disabled, blend_mix, depth_draw_never;
// Lit, not unshaded: an unshaded wake keeps its noon white into the dusk and
// stands out on a darkening river like a strip of paper.
// The wake off a snag standing in the current. The Corps called these sawyers
// and planters and feared them more than anything else on the river: a whole
// cottonwood driven into the bed, with the water piling against it and running
// white away downstream. The quad lies on the water with its near edge at the
// trunk and its length pointing down the channel.

uniform vec3 foam : source_color = vec3(0.74, 0.69, 0.60);  // Missouri foam is muddy
uniform float strength = 0.45;
global uniform float wind_strength;

float wk_hash(vec2 p) {
	vec3 p3 = fract(vec3(p.xyx) * 0.1031);
	p3 += dot(p3, p3.yzx + 33.33);
	return fract((p3.x + p3.y) * p3.z);
}

float wk_noise(vec2 p) {
	vec2 i = floor(p); vec2 f = fract(p);
	vec2 u = f * f * (3.0 - 2.0 * f);
	return mix(mix(wk_hash(i), wk_hash(i + vec2(1, 0)), u.x),
			mix(wk_hash(i + vec2(0, 1)), wk_hash(i + vec2(1, 1)), u.x), u.y);
}

void fragment() {
	// v runs from the trunk (0) to the tail of the wake (1); u across it.
	float v = UV.y;
	float u = (UV.x - 0.5) * 2.0;
	// The V opens as it goes: narrow at the trunk, wide at the tail.
	float spread = 0.12 + v * 0.9;
	float arm = abs(abs(u) - spread * 0.62) / (0.1 + v * 0.16);
	float arms = exp(-arm * arm);
	// And the water piles up against the trunk itself, white and broken.
	float pile = exp(-(v / 0.1) * (v / 0.1)) * exp(-(u / 0.35) * (u / 0.35));
	// Ripples running down the arms, quicker in a wind.
	float run = wk_noise(vec2(u * 6.0, v * 5.0 - TIME * (1.4 + clamp(wind_strength, 0.0, 4.0) * 0.4)));
	// The arms are not a ruled stroke but beads of scum strung along them, and
	// they thin out as the wake spreads.
	float beads = smoothstep(0.35, 0.75, wk_noise(vec2(u * 3.0, v * 14.0 - TIME * 2.0)));
	float a = (arms * beads * (0.4 + 0.6 * run) * (1.0 - v * 0.6) + pile) * (1.0 - smoothstep(0.4, 1.0, v));
	ALBEDO = foam;
	ROUGHNESS = 0.9;
	NORMAL = (VIEW_MATRIX * vec4(0.0, 1.0, 0.0, 0.0)).xyz;
	ALPHA = clamp(a * strength, 0.0, 1.0);
}
