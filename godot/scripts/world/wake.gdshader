shader_type spatial;
render_mode cull_disabled, unshaded, blend_mix, depth_draw_never;
// The wake off a snag standing in the current. The Corps called these sawyers
// and planters and feared them more than anything else on the river: a whole
// cottonwood driven into the bed, with the water piling against it and running
// white away downstream. The quad lies on the water with its near edge at the
// trunk and its length pointing down the channel.

uniform vec3 foam : source_color = vec3(0.86, 0.84, 0.78);
uniform float strength = 0.55;
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
	float a = (arms * (0.55 + 0.45 * run) + pile) * (1.0 - smoothstep(0.55, 1.0, v));
	ALBEDO = foam;
	ALPHA = clamp(a * strength, 0.0, 1.0);
}
