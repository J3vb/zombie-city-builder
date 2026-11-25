shader_type spatial;

uniform sampler2D meadow : source_color, filter_linear_mipmap_anisotropic, repeat_enable;
varying vec2 ground_uv;
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
		if (base.g > base.r * 1.08 || base.r > 0.95) {
			vec2 uv = ground_uv * vec2(0.14, 0.07);
			vec3 turf = mix(texture(meadow, uv).rgb, texture(meadow, mat2(vec2(0.8,0.6),vec2(-0.6,0.8))*uv*0.71).rgb, 0.47);
			float meadow_mask = smoothstep(0.14, 0.67, grain(ground_uv * 0.046) + patches * 0.38 - 0.14);
			vec3 earth = vec3(0.22, 0.196, 0.134) * (0.72 + detail * 0.42);
			ALBEDO = mix(earth, turf * vec3(0.76, 0.88, 0.83), meadow_mask);
		} else {
			ALBEDO = base * (0.72 + patches * 0.40 + detail * 0.21);
		}
	}
}
