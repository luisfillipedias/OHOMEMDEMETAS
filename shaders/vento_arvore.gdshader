shader_type spatial;
render_mode blend_mix, depth_draw_opaque, cull_disabled, diffuse_lambert, specular_disabled;

uniform sampler2D texture_albedo : source_color, filter_nearest_mipmap;
uniform float alpha_scissor_threshold : hint_range(0.0, 1.0) = 0.5;

// Direção do vento unificada no plano XZ
uniform vec2 direcao_vento = vec2(1.0, 0.35);

// Parâmetros de inclinação e balanço orgânico (árvore pesada e imponente)
uniform float velocidade_rajada : hint_range(0.1, 3.0) = 0.75;
uniform float forca_rajada : hint_range(0.0, 1.2) = 0.28;
uniform float forca_flutter : hint_range(0.0, 0.2) = 0.03;

void vertex() {
	vec2 dir = normalize(direcao_vento);
	
	// A base da árvore fica 100% ancorada no solo; apenas a copa e galhos superiores curvam
	float height = max(0.0, VERTEX.y);
	float bend_curve = pow(clamp(height * 0.22, 0.0, 3.2), 1.6);

	// Onda espacial que viaja pelo cenário na direção do vento (ondas contínuas)
	float world_phase = dot(NODE_POSITION_WORLD.xz, dir) * 0.08;

	// Balanço orgânico composto (harmonicos suaves para evitar movimento robótico/rápido)
	float wave1 = sin(TIME * velocidade_rajada + world_phase);
	float wave2 = sin(TIME * (velocidade_rajada * 1.55) + world_phase * 1.3 + 1.1) * 0.3;
	float lean_factor = (wave1 + wave2) * 0.5 + 0.5; // Pressão direcional do vento

	// Inclinação principal na direção do vento
	vec2 trunk_displacement = dir * (lean_factor * forca_rajada * bend_curve);

	// Farfalhar suave e natural das folhagens (ondulação suave, sem tremor frenético)
	float leaf_wave = sin(TIME * 2.6 + (VERTEX.x + NODE_POSITION_WORLD.x) * 0.8 + (VERTEX.z + NODE_POSITION_WORLD.z) * 0.8 + VERTEX.y * 0.6);
	vec2 leaf_flutter = dir * (leaf_wave * forca_flutter * clamp(height * 0.35, 0.0, 2.0));

	// Aplica deslocamento nos vértices
	VERTEX.x += trunk_displacement.x + leaf_flutter.x;
	VERTEX.z += trunk_displacement.y + leaf_flutter.y;
	
	// Leve compressão gravitacional para baixo ao curvar com a força do vento
	VERTEX.y -= (lean_factor * forca_rajada * bend_curve) * 0.10;
}

void fragment() {
	vec4 tex = texture(texture_albedo, UV);
	ALBEDO = tex.rgb;
	ALPHA = tex.a;
	ALPHA_SCISSOR_THRESHOLD = alpha_scissor_threshold;
	ROUGHNESS = 0.95;
}
