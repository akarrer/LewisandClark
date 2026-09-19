shader_type spatial;
render_mode unshaded, blend_add, cull_disabled, depth_draw_never;
// Fireflies after dark: each is a camera-facing speck with its own flash rhythm.
// Nothing is drawn by day (see motes_place.gdshader).

global uniform float night_amount;
uniform vec3 day_colour : source_color = vec3(0.95, 0.90, 0.72);
uniform vec3 firefly : source_color = vec3(0.75, 1.0, 0.35);

varying float v_glow;
varying vec3 v_colour;

float mote_hash(float n) {
	return fract(sin(n * 78.233) * 43758.5453);
}

void vertex() {
	float r = INSTANCE_CUSTOM.x;
	float q = INSTANCE_CUSTOM.y;
	// Each firefly keeps its own rhythm: its own interval between flashes, its
	// own flash length, its own phase, and it sits out a cycle now and then.
	float period = mix(1.4, 6.5, mote_hash(r * 13.0 + 2.0));
	float on_len = mix(0.05, 0.3, mote_hash(q * 7.0 + 5.0));   // fraction of the period alight
	float phase = mote_hash(r * 31.0 + q * 17.0);
	float cycles = (TIME / period) + phase;
	float within = fract(cycles);
	// Rises fast, fades slower, the way a firefly's lantern does.
	float pulse = smoothstep(0.0, on_len * 0.25, within) * (1.0 - smoothstep(on_len * 0.4, on_len, within));
	// Some cycles it simply does not flash.
	float skipped = step(0.25, mote_hash(floor(cycles) * 3.7 + r * 91.0));
	float blink = pulse * skipped;
	float lit = mix(0.5 + 0.5 * r, blink * 3.2, night_amount);
	v_glow = lit;
	v_colour = mix(day_colour, firefly, night_amount);
	// INSTANCE_CUSTOM.z carries the placement scale (0 = not drawn at all).
	float size = mix(1.0, 2.0, night_amount) * (0.6 + r) * INSTANCE_CUSTOM.z;
	MODELVIEW_MATRIX = VIEW_MATRIX * mat4(INV_VIEW_MATRIX[0], INV_VIEW_MATRIX[1], INV_VIEW_MATRIX[2], MODEL_MATRIX[3]);
	VERTEX.xy *= size;
}


void fragment() {
	// Soft round speck.
	float d = length(UV - vec2(0.5)) * 2.0;
	float a = smoothstep(1.0, 0.1, d);
	ALBEDO = v_colour * v_glow * a;
	ALPHA = a;
}
