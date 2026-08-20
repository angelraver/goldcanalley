shader_type spatial;

uniform vec4 color_fondo : source_color = vec4(0.15, 0.55, 0.45, 1.0);
uniform sampler2D textura_png : source_color, filter_linear_mipmap;
uniform vec2 escala_cuadro = vec2(0.8, 0.8);
uniform vec2 posicion_cuadro = vec2(0.0, 0.0);
uniform float rotacion_grados : hint_range(-180.0, 180.0) = 0.0;
uniform bool espejar_horizontal = false; // <--- NUEVA OPCIÓN

void fragment() {
	// 1. Centrar origen y posicionar
	vec2 uv_centrada = UV - vec2(0.5) - posicion_cuadro;
	
	// 2. Rotación
	float rad = radians(rotacion_grados);
	mat2 mat_rotacion = mat2(
		vec2(cos(rad), -sin(rad)),
		vec2(sin(rad), cos(rad))
	);
	
	// 3. Transformación de escala y reciente
	vec2 uv_transformada = (mat_rotacion * uv_centrada) / escala_cuadro + vec2(0.5);
	
	// 4. Invertir X solo si la opción está activa
	if (espejar_horizontal) {
		uv_transformada.x = 1.0 - uv_transformada.x;
	}
	
	vec4 tex = vec4(0.0);
	if (uv_transformada.x >= 0.0 && uv_transformada.x <= 1.0 && uv_transformada.y >= 0.0 && uv_transformada.y <= 1.0) {
		tex = texture(textura_png, uv_transformada);
	}
	
	ALBEDO = mix(color_fondo.rgb, tex.rgb, tex.a);
}