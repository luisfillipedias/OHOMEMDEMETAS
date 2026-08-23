shader_type spatial;
render_mode blend_mix, depth_draw_opaque, cull_disabled, diffuse_lambert, specular_disabled;

uniform sampler2D texture_albedo : source_color, filter_nearest_mipmap;
uniform float alpha_scissor_threshold : hint_range(0.0, 1.0) = 0.5;

uniform float velocidade_vento : hint_range(0.5, 10.0) = 3.2;
uniform float forca_vento : hint_range(0.0, 1.5) = 0.38;
uniform vec2 direcao_vento = vec2(1.0, 0.35);

void vertex() {
	// Altura com escala suave (raízes imóveis, topo balançando forte no vendaval)
	float altura = clamp(VERTEX.y * 0.4, 0.0, 2.5);
	vec2 dir = normalize(direcao_vento);
	
	// Cálculo trigonométrico unificado super otimizado (60 FPS estável)
	float phase = TIME * velocidade_vento + NODE_POSITION_WORLD.x * 0.3 + NODE_POSITION_WORLD.z * 0.3 + VERTEX.y * 0.5;
	float sway = (sin(phase) + sin(phase * 1.6) * 0.4) * forca_vento * altura;
	
	VERTEX.x += dir.x * sway;
	VERTEX.z += dir.y * sway;
}

void fragment() {
	vec4 tex = texture(texture_albedo, UV);
	ALBEDO = tex.rgb;
	ALPHA = tex.a;
	ALPHA_SCISSOR_THRESHOLD = alpha_scissor_threshold;
	ROUGHNESS = 0.95;
}