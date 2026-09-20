shader_type particles;
render_mode disable_velocity, disable_force;
// Places banks of mist on a world-anchored grid in a slab of air over the river,
// so they drift past rather than swimming with the view. Over the water only,
// and only while there is mist to place (see sky.gd).

uniform float span = 70.0;
uniform sampler2D height_tex : filter_linear, repeat_disable;
uniform sampler2D river_tex : filter_linear, repeat_disable;
uniform float map_size = 1024.0;
uniform float river_edge = 62.0;   // out to here from the channel centre
uniform float water_y = -0.35;
global uniform float river_mist;

float hash(vec2 p) {
	vec3 p3 = fract(vec3(p.xyx) * 0.1031);
	p3 += dot(p3, p3.yzx + 33.33);
	return fract((p3.x + p3.y) * p3.z);
}

void start() {
	ACTIVE = true;
}

void process() {
	vec3 centre = EMISSION_TRANSFORM[3].xyz;
	float i = float(INDEX);
	vec2 cell = vec2(hash(vec2(i, 1.7)), hash(vec2(i, 9.1)));
	// Downriver, at the pace mist actually moves: slower than the water.
	float t = TIME * 0.012;
	vec2 extent = vec2(span);
	vec2 xz = (cell + vec2(t * 0.35, t)) * extent * 2.0;
	vec2 base = centre.xz - extent;
	xz = base + mod(xz - base, extent * 2.0);

	vec3 p;
	p.x = xz.x + sin(TIME * 0.06 + i) * 3.0;
	p.z = xz.y + cos(TIME * 0.05 + i * 1.7) * 3.0;
	// Lying on the water: most of it in the first metre, a little standing
	// higher where it is lifting off.
	float lift = pow(hash(vec2(i, 23.7)), 2.2);
	p.y = water_y + mix(0.15, 3.4, lift) + sin(TIME * 0.09 + i * 2.3) * 0.25;

	float river = texture(river_tex, p.xz / map_size).r;
	float over_water = 1.0 - smoothstep(river_edge - 14.0, river_edge, river);
	// Not where the bar stands out of the water: mist sits on the river itself.
	float ground = texture(height_tex, p.xz / map_size).r;
	over_water *= 1.0 - smoothstep(water_y - 0.1, water_y + 0.9, ground);

	float s = mix(0.7, 1.5, hash(vec2(i, 11.7))) * over_water * smoothstep(0.02, 0.35, river_mist);
	TRANSFORM = mat4(vec4(s, 0.0, 0.0, 0.0), vec4(0.0, s, 0.0, 0.0), vec4(0.0, 0.0, s, 0.0), vec4(p, 1.0));
	// x: which bank of mist this is, y: its phase, z: scale (0 = not drawn).
	CUSTOM = vec4(hash(vec2(i, 13.1)), hash(vec2(i, 17.9)), s, 0.0);
	VELOCITY = vec3(0.0);
}
