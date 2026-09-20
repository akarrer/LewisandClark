shader_type canvas_item;
// What you see down a spyglass: one round field with everything else shut out,
// the rim soft where the eye cup is, and the edge of the field going off colour
// the way a single uncorrected lens does.

uniform float amount = 0.0;          // 0 glass down, 1 up to the eye
uniform float aspect = 1.777;

void fragment() {
	vec2 p = (UV - vec2(0.5)) * vec2(aspect, 1.0) * 2.0;
	float r = length(p);
	// The field opens out from nothing as the glass comes up.
	float field = mix(0.05, 0.62, amount);
	float edge = smoothstep(field * 0.86, field, r);
	// A little chromatic smear just inside the rim, and the rim itself dark.
	float fringe = smoothstep(field * 0.6, field * 0.95, r) * (1.0 - edge);
	COLOR = vec4(mix(vec3(0.0), vec3(0.25, 0.18, 0.10), fringe * 0.5), max(edge, 0.0) * amount);
}
