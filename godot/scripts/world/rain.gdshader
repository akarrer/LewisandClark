shader_type spatial;
render_mode unshaded, blend_mix, cull_disabled, depth_draw_never, shadows_disabled;
// A raindrop as a streak along its own fall. The particle's Y axis is turned to
// its velocity (align_y in sky.gd), and the quad is spun about that axis to face
// the eye -- so a drop driven aslant by the wind streaks aslant, rather than
// every streak standing bolt upright whatever the wind does.
//
// A fixed-width quad within a metre of the lens is a white post standing in
// the grass, and one at fifty metres is less than a pixel; so drops fade in
// past a couple of metres and out again with distance, and are drawn a little
// wider the further off they are, so the far curtain still reads.

uniform vec4 tint : source_color = vec4(0.75, 0.8, 0.9, 0.2);

void vertex() {
	vec3 axis = normalize(MODEL_MATRIX[1].xyz);
	vec3 centre = MODEL_MATRIX[3].xyz;
	vec3 to_eye = normalize(CAMERA_POSITION_WORLD - centre);
	vec3 side = normalize(cross(axis, to_eye) + vec3(1e-5));
	float dist = length(CAMERA_POSITION_WORLD - centre);
	float width = 0.006 + dist * 0.0007;
	float len = 0.55;
	vec3 world = centre + side * VERTEX.x * width * 2.0 + axis * VERTEX.y * len;
	POSITION = PROJECTION_MATRIX * VIEW_MATRIX * vec4(world, 1.0);
	COLOR.a = smoothstep(1.5, 4.0, dist) * (1.0 - smoothstep(22.0, 34.0, dist));
}

void fragment() {
	// Brightest down the middle, fading to the ends and the edges.
	float across = 1.0 - abs(UV.x - 0.5) * 2.0;
	float along = sin(UV.y * 3.14159);
	ALBEDO = tint.rgb;
	ALPHA = tint.a * COLOR.a * across * along;
}
