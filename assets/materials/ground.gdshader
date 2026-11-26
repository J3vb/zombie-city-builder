shader_type spatial;

uniform sampler2D meadow : source_color, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D silt : source_color, filter_linear_mipmap_anisotropic, repeat_enable;
// One texel per simulation cell: open water, woodland density, rubble.
uniform sampler2D terrain_mask : hint_default_black, filter_linear_mipmap, repeat_disable;
uniform vec2 map_extent = vec2(1.0);
uniform vec2 patch_offset = vec2(0.0);
varying vec2 ground_pos;

float hash(vec2 p) {
	vec3 q = fract(vec3(p.xyx) * 0.1031);
	q += dot(q, q.yzx + 33.33);
	return fract((q.x + q.y) * q.z);
}

float grain(vec2 p) {
	vec2 cell = floor(p);
	vec2 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	return mix(mix(hash(cell), hash(cell + vec2(1., 0.)), f.x),
		mix(hash(cell + vec2(0., 1.)), hash(cell + vec2(1.)), f.x), f.y);
}

void vertex() {
	ground_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xz;
}

void fragment() {
	vec2 p = ground_pos + patch_offset;
	vec2 map_uv = ground_pos / map_extent;
	vec3 habitat = textureLod(terrain_mask, map_uv, 0.0).rgb;
	vec2 warp = vec2(grain(p * 0.032), grain(p * 0.038 + 19.7));
	float field = grain(p * 0.021 + warp * 1.65);
	float tufts = grain(p * 0.25 + warp * 4.0);
	float shore = habitat.r + (tufts - 0.5) * 0.064;
	float damp = smoothstep(0.008 + warp.x * 0.065, 0.44 + warp.y * 0.07, shore);
	float water = smoothstep(0.46, 0.56, shore);
	// UV2.x contains the terrain kind. Unmarked meshes (the title meadow) use ground.
	int kind = int(round(UV2.x));
	ROUGHNESS = 0.96;
	if (kind == 5 || kind == 4) {
		ALBEDO = COLOR.rgb * (0.85 + 0.20 * tufts + 0.12 * field);
	} else {
		mat2 turn = mat2(vec2(0.8, 0.6), vec2(-0.6, 0.8));
		vec3 ground = vec3(0.0);
		if (water < 1.0) {
			vec2 grass_uv = p * vec2(0.34, 0.17);
			vec3 turf = mix(texture(meadow, grass_uv).rgb,
				texture(meadow, (turn * p) * vec2(0.24, 0.12)).rgb, 0.35 + field * 0.28);
			float blades = dot(turf, vec3(0.30, 0.57, 0.13));
			turf = mix(turf, vec3(blades), 0.44) * vec3(0.82, 0.94, 0.96);
			turf *= mix(vec3(0.81, 0.90, 0.90), vec3(1.20, 1.15, 1.04), field);

			vec3 soil = texture(silt, (turn * p) * 0.28).rgb;
			float clod = dot(soil, vec3(0.30, 0.57, 0.13));
			float litter = kind == 3 ? 1.0 : habitat.g;
			float rubble = kind == 1 ? 1.0 : habitat.b * 0.8;
			float hollow = smoothstep(0.54, 0.86, field * 0.77 + tufts * 0.23);
			float bare = smoothstep(0.10, 0.90, max(hollow, max(damp, rubble))
				+ litter * 0.23 + (tufts - 0.5) * 0.19);
			float wet = bare * smoothstep(0.10, 0.91, damp + hollow * 0.69 + (0.46 - clod));
			soil = mix(soil, vec3(clod), 0.24) * mix(vec3(0.98, 1.01, 0.95), vec3(0.49, 0.56, 0.56), wet);
			ground = mix(turf * (1.0 - litter * 0.24), soil, bare);
			ROUGHNESS = mix(0.97, 0.39, wet);
		}
		if (water > 0.0) {
			float depth = smoothstep(0.50, 0.98, shore + tufts * 0.035);
			float wave = sin(p.x * 2.2 + p.y * 0.94 + warp.x * 14.0 + TIME * 0.9)
				+ 0.46 * sin(p.y * 3.14 - p.x * 0.60 + tufts * 4.0 + TIME * 0.63);
			vec3 lake = mix(vec3(0.26, 0.29, 0.235), vec3(0.155, 0.26, 0.275), depth);
			float sky = pow(1.0 - clamp(dot(NORMAL, VIEW), 0.0, 1.0), 2.0);
			float crest = sin(p.y * 6.1 + p.x * 1.32 + tufts * 12.0 + warp.x * 17.0 + TIME);
			float glint = smoothstep(0.87, 1.0, crest) * smoothstep(0.56, 0.82, tufts);
			lake = mix(lake, vec3(0.43, 0.52, 0.55), sky * 0.70);
			lake += vec3(0.019, 0.028, 0.032) * glint * depth;
			ground = mix(ground, lake * (0.94 + 0.10 * field + 0.026 * tufts), water);
			NORMAL = normalize(NORMAL + mat3(VIEW_MATRIX) * vec3(wave * 0.026, 0.0, wave * 0.014) * water);
			ROUGHNESS = mix(ROUGHNESS, 0.38, water);
		}
		ALBEDO = ground;
	}
}
