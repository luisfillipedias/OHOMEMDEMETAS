shader_type spatial;
render_mode blend_mix, depth_draw_opaque, cull_disabled, diffuse_lambert, specular_disabled;

uniform sampler2D texture_albedo : source_color, filter_nearest_mipmap;
uniform float alpha_scissor_threshold : hint_range(0.0, 1.0) = 0.5;

// Direção unificada do vento no plano XZ
uniform vec2 direcao_vento = vec2(1.0, 0.35);

// Parâmetros globais de vento (controlados pelo áudio de vento em tempo real)
uniform float velocidade_vento : hint_range(0.05, 1.5) = 0.35;
uniform float forca_vento : hint_range(0.0, 2.0) = 0.55;
uniform float forca_flutter : hint_range(0.0, 0.1) = 0.02;

// Perfil de Espécie da Árvore:
// 0 = Conífera / Pinheiro (estrutura cônica rígida, flexão uniforme)
// 1 = Árvore Larga / Copada (tronco grosso firme, copa volumosa com ondulação 3D de galhos)
// 2 = Árvore Fina / Alta / Arbusto (haste flexível, grande arco no topo)
uniform int tipo_arvore : hint_range(0, 2) = 1;

// Variação individual para evitar que árvores do mesmo tipo dancem em uníssono ("puxar corda")
uniform float seed_individual : hint_range(0.0, 100.0) = 0.0;

void vertex() {
	vec2 dir = normalize(direcao_vento);
	// Vetor perpendicular (ortogonal) para turbulência e oscilação lateral 3D
	vec2 perp = vec2(-dir.y, dir.x);
	
	// Posição mundial real do vértice e da base da árvore no terreno
	vec3 world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	vec3 node_base = NODE_POSITION_WORLD;
	
	// Altura real em metros no mundo a partir do solo
	float altura_mundo = max(0.0, world_pos.y - node_base.y);
	
	// Fase espacial única por árvore (baseada na posição no terreno + seed individual)
	float fase = dot(node_base.xz, dir) * 0.07 + seed_individual * 0.43;
	
	// -------------------------------------------------------------
	// PERFIS DE COMPORTAMENTO FÍSICO POR ESPÉCIE
	// -------------------------------------------------------------
	float rigidez_tronco = 1.0;
	float flex_lateral = 1.0;
	float ondulacao_copa = 1.0;
	float mult_velocidade = 1.0;
	float limite_altura = 1.35;
	
	if (tipo_arvore == 0) {
		// PINHEIRO / CONÍFERA: cone rígido, oscilação uniforme, pouco movimento de galhos soltos
		rigidez_tronco = 0.90;
		flex_lateral = 0.40;
		ondulacao_copa = 0.25;
		mult_velocidade = 1.05;
		limite_altura = 1.25;
	} else if (tipo_arvore == 1) {
		// ÁRVORE LARGA / COPADA (Carvalhos, Mangueiras, árvores de campus):
		// Tronco grosso firme, mas a copa volumosa ondula em ondas 3D amplas
		rigidez_tronco = 0.65;
		flex_lateral = 0.85;
		ondulacao_copa = 1.75;
		mult_velocidade = 0.80; // mais lenta e pesada
		limite_altura = 1.10;
	} else {
		// ÁRVORE FINA / PALMEIRA / ARBUSTO:
		// Tronco altamente flexível, arco largo no topo
		rigidez_tronco = 1.40;
		flex_lateral = 0.70;
		ondulacao_copa = 0.60;
		mult_velocidade = 1.20; // mais ágil
		limite_altura = 1.50;
	}

	// Curva física quadrática de envergadura
	float h_factor = clamp(altura_mundo * 0.11, 0.0, limite_altura);
	float bend_curve = h_factor * h_factor;

	float vel = velocidade_vento * mult_velocidade;

	// -------------------------------------------------------------
	// 1. INCLINAÇÃO PRINCIPAL DO TRONCO (Ao longo da direção do vento)
	// Balanço suave e majestoso de baixa frequência que NUNCA inverte contra o vento
	// -------------------------------------------------------------
	float wave_longitudinal = sin(TIME * vel + fase) * 0.7 + sin(TIME * (vel * 0.48) + fase * 1.3 + 1.2) * 0.3;
	// Mantém inclinação positiva constante (0.72 base + 0.28 oscilação suave), sem puxar para trás
	float lean_world = forca_vento * rigidez_tronco * (0.72 + wave_longitudinal * 0.28) * bend_curve;
	vec3 world_disp = vec3(dir.x, 0.0, dir.y) * lean_world;

	// -------------------------------------------------------------
	// 2. OSCILAÇÃO LATERAL 3D AERODINÂMICA (Figura em 8 / Vórtices de vento)
	// Age no eixo PERPENDICULAR (ortogonal) -> NUNCA briga com a inclinação do tronco!
	// -------------------------------------------------------------
	float wave_lateral = sin(TIME * (vel * 1.25) + fase * 1.7 + 0.85);
	float sway_lateral = wave_lateral * (forca_vento * 0.25 * flex_lateral) * bend_curve;
	world_disp += vec3(perp.x, 0.0, perp.y) * sway_lateral;

	// -------------------------------------------------------------
	// 3. ONDULAÇÃO ORGÂNICA DE GALHOS E COPA (Volume tridimensional vivo)
	// -------------------------------------------------------------
	if (ondulacao_copa > 0.1) {
		float branch_time = TIME * (vel * 1.5);
		float branch_phase = world_pos.x * 0.45 + world_pos.z * 0.45 + world_pos.y * 0.35 + seed_individual;
		float branch_sway = sin(branch_time + branch_phase);
		float branch_disp = branch_sway * (forca_vento * 0.16 * ondulacao_copa) * clamp(altura_mundo * 0.14, 0.0, 1.2);
		// Ondula os galhos lateralmente e verticalmente sem forçar contra o vento
		world_disp.x += perp.x * branch_disp;
		world_disp.z += perp.y * branch_disp;
		world_disp.y += sin(branch_time * 0.8 + branch_phase) * branch_disp * 0.25;
	}

	// -------------------------------------------------------------
	// 4. MICRO-FARFALHAR DE FOLHAS (Shimmer natural suave)
	// -------------------------------------------------------------
	float leaf_time = TIME * 2.5 + world_pos.x * 1.2 + world_pos.z * 1.2 + world_pos.y * 0.8;
	float leaf_disp = sin(leaf_time) * (forca_flutter * 0.4) * clamp(altura_mundo * 0.18, 0.0, 0.6);
	world_disp.x += perp.x * leaf_disp;
	world_disp.z += perp.y * leaf_disp;

	// -------------------------------------------------------------
	// 5. COMPRESSÃO GRAVITACIONAL NATURAL AO ENVERGAR
	// -------------------------------------------------------------
	world_disp.y -= lean_world * 0.055;

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
