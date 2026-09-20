shader_type particles;
render_mode disable_velocity, disable_force;
// Places butterflies on a world-anchored grid in a cube of air around the camera,
// each on its own wandering course, so they drift past rather than swimming with
// the view. Daylight only: after dark the fireflies have the air (motes.gd).

uniform float span = 24.0;
uniform sampler2D height_tex : filter_linear, repeat_disable;
uniform sampler2D river_tex : filter_linear, repeat_disable;
uniform float map_size = 1024.0;
uniform float river_clear = 46.0;
global uniform float night_amount;

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
	// A slow general drift downwind, so the population turns over as you walk.
	float t = TIME * 0.02;
	vec2 extent = vec2(span);
	vec2 xz = (cell + vec2(t * 0.8, t * 0.3)) * extent * 2.0;
	vec2 base = centre.xz - extent;
	xz = base + mod(xz - base, extent * 2.0);

	// The flight: a wide slow loop with a quicker jink across it, which is most
	// of what makes a butterfly read as a butterfly and not a bee or a leaf.
	float w = hash(vec2(i, 3.3)) * 6.2831;
	float rate = mix(0.35, 0.8, hash(vec2(i, 5.9)));
	vec3 p;
	p.x = xz.x + sin(TIME * rate + w) * 2.6 + sin(TIME * rate * 3.1 + w * 2.0) * 0.5;
	p.z = xz.y + cos(TIME * rate * 0.85 + w) * 2.6 + cos(TIME * rate * 2.7 + w * 1.5) * 0.5;

	float ground = texture(height_tex, p.xz / map_size).r;
	float river = texture(river_tex, p.xz / map_size).r;
	// Low over the flowers, rising and dropping the whole time.
	float lift = pow(hash(vec2(i, 23.7)), 1.5);
	p.y = ground + mix(0.35, 2.1, lift) + sin(TIME * (rate * 2.3) + w * 1.7) * 0.42;

	float on_grass = step(river_clear, river);
	float by_day = 1.0 - smoothstep(0.1, 0.45, night_amount);
	float s = mix(0.75, 1.3, hash(vec2(i, 11.7))) * on_grass * by_day;
	TRANSFORM = mat4(vec4(s, 0.0, 0.0, 0.0), vec4(0.0, s, 0.0, 0.0), vec4(0.0, 0.0, s, 0.0), vec4(p, 1.0));
	// x: which butterfly it is (species, wingbeat), y: phase, z: scale (0 = not drawn).
	CUSTOM = vec4(hash(vec2(i, 13.1)), hash(vec2(i, 17.9)), s, 0.0);
	VELOCITY = vec3(0.0);
}
