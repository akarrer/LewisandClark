shader_type spatial;
render_mode cull_disabled;
// Prairie grass blades: tawny-to-green by patch and bottomland, dark at the root,
// sun-bleached tips, bending in rolling gusts that travel across the prairie.

uniform vec3 gold : source_color = vec3(0.72, 0.62, 0.30);
uniform vec3 green : source_color = vec3(0.40, 0.52, 0.22);
uniform vec3 bottom_green : source_color = vec3(0.30, 0.46, 0.20);
uniform vec3 root : source_color = vec3(0.30, 0.30, 0.16);
uniform float floodplain_y = 1.2;
uniform float wind = 0.22;

varying float v_t;
varying vec3 v_col;
#include "res://scripts/world/prairie.gdshaderinc"
#include "res://scripts/world/cloud_shadow.gdshaderinc"

void vertex() {
	float t = UV.y;  // 0 root .. 1 tip
	vec3 origin = MODEL_MATRIX[3].xyz;
	vec3 world = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	// Gust bands rolling across the land.
	float band = sin(dot(world.xz, vec2(0.08, 0.05)) - TIME * 1.6) * 0.5 + 0.5;
	float sway = (sin(TIME * 2.4 + origin.x * 0.9 + origin.z * 0.7) * 0.35 + band * 0.9) * wind * t * t;
	vec3 disp = vec3(0.8, -0.15 * band * t, 0.5) * sway;
	mat3 m = mat3(MODEL_MATRIX);
	float s2 = max(dot(m[0], m[0]), 0.0001);
	VERTEX += transpose(m) * disp / s2;

	float r = INSTANCE_CUSTOM.x;
	float patch = INSTANCE_CUSTOM.z;
	float bottom = 1.0 - smoothstep(floodplain_y + 1.0, floodplain_y + 3.5, INSTANCE_CUSTOM.y);
	vec3 base = mix(gold, green, clamp(patch * 0.8 + (r - 0.5) * 0.6, 0.0, 1.0));
	base = mix(base, bottom_green, bottom * 0.6);
	// Species patchwork, sampled at the clump's root so a clump is one kind of grass.
	base = prairie_species(origin.xz, base, 1.0 - bottom);
	v_col = base;
	v_t = t;
}

void fragment() {
	vec3 c = mix(mix(root, v_col, 0.35), v_col, smoothstep(0.0, 0.5, v_t));
	c = mix(c, v_col * 1.25 + vec3(0.05, 0.04, 0.0), smoothstep(0.75, 1.0, v_t));
	ALBEDO = c * cloud_light((INV_VIEW_MATRIX * vec4(VERTEX, 1.0)).xyz);
	ROUGHNESS = 0.9;
	SPECULAR = 0.15;
	BACKLIGHT = c * 0.4;
	// Blades face up for soft, even lighting instead of flickering flat cards.
	NORMAL = mix(NORMAL, (VIEW_MATRIX * vec4(0.0, 1.0, 0.0, 0.0)).xyz, 0.6);
}
