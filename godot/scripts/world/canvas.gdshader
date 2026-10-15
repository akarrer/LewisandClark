shader_type spatial;
// Tent canvas: linen duck that has been rained on, dried, rolled and pitched a
// hundred times since St. Louis. A flat colour read as paper -- the brightest
// thing in every camp shot, white even by moonlight. Here it is greyed and
// warmed, woven, seamed every bolt's width, and darkened toward the eaves
// where the rain runs off and the mud splashes up.

uniform vec3 linen : source_color = vec3(0.70, 0.66, 0.56);
uniform float bolt = 0.72;       // metres between the sewn seams
uniform float panel_len = 1.88;  // ridge to eave (camp.gd _tent: the slant)
global uniform float night_amount;
global uniform float wetness;

varying vec3 v_world;
varying vec3 v_local;

float c_hash(vec2 p) {
	uvec2 q = uvec2(ivec2(floor(p)) + ivec2(1 << 20));
	q = q * 1664525u + 1013904223u;
	q.x += q.y * 1664525u;
	q.y += q.x * 1664525u;
	q = q ^ (q >> 16u);
	return float((q.x ^ q.y) >> 8u) * (1.0 / 16777216.0);
}

float c_noise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	vec2 u = f * f * (3.0 - 2.0 * f);
	return mix(mix(c_hash(i), c_hash(i + vec2(1.0, 0.0)), u.x),
			mix(c_hash(i + vec2(0.0, 1.0)), c_hash(i + vec2(1.0, 1.0)), u.x), u.y);
}

void vertex() {
	v_world = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	v_local = VERTEX;
}

void fragment() {
	// Along the tent (local x) and down the slope (local z), so the weave and
	// seams lie on the cloth whichever way the tent is turned.
	vec2 cloth = v_local.xz;
	float stain = c_noise(v_world.xz * 1.3) * 0.6 + c_noise(v_world.xz * 4.1) * 0.4;
	vec3 c = linen * (0.88 + stain * 0.2);
	// The seams, a doubled line of stitching.
	float seam = 1.0 - smoothstep(0.0, 0.012, abs(fract(cloth.x / bolt) - 0.5) * bolt - 0.0);
	c *= 1.0 - seam * 0.18;
	// A fine weave, only where it can be seen.
	float px = length(fwidth(cloth));
	float weave = (sin(cloth.x * 900.0) * sin(cloth.y * 900.0)) * 0.5 + 0.5;
	c *= 1.0 - weave * 0.05 * (1.0 - smoothstep(0.0008, 0.003, px));
	// Toward the eave (the panel's far end down the slope) the cloth is wet and
	// muddied; the panel runs from the ridge at -z/2 to the eave at +z/2.
	float eave = smoothstep(0.1, 0.95, v_local.z / panel_len + 0.5);
	c = mix(c, c * vec3(0.72, 0.66, 0.56), eave * eave * (0.55 + 0.45 * c_noise(v_world.xz * 2.7 + 9.0)));
	// Moonlight greys it with the land.
	float moonlit = smoothstep(0.55, 1.0, night_amount);
	float lum = dot(c, vec3(0.3, 0.59, 0.11));
	c = mix(c, vec3(lum) * vec3(0.82, 0.9, 1.08), moonlit * 0.7) * mix(1.0, 0.7, moonlit);
	ALBEDO = c * mix(1.0, 0.7, wetness);
	ROUGHNESS = mix(0.92, 0.7, wetness);
	SPECULAR = 0.2;
	// Canvas is thin: the sun shows through it a little.
	BACKLIGHT = c * 0.25;
}
