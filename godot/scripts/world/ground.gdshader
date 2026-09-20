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
uniform vec2 camp = vec2(-1000.0);   // ground worn bare around the fire
uniform float camp_radius = 9.0;
uniform vec2 trace_a = vec2(-1000.0);  // a path worn between two places
uniform vec2 trace_b = vec2(-1000.0);
uniform vec2 trace_c = vec2(-1000.0);
// Narrower than it was. What forty-five men walking the same line wear into a
// prairie is a footpath with the grass beaten out of it, not a cart road.
uniform float trace_width = 0.62;
global uniform float wetness;

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

// Value noise sits on an axis-aligned lattice, and stacking octaves of it
// straight on top of one another prints a basket weave over the ground that is
// plain to see on any slope. Turning each octave a little breaks the lattice up.
const mat2 TURN = mat2(vec2(0.80, 0.60), vec2(-0.60, 0.80));

float fbm(vec2 p) {
	float v = 0.0;
	float a = 0.52;
	for (int i = 0; i < 4; i++) {
		v += a * vnoise(p);
		p = TURN * p * 2.07;
		a *= 0.5;
	}
	return v;
}

// The height the relief normal is bent by: tussocks on the prairie, wind and
// current ripples on the sand. One function, so all three samples of it agree --
// the ripple used to be added to the centre sample only, which cancelled its own
// gradient and left the bars perfectly smooth.
float relief_h(vec2 q, float sand) {
	float h = fbm(q * 2.6);
	if (sand > 0.01) {
		float w = vnoise(q * 0.15) * 6.0;
		float r = sin(q.x * 2.6 + q.y * 1.1 + w) * 0.5 + 0.5;
		h = mix(h, mix(r, vnoise(q * 3.0), 0.35), sand * 0.85);
	}
	return h;
}

// The grass patch field: 0 = thin tawny grass, 1 = thick green.
float grass_patch(vec2 p) {
	// Rotated octaves. Stacking value noise on one axis-aligned lattice, then
	// hardening it with a smoothstep, prints a basket weave over the whole
	// prairie that is plain to see on any slope.
	vec2 q = p / 9.0;
	float v = vnoise(q) * 0.55;
	q = TURN * q * 3.9;
	v += vnoise(q) * 0.30;
	q = TURN * q * 2.3;
	v += vnoise(q) * 0.15;
	return smoothstep(0.25, 0.75, v);
}

#include "res://scripts/world/trace.gdshaderinc"


void vertex() {
	v_world = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	v_normal = normalize((MODEL_MATRIX * vec4(NORMAL, 0.0)).xyz);
}

void fragment() {
	vec2 p = v_world.xz;
	float n = vnoise(p * 0.06) * 0.5 + fbm(p * 0.35) * 0.5;
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
	float streak = vnoise(TURN * vec2(p.x * 1.3 + p.y * 0.4, p.y * 4.0));
	grassy *= 1.0 + (streak - 0.5) * 0.18 * (1.0 - under);
	// Gusts: the same bands that bend the blades brighten the prairie as they pass.
	float band = sin(dot(p, vec2(0.08, 0.05)) - TIME * 1.6) * 0.5 + 0.5;
	grassy *= 1.0 + band * band * 0.10 * (1.0 - under * 0.6);
	// Litter underfoot: dead stems and seed heads, only worth drawing up close.
	float near = 1.0 - smoothstep(6.0, 22.0, dist);
	float litter = fbm(p * 6.5);
	grassy *= 1.0 + (litter - 0.5) * 0.45 * near;
	c = mix(c, grassy, prairie);

	// Bare loess (bluff faces, cutbanks): soft strata by height, and tufts of
	// grass clinging on where the blades themselves are too steep to grow.
	float bare = (1.0 - prairie) * smoothstep(0.08, 0.25, slope);
	float strata = sin(v_world.y * 2.2 + vnoise(p * 0.08) * 5.0) * 0.5 + 0.5;
	vec3 loess = c * (0.9 + strata * 0.14);
	float clinging = smoothstep(0.5, 0.72, fbm(p * 0.9));
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
	// A bar is not one sheet of clean sand. The river leaves silt in it, and the
	// last fall of the water leaves damp patches that dry from the edges in.
	float damp = smoothstep(0.42, 0.74, fbm(p * 0.09)) * (1.0 - smoothstep(0.6, 2.6, v_world.y));
	sandy = mix(sandy, sandy * vec3(0.70, 0.67, 0.62), damp * 0.7);
	float silt = smoothstep(0.52, 0.8, fbm(p * 0.35 + 19.0));
	sandy = mix(sandy, sandy * vec3(0.78, 0.74, 0.66), silt * 0.45);
	// Drift lines: dark bands of twigs and silt left where the river last stood.
	float drift_line = smoothstep(0.06, 0.0, abs(fract(v_world.y * 1.3 + vnoise(p * 0.2) * 0.6) - 0.5) - 0.44);
	sandy *= 1.0 - drift_line * 0.38 * smoothstep(0.2, 0.8, vnoise(p * 1.1));
	// Shell and pebble flecks, thickest in the drift lines where the water sorted
	// them, and only worth drawing where the player can see them.
	float fleck_near = 1.0 - smoothstep(5.0, 26.0, dist);
	float fleck = smoothstep(0.90, 0.995, fbm(p * 9.0)) * (0.35 + drift_line);
	sandy += vec3(0.10, 0.095, 0.085) * fleck * fleck_near;
	// Fine grain up close: coarser sand and silt in soft flecks.
	float grain = fbm(p * 5.5);
	sandy *= 1.0 + (grain - 0.5) * 0.16 * (1.0 - smoothstep(4.0, 20.0, length(v_world - CAMERA_POSITION_WORLD)));
	c = mix(c, sandy, sand);

	// Trampled ground: bare earth around the camp and along the ways between it,
	// the boats and the bluff, with a scuffed fringe either side of the path.
	float half_w;
	float to_path = trace_field(p, trace_a, trace_b, trace_c, trace_width, half_w) + (vnoise(p * 1.2) - 0.5) * 0.55;
	float on_path = 1.0 - smoothstep(half_w * 0.35, half_w * 0.85, to_path);
	// A trail comes and goes along its length -- bare where the ground is hard
	// or the traffic funnels, grassed over between. A line of even width and
	// even colour from end to end reads as something graded, not something worn.
	on_path *= smoothstep(0.32, 0.62, fbm(p * 0.09));
	float fringe = 1.0 - smoothstep(half_w * 0.8, half_w * 2.2, to_path);
	float worn = 1.0 - smoothstep(camp_radius * 0.5, camp_radius, distance(p, camp) + (vnoise(p * 0.6) - 0.5) * 2.0);
	worn = max(worn, on_path);
	// Loess, which is pale: the dust these bluffs are made of is tan, not peat.
	vec3 earth = pow(vec3(0.52, 0.44, 0.33), vec3(2.2)) * (0.85 + fbm(p * 2.2) * 0.3);
	// Two ruts where the feet fall, and dust and small stones between them.
	float rut = 1.0 - smoothstep(0.0, half_w * 0.35, abs(to_path - half_w * 0.5));
	earth *= 1.0 - rut * 0.16;
	earth += vec3(0.05, 0.045, 0.035) * smoothstep(0.86, 0.99, vnoise(p * 14.0)) * on_path;
	// The fringe: grass bruised and bent, paler and drier, before the bare ground.
	c = mix(c, mix(c, earth, 0.3) * 1.05, fringe * prairie * 0.7);
	c = mix(c, earth, worn * prairie * 0.8);

	c *= 1.0 + (n - 0.5) * mottle * 2.0;
	// Slight warm/cool drift over large areas.
	float drift = vnoise(p * 0.012);
	c *= mix(vec3(1.04, 1.0, 0.92), vec3(0.94, 1.02, 1.0), drift);
	c = clamp(c, vec3(0.0), vec3(1.0));
	if (any(isnan(c))) {
		c = vec3(0.25, 0.3, 0.15);
	}
	// Rain-soaked earth goes dark and glossy.
	// Relief up close: the ground is a 4 m grid, so the bumps live in the shading.
	// One height field for all of it — ripples on sand, tussocks on prairie — and
	// its gradient bends the normal, fading out by 25 m where it would only alias.
	float relief = 1.0 - smoothstep(6.0, 25.0, dist);
	if (relief > 0.01) {
		float e = 0.06;
		vec2 dx = vec2(e, 0.0);
		vec2 dz = vec2(0.0, e);
		float scale = mix(0.5, 0.16, sand);  // dunes are softer than tussocks
		// fbm, not two octaves of plain value noise. The gradient of value noise
		// peaks inside every lattice cell, so bending the normal by it laid a
		// cobbled grid over every slope in the game -- the single most visible
		// artifact on the ground, and invisible in the colour, since it was in
		// the shading.
		float h0 = relief_h(p, sand);
		float hx = relief_h(p + dx, sand);
		float hz = relief_h(p + dz, sand);
		vec3 bumped = normalize(v_normal + vec3(-(hx - h0), 0.0, -(hz - h0)) / e * scale * relief);
		NORMAL = normalize((VIEW_MATRIX * vec4(bumped, 0.0)).xyz);
	}
	ALBEDO = c * cloud_light(v_world) * mix(1.0, 0.62, wetness);
	ROUGHNESS = mix(0.95, 0.42, max(wetness, sand * wet * 0.55));
	SPECULAR = mix(0.2, 0.5, wetness);
}
