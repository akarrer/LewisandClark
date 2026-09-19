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

varying vec4 v_region;  // coat, breeches, legs, skin
varying float v_hand;
varying float v_forearm;
varying float v_neck;
varying float v_front;
varying float v_hair;
varying float v_torso;
varying vec3 v_pos;

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
	v_region = r;
	v_hand = hand;
	v_forearm = forearm;
	v_neck = neck;
	// Hair over the back and sides of the head, the face left bare.
	v_hair = head * smoothstep(0.1, -0.35, NORMAL.z + max(NORMAL.y, 0.0) * -0.6);
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
	// Cuffs where the sleeve meets the wrist; a stock wrapped at the throat.
	float cuff = smoothstep(0.02, 0.1, v_hand) * (1.0 - smoothstep(0.45, 0.6, v_hand)) * step(0.05, v_forearm + v_hand * 0.5);
	c = mix(c, facing, cuff);
	// Shot-pouch belt, shoulder to opposite hip, front and back (per pixel: the
	// mannequin's torso triangles are too big to carry a thin band per vertex).
	float belt = 1.0 - smoothstep(0.022, 0.03, abs(v_pos.x - (v_pos.y - 1.12) * 0.9));
	c = mix(c, strap, belt * smoothstep(0.4, 0.7, v_torso));
	c = mix(c, stock, smoothstep(0.6, 0.85, v_neck) * 0.9);
	c = mix(c, hair, smoothstep(0.3, 0.6, v_hair));
	// Woven grain on cloth only.
	float cloth = 1.0 - r.w;
	vec2 g = UV * 900.0;
	float weave = (hash(floor(g)) - 0.5) * 0.08 + (sin(g.x * 3.14) * sin(g.y * 3.14)) * 0.03;
	c *= 1.0 + weave * cloth;
	ALBEDO = c;
	ROUGHNESS = mix(0.95, 0.6, r.w);
	SPECULAR = mix(0.15, 0.35, r.w);
	// A little light through ears and fingers.
	BACKLIGHT = skin * 0.15 * r.w;
}
