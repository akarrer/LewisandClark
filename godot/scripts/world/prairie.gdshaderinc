// August tallgrass is a patchwork, not one colour: big bluestem turning bronze,
// switchgrass staying silver-green, goldenrod coming into bloom in drifts.
// Shared by the grass blades and the ground under/beyond them so they agree.

float ps_hash(vec2 p) {
	vec3 p3 = fract(vec3(p.xyx) * 0.1031);
	p3 += dot(p3, p3.yzx + 33.33);
	return fract((p3.x + p3.y) * p3.z);
}

float ps_noise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	vec2 u = f * f * (3.0 - 2.0 * f);
	return mix(mix(ps_hash(i), ps_hash(i + vec2(1.0, 0.0)), u.x),
			mix(ps_hash(i + vec2(0.0, 1.0)), ps_hash(i + vec2(1.0, 1.0)), u.x), u.y);
}

// ``upland`` 0 in the green bottomland, 1 on the prairie above it.
vec3 prairie_species(vec2 p, vec3 base, float upland) {
	float bluestem = smoothstep(0.5, 0.72, ps_noise(p / 34.0 + 11.0) * 0.75 + ps_noise(p / 9.0) * 0.25);
	float switchgrass = smoothstep(0.58, 0.78, ps_noise(p / 23.0 + 47.0) * 0.8 + ps_noise(p / 6.0 + 3.0) * 0.2);
	float goldenrod = smoothstep(0.7, 0.84, ps_noise(p / 13.0 + 91.0) * 0.7 + ps_noise(p / 3.0 + 7.0) * 0.3);
	// Colours written in sRGB, as picked; shading works in linear.
	vec3 bronze_c = pow(vec3(0.60, 0.40, 0.22), vec3(2.2));
	vec3 silver_c = pow(vec3(0.52, 0.58, 0.40), vec3(2.2));
	vec3 rod = pow(vec3(0.84, 0.66, 0.14), vec3(2.2));
	vec3 c = base;
	c = mix(c, bronze_c, bluestem * 0.5 * upland);
	c = mix(c, silver_c, switchgrass * 0.4);
	c = mix(c, rod, goldenrod * 0.45 * upland);
	return c;
}
