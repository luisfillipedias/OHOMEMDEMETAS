shader_type spatial;
render_mode blend_mix, depth_draw_opaque, cull_disabled, diffuse_lambert, specular_schlick_ggx;

uniform sampler2D texture_albedo : source_color, filter_nearest_mipmap;
uniform float alpha_scissor_threshold : hint_range(0.0, 1.0) = 0.5;

uniform float velocidade_vento : hint_range(0.5, 10.0) = 2.5;
uniform float forca_vento : hint_range(0.0, 1.0) = 0.12;
uniform float turbulencia : hint_range(0.0, 2.0) = 0.5;
uniform vec2 direcao_vento = vec2(1.0, 0.4);

void vertex() {
	// Balança apenas do tronco para cima (usando a altura Y local da árvore)
	float altura = max(0.0, VERTEX.y * 0.3);
	vec2 dir = normalize(direcao_vento);
	
	float onda1 = sin(TIME * velocidade_vento + NODE_POSITION_WORLD.x * 0.4 + VERTEX.y * 0.8);
	float onda2 = cos(TIME * (velocidade_vento * 1.3) + NODE_POSITION_WORLD.z * 0.5) * turbulencia;
	
	float total_onda = (onda1 + onda2) * forca_vento * altura;
	
	VERTEX.x += dir.x * total_onda;
	VERTEX.z += dir.y * total_onda;
}

void fragment() {
	vec4 tex = texture(texture_albedo, UV);
	ALBEDO = tex.rgb;
	ALPHA = tex.a;
	ALPHA_SCISSOR_THRESHOLD = alpha_scissor_threshold;
	ROUGHNESS = 0.9;
	SPECULAR = 0.05;
}