shader_type canvas_item;

uniform float blur_amount : hint_range(0.0, 8.0) = 2.0;

void fragment() {
	vec2 px = TEXTURE_PIXEL_SIZE * blur_amount;

	vec4 color = vec4(0.0);

	// Centro
	color += texture(TEXTURE, clamp(UV, vec2(0.0), vec2(1.0))) * 0.20;

	// Cerca
	color += texture(TEXTURE, clamp(UV + vec2( px.x, 0.0), vec2(0.0), vec2(1.0))) * 0.10;
	color += texture(TEXTURE, clamp(UV + vec2(-px.x, 0.0), vec2(0.0), vec2(1.0))) * 0.10;
	color += texture(TEXTURE, clamp(UV + vec2(0.0,  px.y), vec2(0.0), vec2(1.0))) * 0.10;
	color += texture(TEXTURE, clamp(UV + vec2(0.0, -px.y), vec2(0.0), vec2(1.0))) * 0.10;

	// Diagonales
	color += texture(TEXTURE, clamp(UV + vec2( px.x,  px.y), vec2(0.0), vec2(1.0))) * 0.05;
	color += texture(TEXTURE, clamp(UV + vec2(-px.x,  px.y), vec2(0.0), vec2(1.0))) * 0.05;
	color += texture(TEXTURE, clamp(UV + vec2( px.x, -px.y), vec2(0.0), vec2(1.0))) * 0.05;
	color += texture(TEXTURE, clamp(UV + vec2(-px.x, -px.y), vec2(0.0), vec2(1.0))) * 0.05;

	// Segunda corona, más suave
	vec2 px2 = px * 2.0;

	color += texture(TEXTURE, clamp(UV + vec2( px2.x, 0.0), vec2(0.0), vec2(1.0))) * 0.025;
	color += texture(TEXTURE, clamp(UV + vec2(-px2.x, 0.0), vec2(0.0), vec2(1.0))) * 0.025;
	color += texture(TEXTURE, clamp(UV + vec2(0.0,  px2.y), vec2(0.0), vec2(1.0))) * 0.025;
	color += texture(TEXTURE, clamp(UV + vec2(0.0, -px2.y), vec2(0.0), vec2(1.0))) * 0.025;

	COLOR = color;
}