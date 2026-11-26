shader_type spatial;
render_mode cull_disabled, diffuse_lambert_wrap;

uniform sampler2D boughs : source_color, filter_linear_mipmap_anisotropic, repeat_disable;
varying vec3 crown_tint;

void vertex() {
	// Every instance keeps its own foliage tone, including after a tile is cleared and restored.
	vec2 root = MODEL_MATRIX[3].xz;
	float tone = fract(dot(fract(root * vec2(0.071, 0.113)), vec2(13.71, 5.43)));
	crown_tint = mix(vec3(0.78, 0.91, 0.89), vec3(1.13, 1.05, 0.86), tone);
}

void fragment() {
	vec4 spray = texture(boughs, UV);
	ALBEDO = spray.rgb * COLOR.rgb * crown_tint;
	// Both sides of a spray share the outward crown normal assigned by the mesh.
	NORMAL = FRONT_FACING ? NORMAL : -NORMAL;
	ROUGHNESS = 0.94;
	SPECULAR = 0.16;
	ALPHA = spray.a;
	ALPHA_SCISSOR_THRESHOLD = 0.36;
}
