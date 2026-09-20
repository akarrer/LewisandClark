shader_type spatial;
render_mode cull_disabled;
// The colours of 1804: fifteen stripes and fifteen stars, the flag Congress set
// in 1795 and kept until 1818. Woven in the shader rather than painted, so the
// reverse reads correctly, and it flies on the same wind as the grass.

global uniform float wind_strength;

uniform vec3 red : source_color = vec3(0.68, 0.13, 0.15);
uniform vec3 white : source_color = vec3(0.92, 0.90, 0.85);
uniform vec3 blue : source_color = vec3(0.13, 0.18, 0.40);
uniform float hoist_slack = 0.06;  // the cloth is held at the hoist, loose at the fly

varying float v_shade;

void vertex() {
	float along = UV.x;              // 0 at the hoist, 1 at the fly
	float w = clamp(wind_strength, 0.2, 4.0);
	// Two waves travelling out along the cloth, growing toward the free edge.
	float travel = TIME * (2.2 + w * 0.8);
	float wave = sin(along * 9.0 - travel) * 0.5 + sin(along * 15.0 - travel * 1.6 + UV.y * 3.0) * 0.25;
	float swing = along * along * (0.12 + 0.1 * w);
	VERTEX.z += wave * swing;
	// The cloth lifts and falls as it snaps.
	VERTEX.y += sin(along * 7.0 - travel * 1.1) * swing * 0.35;
	VERTEX.x -= along * hoist_slack * (1.0 - cos(wave));
	// Fold shading: where the cloth turns away from the light it darkens.
	v_shade = 0.82 + 0.18 * cos(along * 9.0 - travel);
}

float star(vec2 p, float r) {
	// A five-pointed star as a ring of alternating radii, in polar terms.
	float a = atan(p.y, p.x);
	float d = length(p);
	float points = cos(a * 5.0) * 0.5 + 0.5;
	return step(d, r * mix(0.42, 1.0, points));
}

void fragment() {
	// UV.y runs DOWN the cloth; everything below is written in flag terms, with
	// the first stripe at the bottom and the union over the top seven.
	vec2 uv = vec2(UV.x, 1.0 - UV.y);
	// No mirroring for the reverse. That is right when the cloth carries a
	// painted image, but this one is woven out of UV.x, which is 0 at the hoist
	// whichever side you are standing on -- and a flag's union is at the hoist
	// from both sides. Mirroring moved it out to the fly end.
	// Fifteen stripes, red at top and bottom.
	float band = floor(uv.y * 15.0);
	vec3 c = mod(band, 2.0) < 0.5 ? red : white;
	// The union: fifteen stars in five columns of three, over the top seven stripes.
	if (uv.x < 0.42 && uv.y > 8.0 / 15.0) {
		c = blue;
		vec2 canton = vec2(uv.x / 0.42, (uv.y - 8.0 / 15.0) / (7.0 / 15.0));
		vec2 cell = fract(canton * vec2(5.0, 3.0)) - 0.5;
		c = mix(c, white, star(cell, 0.34));
	}
	ALBEDO = c * v_shade;
	ROUGHNESS = 0.92;
	SPECULAR = 0.1;
	BACKLIGHT = c * 0.35;  // sun through cloth
}
