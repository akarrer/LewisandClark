shader_type spatial;
render_mode cull_disabled;
// The Missouri, "the Big Muddy": silt-laden and opaque, paling over the bars,
// quick in the channel, with a broken sheen of sky at grazing angles.
//
// The surface is a train of travelling waves whose slopes are known
// analytically, each faded out once a pixel covers more than its own
// wavelength. That level of detail is the whole trick. A normal differenced
// from noise per pixel aliases, and because both the sampling grid and the wave
// pattern are regular the aliasing comes out as long straight interference
// bands ruled across the reach -- which is what this river looked like before,
// and which no amount of softening the colour will hide.

uniform vec3 deep_color : source_color = vec3(0.32, 0.27, 0.19);
uniform vec3 shallow_color : source_color = vec3(0.55, 0.48, 0.35);
uniform vec3 foam_color : source_color = vec3(0.80, 0.76, 0.67);
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
const float GOLDEN = 2.399963;   // radians: no two waves in the train line up

float hash(vec2 p) { return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453); }

float noise(vec2 p) {
	vec2 i = floor(p); vec2 f = fract(p);
	vec2 u = f * f * (3.0 - 2.0 * f);
	return mix(mix(hash(i), hash(i + vec2(1, 0)), u.x), mix(hash(i + vec2(0, 1)), hash(i + vec2(1, 1)), u.x), u.y);
}

float fbm(vec2 p) {
	float v = 0.0;
	float a = 0.52;
	for (int i = 0; i < 4; i++) {
		v += a * noise(p);
		p = TURN * p * 2.07;
		a *= 0.5;
	}
	return v;
}


// The wave train. Returns the surface normal and, through ``h``, the height.
// ``pix`` is how much water one pixel covers, in metres: a wave shorter than
// that cannot be resolved, so it is faded out rather than aliased. ``gust``
// scales the whole train with the wind and with the cat's paws crossing it.
vec3 wave_surface(vec2 w, vec2 along, float tt, float flow, float pix, float gust, out float h) {
	vec2 slope = vec2(0.0);
	h = 0.0;
	// A slow wander in the phase, so the crests are not ruled parallel lines.
	// Its own slope is negligible at this scale, which is why it is left out of
	// the analytic derivative below.
	float wander = noise(w * 0.028) * 6.0;
	for (int i = 0; i < 6; i++) {
		float fi = float(i);
		float lambda = 11.0 * pow(0.5, fi);
		float amp = 0.085 * pow(0.56, fi) * gust;
		amp *= 1.0 - smoothstep(lambda * 0.7, lambda * 2.6, pix);
		if (amp < 0.00002) {
			continue;
		}
		float a = fi * GOLDEN;
		float ca = cos(a);
		float sa = sin(a);
		vec2 dir = vec2(along.x * ca - along.y * sa, along.x * sa + along.y * ca);
		float k = TAU_ / lambda;
		float ph = k * dot(w, dir) - tt * (1.2 + flow * 0.6) * sqrt(k) + wander;
		h += amp * sin(ph);
		slope += amp * k * cos(ph) * dir;
	}
	return vec3(-slope.x, 1.0, -slope.y);
}


void vertex() {
	vec3 world = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	float dist = length(world - CAMERA_POSITION_WORLD);
	// The mesh has about 3 m between vertices, so it can carry the long swell
	// and nothing else; the rest of the train lives in the normal.
	float pix = max(max(dist * 0.0022, 0.002), 3.2);
	// Flat at the edges: the plane cuts the sloping bar there, and a swell only
	// makes that intersection stagger across the mesh cells.
	float rv = texture(river_tex, world.xz / map_size).r;
	float off_bank = smoothstep(river_half, river_half - 20.0, rv);
	float h;
	wave_surface(world.xz, vec2(0.0, 1.0), TIME, flow_speed, pix, 1.0, h);
	VERTEX.y += h * off_bank;
}


void fragment() {
	vec3 world = (INV_VIEW_MATRIX * vec4(VERTEX, 1.0)).xyz;
	vec2 w = world.xz;
	float dist = length(VERTEX);

	// Downriver: along the channel (perpendicular to the distance gradient), southward.
	vec2 uv = w / map_size;
	float e = 4.0 / map_size;
	vec2 g = vec2(texture(river_tex, uv + vec2(e, 0.0)).r - texture(river_tex, uv - vec2(e, 0.0)).r,
			texture(river_tex, uv + vec2(0.0, e)).r - texture(river_tex, uv - vec2(0.0, e)).r);
	vec2 along = length(g) > 0.0001 ? normalize(vec2(-g.y, g.x)) : vec2(0.0, 1.0);
	along *= sign(along.y + 0.0001);
	vec2 across = vec2(-along.y, along.x);
	float s = dot(w, along);
	float t = dot(w, across);

	// How deep the water is: the height of the surface above the bed, taken by
	// reconstructing the bed's world position out of the depth buffer. Not the
	// distance along the view ray to the bed, which is the same number only when
	// you are looking straight down, and which on a bank runs to hundreds of
	// metres over a river three deep.
	float d = texture(depth_tex, SCREEN_UV).r;
	vec4 behind = INV_PROJECTION_MATRIX * vec4(SCREEN_UV * 2.0 - 1.0, d, 1.0);
	vec3 bed = (INV_VIEW_MATRIX * vec4(behind.xyz / behind.w, 1.0)).xyz;
	float depth = max(world.y - bed.y, 0.0);
	// Broken up a little: the bed is a 4 m mesh and its triangle edges would
	// otherwise show as straight contours running through the shoals.
	float d_soft = depth + (fbm(w * 0.07) - 0.5) * 0.9 + (fbm(w * 0.8) - 0.5) * 0.22;

	// Silt: the deeper the column, the less of the bar's pale sand comes back up
	// through it. The channel here is about three metres at its deepest.
	float pale = exp(-max(d_soft, 0.0) * 1.15);
	vec3 c = mix(deep_color, shallow_color, clamp(pale, 0.0, 1.0));

	// What the current carries, in colour only. Any of these put into the normal
	// instead becomes a highlight running the whole length of the river.
	float band = noise(vec2(t * 0.02, (s - TIME * flow_speed * 0.6) * 0.012));
	float streak = noise(vec2(t * 0.14, (s - TIME * flow_speed) * 0.03));
	float boil = fbm(w * 0.05 - along * TIME * flow_speed * 0.04);
	c *= 1.0 + (band - 0.5) * 0.26 + (streak - 0.5) * 0.18 + (boil - 0.5) * 0.16;

	// Cat's paws: patches where a gust ruffles the surface, darker and duller,
	// drifting downwind. They are what makes a wide river read as water.
	float gust = clamp(wind_strength, 0.0, 4.0);
	float paw = smoothstep(0.54, 0.84, fbm(w * 0.035 + along * TIME * 0.02));
	paw *= clamp(gust * 0.5, 0.2, 1.0);
	c *= 1.0 - paw * 0.14;

	// Lapping edge: a broken pale line where the water thins over sand.
	float lap = smoothstep(0.24, -0.02, d_soft)
			* smoothstep(0.3, 0.75, noise(w * 1.1 + along * TIME * 0.5) * 0.7
					+ 0.3 * (sin(TIME * 1.9 + t * 0.7) * 0.5 + 0.5));
	c = mix(c, foam_color, lap * 0.8);

	// One pixel's worth of water, which is what decides how much of the wave
	// train can be drawn here.
	float pix = max(length(fwidth(w)), 0.002);
	float ruffle = 0.55 + 0.45 * gust * 0.25 + paw * 1.1;
	float h;
	vec3 wn = normalize(wave_surface(w, along, TIME, flow_speed, pix, ruffle, h));
	NORMAL = normalize((VIEW_MATRIX * vec4(wn, 0.0)).xyz);

	// Not a mirror: silty water scatters, and a tight lobe on a rippled surface
	// gives hard glints that read as scratches rather than as water.
	ROUGHNESS = clamp(mix(0.22, 0.52, smoothstep(30.0, 280.0, dist)) + lap * 0.45 + paw * 0.2, 0.05, 1.0);
	SPECULAR = 0.2;
	float fres = pow(1.0 - clamp(dot(NORMAL, VIEW), 0.0, 1.0), 5.0);
	// The silt does not stop at the far bank: let the reflection carry the
	// river's own colour into it, or the far reach turns into a sheet of sky.
	vec3 sheen = mix(sky_horizon.rgb, sky_horizon.rgb * deep_color * 2.6, 0.5);
	EMISSION = sheen * fres * mix(0.03, 0.30, smoothstep(5.0, 120.0, dist)) * (1.0 - lap);

	ALBEDO = c * mix(1.0, cloud_light(world), 0.7);
	// The Missouri is opaque: Clark could not see a foot into it, and letting the
	// bed show through only puts the riverbed mesh's own triangle edges on the
	// surface of the water. Only the last inches are thin.
	ALPHA = mix(0.45, 1.0, smoothstep(0.0, 0.22, depth));
}
