shader_type canvas_item;
// The drawn map shown only where the Corps has been: known ground in ink,
// the rest blank paper, with a soft ragged edge between them the way a sketch
// thins out at the limit of what the draughtsman could see.

uniform sampler2D seen_tex : filter_linear;
uniform vec3 paper : source_color = vec3(0.93, 0.88, 0.76);

float map_hash(vec2 p) {
	vec3 p3 = fract(vec3(p.xyx) * 0.1031);
	p3 += dot(p3, p3.yzx + 33.33);
	return fract((p3.x + p3.y) * p3.z);
}

void fragment() {
	vec3 drawn = texture(TEXTURE, UV).rgb;
	// The edge of the known ground is ragged, not a clean circle.
	float rag = (map_hash(floor(UV * 180.0)) - 0.5) * 0.25;
	float known = smoothstep(0.2, 0.55, texture(seen_tex, UV).r + rag);
	// Paper grain everywhere, so the blank is paper and not a flat fill.
	float grain = 0.97 + 0.03 * map_hash(floor(UV * 520.0));
	COLOR = vec4(mix(paper, drawn, known) * grain, 1.0);
}
