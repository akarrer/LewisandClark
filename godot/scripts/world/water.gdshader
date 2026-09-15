shader_type spatial;
// The Missouri: muddy, slow, catching the sky. Stylized, no reflections.

uniform vec4 deep_color : source_color = vec4(0.27, 0.33, 0.30, 1.0);
uniform vec4 shallow_color : source_color = vec4(0.52, 0.48, 0.36, 1.0);
uniform float flow_speed = 0.035;

float hash(vec2 p) { return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453); }
float noise(vec2 p) {
	vec2 i = floor(p); vec2 f = fract(p);
	vec2 u = f * f * (3.0 - 2.0 * f);
	return mix(mix(hash(i), hash(i + vec2(1, 0)), u.x), mix(hash(i + vec2(0, 1)), hash(i + vec2(1, 1)), u.x), u.y);
}

void fragment() {
	vec2 w = (INV_VIEW_MATRIX * vec4(VERTEX, 1.0)).xz;
	float n1 = noise(w * 0.08 + vec2(0.0, TIME * flow_speed * 8.0));
	float n2 = noise(w * 0.31 - vec2(TIME * flow_speed * 3.0, 0.0));
	float ripple = n1 * 0.6 + n2 * 0.4;
	ALBEDO = mix(deep_color.rgb, shallow_color.rgb, ripple * 0.5);
	ROUGHNESS = 0.35 + ripple * 0.2;
	SPECULAR = 0.3;
	float fres = pow(1.0 - clamp(dot(NORMAL, VIEW), 0.0, 1.0), 4.0);
	EMISSION = vec3(0.55, 0.65, 0.75) * fres * 0.25;
	NORMAL_MAP = normalize(vec3(n1 - 0.5, n2 - 0.5, 4.0)) * 0.5 + 0.5;
}
