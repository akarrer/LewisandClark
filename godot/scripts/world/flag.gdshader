shader_type spatial;
render_mode cull_disabled;
// The colours of 1804: fifteen stripes and fifteen stars, the flag Congress set
// in 1795 and kept until 1818. Woven in the shader rather than painted, so the
// reverse reads correctly, and it flies on the same wind as the grass.
//
// Wool bunting dyed with madder and indigo, sewn by hand, and months on a
// keelboat staff: not a printed flag. The cloth rolls in real folds (the
// surface normal follows them, so light runs across each fold and its far
// side falls into shade), it sags toward the fly, and the fly end is weathered
// and fraying.

global uniform float wind_strength;

uniform vec3 red : source_color = vec3(0.58, 0.14, 0.13);    // madder
uniform vec3 white : source_color = vec3(0.86, 0.83, 0.74);  // undyed wool, gone ivory
uniform vec3 blue : source_color = vec3(0.10, 0.13, 0.30);   // indigo
uniform float hoist_slack = 0.06;  // the cloth is held at the hoist, loose at the fly
uniform vec2 size = vec2(1.8, 1.05);   // metres, for the fold depth

// How far the cloth stands off its flat plane at (along the cloth, down it).
float fold(float along, float down, float t, float w) {
	float swing = along * (0.10 + 0.08 * w) + along * along * 0.06;
	float a = sin(along * 8.0 - t + down * 1.4) * 0.55;
	float b = sin(along * 14.5 - t * 1.55 + down * 3.1) * 0.28;
	float c = sin(along * 23.0 - t * 2.3 - down * 2.0) * 0.12 * along;
	return (a + b + c) * swing * size.y;
}

varying float v_along;

void vertex() {
	float along = UV.x;              // 0 at the hoist, 1 at the fly
	float down = UV.y;               // 0 at the top
	float w = clamp(wind_strength, 0.2, 4.0);
	float t = TIME * (2.2 + w * 0.8);
	float z = fold(along, down, t, w);
	// The normal of the folded cloth, from how fast the fold changes along and down it.
	float e = 0.01;
	float dzda = (fold(along + e, down, t, w) - z) / (e * size.x);
	float dzdd = (fold(along, down + e, t, w) - z) / (e * size.y);
	VERTEX.z += z;
	// A cloth in a light wind hangs: the fly end droops, and lifts as it snaps.
	float droop = along * along * mix(0.16, 0.04, clamp(w / 2.5, 0.0, 1.0)) * size.y;
	VERTEX.y -= droop - sin(along * 7.0 - t * 1.1) * along * along * 0.035 * size.y;
	VERTEX.x -= along * hoist_slack * (1.0 - cos(z * 3.0));
	// UV.y runs down the cloth, which is -y.
	NORMAL = normalize(vec3(-dzda, dzdd, 1.0));
	v_along = along;
}

// Signed distance to a five-pointed star of outer radius r (after Quilez).
float sd_star5(vec2 p, float r, float rf) {
	const vec2 k1 = vec2(0.809016994375, -0.587785252292);
	const vec2 k2 = vec2(-k1.x, k1.y);
	p.x = abs(p.x);
	p -= 2.0 * max(dot(k1, p), 0.0) * k1;
	p -= 2.0 * max(dot(k2, p), 0.0) * k2;
	p.x = abs(p.x);
	p.y -= r;
	vec2 ba = rf * vec2(-k1.y, k1.x) - vec2(0.0, 1.0);
	float h = clamp(dot(p, ba) / dot(ba, ba), 0.0, r);
	return length(p - ba * h) * sign(p.y * ba.x - p.x * ba.y);
}

float hash(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

void fragment() {
	// UV.y runs DOWN the cloth; everything below is written in flag terms, with
	// the first stripe at the bottom and the union over the top seven.
	vec2 uv = vec2(UV.x, 1.0 - UV.y);
	// No mirroring for the reverse. That is right when the cloth carries a
	// painted image, but this one is woven out of UV.x, which is 0 at the hoist
	// whichever side you are standing on -- and a flag's union is at the hoist
	// from both sides. Mirroring moved it out to the fly end.
	// Fifteen stripes, red at top and bottom, their seams drawn soft to a pixel.
	float s = uv.y * 15.0;
	float px = fwidth(s);
	float seam = abs(fract(s) - 0.5);           // 0.5 at a seam
	float odd = mod(floor(s), 2.0);
	float blend = smoothstep(0.5 - px, 0.5, seam);
	float red_amt = mix(1.0 - odd, 0.5, blend);
	vec3 c = mix(white, red, red_amt);
	// The union: fifteen stars in five columns of three, over the top seven stripes.
	float in_union = step(uv.x, 0.42) * step(8.0 / 15.0, uv.y);
	if (in_union > 0.5) {
		vec2 canton = vec2(uv.x / 0.42, (uv.y - 8.0 / 15.0) / (7.0 / 15.0));
		// Cells in cloth proportion, so the stars are round, not squashed.
		vec2 cell = (fract(canton * vec2(5.0, 3.0)) - 0.5) * vec2(0.42 * size.x / 5.0, 7.0 / 15.0 * size.y / 3.0);
		// Hand-sewn: each star a little off true, and turned its own way.
		vec2 id = floor(canton * vec2(5.0, 3.0));
		float turn = (hash(id) - 0.5) * 0.35;
		cell = mat2(vec2(cos(turn), sin(turn)), vec2(-sin(turn), cos(turn))) * cell;
		cell += (vec2(hash(id + 3.1), hash(id + 7.7)) - 0.5) * 0.012;
		float r = 0.068 * size.y / 1.05;
		float d = sd_star5(cell, r, 0.45);
		float aa = fwidth(d);
		c = mix(blue, white, 1.0 - smoothstep(-aa, aa, d));
	}
	// Wool bunting: a coarse weave, and the colours uneven where the dye took.
	vec2 g = UV * vec2(size.x, size.y) * 260.0;
	float weave = (sin(g.x) * sin(g.y)) * 0.5 + 0.5;
	float weave_fade = 1.0 - smoothstep(0.4, 1.2, fwidth(g.x));
	c *= 1.0 - 0.06 * weave * weave_fade;
	c *= 0.94 + 0.08 * hash(floor(UV * vec2(30.0, 15.0)));
	// The fly end: weathered paler and dirtier, and fraying, ragged threads cut out.
	float fly = smoothstep(0.75, 1.0, v_along);
	c = mix(c, c * vec3(0.92, 0.88, 0.80) + vec3(0.03, 0.03, 0.02), fly * 0.6);
	// Torn in uneven tongues, a few threads hanging longer here and there.
	float tongue = hash(vec2(floor(UV.y * 11.0), 1.0));
	float thread = hash(vec2(floor(UV.y * 140.0), 2.0));
	float ragged = 0.975 - 0.04 * tongue * tongue + 0.02 * step(0.86, thread) - 0.01 * thread;
	if (UV.x > ragged) {
		discard;
	}
	ALBEDO = c;
	ROUGHNESS = 0.95;
	SPECULAR = 0.06;
	BACKLIGHT = c * 0.45;  // sun through the cloth
}
