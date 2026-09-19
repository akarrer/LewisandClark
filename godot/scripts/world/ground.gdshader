shader_type spatial;
// The ground: baked vertex colours (grass, sandbars, loess) broken up with
// world-space mottling so it never reads as flat paint. Where the vertex alpha
// marks prairie, the ground takes on the grass itself: shadowed thatch near the
// camera (under the grass blades), the colour of the blade tips further out, in
// the same gold/green patches the blades use, with gust sheen rolling across it.

uniform float mottle = 0.22;
// Keep in step with grass_blades.gdshader and grass_field.gdshader.
uniform vec3 gold : source_color = vec3(0.72, 0.62, 0.30);
uniform vec3 green : source_color = vec3(0.40, 0.52, 0.22);
uniform vec3 thatch : source_color = vec3(0.30, 0.28, 0.15);
uniform float grass_radius = 46.0;

varying vec3 v_world;
varying vec3 v_normal;
#include "res://scripts/world/prairie.gdshaderinc"
#include "res://scripts/world/cloud_shadow.gdshaderinc"

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

// The grass patch field: 0 = thin tawny grass, 1 = thick green.
float grass_patch(vec2 p) {
	return smoothstep(0.25, 0.75, vnoise(p / 9.0) * 0.65 + vnoise(p / 2.3) * 0.35);
}

void vertex() {
	v_world = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	v_normal = normalize((MODEL_MATRIX * vec4(NORMAL, 0.0)).xyz);
}

void fragment() {
	vec2 p = v_world.xz;
	float n = vnoise(p * 0.06) * 0.5 + vnoise(p * 0.35) * 0.3 + vnoise(p * 2.1) * 0.2;
	vec3 c = pow(clamp(COLOR.rgb, vec3(0.0), vec3(1.0)), vec3(2.2));  // baked colours are sRGB
	float prairie = clamp(COLOR.a, 0.0, 1.0);

	// Prairie: blend the baked tint toward the grass the blades would show here.
	float patch = grass_patch(p);
	vec3 blades = mix(gold, green, patch * 0.8);
	// The floodplain sits low (~y 1-3); above it the prairie proper.
	blades = prairie_species(p, blades, smoothstep(2.0, 5.0, v_world.y));
	vec3 tips = mix(c, blades * 1.08, 0.55);
	float dist = length(v_world - CAMERA_POSITION_WORLD);
	float under = 1.0 - smoothstep(grass_radius * 0.55, grass_radius * 1.05, dist);
	vec3 grassy = mix(tips, mix(thatch, blades, 0.35), under * 0.75);
	// North-facing slopes (−z) hold moisture and stay greener; crests bleach gold.
	float north = clamp(-v_normal.z * 2.5, 0.0, 1.0);
	float slope = 1.0 - v_normal.y;
	grassy = mix(grassy, grassy * vec3(0.82, 0.95, 0.80), north * smoothstep(0.02, 0.12, slope));
	// Fine streaks, like grass seen from afar, fading as the real blades take over.
	float streak = vnoise(vec2(p.x * 1.3 + p.y * 0.4, p.y * 4.0));
	grassy *= 1.0 + (streak - 0.5) * 0.18 * (1.0 - under);
	// Gusts: the same bands that bend the blades brighten the prairie as they pass.
	float band = sin(dot(p, vec2(0.08, 0.05)) - TIME * 1.6) * 0.5 + 0.5;
	grassy *= 1.0 + band * band * 0.10 * (1.0 - under * 0.6);
	// Litter underfoot: dead stems and seed heads, only worth drawing up close.
	float near = 1.0 - smoothstep(6.0, 22.0, dist);
	float litter = vnoise(vec2(p.x * 9.0 + p.y * 3.0, p.y * 2.5 - p.x * 1.5)) * 0.6 + vnoise(p * 23.0) * 0.4;
	grassy *= 1.0 + (litter - 0.5) * 0.45 * near;
	c = mix(c, grassy, prairie);

	// Bare loess (bluff faces, cutbanks): soft strata by height, and tufts of
	// grass clinging on where the blades themselves are too steep to grow.
	float bare = (1.0 - prairie) * smoothstep(0.08, 0.25, slope);
	float strata = sin(v_world.y * 2.2 + vnoise(p * 0.08) * 5.0) * 0.5 + 0.5;
	vec3 loess = c * (0.9 + strata * 0.14);
	float clinging = smoothstep(0.55, 0.75, vnoise(p * 0.9) * 0.7 + vnoise(p * 5.0) * 0.3);
	loess = mix(loess, mix(thatch, blades, 0.6), clinging * 0.7);
	c = mix(c, loess, bare);

	// Sandbars: wind and current ripples, darkening to wet sand at the waterline
	// (the river surface sits at y = -0.35).
	float sand = (1.0 - prairie) * (1.0 - smoothstep(0.08, 0.2, slope));
	float warp = vnoise(p * 0.15) * 6.0;
	float ripple = sin(p.x * 2.6 + p.y * 1.1 + warp) * 0.5 + 0.5;
	ripple = mix(ripple, vnoise(p * 3.0), 0.35);
	vec3 sandy = c * (0.9 + ripple * 0.2);
	float wet = 1.0 - smoothstep(-0.2, 0.9, v_world.y + (vnoise(p * 0.5) - 0.5) * 0.4);
	sandy = mix(sandy, sandy * vec3(0.62, 0.60, 0.58), wet * 0.85);
	// Drift lines: dark bands of twigs and silt left where the river last stood.
	float drift_line = smoothstep(0.06, 0.0, abs(fract(v_world.y * 1.3 + vnoise(p * 0.2) * 0.6) - 0.5) - 0.44);
	sandy *= 1.0 - drift_line * 0.25 * smoothstep(0.2, 0.8, vnoise(p * 1.1));
	// Fine grain up close: coarser sand and silt in soft flecks.
	float grain = vnoise(p * 7.0) * 0.6 + vnoise(p * 19.0) * 0.4;
	sandy *= 1.0 + (grain - 0.5) * 0.16 * (1.0 - smoothstep(4.0, 20.0, length(v_world - CAMERA_POSITION_WORLD)));
	c = mix(c, sandy, sand);

	c *= 1.0 + (n - 0.5) * mottle * 2.0;
	// Slight warm/cool drift over large areas.
	float drift = vnoise(p * 0.012);
	c *= mix(vec3(1.04, 1.0, 0.92), vec3(0.94, 1.02, 1.0), drift);
	c = clamp(c, vec3(0.0), vec3(1.0));
	if (any(isnan(c))) {
		c = vec3(0.25, 0.3, 0.15);
	}
	ALBEDO = c * cloud_light(v_world);
	ROUGHNESS = 0.95;
	SPECULAR = 0.2;
}
