shader_type sky;
// Big prairie sky: graded blue, sun disk and glow, painterly drifting clouds lit
// by the sun, warm sunsets, and stars with a moon at night. Colours and cloud
// cover are driven from sky.gd by the Day Clock and weather.

uniform vec3 zenith_color : source_color = vec3(0.24, 0.45, 0.78);
uniform vec3 horizon_color : source_color = vec3(0.72, 0.80, 0.88);
uniform vec3 ground_color : source_color = vec3(0.30, 0.28, 0.22);
uniform vec3 sun_color : source_color = vec3(1.0, 0.95, 0.85);
uniform vec3 glow_color : source_color = vec3(1.0, 0.75, 0.45);
uniform float glow_amount = 0.35;
uniform float sun_size = 0.9994;
uniform float cloud_coverage = 0.45;   // 0 clear .. 1 overcast
uniform float cloud_darkness = 0.0;    // storm
uniform vec3 cloud_light : source_color = vec3(1.0, 0.98, 0.95);
uniform vec3 cloud_shadow : source_color = vec3(0.55, 0.60, 0.70);
uniform float star_amount = 0.0;
uniform vec3 moon_dir = vec3(0.3, 0.6, -0.7);
uniform float moon_amount = 0.0;
uniform float wind_speed = 0.006;

float hash12(vec2 p) {
	vec3 p3 = fract(vec3(p.xyx) * 0.1031);
	p3 += dot(p3, p3.yzx + 33.33);
	return fract((p3.x + p3.y) * p3.z);
}

float vnoise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	vec2 u = f * f * (3.0 - 2.0 * f);
	return mix(mix(hash12(i), hash12(i + vec2(1.0, 0.0)), u.x),
			mix(hash12(i + vec2(0.0, 1.0)), hash12(i + vec2(1.0, 1.0)), u.x), u.y);
}

float fbm(vec2 p, int octaves) {
	float v = 0.0;
	float a = 0.5;
	mat2 rot = mat2(vec2(0.8, -0.6), vec2(0.6, 0.8));
	for (int i = 0; i < octaves; i++) {
		v += a * vnoise(p);
		p = rot * p * 2.03 + vec2(1.7, 9.2);
		a *= 0.5;
	}
	return v;
}

void sky() {
	vec3 dir = normalize(EYEDIR);
	vec3 sun = normalize(LIGHT0_DIRECTION);
	float up = dir.y;

	// Base gradient, with a brighter band at the horizon.
	float t = pow(clamp(up, 0.0, 1.0), 0.55);
	vec3 col = mix(horizon_color, zenith_color, t);
	float mu = dot(dir, sun);
	float sun_up = clamp(sun.y * 4.0 + 0.4, 0.0, 1.0);
	// Warm scattering around the sun, strongest when it is low.
	float halo = pow(max(mu, 0.0), 6.0) * glow_amount * (1.0 - clamp(up, 0.0, 1.0));
	col += glow_color * halo * sun_up;
	col = mix(col, ground_color, smoothstep(0.0, -0.08, up));

	if (!AT_CUBEMAP_PASS) {
		// Two decks of cloud on planes above the prairie: fair-weather cumulus
		// piling up over the plains, and thin cirrus much higher and slower.
		if (up > 0.0) {
			vec2 drift = vec2(TIME * wind_speed, TIME * wind_speed * 0.4) * (1.0 + cloud_darkness * 2.0);

			// Cumulus: rounded, bright-topped heaps that grow taller in a storm.
			vec2 uv = dir.xz / (up + 0.12) * mix(0.72, 0.5, cloud_darkness);
			float n = fbm(uv + drift, 6);
			float billow = fbm(uv * 2.4 - drift * 1.4, 4);
			float shape = n * 0.78 + billow * 0.22;
			float cover = mix(0.74, 0.26, cloud_coverage);
			float edge = mix(0.1, 0.34, cloud_darkness);
			float density = smoothstep(cover, cover + edge, shape);
			density = density * density * (3.0 - 2.0 * density);  // firm, rounded edges
			// Light the tops toward the sun: sample the noise a step sunward.
			vec2 sun_step = normalize(sun.xz + 0.0001) * 0.1;
			float toward = fbm(uv + drift + sun_step, 4);
			float lit = clamp(0.55 + (shape - toward) * 5.0, 0.0, 1.0);
			// Shaded bases: the underside of a heap is flat and grey.
			float base = smoothstep(0.3, 0.015, up) * 0.65;
			vec3 cloud = mix(cloud_shadow, cloud_light, lit * (1.0 - base));
			cloud = mix(cloud, glow_color * 1.15, halo * 1.4);
			cloud *= 1.0 - cloud_darkness * 0.65;

			// Cirrus: fibrous streaks, stretched along the wind, high and faint.
			vec2 cuv = dir.xz / (up + 0.035) * 0.42;
			cuv.x *= 0.35;  // drawn out downwind
			float cirrus = fbm(cuv + drift * 0.35, 5);
			float cirrus_d = smoothstep(0.52, 0.78, cirrus) * (1.0 - cloud_darkness) * (0.35 + 0.35 * cloud_coverage);
			vec3 cirrus_col = mix(cloud_light, glow_color, halo * 0.8);

			float fade = smoothstep(0.0, 0.12, up);
			col = mix(col, cirrus_col, cirrus_d * smoothstep(0.02, 0.2, up) * 0.75);
			col = mix(col, cloud, density * fade * 0.95);
		}

		// Sun disk (hidden by thick cloud).
		float disk = smoothstep(sun_size, sun_size + 0.0003, mu);
		col += sun_color * disk * 6.0 * (1.0 - cloud_darkness) * sun_up;

		// Night: the prairie sky. Two grades of star, a Milky Way arching over
		// (Cygnus high overhead in an August evening at this latitude) and its
		// dust lanes, then the moon.
		if (star_amount > 0.001 && up > 0.0) {
			float clear_sky = star_amount * smoothstep(0.0, 0.2, up) * (1.0 - cloud_coverage);
			vec2 suv = vec2(atan(dir.x, dir.z) * 160.0, asin(up) * 160.0);
			// Bright, named stars: sparse, varied in size and colour, slow to twinkle.
			vec2 sc = floor(suv);
			float h = hash12(sc);
			vec2 offs = vec2(hash12(sc + 3.1), hash12(sc + 7.9)) * 0.6 + 0.2;
			float d = length(fract(suv) - offs);
			float mag = mix(0.5, 1.8, hash12(sc + 1.3));
			float twinkle = 0.72 + 0.28 * sin(TIME * 1.7 + h * 90.0);
			float star = step(0.985, h) * smoothstep(0.1 * mag, 0.0, d) * twinkle * mag;
			// A few of them warm, most of them blue-white.
			vec3 star_col = mix(vec3(0.82, 0.88, 1.0), vec3(1.0, 0.86, 0.72), step(0.7, hash12(sc + 5.7)));
			col += star_col * star * clear_sky;
			// Faint field: the dust of lesser stars, on a finer grid.
			vec2 fuv = suv * 2.7;
			vec2 fc = floor(fuv);
			float fh = hash12(fc + 19.3);
			float faint = step(0.955, fh) * smoothstep(0.09, 0.0, length(fract(fuv) - 0.5)) * mix(0.15, 0.5, hash12(fc + 2.2));
			col += vec3(0.86, 0.9, 1.0) * faint * clear_sky;
			// The Milky Way: a broad band about its own axis, curdled with dust.
			vec3 axis = normalize(vec3(0.76, 0.16, -0.63));  // band arches near the zenith
			float band = 1.0 - smoothstep(0.04, 0.34, abs(dot(dir, axis)));
			float clouds_of_stars = fbm(vec2(atan(dir.x, dir.z) * 3.2, asin(up) * 4.0) + 4.0, 5);
			float lanes = smoothstep(0.3, 0.8, clouds_of_stars);
			col += vec3(0.62, 0.66, 0.82) * band * (0.03 + 0.045 * lanes) * clear_sky;
			col += vec3(0.9, 0.92, 1.0) * band * faint * 2.5 * clear_sky;  // the band is thick with faint stars
		}

		float moon = smoothstep(0.99935, 0.9995, dot(dir, normalize(moon_dir)));
		col += vec3(0.95, 0.94, 0.88) * moon * moon_amount * 2.2;
		col += vec3(0.30, 0.34, 0.48) * pow(max(dot(dir, normalize(moon_dir)), 0.0), 60.0) * moon_amount * 0.35;
		col += vec3(0.16, 0.19, 0.30) * pow(max(dot(dir, normalize(moon_dir)), 0.0), 16.0) * moon_amount * 0.07;
	}

	COLOR = col;
}
