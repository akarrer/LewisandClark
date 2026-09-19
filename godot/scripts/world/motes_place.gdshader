shader_type particles;
render_mode disable_velocity, disable_force;
// Places motes on a world-anchored grid in a cube of air around the camera, so
// they drift past rather than swimming with the view.

uniform float span = 34.0;
uniform int count = 700;

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
	vec3 cell = vec3(hash(vec2(i, 1.7)), hash(vec2(i, 5.3)), hash(vec2(i, 9.1)));
	// A slow updraught, and sideways drift with the wind.
	float t = TIME * 0.05;
	// Flattened: motes and fireflies stay within a few metres of eye level.
	vec3 extent = vec3(span, span * 0.22, span);
	vec3 p = (cell + vec3(t * 0.6, t * 0.35, t * 0.2)) * extent * 2.0;
	vec3 base = centre - extent;
	p = base + mod(p - base, extent * 2.0);
	// Bob, so they swirl rather than slide.
	float w = hash(vec2(i, 3.3)) * 6.2831;
	p += vec3(sin(TIME * 0.5 + w), sin(TIME * 0.7 + w * 1.3) * 0.6, cos(TIME * 0.45 + w)) * 0.5;
	float s = mix(0.6, 1.6, hash(vec2(i, 11.7)));
	TRANSFORM = mat4(vec4(s, 0.0, 0.0, 0.0), vec4(0.0, s, 0.0, 0.0), vec4(0.0, 0.0, s, 0.0), vec4(p, 1.0));
	CUSTOM = vec4(hash(vec2(i, 13.1)), hash(vec2(i, 17.9)), 0.0, 0.0);
	VELOCITY = vec3(0.0);
}
