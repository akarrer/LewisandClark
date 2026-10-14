shader_type spatial;
render_mode cull_disabled;
// Wind for the Quaternius trees, bushes and plants: the whole plant bends from
// the ground up (bark and leaves together, so leaves stay on their branches),
// leaves flutter, light shines through them, and each plant is tinted a little
// differently so a grove doesn't look copy-pasted.

uniform sampler2D albedo_tex : source_color, filter_linear_mipmap_anisotropic;
uniform vec4 tint : source_color = vec4(1.0);
uniform float alpha_cut = 0.5;
uniform float sway = 0.25;          // metres of bend at the top
uniform float plant_height = 8.0;   // local height of the top
uniform float flutter = 1.0;        // 0 for bark
uniform float translucency = 0.35;  // 0 for bark
uniform float variation = 0.12;
uniform float base_shade = 0.7;
uniform float bark = 0.0;           // 1 on trunks: cottonwood bark is deeply furrowed
// Where a plant stands decides how far it has cured: the MultiMesh carries that
// per instance in COLOR.r, 0 for a green swale and 1 for the burnt-off upland.
uniform vec4 cured : source_color = vec4(1.0);
global uniform float wind_strength;     // darken toward the ground (fake occlusion)

varying float v_height;
varying vec3 v_tint;
varying vec3 v_local;
#include "res://scripts/world/cloud_shadow.gdshaderinc"

float hash(vec2 p) {
	vec3 p3 = fract(vec3(p.xyx) * 0.1031);
	p3 += dot(p3, p3.yzx + 33.33);
	return fract((p3.x + p3.y) * p3.z);
}

void vertex() {
	vec3 origin = MODEL_MATRIX[3].xyz;
	vec3 world = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	float h = clamp(VERTEX.y / plant_height, 0.0, 1.0);
	float gust = sin(TIME * 0.45 + origin.x * 0.011 + origin.z * 0.008) * 0.5 + 0.5;
	float w = clamp(wind_strength, 0.0, 4.0);
	float bend = sin(TIME * (1.3 + w * 0.5) + origin.x * 0.21 + origin.z * 0.17) * (0.35 + 0.9 * gust);
	vec3 disp = vec3(1.0, 0.0, 0.55) * bend * sway * w * h * h;
	float leaf = sin(TIME * 6.5 + world.x * 1.7 + world.y * 2.3 + world.z * 1.3);
	disp += vec3(leaf, leaf * 0.5, -leaf) * 0.035 * flutter * w * h * (0.5 + gust);
	// World-space push back into local space (instances are rotated, stretched and leaning).
	VERTEX += inverse(mat3(MODEL_MATRIX)) * disp;

	float r = hash(origin.xz);
	float g = hash(origin.zx + 7.7);
	v_tint = vec3(1.0 + (r - 0.5) * variation * 2.0, 1.0 + (g - 0.5) * variation * 1.5, 1.0 - (r - 0.5) * variation);
	v_tint *= mix(vec3(1.0), cured.rgb, COLOR.r);
	v_height = h;
	v_local = VERTEX;
}

global uniform float night_amount;

void fragment() {
	// Thinned out right in front of the lens. The camera rides a spring arm
	// behind the Leader and backs into whatever stands there; a blade or a leaf
	// a hand's breadth away fills half the screen as a flat green slab. A
	// screen-door dither, so it costs a discard and no sorting.
	float lens = smoothstep(0.5, 1.4, -VERTEX.z);
	if (lens < 1.0 && fract(52.9829189 * fract(dot(FRAGCOORD.xy, vec2(0.06711056, 0.00583715)))) > lens) {
		discard;
	}
	vec4 tex = texture(albedo_tex, UV);
	vec3 c = tex.rgb * tint.rgb * v_tint;
	c *= mix(base_shade, 1.08, smoothstep(0.0, 0.6, v_height));
	if (bark > 0.5) {
		// Furrows running up the trunk, deeper and wider low down, as a mature
		// cottonwood's bark is: the texture alone reads as painted-on card.
		float around = atan(v_local.x, v_local.z);
		float furrow = sin(around * 26.0 + v_local.y * 1.4) * 0.5 + 0.5;
		furrow = pow(furrow, 1.6);
		float grain = hash(vec2(floor(around * 22.0), floor(v_local.y * 6.0))) * 0.5;
		float depth = mix(0.22, 0.42, 1.0 - smoothstep(0.0, 0.5, v_height));
		c *= 1.0 - (1.0 - furrow) * depth - grain * 0.06;
	}
	// Moonlight, as on the grass: leaves green in the dark sat oddly beside a
	// prairie gone grey. Dusk keeps its colour.
	float moonlit = smoothstep(0.55, 1.0, night_amount);
	float lum = dot(c, vec3(0.3, 0.59, 0.11));
	c = mix(c, vec3(lum) * vec3(0.82, 0.9, 1.08), moonlit * 0.75);
	ALBEDO = c * cloud_light((INV_VIEW_MATRIX * vec4(VERTEX, 1.0)).xyz);
	// Mip levels average leaf alpha toward the cut, so distant canopies would
	// dissolve into bare branches; boost alpha as the mip level climbs.
	float lod = textureQueryLod(albedo_tex, UV).x;
	ALPHA = tex.a * (1.0 + max(lod, 0.0) * 0.28);
	ALPHA_SCISSOR_THRESHOLD = alpha_cut;
	ROUGHNESS = 0.85;
	SPECULAR = 0.25;
	BACKLIGHT = c * translucency * (1.0 - moonlit * 0.7);
}
