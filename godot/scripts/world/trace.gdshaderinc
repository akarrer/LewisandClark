// A trodden way between two places: it bends as walkers bend, wanders wider in
// some stretches than others, and fades out through trampled grass rather than
// ending at a ruled line. Shared by ground.gdshader and grass_field.gdshader so
// the bare earth and the thinning grass agree on where the path is.

float tr_hash(vec2 p) {
	vec3 p3 = fract(vec3(p.xyx) * 0.1031);
	p3 += dot(p3, p3.yzx + 33.33);
	return fract((p3.x + p3.y) * p3.z);
}

float tr_noise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	vec2 u = f * f * (3.0 - 2.0 * f);
	return mix(mix(tr_hash(i), tr_hash(i + vec2(1.0, 0.0)), u.x),
			mix(tr_hash(i + vec2(0.0, 1.0)), tr_hash(i + vec2(1.0, 1.0)), u.x), u.y);
}

// Distance from p to the meandering path a -> b -> c, with the path's local
// half-width written to half_w.
float trace_field(vec2 p, vec2 a, vec2 b, vec2 c, float width, out float half_w) {
	float best = 1e9;
	half_w = width;
	for (int i = 0; i < 2; i++) {
		vec2 s0 = i == 0 ? a : b;
		vec2 s1 = i == 0 ? b : c;
		vec2 d = s1 - s0;
		float len = max(length(d), 0.001);
		vec2 dir = d / len;
		vec2 side = vec2(-dir.y, dir.x);
		float t = clamp(dot(p - s0, dir) / len, 0.0, 1.0);
		// The bend: a long curve with a slower wander laid over it, held to the
		// ends so the way still arrives where it is going.
		float ends = sin(t * 3.14159);
		float bend = (sin(t * 5.6 + float(i) * 2.3) * 2.4
				+ (tr_noise(vec2(t * 4.0, float(i) * 3.1)) - 0.5) * 3.0) * ends;
		vec2 on = s0 + dir * (t * len) + side * bend;
		float dist = distance(p, on);
		if (dist < best) {
			best = dist;
			// Wider where the ground opens out, pinched where it does not.
			half_w = width * (0.7 + 0.7 * tr_noise(vec2(t * 3.5 + float(i) * 5.0, 1.7)));
		}
	}
	return best;
}
