shader_type spatial;
render_mode cull_disabled;
// The Missouri, "the Big Muddy": silt-brown and quick, paling to sandy shallows
// at the banks with a ruffled line where it laps the sand, streaks of current
// running downriver along its bends, and the sky's sheen at grazing angles.

uniform vec3 deep_color : source_color = vec3(0.37, 0.32, 0.23);
uniform vec3 shallow_color : source_color = vec3(0.52, 0.46, 0.34);
uniform vec3 foam_color : source_color = vec3(0.80, 0.76, 0.67);
uniform float flow_speed = 0.9;       // m/s of the streaks
uniform sampler2D river_tex : filter_linear, repeat_disable;  // distance to the 1804 channel (m)
uniform float map_size = 1024.0;
uniform sampler2D depth_tex : hint_depth_texture, filter_linear;
global uniform vec4 sky_horizon;
global uniform float wind_strength;
#include "res://scripts/world/cloud_shadow.gdshaderinc"

float hash(vec2 p) { return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453); }
float noise(vec2 p) {
	vec2 i = floor(p); vec2 f = fract(p);
	vec2 u = f * f * (3.0 - 2.0 * f);
	return mix(mix(hash(i), hash(i + vec2(1, 0)), u.x), mix(hash(i + vec2(0, 1)), hash(i + vec2(1, 1)), u.x), u.y);
}

void vertex() {
	// Low swells running downriver, so the surface catches light on real ripples
	// rather than a flat plane. Amplitude falls off far from the camera, where
	// the waves would be sub-pixel anyway.
	vec3 world = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	float near = 1.0 - smoothstep(30.0, 260.0, length(world - CAMERA_POSITION_WORLD));
	float swell = sin(world.z * 0.55 - TIME * 1.1) * 0.07
			+ sin(world.x * 0.37 + world.z * 0.2 - TIME * 0.7) * 0.05;
	VERTEX.y += swell * near;
}


void fragment() {
	vec3 world = (INV_VIEW_MATRIX * vec4(VERTEX, 1.0)).xyz;
	vec2 w = world.xz;

	// Downriver: along the channel (perpendicular to the distance gradient), southward.
	vec2 uv = w / map_size;
	float e = 4.0 / map_size;
	vec2 g = vec2(texture(river_tex, uv + vec2(e, 0.0)).r - texture(river_tex, uv - vec2(e, 0.0)).r,
			texture(river_tex, uv + vec2(0.0, e)).r - texture(river_tex, uv - vec2(0.0, e)).r);
	vec2 along = length(g) > 0.0001 ? normalize(vec2(-g.y, g.x)) : vec2(0.0, 1.0);
	along *= sign(along.y + 0.0001);
	vec2 across = vec2(-along.y, along.x);
	float s = dot(w, along);
	float t = dot(w, across);

	// Current: long silt streaks drifting downriver, over slower boils.
	float streak = noise(vec2(t * 0.45, (s - TIME * flow_speed) * 0.045));
	// A second, much wider set of bands. The fine streaks are sub-pixel by a couple
	// of hundred metres and the far reach goes flat without these.
	float band = noise(vec2(t * 0.075, (s - TIME * flow_speed * 0.6) * 0.016));
	float boil = noise(w * 0.06 - along * TIME * flow_speed * 0.05);
	float fine = noise(vec2(t * 2.2, (s - TIME * flow_speed * 1.2) * 0.35));

	// Water depth from the scene behind it (the riverbank under the surface).
	float d = texture(depth_tex, SCREEN_UV).r;
	vec4 behind = INV_PROJECTION_MATRIX * vec4(SCREEN_UV * 2.0 - 1.0, d, 1.0);
	float depth = max(-behind.z / behind.w - (-VERTEX.z), 0.0);
	float shallow = 1.0 - smoothstep(0.0, 1.6, depth);

	vec3 c = mix(deep_color, shallow_color, clamp(shallow * 0.8 + (boil - 0.5) * 0.35, 0.0, 1.0));
	c *= 1.0 + (streak - 0.5) * 0.22 + (fine - 0.5) * 0.08 + (band - 0.5) * 0.26;
	// Cat's paws: patches where a gust ruffles the surface, darker and duller,
	// drifting downwind. They are what makes a wide river read as water.
	float gust = clamp(wind_strength, 0.0, 4.0);
	float paw = smoothstep(0.58, 0.82, noise(w * 0.045 + along * TIME * 0.02) * 0.7 + noise(w * 0.14 - TIME * 0.05) * 0.3);
	paw *= clamp(gust * 0.5, 0.25, 1.0);
	c *= 1.0 - paw * 0.1;

	// Lapping edge: a broken pale line where the water thins over sand.
	float lap = smoothstep(0.35, 0.0, depth) * smoothstep(0.35, 0.65, noise(w * 1.3 + along * TIME * 0.4) * 0.6 + fine * 0.4 + sin(TIME * 1.7 + t * 0.8) * 0.1);
	c = mix(c, foam_color, lap * 0.75);
	ALBEDO = c * mix(1.0, cloud_light(world), 0.7);
	ALPHA = mix(0.55, 1.0, smoothstep(0.0, 0.5, depth));

	// Rougher with distance: grazing glints far off otherwise alias into sparkles that glow blows up.
	float dist = length(VERTEX);
	// Smooth enough for SSR to mirror the banks, broken up by the current streaks.
	ROUGHNESS = mix(0.12, 0.45, smoothstep(60.0, 400.0, dist)) + streak * 0.08 + lap * 0.5 + paw * 0.3;
	// Silt-laden water: the mirror only shows at grazing angles (Fresnel does the rest).
	SPECULAR = mix(0.16, 0.1, smoothstep(60.0, 400.0, dist));
	// Near grazing almost everything is Fresnel; keep the sheen to the far reach so
	// the silt stays readable at the player's usual angle.
	float fres = pow(1.0 - clamp(dot(NORMAL, VIEW), 0.0, 1.0), 5.0);
	// The silt does not stop at the far bank: let the reflection carry the river's
	// own colour into it, or the far reach turns into a sheet of white sky.
	vec3 sheen = mix(sky_horizon.rgb, sky_horizon.rgb * deep_color * 2.4, 0.45);
	EMISSION = sheen * fres * mix(0.0, 0.26, smoothstep(5.0, 90.0, dist)) * (1.0 + 0.7 * smoothstep(80.0, 450.0, dist)) * (1.0 - lap);
	float ruffle = 1.0 + paw * 2.5;
	NORMAL_MAP = normalize(vec3(((fine - 0.5) * 0.35 + (streak - 0.5) * 0.2) * ruffle, (boil - 0.5) * 0.4 * ruffle, 4.0)) * 0.5 + 0.5;
}
