shader_type spatial;
render_mode cull_disabled;

// The tile stores stone grain, dust variation and hairline cracks in R, G and B.
uniform sampler2D aggregate : filter_linear_mipmap_anisotropic, repeat_enable;
uniform vec4 binder : source_color = vec4(0.234, 0.244, 0.242, 1.0);
uniform vec4 dust : source_color = vec4(0.32, 0.32, 0.305, 1.0);
uniform float fissures : hint_range(0.0, 1.0) = 0.50;
varying vec2 road_pos;

void vertex() {
	road_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xz;
	NORMAL = vec3(0.0, 1.0, 0.0);
}

void fragment() {
	vec2 uv = road_pos / 5.1;
	mat2 turn = mat2(vec2(0.8, 0.6), vec2(-0.6, 0.8));
	vec3 fine = texture(aggregate, uv).rgb;
	vec3 coarse = texture(aggregate, turn * uv * 0.41 + vec2(0.32, 0.19)).rgb;
	float patches = texture(aggregate, road_pos * 0.034).g;
	float wear = clamp(fine.g * 0.23 + coarse.g * 0.50 + patches * 0.27, 0.0, 1.0);
	float chips = (fine.r - 0.5) * 0.93 + (coarse.r - 0.5) * 0.31;
	float cracks = coarse.b * smoothstep(0.27, 0.66, patches);
	ALBEDO = mix(binder.rgb, dust.rgb, wear) * (1.0 + chips) * (1.0 - fissures * cracks);
	ROUGHNESS = 0.96;
}
