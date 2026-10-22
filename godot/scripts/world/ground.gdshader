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
uniform float grass_radius = 60.0;   // where the 3D grass ends (GrassFar: 216 rows x 0.6 m / 2 - 2)
uniform vec2 camp = vec2(-1000.0);   // ground worn bare around the fire
uniform float camp_radius = 9.0;
uniform vec2 trace_a = vec2(-1000.0);  // a path worn between two places
uniform vec2 trace_b = vec2(-1000.0);
uniform vec2 trace_c = vec2(-1000.0);
// Narrower than it was. What forty-five men walking the same line wear into a
// prairie is a footpath with the grass beaten out of it, not a cart road.
uniform float trace_width = 0.62;
global uniform float wetness;
global uniform float night_amount;
// The baked colour and normal again, one texel per vertex (terrain.gd), read
// per pixel inside the map. The distant hills share this material and have
// only their vertices.
uniform sampler2D ground_color_tex : filter_linear, repeat_disable;
uniform sampler2D ground_normal_tex : filter_linear, repeat_disable;
uniform sampler2D ground_lie_tex : filter_linear, repeat_disable;   // the broad slope (x, z)
uniform float map_size = 1024.0;
uniform float map_res = 256.0;

varying vec3 v_world;
varying vec3 v_normal;
#include "res://scripts/world/prairie.gdshaderinc"
#include "res://scripts/world/cloud_shadow.gdshaderinc"

// Only ever asked at a lattice corner, so keyed by an integer hash. A float
// hash loses its low digits at the coordinates the fine patterns reach (a
// grain at 5.5 a metre is lattice 3,000 a kilometre out, flecks at 9 near
// 5,000) and returns two values for one corner, seen from either side; the
// noise then jumps along straight seams laid across the sand.
float hash(vec2 p) {
	uvec2 q = uvec2(ivec2(floor(p)) + ivec2(1 << 20));
	// PCG-style 2D hash: a plain multiply-xor of the two axes left whole
	// rows of corners with related values, and a run of them drew one straight
	// white seam the length of the river.
	q = q * 1664525u + 1013904223u;
	q.x += q.y * 1664525u;
	q.y += q.x * 1664525u;
	q = q ^ (q >> 16u);
	q.x += q.y * 1664525u;
	q.y += q.x * 1664525u;
	q = q ^ (q >> 16u);
	uint n = q.x ^ q.y;
	return float(n >> 8u) * (1.0 / 16777216.0);
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

// Gradient noise, for the relief. Value noise will not do there: its slope
// falls to zero along every edge of its lattice, so a normal bent by it is
// left unbent in straight lines across the ground -- and with each octave
// turned, those lines ran across every slope and sandbar at several angles,
// long and ruled, which is the crease this game had for weeks. Gradient
// noise is zero on the lattice points instead, and its slope never stops.
// Keyed by an integer hash. The float hash above loses its low digits at the
// lattice coordinates the fine octaves reach (tens of thousands), and then
// gives a corner one gradient seen from one side and another from the other:
// the pattern jumped across straight seams that ran the length of every
// slope, which no amount of filtering could smooth.
vec2 g_dir(vec2 c) {
	uvec2 q = uvec2(ivec2(c) + ivec2(1 << 20));
	// PCG-style 2D hash: a plain multiply-xor of the two axes left whole
	// rows of corners with related values, and a run of them drew one straight
	// white seam the length of the river.
	q = q * 1664525u + 1013904223u;
	q.x += q.y * 1664525u;
	q.y += q.x * 1664525u;
	q = q ^ (q >> 16u);
	q.x += q.y * 1664525u;
	q.y += q.x * 1664525u;
	q = q ^ (q >> 16u);
	uint n = q.x ^ q.y;
	float a = float(n >> 8u) * (6.2831853 / 16777216.0);
	return vec2(cos(a), sin(a));
}

float gnoise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	vec2 u = f * f * f * (f * (f * 6.0 - 15.0) + 10.0);
	float a = dot(g_dir(i), f);
	float b = dot(g_dir(i + vec2(1.0, 0.0)), f - vec2(1.0, 0.0));
	float c = dot(g_dir(i + vec2(0.0, 1.0)), f - vec2(0.0, 1.0));
	float d = dot(g_dir(i + vec2(1.0, 1.0)), f - vec2(1.0, 1.0));
	return mix(mix(a, b, u.x), mix(c, d, u.x), u.y) + 0.5;
}

// ``cycles_per_px`` is how many of the base octave's waves one pixel spans.
// An octave finer than a pixel aliases, and an aliased octave of a regular
// lattice comes out as straight moire bands -- so each is faded out before it
// gets there rather than drawn and hoped for.
float gfbm(vec2 p, float cycles_per_px) {
	float v = 0.0;
	float a = 0.52;
	float f = cycles_per_px;
	for (int i = 0; i < 4; i++) {
		float keep = 1.0 - smoothstep(0.2, 0.45, f);
		v += a * mix(0.5, gnoise(p), keep);
		p = TURN * p * 2.07;
		f *= 2.07;
		a *= 0.5;
	}
	return v;
}

// How near a point is to the edge of its cell in a field of random cells:
// 0 on an edge. Mud drying on a bar shrinks and splits into these polygons.
float cell_edge(vec2 x) {
	vec2 i = floor(x);
	vec2 f = fract(x);
	float d1 = 8.0;
	float d2 = 8.0;
	for (int j = -1; j <= 1; j++) {
		for (int k = -1; k <= 1; k++) {
			vec2 g = vec2(float(k), float(j));
			vec2 o = vec2(hash(i + g), hash(i + g + vec2(4099.0, 77.0))) * 0.8 + 0.1;
			float d = length(g + o - f);
			if (d < d1) {
				d2 = d1;
				d1 = d;
			} else if (d < d2) {
				d2 = d;
			}
		}
	}
	return d2 - d1;
}

// The height the relief normal is bent by: tussocks on the prairie, soft
// hummocks on the sand. One function, so all three samples of it agree.
float relief_h(vec2 q, float sand, float px) {
	// The ripple marks on the sand are not in here: they are sharp enough that
	// their slope is taken exactly (see fragment) rather than by differencing.
	float h = gfbm(q * 2.6, px * 2.6);
	return mix(h, gnoise(q * 0.9), sand * 0.7);
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


// A cubic B-spline lookup from four bilinear fetches. Bilinear normals are
// continuous but their slope jumps at every texel, and on a 4 m grid each jump
// shades as a crease running along the cell edge; the B-spline is smooth
// across them.
vec4 texture_bspline(sampler2D tex, vec2 uv, float res) {
	vec2 st = uv * res - 0.5;
	vec2 i = floor(st);
	vec2 f = st - i;
	vec2 f2 = f * f;
	vec2 f3 = f2 * f;
	vec2 w0 = (1.0 - 3.0 * f + 3.0 * f2 - f3) / 6.0;
	vec2 w1 = (4.0 - 6.0 * f2 + 3.0 * f3) / 6.0;
	vec2 w2 = (1.0 + 3.0 * f + 3.0 * f2 - 3.0 * f3) / 6.0;
	vec2 w3 = f3 / 6.0;
	vec2 g0 = w0 + w1;
	vec2 g1 = w2 + w3;
	vec2 h0 = (i - 0.5 + w1 / g0) / res;
	vec2 h1 = (i + 1.5 + w3 / g1) / res;
	return g0.y * (g0.x * texture(tex, vec2(h0.x, h0.y)) + g1.x * texture(tex, vec2(h1.x, h0.y)))
			+ g1.y * (g0.x * texture(tex, vec2(h0.x, h1.y)) + g1.x * texture(tex, vec2(h1.x, h1.y)));
}


void vertex() {
	v_world = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	v_normal = normalize((MODEL_MATRIX * vec4(NORMAL, 0.0)).xyz);
}

void fragment() {
	vec2 p = v_world.xz;
	float n = vnoise(p * 0.06) * 0.5 + fbm(p * 0.35) * 0.5;
	vec4 base = COLOR;
	vec3 nrm = v_normal;
	// The height every band keyed to it reads (wet sand, swash, drift lines).
	// The mesh's own height is flat across each triangle, so a band drawn from
	// it kinks at every edge and draws the triangles on the sand.
	float hgt = v_world.y;
	// The lie of the land: what grows where goes by this, the light by nrm.
	vec3 lie = v_normal;
	if (p.x >= 0.0 && p.y >= 0.0 && p.x <= map_size && p.y <= map_size) {
		vec2 guv = (p / map_size * map_res + 0.5) / (map_res + 1.0);   // texel centres on the vertices
		// The baked colour jumps from one vertex to the next where sand gives way
		// to grass or loess, and any interpolation of it prints the 4 m grid.
		// Smoothed, and the lookup nudged by a texel's worth of noise, so where
		// the colour changes it does so along a ragged line, not a cell edge.
		vec2 wob = (vec2(vnoise(p * 0.21), vnoise(p * 0.21 + 31.7)) - 0.5) * 1.6 / (map_res + 1.0);
		base = texture_bspline(ground_color_tex, guv + wob, map_res + 1.0);
		vec4 nh = texture_bspline(ground_normal_tex, guv, map_res + 1.0);
		nrm = normalize(nh.xyz);
		hgt = nh.w;
		vec2 lxz = texture_bspline(ground_lie_tex, guv, map_res + 1.0).xy;
		lie = vec3(lxz.x, sqrt(max(1.0 - dot(lxz, lxz), 0.0)), lxz.y);
	}
	vec3 c = pow(clamp(base.rgb, vec3(0.0), vec3(1.0)), vec3(2.2));  // baked colours are sRGB
	float prairie = clamp(base.a, 0.0, 1.0);

	// Prairie: blend the baked tint toward the grass the blades would show here.
	float patch = grass_patch(p);
	vec3 blades = mix(gold, green, patch * 0.8);
	// The floodplain sits low (~y 1-3); above it the prairie proper.
	blades = prairie_species(p, blades, smoothstep(2.0, 5.0, hgt));
	// Past the blades the ground has to be the blades, seen from afar: their
	// tips and the shade between them, which averages a little darker than a
	// tip. Half-way to the blade colour left the far prairie a pale green field
	// beyond a gold one, with the seam running round the camera.
	// Seen from off, a prairie is mostly blade tips, and the blade shader
	// brightens and warms its tips to straw (and dries the lighter blades).
	// The plain blade colour here left every hill past the blades a cool,
	// minty green beyond a gold field, with the line between them going round
	// the camera.
	vec3 seen = mix(blades, blades * 1.22 + vec3(0.05, 0.04, 0.0), 0.55) * vec3(1.05, 1.0, 0.88);
	vec3 tips = mix(c, seen * 0.98, 0.85);
	float dist = length(v_world - CAMERA_POSITION_WORLD);
	float under = 1.0 - smoothstep(grass_radius * 0.55, grass_radius * 1.05, dist);
	// Under the blades the ground is in their shade: dead thatch, darker than
	// any blade standing on it, which is what lets the blades be seen at all.
	vec3 grassy = mix(tips, mix(thatch, blades, 0.22) * 0.82, under * 0.85);
	// North-facing slopes (−z) hold moisture and stay greener; crests bleach gold.
	float north = clamp(-lie.z * 2.5, 0.0, 1.0);
	float slope = 1.0 - lie.y;
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
	// And where the prairie runs over a cut bank too steep for grass to stand
	// (from about thirty-five degrees the sod breaks): raw loess between the tufts,
	// not a smooth sheet of the far-grass colour.
	bare = max(bare, prairie * smoothstep(0.12, 0.22, slope) * 0.9);
	float strata = sin(hgt * 2.2 + vnoise(p * 0.08) * 5.0) * 0.5 + 0.5;
	// On prairie the colour here is already the grass's; a cut bank there shows
	// the loess under it, pale buff, with the darker sod lip along its top edge.
	vec3 loess_base = mix(c, pow(vec3(0.62, 0.53, 0.39), vec3(2.2)) * (0.9 + fbm(p * 1.3) * 0.2), prairie);
	vec3 loess = loess_base * (0.9 + strata * 0.14);
	float clinging = smoothstep(0.5, 0.72, fbm(p * 0.9));
	loess = mix(loess, mix(thatch, blades, 0.6), clinging * 0.7);
	c = mix(c, loess, bare);

	// Sandbars: wind and current ripples, darkening to wet sand at the waterline
	// (the river surface sits at y = -0.35).
	float sand = (1.0 - prairie) * (1.0 - smoothstep(0.08, 0.2, slope));
	// Ripple marks: the current builds them across its flow in trains that bend
	// and fork, a long gentle back and a short steep face downstream, with the
	// dark grains and silt lying in the troughs. A soft sine at two metres read
	// as brush strokes; these are half a metre and sharp-crested, and they fade
	// out by the width of a pixel before they can alias into a moire.
	// One heading, bent by a slow warp. Turning the heading itself with the
	// noise multiplies its turn by the distance from the origin, and five
	// hundred metres out that made the phase change faster than a pixel.
	vec2 r_dir = vec2(0.8, 0.6);
	float r_ph = dot(p, r_dir) / 0.55 + vnoise(p * 0.03) * 12.0 + vnoise(p * 0.16) * 2.6 + fbm(p * 0.45) * 1.1;
	float r_f = fract(r_ph);
	float r_m = min(r_f / 0.72, (1.0 - r_f) / 0.28);
	float r_h = r_m * r_m;                    // round troughs, sharp crests
	float r_dh = r_f < 0.72 ? 2.0 * r_m / 0.72 : -2.0 * r_m / 0.28;
	// How much ground a pixel covers, worked out from the distance and the
	// smooth normal rather than with fwidth. fwidth measures the triangle the
	// pixel lands on, and on a sharp bank every triangle leans its own way, so
	// the ripples faded in and out by triangles and drew the mesh on the sand.
	vec3 to_eye = CAMERA_POSITION_WORLD - v_world;
	float graze = max(abs(dot(nrm, normalize(to_eye))), 0.08);
	float footprint = length(to_eye) * 0.0012 / graze;
	float r_fade = 1.0 - smoothstep(0.18, 0.45, footprint / 0.55 * 1.4);
	// In trains, not one sheet: the higher, drier bar has been blown smooth.
	// Trains, with plain sand between them. A wide threshold on one octave
	// laid ripples over nearly every bar, edge to edge, like corrugated iron.
	float r_field = vnoise(p * 0.05 + 7.0) * 0.65 + vnoise(TURN * p * 0.13 + 3.0) * 0.35;
	float r_mask = smoothstep(0.5, 0.72, r_field) * (1.0 - smoothstep(0.8, 2.4, hgt) * 0.7);
	float r_amt = r_fade * r_mask * sand;
	vec2 ripple_slope = r_dir * (r_dh / 0.55) * 0.02 * r_amt;
	float ripple = mix(0.5, r_h, r_amt);
	// Missouri sand is grey-buff, not beach gold, and at noon a pale sheet of it
	// was the brightest thing on the screen.
	// Buff, though: grey-white read as snow under a blue sky.
	vec3 sandy = c * vec3(0.95, 0.92, 0.85) * (0.87 + ripple * 0.14);
	float wet = 1.0 - smoothstep(-0.2, 0.9, hgt + (vnoise(p * 0.5) - 0.5) * 0.4);
	sandy = mix(sandy, sandy * vec3(0.60, 0.56, 0.50), wet * 0.85);  // wet sand goes brown, not grey
	// The swash: the last hand's breadth above the water is soaked through,
	// darkest and glossy, with a ragged line where the lap last reached.
	float swash = 1.0 - smoothstep(-0.36, -0.1, hgt + (vnoise(p * 1.7) - 0.5) * 0.12);
	sandy = mix(sandy, sandy * vec3(0.52, 0.48, 0.42), swash * 0.8);
	// A bar is not one sheet of clean sand. The river leaves silt in it, and the
	// last fall of the water leaves damp patches that dry from the edges in.
	float damp = smoothstep(0.42, 0.74, fbm(p * 0.09)) * (1.0 - smoothstep(0.6, 2.6, hgt));
	sandy = mix(sandy, sandy * vec3(0.78, 0.76, 0.72), damp * 0.5);  // soft: strong, these read as smudges
	float silt = smoothstep(0.52, 0.8, fbm(p * 0.35 + 19.0));
	sandy = mix(sandy, sandy * vec3(0.84, 0.81, 0.75), silt * 0.4);
	// Only where there is sand to see: it is most of a pixel's work on a bar,
	// and the prairie covers most of the screen.
	if (sand > 0.001) {
		// The dry top of a bar is the wind's: fine pale sand drifted in long tongues
		// down the wind with the coarse, darker lag left between them, and the
		// surface combed into small ripples a hand apart. Without it the high bars
		// were one flat sheet from the waterline to the willows.
		vec2 wind = vec2(0.95, -0.31);
		vec2 across = vec2(-wind.y, wind.x);
		// Bars stand only a foot or two out of the river (its surface is at -0.35).
		// Mud lies in the hollows; the wind has the rest (see below).
		float mud = smoothstep(0.55, 0.75, fbm(p * 0.07 + 41.0)) * (1.0 - smoothstep(0.15, 0.5, hgt)) * (1.0 - swash);
		float dry = smoothstep(-0.05, 0.4, hgt) * (1.0 - damp) * (1.0 - mud);
		float tongues = vnoise(vec2(dot(p, wind) * 0.06, dot(p, across) * 0.55)) * 0.65
				+ vnoise(vec2(dot(p, wind) * 0.15, dot(p, across) * 1.3) + 11.0) * 0.35;
		sandy *= mix(1.0, mix(0.88, 1.06, smoothstep(0.3, 0.72, tongues)), dry);
		// Wind ripples: crests across the wind, a long back and steep lee like the
		// current's but under half the size, and only where the current's are not.
		float w_ph = dot(p, wind) / 0.24 + vnoise(p * 0.7) * 3.0 + vnoise(p * 2.3) * 0.8;
		float w_f = fract(w_ph);
		float w_m = min(w_f / 0.75, (1.0 - w_f) / 0.25);
		float w_dh = w_f < 0.75 ? 2.0 * w_m / 0.75 : -2.0 * w_m / 0.25;
		float w_amt = (1.0 - smoothstep(0.18, 0.45, footprint / 0.24 * 1.4)) * dry * (1.0 - r_mask) * sand
				* smoothstep(0.3, 0.5, vnoise(p * 0.22 + 5.0));
		ripple_slope += wind * (w_dh / 0.24) * 0.012 * w_amt;
		sandy *= 1.0 + (w_m * w_m - 0.5) * 0.14 * w_amt;
		// Mud: in the low hollows the last fall of the river left a skin of silt,
		// grey-brown, that has dried and split into polygons a hand or two across.
		if (mud > 0.01 && dist < 60.0) {
			// A crack is a couple of centimetres wide, thinner than a pixel a few
			// metres off at a low eye. Drawn no thinner than a pixel, and paler as it
			// is widened, so it keeps its weight on the screen and does not alias.
			float w_cell = max(0.06, footprint * 2.4 * 1.3);
			float cracks = 1.0 - smoothstep(w_cell * 0.45, w_cell, cell_edge(p * 2.4 + (vec2(vnoise(p * 3.1), vnoise(p * 3.1 + 9.0)) - 0.5) * 0.35));
			cracks *= min(1.0, 0.09 / w_cell) * (1.0 - smoothstep(0.06, 0.14, footprint));
			vec3 skin = sandy * vec3(0.80, 0.77, 0.72);
			skin *= 1.0 - cracks * 0.45;
			sandy = mix(sandy, skin, mud * (1.0 - smoothstep(35.0, 60.0, dist)));
		}
	}
	// Drift lines: dark bands of twigs and silt left where the river last stood.
	float drift_line = smoothstep(0.06, 0.0, abs(fract(hgt * 1.3 + vnoise(p * 0.2) * 0.6) - 0.5) - 0.44);
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

	// Less on the bars: at three metres it reads on clean sand as dirty smudges.
	c *= 1.0 + (n - 0.5) * mottle * 2.0 * mix(1.0, 0.35, sand);
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
	vec3 bumped = nrm - vec3(ripple_slope.x, 0.0, ripple_slope.y);
	if (relief > 0.01) {
		// The step the slope is measured over: never finer than a pixel, nor
		// than the finest wave still drawn, or the difference aliases too.
		float px = max(footprint, 0.004);
		float e = max(0.06, px * 1.5);
		vec2 dx = vec2(e, 0.0);
		vec2 dz = vec2(0.0, e);
		// Tussocks are a hand high on a pace of ground, a gentle tilt. At 0.5 the
		// bumps leant up to sixty degrees, their far sides went near black, and
		// wherever the grass was thin (the camp, the landing) the ground read as
		// a camouflage print.
		float scale = 0.16;
		// fbm, not two octaves of plain value noise. The gradient of value noise
		// peaks inside every lattice cell, so bending the normal by it laid a
		// cobbled grid over every slope in the game -- the single most visible
		// artifact on the ground, and invisible in the colour, since it was in
		// the shading.
		float h0 = relief_h(p, sand, px);
		float hx = relief_h(p + dx, sand, px);
		float hz = relief_h(p + dz, sand, px);
		vec2 tilt = vec2(-(hx - h0), -(hz - h0)) / e * scale * relief;
		// And never more than about twenty-five degrees, whatever the noise does.
		tilt *= min(1.0, 0.45 / max(length(tilt), 1e-4));
		bumped += vec3(tilt.x, 0.0, tilt.y);
	}
	NORMAL = normalize((VIEW_MATRIX * vec4(normalize(bumped), 0.0)).xyz);
	// The same moonlight as the blades: the prairie under them goes grey with them.
	float lum = dot(c, vec3(0.3, 0.59, 0.11));
	float moonlit = smoothstep(0.55, 1.0, night_amount);  // dusk keeps its gold
	c = mix(c, vec3(lum) * vec3(0.82, 0.9, 1.08), moonlit * 0.8 * prairie) * mix(1.0, 0.62, moonlit * prairie);
	ALBEDO = c * cloud_light(v_world) * mix(1.0, 0.62, wetness);
	ROUGHNESS = mix(0.95, 0.42, max(wetness, sand * max(wet * 0.55, swash * 0.6)));
	SPECULAR = mix(0.2, 0.5, wetness);
}
