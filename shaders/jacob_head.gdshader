shader_type spatial;
render_mode cull_back, diffuse_burley, specular_schlick_ggx;

uniform sampler2D face_tex : source_color, filter_linear_mipmap, repeat_disable;
uniform vec4 skin_color : source_color = vec4(0.945, 0.812, 0.690, 1.0);
uniform float projection_scale = 1.22;
uniform float projection_y_shift = 0.06;

varying vec3 obj_pos;
varying vec3 obj_n;

void vertex() {
	obj_pos = VERTEX;
	obj_n = NORMAL;
}

void fragment() {
	vec2 uv = vec2(
		obj_pos.x * projection_scale + 0.5,
		-obj_pos.y * projection_scale + 0.50 + projection_y_shift
	);
	vec4 tex = texture(face_tex, uv);
	float in_frame = step(0.02, uv.x) * step(uv.x, 0.98) * step(0.02, uv.y) * step(uv.y, 0.98);
	float facing = smoothstep(0.08, 0.62, obj_n.z);
	float mask = clamp(tex.a * in_frame * facing, 0.0, 1.0);
	vec3 color = mix(skin_color.rgb, tex.rgb, mask);
	ALBEDO = color;
	ROUGHNESS = mix(0.48, 0.58, mask);
	SPECULAR = 0.35;
	SSS_STRENGTH = 0.4;
}
