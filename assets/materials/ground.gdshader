shader_type spatial;

varying vec2 ground_uv;
float grain(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	vec3 k = fract(vec3(i.xyx) * vec3(0.1031, 0.11369, 0.13787));
	float a = fract((k.x + k.y) * (k.z + 14.9));
	k = fract(vec3(i.xyx + vec3(1., 0., 1.)) * vec3(0.1031, 0.11369, 0.13787));
	float b = fract((k.x + k.y) * (k.z + 14.9));
	k = fract(vec3(i.xyx + vec3(0., 1., 0.)) * vec3(0.1031, 0.11369, 0.13787));
	float c = fract((k.x + k.y) * (k.z + 14.9));
	k = fract(vec3(i.xyx + vec3(1., 1., 1.)) * vec3(0.1031, 0.11369, 0.13787));
	float d = fract((k.x + k.y) * (k.z + 14.9));
	return mix(mix(a, b, f.x), mix(c, d, f.x), f.y);
}

void vertex() { ground_uv = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xz; }

void fragment() {
	float patches = grain(ground_uv * 0.21);
	float detail = grain(ground_uv * 2.3);
	vec3 base = COLOR.rgb;
	ROUGHNESS = 0.98;
	if (base.b > base.r * 1.26) {
		float ripple = sin(ground_uv.x * 1.9 + ground_uv.y * 0.46 + patches * 9.0 + TIME * 0.65);
		ALBEDO = base * (0.9 + patches * 0.14) + vec3(0.05, 0.08, 0.09) * smoothstep(0.89, 1.0, ripple) * detail;
		ROUGHNESS = 0.54;
	} else {
		ALBEDO = base * (0.77 + patches * 0.38 + detail * 0.13);
	}
}
