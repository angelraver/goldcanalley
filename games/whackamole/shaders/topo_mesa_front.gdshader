shader_type spatial;

uniform vec4 color_fondo : source_color = vec4(0.15, 0.55, 0.45, 1.0);
// 1. Desactivamos repeat_enable utilizando repeat_disable para evitar que los bordes opuestos se filtren
uniform sampler2D textura_png : source_color, filter_linear, repeat_disable;
uniform vec2 escala_cuadro = vec2(0.8, 0.8);
uniform vec2 posicion_cuadro = vec2(0.0, 0.0);
uniform float rotacion_grados : hint_range(-180.0, 180.0) = 0.0;
uniform bool espejar_horizontal = false;

// 2. Umbral para cortar transparencias sucias
uniform float umbral_corte_alpha : hint_range(0.0, 1.0) = 0.05;

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
	
	// 4. Invertir X si la opción está activa
	if (espejar_horizontal) {
		uv_transformada.x = 1.0 - uv_transformada.x;
	}
	
	vec4 tex = vec4(0.0);
	
	// 5. Validar límites UV evitando bordes fantasma
	if (uv_transformada.x > 0.001 && uv_transformada.x < 0.999 && 
	    uv_transformada.y > 0.001 && uv_transformada.y < 0.999) {
		
		tex = texture(textura_png, uv_transformada);
		
		// Si el canal Alpha del PNG es menor al umbral, lo consideramos transparente
		if (tex.a < umbral_corte_alpha) {
			tex.a = 0.0;
		}
	}
	
	// 6. Aplicar mezcla limpia sin líneas en el borde
	ALBEDO = mix(color_fondo.rgb, tex.rgb, tex.a);
}