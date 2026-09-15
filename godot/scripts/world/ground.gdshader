shader_type spatial;
// The ground: baked vertex colours (grass, sandbars, loess) broken up with
// world-space mottling so it never reads as flat paint.

uniform float mottle = 0.22;

varying vec3 v_world;

float hash(vec2 p) {
	vec3 p3 = fract(vec3(p.xyx) * 0.1031);
	p3 += dot(p3, p3.yzx + 33.33);
	return fract((p3.x + p3.y) * p3.z);
}

float vnoise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	vec2 u = f * f * (3.0 - 2.0 * f);
	return mix(mix(hash(i), hash(i + vec2(1.0, 0.0)), u.x), mix(hash(i + vec2(0.0, 1.0)), hash(i + vec2(1.0, 1.0)), u.x), u.y);
}

void vertex() {
	v_world = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

void fragment() {
	vec2 p = v_world.xz;
	float n = vnoise(p * 0.06) * 0.5 + vnoise(p * 0.35) * 0.3 + vnoise(p * 2.1) * 0.2;
	vec3 c = pow(max(COLOR.rgb, vec3(0.0)), vec3(2.2));  // baked colours are sRGB
	c *= 1.0 + (n - 0.5) * mottle * 2.0;
	// Slight warm/cool drift over large areas.
	float drift = vnoise(p * 0.012);
	c *= mix(vec3(1.04, 1.0, 0.92), vec3(0.94, 1.02, 1.0), drift);
	c = clamp(c, vec3(0.0), vec3(1.0));
	if (any(isnan(c))) {
		c = vec3(0.25, 0.3, 0.15);
	}
	ALBEDO = c;
	ROUGHNESS = 0.95;
	SPECULAR = 0.2;
}
