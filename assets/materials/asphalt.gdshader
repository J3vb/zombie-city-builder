shader_type spatial;
render_mode cull_disabled;
uniform sampler2D aggregate : source_color,filter_linear_mipmap_anisotropic,repeat_enable;
varying vec2 road_pos;
void vertex() { road_pos=(MODEL_MATRIX*vec4(VERTEX,1.0)).xz; NORMAL=vec3(0.0,1.0,0.0); }
void fragment() {
	float grit=dot(texture(aggregate,road_pos*vec2(0.65,0.32)).rgb,vec3(0.3,0.58,0.12));
	float wear=texture(aggregate,road_pos*0.025).g;
	ALBEDO=mix(vec3(0.092,0.103,0.103),vec3(0.25,0.22,0.176),smoothstep(0.16,0.48,wear))*(0.65+0.9*grit);
	ROUGHNESS=0.96;
}

