shader_type spatial;
render_mode blend_mix, depth_draw_opaque, cull_disabled, diffuse_lambert, specular_disabled;

uniform sampler2D texture_albedo : source_color, filter_nearest_mipmap;
uniform float alpha_scissor_threshold : hint_range(0.0, 1.0) = 0.5;

// Direção unificada do vento no plano XZ
uniform vec2 direcao_vento = vec2(1.0, 0.35);

// Parâmetros de vento (velocidade FIXA constante para evitar saltos temporais; modulação exclusiva por FORÇA)
uniform float velocidade_vento : hint_range(0.05, 1.5) = 0.34;
uniform float forca_vento : hint_range(0.0, 4.0) = 1.0;
uniform float forca_flutter : hint_range(0.0, 0.15) = 0.025;

// Perfil de Espécie da Árvore:
// 0 = Conífera / Pinheiro (estrutura rígida, cone uniforme)
// 1 = Árvore Larga / Copada (tronco firme, copa viva)
// 2 = Árvore Fina / Palmeira / Arbusto (haste flexível)
uniform int tipo_arvore : hint_range(0, 2) = 1;

// Seed individual por árvore para quebrar sincronização coletiva
uniform float seed_individual : hint_range(0.0, 100.0) = 0.0;

void vertex() {
	vec2 dir = normalize(direcao_vento);
	vec2 perp = vec2(-dir.y, dir.x);
	
	// Posição base do nó no mundo (fixa e estática no terreno, NUNCA muda durante a animação)
	vec3 node_base = NODE_POSITION_WORLD;
	
	// Posição de repouso estática no mundo (sem deformação)
	vec3 rest_world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	float altura_mundo = max(0.0, rest_world_pos.y - node_base.y);
	
	// Fases estáticas baseadas na posição física fixa no mapa + seed individual
	float fase_global = dot(node_base.xz, dir) * 0.06 + seed_individual * 0.41;
	// Fase local estática de galhos baseada na coordenada local do vértice
	float fase_local = dot(VERTEX.xyz, vec3(1.7, 1.2, 1.9)) + seed_individual;
	
	// -------------------------------------------------------------
	// 1. PERFIS FÍSICOS DE ESPÉCIE
	// -------------------------------------------------------------
	float rigidez_tronco = 1.0;
	float mult_lateral = 1.0;
	float mult_galho = 1.0;
	float limite_h = 1.55;
	
	if (tipo_arvore == 0) {
		// PINHEIRO / CONÍFERA
		rigidez_tronco = 0.95;
		mult_lateral = 0.45;
		mult_galho = 0.30;
		limite_h = 1.40;
	} else if (tipo_arvore == 1) {
		// ÁRVORE LARGA / COPADA (Carvalhos, árvores urbanas de campus)
		rigidez_tronco = 0.85;
		mult_lateral = 0.85;
		mult_galho = 1.80;
		limite_h = 1.35;
	} else {
		// ÁRVORE FINA / PALMEIRA / ARBUSTO
		rigidez_tronco = 1.45;
		mult_lateral = 0.75;
		mult_galho = 0.60;
		limite_h = 1.70;
	}

	// Curva física quadrática de envergadura vertical (aumentada para ser claramente visível)
	float h_factor = clamp(altura_mundo * 0.12, 0.0, limite_h);
	float bend_curve = h_factor * h_factor;

	// -------------------------------------------------------------
	// 2. ÓRBITA AERODINÂMICA CONTÍNUA (Lissajous / Elipse Ampla)
	// Balanço profundo e imponente que enverga a árvore no vento
	// -------------------------------------------------------------
	float t_fundamental = TIME * velocidade_vento + fase_global;
	
	// Onda longitudinal (na direção do vento) - 45% inclinação base + 55% arco de oscilação
	float wave_fwd = sin(t_fundamental) * 0.72 + sin(t_fundamental * 0.48 + 1.2) * 0.28;
	float lean_fwd = forca_vento * rigidez_tronco * (0.45 + wave_fwd * 0.55) * bend_curve;
	vec3 world_disp = vec3(dir.x, 0.0, dir.y) * lean_fwd;

	// Onda transversal (lateral / órbita suave em fase de 90 graus / cosseno)
	float wave_lat = cos(t_fundamental * 0.88 + 0.5);
	float lean_lat = forca_vento * (0.28 * mult_lateral) * wave_lat * bend_curve;
	world_disp += vec3(perp.x, 0.0, perp.y) * lean_lat;

	// -------------------------------------------------------------
	// 3. RESPIRAÇÃO E ONDULAÇÃO ORGÂNICA DE GALHOS E COPA
	// Ondulação tridimensional de grande escala nos galhos externos
	// -------------------------------------------------------------
	if (mult_galho > 0.1) {
		float branch_t = TIME * (velocidade_vento * 1.35) + fase_local;
		float branch_wave = sin(branch_t);
		float branch_disp = forca_vento * (0.16 * mult_galho) * branch_wave * clamp(altura_mundo * 0.16, 0.0, 1.4);
		// Galhos ondulam radialmente e verticalmente
		world_disp.x += perp.x * branch_disp;
		world_disp.z += perp.y * branch_disp;
		world_disp.y += sin(branch_t * 0.75) * (branch_disp * 0.45);
	}

	// -------------------------------------------------------------
	// 4. MICRO-FARFALHAR DAS FOLHAS (Shimmer natural)
	// -------------------------------------------------------------
	float leaf_wave = sin(TIME * 2.4 + fase_local * 2.0);
	float leaf_disp = leaf_wave * forca_flutter * clamp(altura_mundo * 0.20, 0.0, 0.6);
	world_disp.x += (dir.x * 0.3 + perp.x * 0.7) * leaf_disp;
	world_disp.z += (dir.y * 0.3 + perp.y * 0.7) * leaf_disp;

	// -------------------------------------------------------------
	// 5. COMPRESSÃO GRAVITACIONAL NATURAL AO ENVERGAR
	// -------------------------------------------------------------
	world_disp.y -= lean_fwd * 0.06;

	// 6. Converte de volta para o espaço local da malha
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
