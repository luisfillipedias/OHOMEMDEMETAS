shader_type spatial;
render_mode blend_mix, depth_draw_opaque, cull_disabled, diffuse_lambert, specular_disabled;

uniform sampler2D texture_albedo : source_color, filter_nearest_mipmap;
uniform float alpha_scissor_threshold : hint_range(0.0, 1.0) = 0.5;

// Direção unificada do vento no plano XZ
uniform vec2 direcao_vento = vec2(1.0, 0.35);

// Parâmetros de vento calibrados no ESPAÇO DE MUNDO (em metros reais)
uniform float velocidade_vento : hint_range(0.1, 3.0) = 0.95;
uniform float forca_vento : hint_range(0.0, 2.0) = 0.65;
uniform float forca_flutter : hint_range(0.0, 0.2) = 0.045;

void vertex() {
	vec2 dir = normalize(direcao_vento);
	
	// 1. Posição mundial real do vértice e da base da árvore no terreno
	vec3 world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	vec3 node_base = NODE_POSITION_WORLD;
	
	// 2. Altura real em metros no mundo (independe se o modelo foi importado em escala 0.13, 1.0 ou 100x)
	float altura_mundo = max(0.0, world_pos.y - node_base.y);
	
	// Curva física de flexão (tronco ancorado no solo, copa flexível no topo)
	float bend_curve = pow(clamp(altura_mundo * 0.18, 0.0, 3.0), 1.35);

	// Fase espacial que viaja pelo cenário na direção do vento
	float fase = dot(node_base.xz, dir) * 0.08;

	// Balanço orgânico composto (2 harmônicos lentos para peso de madeira real)
	float wave1 = sin(TIME * velocidade_vento + fase);
	float wave2 = sin(TIME * (velocidade_vento * 0.58) + fase * 1.3 + 1.1) * 0.4;
	float sway = (wave1 + wave2) * 0.5; // [-0.7 .. +0.7]

	// 3. Inclinação principal do tronco na direção do vento (em metros reais de mundo)
	float lean_world = forca_vento * (0.65 + sway * 0.35) * bend_curve;
	vec3 world_disp = vec3(dir.x, 0.0, dir.y) * lean_world;

	// 4. Ondulação orgânica de galhos e copas folheadas (movimento 3D volumoso para árvores largas)
	float branch_wave = sin(TIME * 2.2 + world_pos.x * 0.7 + world_pos.z * 0.7 + world_pos.y * 0.4);
	float branch_disp = branch_wave * (forca_vento * 0.22) * clamp(altura_mundo * 0.15, 0.0, 1.5);
	world_disp.x += dir.y * branch_disp * 0.45; // ondulação perpendicular suave
	world_disp.z += -dir.x * branch_disp * 0.45;

	// 5. Farfalhar sutil e orgânico nas pontas das folhas
	float leaf_wave = sin(TIME * 4.0 + world_pos.x * 1.8 + world_pos.z * 1.8 + world_pos.y * 1.2);
	float leaf_disp = leaf_wave * forca_flutter * clamp(altura_mundo * 0.25, 0.0, 1.2);
	world_disp += vec3(dir.x, 0.0, dir.y) * leaf_disp;

	// 6. Compressão gravitacional natural para baixo ao envergar
	world_disp.y -= lean_world * 0.07;

	// 7. Converte o deslocamento em metros de volta para o espaço local da malha
	// Isso normaliza todas as escalas importadas (árvores grandes folheadas se movem igual aos pinheiros!)
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
