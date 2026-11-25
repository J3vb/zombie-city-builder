shader_type spatial;
render_mode cull_disabled;

uniform float stride_clock = 0.0;
varying flat float part_id;
varying flat float kind;

void vertex() {
	part_id = floor(UV.x * 10.0 + 0.5);
	kind = floor(INSTANCE_CUSTOM.r * 4.0 + 0.5);
	float gait = sin(stride_clock * (kind == 1.0 ? 9.0 : 4.4) + INSTANCE_CUSTOM.g * 6.28318);
	float side = VERTEX.x < 0.0 ? -1.0 : 1.0;
	float ankle = max(0.0, 0.68 - VERTEX.y);
	if (part_id < 2.0) {
		VERTEX.z += side * gait * ankle * 0.4;
	}
	if (part_id == 3.0 || part_id == 4.0) {
		VERTEX.z -= side * gait * 0.11;
	}
	if (kind == 1.0) { // Runner, pitched forward with narrow shoulders.
		VERTEX.z += max(0.0, VERTEX.y - 0.6) * 0.32;
		VERTEX.x *= 0.86;
	} else if (kind == 2.0) { // Brute, heavy shoulders and long arms.
		VERTEX.x *= part_id >= 2.0 && part_id <= 4.0 ? 1.48 : 1.12;
		if (part_id == 3.0 || part_id == 4.0) { VERTEX.y -= 0.15; }
	} else if (kind == 3.0) { // Screamer, reared head and lifted arms.
		if (part_id >= 5.0) { VERTEX.y += 0.18; }
		if (part_id == 3.0 || part_id == 4.0) {
			VERTEX.x += side * 0.17;
			VERTEX.y += 0.48;
		}
	} else if (kind == 4.0) { // Crawler, torso laid across the forearms.
		float upright = VERTEX.y;
		VERTEX.y = 0.51 + VERTEX.z * 0.70 + upright * 0.22;
		NORMAL = normalize(vec3(NORMAL.x, NORMAL.z, NORMAL.y));
		VERTEX.z = (upright - 0.78) * 0.97;
		if (part_id == 3.0 || part_id == 4.0) { VERTEX.y -= 0.28; }
	}
}

void fragment() {
	vec3 coat = mix(vec3(0.22, 0.235, 0.21), COLOR.rgb * 0.62, 0.42);
	ALBEDO = coat;
	if (part_id < 2.0) { ALBEDO = vec3(0.12, 0.135, 0.12); }
	if (part_id >= 5.0) { ALBEDO = mix(coat, vec3(0.46, 0.48, 0.37), 0.65); }
	if (part_id == 6.0) {
		ALBEDO = vec3(0.89, 0.47, 0.14);
		EMISSION = ALBEDO * 0.42;
	}
	if (kind == 4.0 && part_id >= 2.0 && part_id <= 4.0) { ALBEDO = vec3(0.24, 0.265, 0.245); }
	if (part_id == 7.0) { ALBEDO = vec3(0.15, 0.10, 0.08); }
	ROUGHNESS = 0.96;
}
