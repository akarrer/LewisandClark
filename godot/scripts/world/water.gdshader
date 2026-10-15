shader_type spatial;
render_mode cull_disabled;
// The Missouri, "the Big Muddy": silt-laden and opaque, paling over the bars,
// quick in the channel, and rolling when it blows. Clark records the waves on
// this reach running high enough to take water over the pirogues' gunwales, so
// the wind drives the whole surface here -- glassy at dawn, whitecapping in a
// squall.
//
// Two wave trains. The long ones are Gerstner: they move the surface sideways
// as well as up, which bunches the water at the crests and broadens the
// troughs, and that is what makes a swell look like a swell rather than a
// ruffled sheet. The short ones live only in the normal. Every wave's slope is
// known analytically, and each is faded out once a pixel covers more than its
// own wavelength -- fwidth gives that footprint exactly. A normal differenced
// from noise per pixel aliases instead, and because both the sampling grid and
// the wave pattern are regular, that aliasing comes out as long straight
// interference bands ruled across the reach.

uniform vec3 deep_color : source_color = vec3(0.27, 0.205, 0.13);
uniform vec3 mid_color : source_color = vec3(0.50, 0.385, 0.225);
uniform vec3 shallow_color : source_color = vec3(0.70, 0.58, 0.365);
uniform vec3 foam_color : source_color = vec3(0.76, 0.72, 0.64);
uniform float flow_speed = 0.9;       // m/s the silt patterns travel downriver
uniform sampler2D river_tex : filter_linear, repeat_disable;  // river_half + distance from the waterline (m)
uniform sampler2D flow_tex : filter_linear, repeat_disable;   // distance to the channel centreline (m)
uniform float map_size = 1024.0;
uniform float river_half = 55.0;      // metres from the channel centre to the bank
uniform sampler2D depth_tex : hint_depth_texture, filter_linear;
global uniform vec4 sky_horizon;
global uniform vec4 sky_zenith;
uniform sampler2D screen_tex : hint_screen_texture, filter_linear_mipmap;
global uniform float wind_strength;
global uniform float night_amount;
global uniform vec3 moon_dir;
global uniform float moon_light;     // 0 with no moon up .. 1 for a full one
// sun_dir comes in with cloud_shadow.gdshaderinc, just below.
#include "res://scripts/world/cloud_shadow.gdshaderinc"

const mat2 TURN = mat2(vec2(0.80, 0.60), vec2(-0.60, 0.80));
const float TAU_ = 6.2831853;
const float GOLDEN = 2.399963;   // radians: no two waves in a train line up

// The long swell: wavelengths the water mesh can actually carry. At 2.3 m
// between vertices anything under about twelve metres has two vertices to its
// name and comes out as a wire cross-hatch rather than a wave.
const int SWELLS = 2;
const float SWELL_LAMBDA = 21.0;
const float SWELL_AMP = 0.26;
const float STEEPNESS = 0.55;    // how far the Gerstner crests pinch

varying vec3 v_base;             // world position before the waves moved it
varying vec2 v_along;            // downriver, worked out per vertex (see below)

// No sin() in here: the surface calls noise a few dozen times a pixel and the
// river fills a good part of the screen, so the hash is worth the care.
float hash(vec2 p) {
	vec3 p3 = fract(vec3(p.xyx) * 0.1031);
	p3 += dot(p3, p3.yzx + 33.33);
	return fract((p3.x + p3.y) * p3.z);
}

// For the lattice corners of noise(): an exact integer hash. The float one
// loses its low digits at the coordinates the fine foam and flecks reach,
// and seams the pattern along straight lines (see ground.gdshader).
float lhash(vec2 p) {
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

float noise(vec2 p) {
	vec2 i = floor(p); vec2 f = fract(p);
	vec2 u = f * f * (3.0 - 2.0 * f);
	return mix(mix(lhash(i), lhash(i + vec2(1, 0)), u.x), mix(lhash(i + vec2(0, 1)), lhash(i + vec2(1, 1)), u.x), u.y);
}

float fbm(vec2 p) {
	float v = 0.0;
	float a = 0.55;
	for (int i = 0; i < 3; i++) {
		v += a * noise(p);
		p = TURN * p * 2.07;
		a *= 0.5;
	}
	return v;
}

// How hard it is blowing, 0 at a dead calm and 1 in a squall.
float blow() {
	return clamp(wind_strength, 0.0, 4.0) * 0.25;
}

// Downriver: along the channel, which is perpendicular to the gradient of the
// distance-to-channel field, and southward. Four texture fetches, so it is done
// once per vertex rather than once per pixel -- the channel does not bend
// anything like fast enough to need more.
vec2 downriver(vec2 xz, sampler2D river, float msize) {
	vec2 uv = xz / msize;
	float e = 4.0 / msize;
	vec2 g = vec2(texture(river, uv + vec2(e, 0.0)).r - texture(river, uv - vec2(e, 0.0)).r,
			texture(river, uv + vec2(0.0, e)).r - texture(river, uv - vec2(0.0, e)).r);
	vec2 a = length(g) > 0.0001 ? normalize(vec2(-g.y, g.x)) : vec2(0.0, 1.0);
	return a * sign(a.y + 0.0001);
}

vec2 turn_by(vec2 d, float a) {
	float c = cos(a);
	float s = sin(a);
	return vec2(d.x * c - d.y * s, d.x * s + d.y * c);
}


// The long swell, as Gerstner waves. ``offset`` is the sideways pull that
// pinches the crests; ``h`` the lift; ``slope`` the surface gradient; ``fold``
// how far the water is heaping up, which is where the caps break.
void swell(vec2 base, vec2 along, float tt, float pix, float amp_scale,
		out vec2 offset, out float h, out vec2 slope, out float fold) {
	offset = vec2(0.0);
	h = 0.0;
	slope = vec2(0.0);
	fold = 0.0;
	// The crests wander, so they do not run as ruled parallel lines.
	float wander = noise(base * 0.017) * 5.0;
	for (int i = 0; i < SWELLS; i++) {
		float fi = float(i);
		float lambda = SWELL_LAMBDA * pow(0.58, fi);
		// In groups, not an even train: two plane waves of one height everywhere
		// interfere into a diamond lattice that reads, from the bluff, as a
		// quilted sheet rather than as water.
		float group = 0.35 + 1.3 * noise(base * 0.011 + fi * 5.1 - along * tt * 0.04);
		float amp = SWELL_AMP * pow(0.6, fi) * amp_scale * group;
		amp *= 1.0 - smoothstep(lambda * 0.7, lambda * 2.6, pix);
		if (amp < 0.0002) {
			continue;
		}
		vec2 dir = turn_by(along, fi * GOLDEN);
		float k = TAU_ / lambda;
		float ph = k * dot(base, dir) - tt * sqrt(9.81 * k) * 0.55 + wander;
		float c = cos(ph);
		float sn = sin(ph);
		float q = STEEPNESS / (k * amp * float(SWELLS) + 0.0001);
		q = min(q, 1.0);
		offset += q * amp * dir * c;
		h += amp * sn;
		slope += amp * k * c * dir;
		fold += q * amp * k * sn;
	}
}


// The chop and ripple on top of the swell: normal only, too short for the mesh.
vec2 chop_slope(vec2 base, vec2 along, float tt, float flow, float pix, float gust) {
	vec2 slope = vec2(0.0);
	float wander = noise(base * 0.028) * 6.0;
	// Eight waves, not six, at wavelengths that are not halvings of one
	// another, each crest bent by its own slow warp. Six plane waves in exact
	// octaves interfere into a lattice, and a lattice on a river reads as a
	// screen door laid over it.
	for (int i = 0; i < 8; i++) {
		float fi = float(i);
		float lambda = 7.0 * pow(0.6, fi) * (1.0 + 0.12 * sin(fi * 2.3));
		float amp = 0.05 * pow(0.66, fi) * gust;
		// The chop fades a good deal earlier than the swell. It is short enough
		// that it reaches the pixel limit while it is still the whole texture of
		// the surface, and the shimmer that follows is worse than losing it.
		// Gone before a wave is three pixels long: any later and the short ones
		// weave a fine basket pattern over the reach seen from the bluff.
		amp *= 1.0 - smoothstep(lambda * 0.12, lambda * 0.35, pix);
		// And thinned well before that from height: looking down from the bluff
		// the pixel is small but a whole field of crests is in view at once, and
		// any two trains still left cross-hatch it like a woven mat.
		amp *= 1.0 - 0.7 * smoothstep(lambda * 0.03, lambda * 0.12, pix);
		if (amp < 0.00002) {
			continue;
		}
		vec2 dir = turn_by(along, (fi + 0.5) * GOLDEN);
		float k = TAU_ / lambda;
		float bend = noise(turn_by(base, fi * GOLDEN + 0.4) * (0.9 / lambda) + fi * 17.3) * 3.2;  // turned, or the lattice prints a grid
		float ph = k * dot(base, dir) - tt * (1.2 + flow * 0.6) * sqrt(k) + wander + bend;
		slope += amp * k * cos(ph) * dir;
	}
	return slope;
}


// A line of something the current carries -- scum on a seam, the edge of a
// boil -- drawn ``width`` metres wide but never thinner than a pixel and a
// half. Where a pixel is wider than the line, it is spread out and dimmed by
// the same ratio, so a seam fades into the reach instead of breaking into
// dashes the way a hairline does past a hundred yards.
float soft_line(float d, float width, float pix) {
	float wd = max(width, pix * 1.5);
	return (1.0 - smoothstep(0.0, wd, abs(d))) * sqrt(width / wd);
}


// Boils: water welling up off the bed in the channel, a smooth pale disk that
// spreads, rings itself with a dark edge, and is gone, while the next one
// rises somewhere else. One cell in a drifting grid, each with its own time.
// ``rim`` is the ring, ``slick`` the glassy middle.
void boils(vec2 p, float tt, float pix, out float slick, out float rim) {
	slick = 0.0;
	rim = 0.0;
	const float CELL = 11.0;
	vec2 g = floor(p / CELL);
	for (int j = -1; j <= 1; j++) {
		for (int i = -1; i <= 1; i++) {
			vec2 c = g + vec2(float(i), float(j));
			float h = hash(c);
			vec2 at = (c + 0.2 + 0.6 * vec2(h, hash(c + 7.1))) * CELL;
			float life = fract(tt / (9.0 + 6.0 * h) + h * 13.7);
			float r = (0.6 + 4.2 * sqrt(life)) * (0.6 + 0.6 * hash(c + 3.3));
			float d = length(p - at) - r;
			float fade = smoothstep(0.0, 0.1, life) * (1.0 - smoothstep(0.55, 1.0, life));
			slick = max(slick, (1.0 - smoothstep(-r * 0.6, 0.0, d)) * fade);
			rim = max(rim, soft_line(d, 0.35, pix) * fade);
		}
	}
}


// Eddies: in the lee of a point or a cutbank the water along the shore turns
// back upstream and wheels round on itself. A slow log spiral of scum turning
// in place, a broken eddy line where it meets the current, and the water
// inside glassier than the reach. ``near`` says how much bank there is here to
// make one; past it this does nothing and costs nothing.
void eddies(vec2 p, float tt, float pix, float near, out float scum, out float calm) {
	scum = 0.0;
	calm = 0.0;
	if (near < 0.01 || pix > 0.8) {
		return;
	}
	const float CELL = 26.0;
	vec2 g = floor(p / CELL);
	for (int j = -1; j <= 1; j++) {
		for (int i = -1; i <= 1; i++) {
			vec2 c = g + vec2(float(i), float(j));
			float h = hash(c + 41.7);
			if (h < 0.45) {
				continue;             // not every stretch of bank turns one
			}
			vec2 at = (c + 0.25 + 0.5 * vec2(hash(c + 3.9), hash(c + 8.4))) * CELL;
			float R = 5.0 + 6.0 * hash(c + 1.3);
			vec2 d = p - at;
			float r = length(d);
			if (r > R * 1.2) {
				continue;
			}
			float spin = h > 0.72 ? 1.0 : -1.0;
			float a = atan(d.y, d.x);
			// Two arms, wound in, turning: what the scum on an eddy does.
			float arm = sin(a * 2.0 + spin * log(r + 0.6) * 4.0 - spin * tt * (0.5 + h * 0.4));
			float inside = 1.0 - smoothstep(R * 0.75, R, r);
			// The arms crowd together at the eye; fade them before they alias.
			float eye = smoothstep(0.6, 2.2, r) * (1.0 - smoothstep(0.15, 0.5, pix));
			float threads = smoothstep(0.35, 0.75, noise(d * 1.5 - tt * 0.2));
			scum = max(scum, smoothstep(0.7, 0.97, arm) * inside * eye * threads * 0.75);
			// The eddy line: where the turned water rubs against the current.
			// Beaded and broken, and fainter than the scum inside: drawn whole it
			// is a white crescent, which reads as a mark painted on the water.
			float rim = soft_line(r - R + (noise(d * 0.6) - 0.5) * 1.2, 0.3, pix)
					* smoothstep(0.5, 0.8, noise(vec2(a * 4.0 + tt * 0.3 * spin, h * 9.0)))
					* smoothstep(0.3, 0.7, noise(d * 2.2 + tt * 0.4));
			scum = max(scum, rim * 0.45);
			calm = max(calm, inside);
		}
	}
	scum *= near;
	calm *= near;
}


// What the water reflects, found by marching the reflected ray through the
// depth buffer. The river is drawn in the transparent pass (it thins over the
// bars), and the engine's own screen-space reflections never reach a
// transparent surface: the far bank and its trees were simply not in the
// water. ``hit`` comes back 0 where the ray leaves the screen or runs into
// nothing, and the caller shows the sky there.
vec3 march_reflection(vec3 from, vec3 dir, mat4 view, mat4 proj, mat4 inv_proj,
		sampler2D dtex, sampler2D stex, float blur, out float hit) {
	hit = 0.0;
	float t = 0.6;
	vec2 hit_uv = vec2(0.0);
	float prev_t = 0.0;
	for (int i = 0; i < 36; i++) {
		vec3 p = from + dir * t;
		vec4 vp = view * vec4(p, 1.0);
		vec4 cp = proj * vp;
		if (cp.w <= 0.0) {
			break;
		}
		vec2 uv = cp.xy / cp.w * 0.5 + 0.5;
		if (uv.x < 0.0 || uv.x > 1.0 || uv.y < 0.0 || uv.y > 1.0) {
			break;
		}
		float d = texture(dtex, uv).r;
		vec4 sv = inv_proj * vec4(uv * 2.0 - 1.0, d, 1.0);
		float scene_z = sv.z / sv.w;
		// Behind what the screen shows there, and not so far behind that it
		// passed under it unseen. "Too far" is a step's length: the steps grow
		// with distance, and a fixed allowance let a ray skip clean through a
		// treeline and come back with the sky behind it, which broke the
		// reflection of the far bank into scattered blots.
		float step_len = t - prev_t;
		if (vp.z < scene_z && scene_z - vp.z < 1.0 + step_len * 1.6) {
			// Narrow it down between the last miss and this.
			float a = prev_t;
			float b = t;
			for (int k = 0; k < 5; k++) {
				float m = (a + b) * 0.5;
				vec4 mv = view * vec4(from + dir * m, 1.0);
				vec4 mc = proj * mv;
				vec2 muv = mc.xy / mc.w * 0.5 + 0.5;
				vec4 ms = inv_proj * vec4(muv * 2.0 - 1.0, texture(dtex, muv).r, 1.0);
				if (mv.z < ms.z / ms.w) {
					b = m;
				} else {
					a = m;
				}
			}
			vec4 fc = proj * view * vec4(from + dir * b, 1.0);
			hit_uv = fc.xy / fc.w * 0.5 + 0.5;
			vec2 edge = min(hit_uv, 1.0 - hit_uv);
			hit = smoothstep(0.0, 0.08, min(edge.x, edge.y));
			break;
		}
		prev_t = t;
		t *= 1.18;
	}
	return hit > 0.0 ? textureLod(stex, hit_uv, blur).rgb : vec3(0.0);
}


// How deep the water is at a point on screen: the height of the surface above
// whatever the depth buffer has behind it. Whatever that is -- the bed, a hull,
// a snag, a man's legs -- the water breaks against it the same way.
float water_depth_at(vec2 suv, float surface_y, sampler2D dtex, mat4 inv_proj, mat4 inv_view) {
	float dd = texture(dtex, suv).r;
	vec4 bb = inv_proj * vec4(suv * 2.0 - 1.0, dd, 1.0);
	vec3 bw = (inv_view * vec4(bb.xyz / bb.w, 1.0)).xyz;
	return max(surface_y - bw.y, 0.0);
}


void vertex() {
	vec3 world = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	v_base = world;
	float dist = length(world - CAMERA_POSITION_WORLD);
	// UV.x is this vertex's own spacing in the ring grid (see water.gd). A wave
	// shorter than that has nothing to sit on, so it is faded out rather than
	// turned into a wire cross-hatch.
	float pix = max(max(dist * 0.0022, 0.002), UV.x * 1.6);
	// Flat at the edges: the plane cuts the sloping bar there, and a swell only
	// makes that intersection stagger across the mesh cells.
	v_along = downriver(world.xz, flow_tex, map_size);
	float rv = texture(river_tex, world.xz / map_size).r;
	float off_bank = smoothstep(river_half, river_half - 22.0, rv);
	vec2 offset;
	float h;
	vec2 slope;
	float fold;
	// The same downriver as the fragment uses, or the lit swell and the
	// displaced one run at an angle to each other.
	swell(world.xz, normalize(v_along + vec2(0.0, 0.0001)), TIME, pix, 0.35 + 0.9 * blow(), offset, h, slope, fold);
	VERTEX.xz += offset * off_bank;
	VERTEX.y += h * off_bank;
}


void fragment() {
	vec3 world = (INV_VIEW_MATRIX * vec4(VERTEX, 1.0)).xyz;
	vec2 w = v_base.xz;              // the waves are evaluated where they started
	float dist = length(VERTEX);

	vec2 along = normalize(v_along + vec2(0.0, 0.0001));
	vec2 across = vec2(-along.y, along.x);
	float s = dot(w, along);
	float t = dot(w, across);

	// How deep the water is: the height of the surface above the bed, taken by
	// reconstructing the bed's world position out of the depth buffer. Not the
	// distance along the view ray to the bed, which is the same number only when
	// you are looking straight down, and which on a bank runs to hundreds of
	// metres over a river three deep.
	float depth = water_depth_at(SCREEN_UV, world.y, depth_tex, INV_PROJECTION_MATRIX, INV_VIEW_MATRIX);
	// Broken up a little: the bed is a 4 m mesh and its triangle edges would
	// otherwise show as straight contours running through the shoals.
	float d_soft = depth + (fbm(w * 0.07) - 0.5) * 0.9 + (noise(w * 0.8) - 0.5) * 0.22;

	// Silt: the deeper the column, the less of the bar's pale sand comes back up
	// through it. The channel here is about three metres at its deepest, so the
	// whole ramp lives in the first few.
	float pale = exp(-max(d_soft, 0.0) * 1.0);
	vec3 c = mix(deep_color, mid_color, clamp(pale * 1.9, 0.0, 1.0));
	c = mix(c, shallow_color, clamp((pale - 0.52) * 2.1, 0.0, 1.0));

	// What the current carries, in colour only. Any of these put into the normal
	// instead becomes a specular highlight running the length of the river.
	float band = noise(vec2(t * 0.02, (s - TIME * flow_speed * 0.6) * 0.012));
	float streak = noise(vec2(t * 0.14, (s - TIME * flow_speed) * 0.03));
	float boil = fbm(w * 0.05 - along * TIME * flow_speed * 0.04);
	c *= 1.0 + (band - 0.5) * 0.26 + (streak - 0.5) * 0.18 + (boil - 0.5) * 0.16;

	// The current, drawn off the channel rather than off the compass: ``fc`` is
	// the distance from the channel's middle, so lines of it follow the bends.
	float pix0 = max(length(fwidth(w)), 0.002);
	float fc = texture(flow_tex, w / map_size).r;
	float run = s - TIME * flow_speed;               // downriver, moving with it
	// Seams: where two threads of the current meet, the scum and the drift
	// they carry collect in a line, and the water along it lies glassy. They
	// wander across the channel and break up along it.
	float q = fc + (noise(vec2(fc * 0.03, run * 0.008)) - 0.5) * 18.0;
	float lane = abs(fract(q / 26.0 + 0.3) - 0.5) * 26.0;
	float seam = soft_line(lane, 1.1, pix0)
			* smoothstep(0.35, 0.65, noise(vec2(q * 0.05, run * 0.035)))
			* smoothstep(river_half * 0.95, river_half * 0.55, fc);
	float glass = soft_line(lane, 3.5, pix0) * 0.6;
	// Boils, in the deep middle where the current is quickest.
	float slick;
	float rim;
	boils(w - along * TIME * flow_speed, TIME, pix0, slick, rim);
	float channel = smoothstep(river_half * 0.6, river_half * 0.2, fc) * smoothstep(0.8, 2.0, d_soft);
	slick *= channel;
	rim *= channel;
	// Eddies, in a band off the bank: past the shallows, short of the channel.
	float inshore = river_half - texture(river_tex, w / map_size).r;  // metres out from the waterline
	float eddy_band = smoothstep(1.0, 4.0, inshore) * (1.0 - smoothstep(12.0, 22.0, inshore));
	float eddy_scum;
	float eddy_calm;
	eddies(w, TIME, pix0, eddy_band, eddy_scum, eddy_calm);
	seam = max(seam, eddy_scum);
	glass = max(glass, eddy_calm * 0.5);
	// A boil brings up cooler, siltier water: paler and lighter in the middle.
	c = mix(c, mid_color * 1.15, slick * 0.45);
	c *= 1.0 - rim * 0.3;

	// Cat's paws: patches where a gust ruffles the surface, darker and duller,
	// drifting downwind. They are what makes a wide river read as water.
	float gust = blow();
	float paw = smoothstep(0.54, 0.84, fbm(w * 0.035 + along * TIME * 0.02));
	paw *= clamp(gust * 2.0, 0.2, 1.0);
	c *= 1.0 - paw * 0.14;

	// The surface. One pixel's worth of water decides how much of it can be drawn.
	float pix = max(length(fwidth(w)), 0.002);
	vec2 offset;
	float h;
	vec2 slope;
	float fold;
	swell(w, along, TIME, pix, 0.35 + 0.9 * gust, offset, h, slope, fold);
	float ruffle = (0.5 + 1.3 * gust + paw * 1.2) * (1.0 - (glass + slick) * 0.55);
	slope += chop_slope(w, along, TIME, flow_speed, pix, ruffle);
	vec3 wn = normalize(vec3(-slope.x, 1.0 - fold, -slope.y));
	NORMAL = normalize((VIEW_MATRIX * vec4(wn, 0.0)).xyz);

	// Whitecaps: where the swell heaps up steeply enough to break. In a calm
	// there are none, which is the point of hanging them on the fold and not on
	// the height.
	float cap = smoothstep(0.34, 0.72, fold) * smoothstep(0.12, 0.45, gust);
	cap *= smoothstep(0.35, 0.75, noise(w * 0.5 - along * TIME * 0.8));
	// And the lapping edge, a broken pale line where the water thins over sand.
	// It comes and goes with the lap: a thin scum that runs up the bar, breaks
	// into beads and is gone, not a white kerb painted down the shore. Muddy
	// water makes muddy foam.
	float surge = sin(TIME * 1.3 + t * 0.35 + noise(w * 0.2) * 4.0) * 0.5 + 0.5;
	float lap = smoothstep(0.05 + surge * 0.14, -0.02, d_soft) * smoothstep(-0.06, 0.04, d_soft + surge * 0.1)
			* smoothstep(0.45, 0.85, noise(w * 1.6 + along * TIME * 0.5) * 0.75 + 0.25 * surge);
	lap *= 0.7;
	// Foam where the water breaks against something standing in it -- a moored
	// hull, a snag, a man wading. The depth buffer does not care which.
	// Its break-up is at a third of a metre, which is a good deal finer than a
	// pixel covers past about twenty yards, so it is faded out over that range
	// rather than left to alias into a cross-hatch over the whole shallows.
	// Only against something that stands up out of the bed. A bar shelves
	// gently under the surface and a hull or snag drops away almost sheer, and
	// without telling them apart this drew an unbroken foam line down every
	// shore in the Region.
	float sheer = length(fwidth(depth)) / max(length(fwidth(w)), 0.0001);
	float contact = smoothstep(0.3, 0.0, depth) * smoothstep(0.5, 1.5, sheer)
			* (0.55 + 0.45 * noise(w * 1.4 - along * TIME * 1.6))
			* (1.0 - smoothstep(22.0, 65.0, dist));
	// Foam is not a flat wash: it breaks into streaks that run with the water.
	float grain = 0.5 + 0.5 * noise(vec2(t * 1.1, (s - TIME * flow_speed) * 0.32));
	float foam = clamp((cap + lap) * (0.45 + 0.75 * grain) + contact * 0.9, 0.0, 1.0);
	// Flecks of foam and drift riding the current. On a reach this wide they are
	// most of what tells you the water is moving at all -- but they are specks
	// of dirty foam, not sparks, so they are small, few, and only half bright.
	// Their break-up is at a fifth of a metre, so they are gone by forty yards:
	// past that a pixel covers several of them and they alias into a hatch.
	float drift = noise((w - along * TIME * flow_speed * 1.25) * 5.5);
	float fleck = smoothstep(0.93, 1.0, drift) * (1.0 - smoothstep(12.0, 42.0, dist));
	foam = clamp(foam + fleck * 0.22 + seam * 0.55, 0.0, 1.0);
	c = mix(c, foam_color, smoothstep(0.05, 0.75, foam) * 0.92);

	// Not a mirror: silty water scatters, and a tight lobe on a rippled surface
	// gives hard glints that read as scratches rather than as water. Foam is
	// matte, and a gust dulls the patch it crosses.
	// Geometric specular antialiasing: where the normal itself changes fast from
	// one pixel to the next, widen the lobe by that much. Without it the
	// highlight on a rippled surface seen at a grazing angle crawls with a fine
	// pixel shimmer, which is the one artifact a wave LOD cannot reach -- the
	// waves are already faded out there; what is left is the slope of the water
	// turning through the highlight inside a single pixel.
	float slope_aa = clamp(length(fwidth(wn)) * 2.4, 0.0, 0.55);
	ROUGHNESS = clamp(mix(0.30, 0.52, smoothstep(30.0, 280.0, dist)) + foam * 0.45 + paw * 0.2 + slope_aa + (1.0 - smoothstep(0.0, 0.3, d_soft)) * 0.5
			- (glass + slick * 0.5) * 0.18, 0.05, 1.0);
	// No engine specular: the reflection is done here, sky and scene both, and
	// the sun and moon roads below. Left on, the engine's sky reflection would
	// lie over the trees this finds in the water.
	SPECULAR = 0.0;
	vec3 eye_dir = normalize(world - CAMERA_POSITION_WORLD);
	// The reflecting normal: the swell and chop, but tamed. Full strength they
	// tear the reflection to confetti; this keeps a far bank recognisable,
	// broken into the streaks a moving river makes of it.
	vec3 rn = normalize(mix(vec3(0.0, 1.0, 0.0), wn, 0.35));
	vec3 rdir = reflect(eye_dir, rn);
	// The current shivers the reflection into streaks that run with it. The
	// chop alone does this up close, but it is thinned out with distance, and
	// past it the far bank lay in the water as still as in a millpond.
	vec2 riffle = vec2(noise(vec2(t * 0.35, (s - TIME * flow_speed) * 0.06)),
			noise(vec2(t * 0.35 + 9.1, (s - TIME * flow_speed) * 0.06))) - 0.5;
	rdir.xz += (along * riffle.x * 0.6 + across * riffle.y) * 0.05 * (0.5 + gust);
	rdir = normalize(rdir);
	rdir.y = max(rdir.y, 0.002);
	float cos_v = clamp(dot(-eye_dir, rn), 0.0, 1.0);
	// Water's own Fresnel (F0 = 0.02): next to nothing looking down into it,
	// most of the sky skimming across the far reach.
	float fres = 0.02 + 0.98 * pow(1.0 - cos_v, 5.0);
	// Not where the water is a film over the bar: the grazing sheen there drew
	// one unbroken pale line down every shore.
	float film = smoothstep(0.0, 0.3, d_soft);
	// The sky, though, is looked up off the full wave normal. Each ripple tips
	// toward higher, bluer sky or lower, paler sky, and that flicker of light
	// and dark is the whole texture of open water at middle distance; off the
	// tamed normal the reach between the bank and the far trees lay like oil.
	vec3 sky_dir = reflect(eye_dir, normalize(mix(vec3(0.0, 1.0, 0.0), wn, 1.0)));
	float sky_up = clamp(sky_dir.y, 0.0, 1.0);
	vec3 sky_seen = mix(sky_horizon.rgb * 1.05, sky_zenith.rgb * 0.85, pow(sky_up, 0.45));
	float found;
	vec3 scene_seen = march_reflection(world, rdir, VIEW_MATRIX, PROJECTION_MATRIX, INV_PROJECTION_MATRIX,
			depth_tex, screen_tex, 1.0 + ROUGHNESS * 3.0, found);
	vec3 seen = mix(sky_seen, scene_seen, found);
	// Silt water is not a mirror even where the light skims it: a little of the
	// river's own colour stays in the reflection, and a ruffled patch or foam
	// takes most of it away.
	float reflectance = 0.8 * fres * (1.0 - foam) * film * (1.0 - paw * 0.4) * mix(1.0, 0.55, smoothstep(0.35, 0.8, ROUGHNESS));
	EMISSION = seen * reflectance * mix(vec3(1.0), deep_color * 2.4, 0.3);
	c *= 1.0 - reflectance;
	// Light coming up through the back of a crest, which is most of what gives a
	// swell its shape from a low angle.
	float crest = clamp(h / max(SWELL_AMP, 0.001), 0.0, 1.0);
	BACKLIGHT = mix(mid_color, shallow_color, 0.65) * 1.5 * crest * (1.0 - foam);
	// The sun's road. Taken off the same wave normal as everything else, so it
	// breaks up with the ripple and fades out with it. A sparkle laid on as its
	// own noise would alias into a glitter of fireflies at any distance, which
	// is the mistake this shader has already made twice.
	vec3 sun = normalize(sun_dir);
	vec3 eye = normalize(CAMERA_POSITION_WORLD - world);
	float mirror = pow(clamp(dot(wn, normalize(sun + eye)), 0.0, 1.0), 90.0);
	EMISSION += vec3(1.0, 0.94, 0.82) * mirror * 1.7 * (1.0 - foam) * smoothstep(0.0, 0.18, sun.y);

	// By moonlight, as on the land: the caramel goes grey and dims, or the
	// river glows warm brown through a blue-grey night.
	float moonlit = smoothstep(0.55, 1.0, night_amount);
	float lum = dot(c, vec3(0.3, 0.59, 0.11));
	c = mix(c, vec3(lum) * vec3(0.82, 0.9, 1.08), moonlit * 0.8) * mix(1.0, 0.7, moonlit);
	// The moon's road itself is the night light's own highlight (sky.gd scales
	// it by the phase). This adds only the glints: the crests that catch the
	// moon dead on, breaking the road into a column of sparks.
	vec3 moon = normalize(moon_dir);
	float mglint = pow(clamp(dot(wn, normalize(moon + eye)), 0.0, 1.0), 220.0);
	// And the road itself, now the engine's specular is off: a broader lobe
	// off the same normal, brightest at a skim.
	float mroad = pow(clamp(dot(wn, normalize(moon + eye)), 0.0, 1.0), 60.0) * (0.3 + fres);
	EMISSION += vec3(0.80, 0.86, 0.96) * (mglint * 0.6 + mroad * 0.32) * moon_light
			* smoothstep(0.0, 0.1, moon.y) * (1.0 - foam) * film;
	ALBEDO = c * mix(1.0, cloud_light(world), 0.7);
	// The Missouri is opaque: Clark could not see a foot into it, and letting the
	// bed show through only puts the riverbed mesh's own triangle edges on the
	// surface of the water. Only the last inches are thin.
	ALPHA = mix(0.45, 1.0, smoothstep(0.0, 0.22, depth));
}
