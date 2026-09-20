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

uniform vec3 deep_color : source_color = vec3(0.27, 0.22, 0.15);
uniform vec3 mid_color : source_color = vec3(0.42, 0.34, 0.22);
uniform vec3 shallow_color : source_color = vec3(0.60, 0.52, 0.36);
uniform vec3 foam_color : source_color = vec3(0.84, 0.81, 0.74);
uniform float flow_speed = 0.9;       // m/s the silt patterns travel downriver
uniform sampler2D river_tex : filter_linear, repeat_disable;  // distance to the 1804 channel (m)
uniform float map_size = 1024.0;
uniform float river_half = 55.0;      // metres from the channel centre to the bank
uniform sampler2D depth_tex : hint_depth_texture, filter_linear;
global uniform vec4 sky_horizon;
global uniform float wind_strength;
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

float noise(vec2 p) {
	vec2 i = floor(p); vec2 f = fract(p);
	vec2 u = f * f * (3.0 - 2.0 * f);
	return mix(mix(hash(i), hash(i + vec2(1, 0)), u.x), mix(hash(i + vec2(0, 1)), hash(i + vec2(1, 1)), u.x), u.y);
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
		float amp = SWELL_AMP * pow(0.6, fi) * amp_scale;
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
	for (int i = 0; i < 6; i++) {
		float fi = float(i);
		float lambda = 7.0 * pow(0.5, fi);
		float amp = 0.05 * pow(0.58, fi) * gust;
		// The chop fades a good deal earlier than the swell. It is short enough
		// that it reaches the pixel limit while it is still the whole texture of
		// the surface, and the shimmer that follows is worse than losing it.
		amp *= 1.0 - smoothstep(lambda * 0.3, lambda * 1.3, pix);
		if (amp < 0.00002) {
			continue;
		}
		vec2 dir = turn_by(along, (fi + 0.5) * GOLDEN);
		float k = TAU_ / lambda;
		float ph = k * dot(base, dir) - tt * (1.2 + flow * 0.6) * sqrt(k) + wander;
		slope += amp * k * cos(ph) * dir;
	}
	return slope;
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
	v_along = downriver(world.xz, river_tex, map_size);
	float rv = texture(river_tex, world.xz / map_size).r;
	float off_bank = smoothstep(river_half, river_half - 22.0, rv);
	vec2 offset;
	float h;
	vec2 slope;
	float fold;
	swell(world.xz, vec2(0.0, 1.0), TIME, pix, 0.35 + 0.9 * blow(), offset, h, slope, fold);
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
	float ruffle = 0.5 + 1.3 * gust + paw * 1.2;
	slope += chop_slope(w, along, TIME, flow_speed, pix, ruffle);
	vec3 wn = normalize(vec3(-slope.x, 1.0 - fold, -slope.y));
	NORMAL = normalize((VIEW_MATRIX * vec4(wn, 0.0)).xyz);

	// Whitecaps: where the swell heaps up steeply enough to break. In a calm
	// there are none, which is the point of hanging them on the fold and not on
	// the height.
	float cap = smoothstep(0.34, 0.72, fold) * smoothstep(0.12, 0.45, gust);
	cap *= smoothstep(0.35, 0.75, noise(w * 0.5 - along * TIME * 0.8));
	// And the lapping edge, a broken pale line where the water thins over sand.
	float lap = smoothstep(0.24, -0.02, d_soft)
			* smoothstep(0.3, 0.75, noise(w * 1.1 + along * TIME * 0.5) * 0.7
					+ 0.3 * (sin(TIME * 1.9 + t * 0.7) * 0.5 + 0.5));
	// Foam where the water breaks against something standing in it -- a moored
	// hull, a snag, a man wading. The depth buffer does not care which.
	// Its break-up is at a third of a metre, which is a good deal finer than a
	// pixel covers past about twenty yards, so it is faded out over that range
	// rather than left to alias into a cross-hatch over the whole shallows.
	float contact = smoothstep(0.3, 0.0, depth)
			* (0.55 + 0.45 * noise(w * 1.4 - along * TIME * 1.6))
			* (1.0 - smoothstep(22.0, 65.0, dist));
	float foam = clamp(cap + lap + contact * 0.9, 0.0, 1.0);
	// Flecks of foam and drift riding the current. On a reach this wide they are
	// most of what tells you the water is moving at all -- but they are specks
	// of dirty foam, not sparks, so they are small, few, and only half bright.
	// Their break-up is at a fifth of a metre, so they are gone by forty yards:
	// past that a pixel covers several of them and they alias into a hatch.
	float drift = noise((w - along * TIME * flow_speed * 1.25) * 5.5);
	float fleck = smoothstep(0.93, 1.0, drift) * (1.0 - smoothstep(12.0, 42.0, dist));
	foam = clamp(foam + fleck * 0.22, 0.0, 1.0);
	c = mix(c, foam_color, foam * 0.85);

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
	ROUGHNESS = clamp(mix(0.20, 0.52, smoothstep(30.0, 280.0, dist)) + foam * 0.45 + paw * 0.2 + slope_aa, 0.05, 1.0);
	SPECULAR = 0.24;
	float fres = pow(1.0 - clamp(dot(NORMAL, VIEW), 0.0, 1.0), 5.0);
	// The silt does not stop at the far bank: let the reflection carry the
	// river's own colour into it, or the far reach turns into a sheet of sky.
	vec3 sheen = mix(sky_horizon.rgb, sky_horizon.rgb * deep_color * 2.6, 0.5);
	EMISSION = sheen * fres * mix(0.03, 0.30, smoothstep(5.0, 120.0, dist)) * (1.0 - foam);
	// Light coming up through the back of a crest, which is most of what gives a
	// swell its shape from a low angle.
	BACKLIGHT = shallow_color * clamp(h / max(SWELL_AMP, 0.001), 0.0, 1.0) * 0.5 * (1.0 - foam);

	ALBEDO = c * mix(1.0, cloud_light(world), 0.7);
	// The Missouri is opaque: Clark could not see a foot into it, and letting the
	// bed show through only puts the riverbed mesh's own triangle edges on the
	// surface of the water. Only the last inches are thin.
	ALPHA = mix(0.45, 1.0, smoothstep(0.0, 0.22, depth));
}
