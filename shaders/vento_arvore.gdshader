shader_type spatial;
render_mode blend_mix, depth_draw_opaque, cull_disabled, diffuse_lambert, specular_schlick_ggx;

uniform sampler2D texture_albedo : source_color, filter_nearest_mipmap;
uniform float alpha_scissor_threshold : hint_range(0.0, 1.0) = 0.5;

uniform float velocidade_vento : hint_range(0.5, 10.0) = 3.2;
uniform float forca_vento : hint_range(0.0, 1.5) = 0.38;
uniform float turbulencia : hint_range(0.0, 2.0) = 0.7;
uniform vec2 direcao_vento = vec2(1.0, 0.35);

void vertex() {
	// Altura com escala suave (raízes imóveis, topo balançando forte no vendaval)
	float altura = pow(clamp(VERTEX.y * 0.45, 0.0, 2.5), 1.2);
	vec2 dir = normalize(direcao_vento);
	
	// Rajadas de vento combinadas (onda principal + oscilações rápidas de turbulência)
	float tempo = TIME * velocidade_vento;
	float onda1 = sin(tempo + NODE_POSITION_WORLD.x * 0.35 + NODE_POSITION_WORLD.z * 0.25 + VERTEX.y * 0.6);
	float onda2 = cos(tempo * 1.45 + VERTEX.x * 0.9) * turbulencia;
	float rajada = sin(TIME * 0.6) * 0.35 + 0.65; // Vento oscila em rajadas (mais realista)
	
	float total_onda = (onda1 + onda2) * forca_vento * altura * rajada;
	
	VERTEX.x += dir.x * total_onda;
	VERTEX.z += dir.y * total_onda;
	// Pequena inclinação vertical quando a rajada empurra
	VERTEX.y -= abs(total_onda) * 0.12;
}

void fragment() {
	vec4 tex = texture(texture_albedo, UV);
	ALBEDO = tex.rgb;
	ALPHA = tex.a;
	ALPHA_SCISSOR_THRESHOLD = alpha_scissor_threshold;
	ROUGHNESS = 0.9;
	SPECULAR = 0.05;
}