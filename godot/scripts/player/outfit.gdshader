shader_type spatial;
// Dresses the placeholder mannequin in period clothes without new art: each
// vertex is coloured by the bones that move it (head and hands skin, torso and
// arms coat, thighs breeches, shins leggings), with facing-coloured cuffs, a
// waistcoat down the front, a white stock at the throat and a woven cloth grain.
// Bone indices are the Universal Animation Library skeleton's (see character_body.gd).

uniform vec3 coat : source_color = vec3(0.20, 0.27, 0.45);
uniform vec3 facing : source_color = vec3(0.50, 0.14, 0.12);
uniform vec3 waistcoat : source_color = vec3(0.78, 0.72, 0.56);
uniform vec3 breeches : source_color = vec3(0.62, 0.52, 0.36);
uniform vec3 legs : source_color = vec3(0.14, 0.11, 0.09);
uniform vec3 skin : source_color = vec3(0.80, 0.62, 0.50);
uniform vec3 stock : source_color = vec3(0.88, 0.86, 0.80);
uniform vec3 hair : source_color = vec3(0.30, 0.20, 0.12);
uniform vec3 strap : source_color = vec3(0.30, 0.21, 0.13);
uniform float has_waistcoat = 1.0;
// The hem of the frock or coat (rest-pose height; Clothes.CUTS). The body
// above it is under the cloth, so it is the cloth's colour: where a stride
// brings a thigh out through the skirt it then reads as a fold, not a patch
// of breeches, and no band of breeches shows at the waist.
uniform float hem = -1.0;
uniform float open_front = 0.0;   // 1 for a coat open down the front: the breeches show there
varying float v_under;

varying vec4 v_region;  // coat, breeches, legs, skin
varying float v_hand;
varying float v_forearm;
varying float v_neck;
varying float v_front;
varying float v_hair;
varying float v_torso;
varying vec3 v_pos;
// Rest-pose position (Clothes puts it in CUSTOM0; w = 1 on the skirt): the
// face and the hairline are painted in it, whatever pose the body is in.
varying vec4 v_rest;
#include "res://scripts/world/cloud_shadow.gdshaderinc"

void vertex() {
	vec4 r = vec4(0.0);
	float hand = 0.0;
	float forearm = 0.0;
	float neck = 0.0;
	float spine = 0.0;
	float head = 0.0;
	float torso = 0.0;
	for (int i = 0; i < 4; i++) {
		int b = int(BONE_INDICES[i]);
		float w = BONE_WEIGHTS[i];
		if (b == 5) {
			neck += w;  // spreads over the upper chest and shoulders: coat, stock only at the throat
			r.x += w;
			torso += w;
		} else if (b == 6 || (b >= 10 && b <= 25) || (b >= 29 && b <= 44)) {
			r.w += w;
			if (b != 6) hand += w;
			else head += w;
		} else if (b == 45 || b == 49) {
			r.y += w;
		} else if (b >= 46) {
			r.z += w;
		} else {
			r.x += w;  // hips, spine, shoulders, arms
			if (b <= 4) torso += w;
			if (b == 9 || b == 28) forearm += w;
			if (b >= 2 && b <= 4) spine += w;
		}
	}
	v_rest = CUSTOM0;
	if (CUSTOM0.w > 0.5) {
		r = vec4(1.0, 0.0, 0.0, 0.0);  // the skirt is the coat's cloth, though it hangs off the thighs
		torso = 0.0;
	}
	v_region = r;
	v_under = (CUSTOM0.w < 0.5 && hem > 0.0) ? smoothstep(hem + 0.01, hem + 0.05, CUSTOM0.y) * (r.y + r.z) : 0.0;
	v_under *= 1.0 - open_front * smoothstep(0.0, 0.05, CUSTOM0.z) * (1.0 - smoothstep(0.07, 0.13, abs(CUSTOM0.x)));
	v_hand = hand;
	v_forearm = forearm;
	v_neck = neck;
	// Hair over the crown, back and sides, down to a hairline across the brow.
	vec3 q = CUSTOM0.xyz;
	float hairline = mix(1.61, 1.748, smoothstep(0.0, 0.07, q.z)) + abs(q.x) * 0.25 * smoothstep(0.0, 0.07, q.z);
	v_hair = head * smoothstep(hairline - 0.006, hairline + 0.006, q.y);
	v_torso = torso;
	v_pos = VERTEX;
	// Waistcoat: the front-centre of the chest (the mannequin faces +Z).
	v_front = spine * smoothstep(0.2, 0.6, NORMAL.z) * (1.0 - smoothstep(0.035, 0.06, abs(VERTEX.x)));
}

float hash(vec2 p) {
	vec3 p3 = fract(vec3(p.xyx) * 0.1031);
	p3 += dot(p3, p3.yzx + 33.33);
	return fract((p3.x + p3.y) * p3.z);
}

void fragment() {
	vec4 r = v_region / max(dot(v_region, vec4(1.0)), 0.0001);
	vec3 body = mix(coat, waistcoat, clamp(v_front * 1.6, 0.0, 1.0) * has_waistcoat);
	vec3 c = body * r.x + breeches * r.y + legs * r.z + skin * r.w;
	// And in the cloth's shadow: a knee that comes through the skirt mid-stride,
	// lit as if out in the open, showed as a pale patch on it.
	c = mix(c, coat * 0.55, clamp(v_under, 0.0, 1.0));
	// Cuffs where the sleeve meets the wrist; a stock wrapped at the throat.
	float cuff = smoothstep(0.02, 0.1, v_hand) * (1.0 - smoothstep(0.45, 0.6, v_hand)) * step(0.05, v_forearm + v_hand * 0.5);
	c = mix(c, facing, cuff);
	// Shot-pouch belt, shoulder to opposite hip, front and back (per pixel: the
	// mannequin's torso triangles are too big to carry a thin band per vertex).
	float belt = 1.0 - smoothstep(0.022, 0.03, abs(v_pos.x - (v_pos.y - 1.12) * 0.9));
	c = mix(c, strap, belt * smoothstep(0.4, 0.7, v_torso));
	// The stock: a band of linen wound round the neck, under the jaw. Drawn in
	// the rest pose, not by the neck bone's weight, which spreads over the
	// shoulders and left a speckled smear across the top of the chest.
	vec3 rq = v_rest.xyz;
	float round_neck = 1.0 - smoothstep(0.065, 0.085, length(rq.xz - vec2(0.0, -0.005)));
	float stock_band = smoothstep(1.482, 1.488, rq.y) * (1.0 - smoothstep(1.56, 1.566, rq.y)) * round_neck;
	stock_band = step(0.5, stock_band);   // a band of linen has an edge
	c = mix(c, stock, stock_band * (1.0 - v_rest.w));
	c = mix(c, hair, smoothstep(0.3, 0.6, v_hair));
	// A face: brows, eyes set in shadow, the shade under the nose, a mouth.
	// Only on the front of the head (the mannequin faces +Z in its rest pose).
	vec3 q = v_rest.xyz;
	float face = r.w * smoothstep(0.05, 0.08, q.z) * step(1.58, q.y) * (1.0 - v_hair);
	if (face > 0.0) {
		float ax = abs(q.x);
		float socket = 1.0 - smoothstep(0.0, 1.0, length(vec2((ax - 0.034) / 0.026, (q.y - 1.705) / 0.016)));
		float eye = 1.0 - smoothstep(0.7, 1.0, length(vec2((ax - 0.034) / 0.011, (q.y - 1.703) / 0.0055)));
		float brow_y = 1.722 + (ax - 0.034) * -0.12;
		float brow = (1.0 - smoothstep(0.003, 0.0055, abs(q.y - brow_y))) * (1.0 - smoothstep(0.050, 0.058, ax)) * smoothstep(0.010, 0.016, ax);
		float nose = (1.0 - smoothstep(0.0, 1.0, length(vec2(q.x / 0.016, (q.y - 1.662) / 0.006)))) * 0.6
				+ (1.0 - smoothstep(0.0025, 0.005, ax)) * smoothstep(1.66, 1.67, q.y) * (1.0 - smoothstep(1.69, 1.70, q.y)) * 0.15;
		float mouth = (1.0 - smoothstep(0.0018, 0.0035, abs(q.y - 1.637 - ax * ax * 3.0))) * (1.0 - smoothstep(0.016, 0.022, ax));
		float cheek = 1.0 - smoothstep(0.0, 1.0, length(vec2((ax - 0.048) / 0.02, (q.y - 1.668) / 0.016)));
		vec3 f = c;
		f = mix(f, f * vec3(1.06, 0.92, 0.88), cheek * 0.35);
		f *= 1.0 - socket * 0.22 - nose * 0.25;
		f = mix(f, hair * 0.85, brow);
		f = mix(f, vec3(0.07, 0.05, 0.045), eye * 0.9);
		f = mix(f, f * vec3(0.62, 0.42, 0.40), mouth * 0.85);
		c = mix(c, f, face);
	}
	// Woven grain on cloth only.
	float cloth = 1.0 - r.w;
	vec2 g = UV * 900.0;
	float weave = (hash(floor(g)) - 0.5) * 0.08 + (sin(g.x * 3.14) * sin(g.y * 3.14)) * 0.03;
	c *= 1.0 + weave * cloth;
	// Where cloth meets cloth: the legs in the shade just under the hem, the
	// inside of a skirt or cape in its own shadow.
	if (hem > 0.0 && v_rest.w < 0.5) {
		c *= 1.0 - 0.38 * smoothstep(hem - 0.16, hem - 0.01, v_rest.y) * (1.0 - smoothstep(hem + 0.02, hem + 0.05, v_rest.y)) * (r.y + r.z);
	}
	if (fract(v_rest.w) > 0.1) {
		c *= 0.55;
	}
	// The cape's edge cut into a fringe, and a darker line where it is hemmed.
	if (v_rest.w > 1.5) {
		float fringe_zone = smoothstep(0.72, 0.8, UV.y);
		float strand = step(0.5, fract(UV.x * 34.0));
		if (fringe_zone > 0.5 && strand < 0.5 && UV.y > 0.8) {
			discard;
		}
		c *= 1.0 - 0.25 * (1.0 - smoothstep(0.0, 0.03, abs(UV.y - 0.76)));
	}
	ALBEDO = c * cloud_light((INV_VIEW_MATRIX * vec4(VERTEX, 1.0)).xyz);
	ROUGHNESS = mix(mix(0.95, 0.6, r.w), 0.95, stock_band);
	SPECULAR = mix(mix(0.15, 0.35, r.w), 0.1, stock_band);   // linen, not wet skin
	// A little light through ears and fingers.
	BACKLIGHT = skin * 0.15 * r.w;
}
