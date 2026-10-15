shader_type spatial;
render_mode cull_back;
// The far groves (foliage.gd _far_tree_mesh): a crown of three or four lumps on
// a stub of trunk, never nearer than a couple of hundred metres. Smooth-shaded
// lumps still read as blocks at that range, so the crown is broken up here: a
// leafy mottle in the colour, the underside in its own shade, and the outline
// eaten into where the surface turns away, so the edge is ragged like foliage
// rather than a polygon's straight side. COLOR.a is 1 on the crown, 0 on trunk.

global uniform float night_amount;
#include "res://scripts/world/cloud_shadow.gdshaderinc"

varying vec3 v_obj;
varying vec3 v_tint;

float ft_hash(vec3 p) {
	p = fract(p * 0.3183099 + 0.1);
	p *= 17.0;
	return fract(p.x * p.y * p.z * (p.x + p.y + p.z));
}

float ft_noise(vec3 x) {
	vec3 i = floor(x);
	vec3 f = fract(x);
	f = f * f * (3.0 - 2.0 * f);
	return mix(mix(mix(ft_hash(i), ft_hash(i + vec3(1, 0, 0)), f.x),
			mix(ft_hash(i + vec3(0, 1, 0)), ft_hash(i + vec3(1, 1, 0)), f.x), f.y),
			mix(mix(ft_hash(i + vec3(0, 0, 1)), ft_hash(i + vec3(1, 0, 1)), f.x),
			mix(ft_hash(i + vec3(0, 1, 1)), ft_hash(i + vec3(1, 1, 1)), f.x), f.y), f.z);
}

void vertex() {
	v_obj = VERTEX * 6.0 + MODEL_MATRIX[3].xyz * 0.01;   // per-tree offset into the noise
	v_tint = pow(COLOR.rgb, vec3(2.2));   // the tints are authored as sRGB
}

void fragment() {
	float crown = COLOR.a;
	float leaf = ft_noise(v_obj * 1.3) * 0.6 + ft_noise(v_obj * 3.1) * 0.4;
	// Ragged outline: where the crown turns edge-on to the eye, cut it by the
	// leaf noise. Alpha scissor, so it costs no sorting.
	float edge_on = 1.0 - abs(dot(NORMAL, VIEW));
	float keep = mix(1.0, smoothstep(0.25, 0.6, leaf + 0.55 - edge_on * 0.9), crown);
	ALPHA = keep;
	ALPHA_SCISSOR_THRESHOLD = 0.5;
	vec3 world = (INV_VIEW_MATRIX * vec4(VERTEX, 1.0)).xyz;
	vec3 wn = (INV_VIEW_MATRIX * vec4(NORMAL, 0.0)).xyz;
	// Lit crowns are lighter on top, darker and cooler under, and dappled.
	float up = wn.y * 0.5 + 0.5;
	// Matched by eye to the real cottonwoods at the same range: these were a
	// pale mint beside them, because a crown is mostly its own shade.
	vec3 c = v_tint * vec3(0.78, 0.85, 0.62) * mix(0.45, 1.0, up) * (0.75 + leaf * 0.45);
	c = mix(c, vec3(0.06, 0.05, 0.035), 1.0 - crown);         // bark, in shade under the crown
	float moonlit = smoothstep(0.55, 1.0, night_amount);
	float lum = dot(c, vec3(0.3, 0.59, 0.11));
	c = mix(c, vec3(lum) * vec3(0.82, 0.9, 1.08), moonlit * 0.75);
	ALBEDO = c * cloud_light(world);
	ROUGHNESS = 0.95;
	SPECULAR = 0.15;
}
