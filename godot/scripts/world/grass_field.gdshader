shader_type particles;
render_mode disable_velocity, disable_force;
// Lays grass clumps on a world-anchored grid around the node (which follows the
// camera), reading ground height and the river from the baked terrain textures.
// Clumps are hidden (scale 0) in the water, on steep ground and past the fade radius.

uniform sampler2D height_tex : filter_linear, repeat_disable;
uniform sampler2D river_tex : filter_linear, repeat_disable;
uniform float map_size = 1024.0;
uniform float cell = 4.0;
uniform float spacing = 0.5;
uniform float clump_scale = 1.0;
uniform int rows = 200;
uniform float river_clear = 48.0;
uniform float max_dist = 46.0;
uniform float min_dist = 0.0;   // the far field leaves the middle to the near field
uniform vec2 camp = vec2(-1000.0);  // trampled ground around the camp
uniform float camp_radius = 9.0;
// A camp of forty-five men beats the grass down well beyond the bare ring around
// the fire: the tents stand outside that ring, and blades were growing up
// through the canvas and out the ridge.
uniform float camp_clear = 13.5;
uniform vec2 town = vec2(-1000.0);   // a dog town, where the grass is kept cropped
uniform float town_radius = 24.0;
uniform vec2 trace_a = vec2(-1000.0);
uniform vec2 trace_b = vec2(-1000.0);
uniform vec2 trace_c = vec2(-1000.0);
uniform float trace_width = 1.05;
uniform bool fade_out = true;

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

// Same field as grass_patch() in ground.gdshader, so the ground matches the blades.
const mat2 TURN = mat2(vec2(0.80, 0.60), vec2(-0.60, 0.80));

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


void start() {
	ACTIVE = true;
}

void process() {
	vec3 center = EMISSION_TRANSFORM[3].xyz;
	int idx = int(INDEX);
	vec2 grid = vec2(float(idx % rows), float(idx / rows)) - float(rows / 2);
	vec2 c = floor(center.xz / spacing) + grid;
	vec2 jitter = vec2(hash(c), hash(c + 17.3)) - 0.5;
	vec2 p = (c + 0.5 + jitter * 1.7) * spacing;  // overlap neighbours so no rows show
	vec2 uv = p / map_size;
	float h = texture(height_tex, uv).r;
	float river = texture(river_tex, uv).r;
	float e = cell / map_size;
	float hx = texture(height_tex, uv + vec2(e, 0.0)).r - texture(height_tex, uv - vec2(e, 0.0)).r;
	float hz = texture(height_tex, uv + vec2(0.0, e)).r - texture(height_tex, uv - vec2(0.0, e)).r;
	float slope = length(vec2(hx, hz)) / (2.0 * cell);
	float d = length(p - center.xz);
	float inside = step(0.0, uv.x) * step(uv.x, 1.0) * step(0.0, uv.y) * step(uv.y, 1.0);
	// Patchy prairie: some ground thick with grass, some thin.
	float patch = grass_patch(p);
	float keep = inside * smoothstep(river_clear - 2.0, river_clear + 6.0, river)
			* (1.0 - smoothstep(1.0, 1.35, slope))  // loess bluffs stay grassed to ~50 degrees
			* (fade_out ? 1.0 - smoothstep(max_dist * 0.7, max_dist, d) : step(d, max_dist))
			* step(min_dist, d)
			* smoothstep(camp_clear * 0.42, camp_clear, distance(p, camp))
			* step(0.08, patch * 0.5 + hash(c + 3.3) * 0.5);
	// Thin patches are short, sparse grass rather than bare ground.
	float s = keep * mix(0.6, 1.2, hash(c + 5.1)) * mix(0.8, 1.2, patch) * clump_scale;
	// The path: bare down the middle, then grass beaten short either side of it,
	// and shorter as it nears the camp, rather than a hard edge anywhere.
	float half_w;
	float to_path = trace_field(p, trace_a, trace_b, trace_c, trace_width, half_w);
	s *= smoothstep(half_w * 0.45, half_w * 1.15, to_path);
	s *= mix(0.45, 1.0, smoothstep(half_w, half_w * 2.4, to_path));
	s *= mix(0.55, 1.0, smoothstep(camp_clear, camp_clear * 1.7, distance(p, camp)));
	// A dog town is mown to the ground: they keep it short to see what is coming.
	s *= mix(0.3, 1.0, smoothstep(town_radius * 0.45, town_radius, distance(p, town)));
	float ang = hash(c + 9.7) * 6.2831;
	float ca = cos(ang);
	float sa = sin(ang);
	float tall = mix(0.75, 1.35, hash(c + 2.2));
	TRANSFORM = mat4(
		vec4(ca * s, 0.0, -sa * s, 0.0),
		vec4(0.0, s * tall, 0.0, 0.0),
		vec4(sa * s, 0.0, ca * s, 0.0),
		vec4(p.x, h - 0.04, p.y, 1.0));
	CUSTOM = vec4(hash(c + 11.1), h, patch, 0.0);
	VELOCITY = vec3(0.0);
}
