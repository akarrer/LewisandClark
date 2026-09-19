shader_type spatial;
render_mode unshaded, blend_add, cull_disabled, depth_draw_never;
// Chaff and insects by day, fireflies after dark. Each mote is a camera-facing
// speck; night_amount (from sky.gd) crossfades between the two.

global uniform float night_amount;
uniform vec3 day_colour : source_color = vec3(0.95, 0.90, 0.72);
uniform vec3 firefly : source_color = vec3(0.75, 1.0, 0.35);

varying float v_glow;
varying vec3 v_colour;

void vertex() {
	// Billboard, then size: fireflies are a little larger than chaff.
	float r = INSTANCE_CUSTOM.x;
	float blink = 0.5 + 0.5 * sin(TIME * (1.4 + r * 2.2) + INSTANCE_CUSTOM.y * 40.0);
	blink = smoothstep(0.55, 1.0, blink);
	// Bright enough at night to bloom a little; by day just a catch of light.
	float lit = mix(0.5 + 0.5 * r, blink * 2.6, night_amount);
	v_glow = lit;
	v_colour = mix(day_colour, firefly, night_amount);
	float size = mix(1.0, 2.0, night_amount) * (0.6 + r);
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
