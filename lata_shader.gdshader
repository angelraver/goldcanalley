shader_type spatial;

uniform sampler2D tex_side : source_color, filter_linear_mipmap;
uniform sampler2D tex_top : source_color, filter_linear_mipmap;
uniform sampler2D tex_bottom : source_color, filter_linear_mipmap;
uniform float top_radius = 0.5;
uniform float bottom_radius = 0.5;
varying vec3 local_pos;
varying vec3 local_normal;

void vertex() {
	local_pos = VERTEX;
	local_normal = NORMAL;
}

void fragment() {
	if (local_normal.y > 0.5) {
		// Tapa Superior: calcula de -radius a +radius para dar [0.0, 1.0] exacto
		vec2 uv_top = (local_pos.xz / (2.0 * top_radius)) + vec2(0.5);
		ALBEDO = texture(tex_top, uv_top).rgb;
	} else if (local_normal.y < -0.5) {
		// Tapa Inferior
		vec2 uv_bottom = (vec2(-local_pos.x, local_pos.z) / (2.0 * bottom_radius)) + vec2(0.5);
		ALBEDO = texture(tex_bottom, uv_bottom).rgb;
	} else {
		// Cara Lateral: UVs nativas + escala y offset de valores.json
		vec2 uv_side = (UV * vec2(1, 2)) + vec2(0, 0);
		ALBEDO = texture(tex_side, uv_side).rgb;
	}
}