shader_type spatial;
render_mode cull_disabled, depth_draw_never, blend_mix, unshaded;
// Mist lying on the river at first light. Each puff is a soft camera-facing
// billboard, lit by the sky rather than by the sun, because that is what mist
// looks like from inside it: no shading of its own, only the light it scatters.
//
// Unshaded on purpose. A lit billboard picks up one normal for the whole puff
// and flickers as it turns; the colour here is the horizon's, warmed a little
// where the sun is coming up behind it.

global uniform float river_mist;
global uniform vec4 sky_horizon;
global uniform vec3 sun_dir;
uniform vec3 warm : source_color = vec3(1.0, 0.92, 0.82);
uniform float near_fade = 7.0;     // metres: thin it out before it is in your face

varying float v_alpha;
varying vec3 v_colour;

float mist_hash(float n) {
	return fract(sin(n * 78.233) * 43758.5453);
}

void vertex() {
	float r = INSTANCE_CUSTOM.x;
	float q = INSTANCE_CUSTOM.y;
	vec3 centre = MODEL_MATRIX[3].xyz;
	float dist = length(centre - CAMERA_POSITION_WORLD);
	// A bank of mist is wide and shallow, and no two are the same size.
	float wide = mix(7.0, 16.0, r) * INSTANCE_CUSTOM.z;
	float tall = wide * mix(0.22, 0.42, q);
	// Thinner close to, so walking into one does not white the screen out, and
	// thinner again far off, where a hard edge to the bank would show.
	float near = smoothstep(0.0, near_fade, dist);
	float far = 1.0 - smoothstep(180.0, 340.0, dist);
	// Slow breathing, out of step from one puff to the next.
	float breathe = 0.8 + 0.2 * sin(TIME * 0.11 + q * 6.2831);
	v_alpha = river_mist * near * far * breathe * mix(0.1, 0.2, r);
	// The sun coming up through it warms the side it is on.
	float toward_sun = clamp(dot(normalize(vec3(sun_dir.x, 0.0, sun_dir.z)),
			normalize(centre - CAMERA_POSITION_WORLD + vec3(0.0001))), 0.0, 1.0);
	v_colour = mix(sky_horizon.rgb * 1.25, warm, toward_sun * 0.5);
	MODELVIEW_MATRIX = VIEW_MATRIX * mat4(INV_VIEW_MATRIX[0], INV_VIEW_MATRIX[1], INV_VIEW_MATRIX[2], MODEL_MATRIX[3]);
	VERTEX.x *= wide;
	VERTEX.y *= tall;
	VERTEX += vec3(sin(q * 31.0) * wide * 0.2, 0.0, 0.0);
}

void fragment() {
	// A soft lozenge, softer at the top than the bottom: mist has an edge where
	// it meets the water and none at all where it thins into the air.
	vec2 d = (UV - vec2(0.5)) * 2.0;
	float body = 1.0 - clamp(dot(d, d), 0.0, 1.0);
	float shape = pow(body, 1.4);
	shape *= mix(1.0, 0.45, smoothstep(-0.2, 1.0, d.y));
	ALBEDO = v_colour;
	ALPHA = clamp(shape * v_alpha, 0.0, 1.0);
}
