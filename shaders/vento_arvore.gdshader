shader_type spatial;
render_mode blend_mix, depth_draw_opaque, cull_disabled, diffuse_lambert, specular_disabled;

uniform sampler2D texture_albedo : source_color, filter_nearest_mipmap;
uniform float alpha_scissor_threshold : hint_range(0.0, 1.0) = 0.5;

// Direção unificada do vento no plano XZ
uniform vec2 direcao_vento = vec2(1.0, 0.35);

// Parâmetros de vento amplos e físicos (visíveis tanto em calma quanto em rajadas fortes)
uniform float velocidade_vento : hint_range(0.05, 1.5) = 0.35;
uniform float forca_vento : hint_range(0.0, 2.0) = 0.55;
uniform float forca_flutter : hint_range(0.0, 0.1) = 0.02;

void vertex() {
	vec2 dir = normalize(direcao_vento);
	
	// Posição mundial real do vértice e da base da árvore no terreno
	vec3 world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	vec3 node_base = NODE_POSITION_WORLD;
	
	// Altura real em metros no mundo a partir da base da árvore
	float altura_mundo = max(0.0, world_pos.y - node_base.y);
	
	// Curva física quadrática ampla: a base fica no chão e a copa balança livremente
	float h_factor = clamp(altura_mundo * 0.11, 0.0, 1.35);
	float bend_curve = h_factor * h_factor;

	// Fase espacial lenta que viaja pelo cenário na direção do vento
	float fase = dot(node_base.xz, dir) * 0.06;

	// Balanço orgânico suave e pesado (tronco de madeira de baixa frequência)
	float wave1 = sin(TIME * velocidade_vento + fase);
	float wave2 = sin(TIME * (velocidade_vento * 0.54) + fase * 1.3 + 1.1) * 0.35;
	float sway = (wave1 + wave2) * 0.5; // [-0.67 .. +0.67]

	// 1. Inclinação contínua + balanço proporcional à energia real do áudio de vento
	float lean_world = forca_vento * (0.65 + sway * 0.35) * bend_curve;
	vec3 world_disp = vec3(dir.x, 0.0, dir.y) * lean_world;

	// 2. Micro-ondulação suave nas pontas das folhas (sem vibração)
	float leaf_wave = sin(TIME * 1.6 + world_pos.x * 0.5 + world_pos.z * 0.5 + world_pos.y * 0.4);
	float leaf_disp = leaf_wave * forca_flutter * clamp(altura_mundo * 0.20, 0.0, 1.0);
	world_disp += vec3(dir.x, 0.0, dir.y) * leaf_disp;

	// 3. Leve compressão gravitacional para baixo ao envergar
	world_disp.y -= lean_world * 0.06;

	// 4. Converte de volta para o espaço local da malha (normaliza todas as escalas 3D)
	mat3 inv_model = inverse(mat3(MODEL_MATRIX));
	VERTEX += inv_model * world_disp;
}

void fragment() {
	vec4 tex = texture(texture_albedo, UV);
	ALBEDO = tex.rgb;
	ALPHA = tex.a;
	ALPHA_SCISSOR_THRESHOLD = alpha_scissor_threshold;
	ROUGHNESS = 0.95;
}
