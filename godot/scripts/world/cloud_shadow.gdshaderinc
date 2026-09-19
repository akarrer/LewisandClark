// Shadows of the sky's clouds drifting over the land: the same fbm, coverage and
// wind direction as sky.gdshader, anchored in the world on a cloud layer 400 m up and cast
// along the sun's direction. Set from sky.gd each frame (see [shader_globals]).

global uniform float cloud_cover;           // sky cloud_coverage
global uniform float cloud_shadow_strength; // 0 at night and under overcast
global uniform vec3 sun_dir;                // toward the sun

float cs_hash(vec2 p) {
	vec3 p3 = fract(vec3(p.xyx) * 0.1031);
	p3 += dot(p3, p3.yzx + 33.33);
	return fract((p3.x + p3.y) * p3.z);
}

float cs_noise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	vec2 u = f * f * (3.0 - 2.0 * f);
	return mix(mix(cs_hash(i), cs_hash(i + vec2(1.0, 0.0)), u.x),
			mix(cs_hash(i + vec2(0.0, 1.0)), cs_hash(i + vec2(1.0, 1.0)), u.x), u.y);
}

// 1 in full sun, down to (1 - strength) under a cloud.
float cloud_light(vec3 world) {
	if (cloud_shadow_strength < 0.001) {
		return 1.0;
	}
	vec3 s = normalize(sun_dir);
	// Shrunk from the sky's scale (~560 m clouds) so a single vista crosses several
	// shadows on a map only 1 km across; they drift at a walking-pace 4 m/s.
	vec2 q = world.xz + s.xz / max(s.y, 0.2) * (400.0 - world.y);
	vec2 uv = q / 240.0 + vec2(TIME, TIME * 0.4) * (4.0 / 240.0);
	float v = 0.0;
	float a = 0.5;
	mat2 rot = mat2(vec2(0.8, -0.6), vec2(0.6, 0.8));
	for (int i = 0; i < 4; i++) {
		v += a * cs_noise(uv);
		uv = rot * uv * 2.03 + vec2(1.7, 9.2);
		a *= 0.5;
	}
	// Matches the cumulus deck in sky.gdshader (its billow layer averages ~+0.16).
	float cover = mix(0.74, 0.26, cloud_cover);
	float density = smoothstep(cover - 0.02, cover + 0.12, v * 0.78 + 0.16);
	return 1.0 - density * cloud_shadow_strength;
}
