shader_type spatial;
render_mode cull_disabled, depth_draw_opaque;
// A butterfly: two pairs of wings drawn into one camera-facing quad, opening and
// closing on its own beat. Four kinds, which is roughly what is on the wing over
// this prairie in August -- monarch, sulphur, cabbage white and a small blue.

varying vec3 v_colour;
varying vec3 v_edge;
varying float v_open;
varying float v_pattern;   // 1 on the strongly marked kinds, 0 on the plain ones

float bf_hash(float n) {
	return fract(sin(n * 78.233) * 43758.5453);
}

void vertex() {
	float r = INSTANCE_CUSTOM.x;
	float q = INSTANCE_CUSTOM.y;
	// Species, and with it the colour and the size.
	float kind = floor(r * 4.0);
	vec3 wing = vec3(0.86, 0.45, 0.10);     // monarch
	vec3 edge = vec3(0.10, 0.08, 0.07);
	float size = 0.17;
	if (kind == 1.0) {
		wing = vec3(0.92, 0.82, 0.22);      // clouded sulphur
		edge = vec3(0.50, 0.36, 0.10);
		size = 0.155;
	} else if (kind == 2.0) {
		wing = vec3(0.93, 0.92, 0.88);      // cabbage white
		edge = vec3(0.34, 0.33, 0.30);
		size = 0.15;
	} else if (kind == 3.0) {
		wing = vec3(0.52, 0.60, 0.86);      // a small blue
		edge = vec3(0.24, 0.26, 0.38);
		size = 0.115;
	}
	v_colour = wing;
	v_edge = edge;
	v_pattern = kind == 0.0 ? 1.0 : (kind == 3.0 ? 0.35 : 0.5);
	// The beat: wings up to nearly shut, then open flat. Small ones beat faster.
	float beat = mix(5.5, 11.0, bf_hash(q * 7.0 + 5.0)) * mix(1.0, 1.45, step(size, 0.16));
	float open = 0.32 + 0.68 * abs(sin(TIME * beat + q * 6.2831));
	v_open = open;
	MODELVIEW_MATRIX = VIEW_MATRIX * mat4(INV_VIEW_MATRIX[0], INV_VIEW_MATRIX[1], INV_VIEW_MATRIX[2], MODEL_MATRIX[3]);
	// Closing the wings narrows the silhouette: that flicker is the whole read.
	VERTEX.x *= size * INSTANCE_CUSTOM.z * open;
	VERTEX.y *= size * INSTANCE_CUSTOM.z;
}

void fragment() {
	// UV.y runs DOWN the quad, so flip it: the forewing and the antennae belong
	// at the top of the butterfly, not the bottom.
	vec2 p = vec2(UV.x - 0.5, 0.5 - UV.y) * 2.0;
	vec2 q = vec2(abs(p.x), p.y);          // one wing, mirrored about the body
	float th = atan(q.y, q.x + 0.0001);    // angle out from the wing root
	float rad = length(q);
	// The outline as a reach that varies with the angle: the forewing swept up
	// and out to a point, the hindwing smaller and rounder below it, and a notch
	// where the two meet. Two ellipses instead gives four separate eggs.
	float fore = 1.02 * exp(-pow((th - 0.50) / 0.62, 2.0));
	float hind = 0.78 * exp(-pow((th + 0.52) / 0.55, 2.0));
	float reach = max(fore, hind) + 0.10;
	float wing = rad / reach;
	float body = pow(abs(q.x / 0.048), 2.0) + pow(abs((p.y + 0.04) / 0.58), 2.6);
	// Antennae, sweeping up and out from the head with a club on the end.
	float stem = abs(q.x - (0.04 + (p.y - 0.46) * 0.75)) * 42.0 + max(0.46 - p.y, 0.0) * 40.0
			+ max(p.y - 0.96, 0.0) * 40.0;

	if (wing > 1.0 && body > 1.0 && stem > 1.0) {
		discard;
	}
	vec3 c = v_colour;
	// Veins running out from the root, and a dark border with pale spots in it:
	// between them that is most of what tells one of these from a moth.
	float vein = smoothstep(0.55, 1.0, abs(sin(th * 7.0 + 0.6)));
	c = mix(c, v_edge, vein * 0.28 * v_pattern);
	float rim = smoothstep(0.62, 0.99, wing);
	c = mix(c, v_edge, rim);
	float spot = smoothstep(0.7, 1.0, abs(sin(th * 11.0))) * smoothstep(0.8, 0.93, wing) * (1.0 - smoothstep(0.93, 1.0, wing));
	c = mix(c, vec3(0.95, 0.94, 0.9), spot * 0.85 * v_pattern);
	if (body < 1.0 || stem < 1.0) {
		c = v_edge * 0.8;
	}
	// The underside is paler; which face you see depends on where it is in the beat.
	c *= mix(1.3, 1.0, v_open);
	ALBEDO = c;
	ROUGHNESS = 0.85;
}
