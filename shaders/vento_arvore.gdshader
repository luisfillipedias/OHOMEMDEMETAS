shader_type spatial;
render_mode blend_mix, depth_draw_opaque, cull_disabled, diffuse_lambert, specular_disabled;

uniform sampler2D texture_albedo : source_color, filter_nearest_mipmap;
uniform float alpha_scissor_threshold : hint_range(0.0, 1.0) = 0.5;

// Direção ÚNICA do vento pra cena inteira (todas as árvores se inclinam na mesma direção)
uniform vec2 direcao_vento = vec2(1.0, 0.35);

// Rajada lenta e imponente (inclinação geral da árvore, a "onda" do vento)
uniform float velocidade_rajada : hint_range(0.1, 4.0) = 0.85;
uniform float forca_rajada : hint_range(0.0, 1.5) = 0.28;

// Tremor rápido e pequeno (folhas e galhos finos vibrando)
uniform float velocidade_flutter : hint_range(1.0, 20.0) = 7.5;
uniform float forca_flutter : hint_range(0.0, 0.5) = 0.04;

void vertex() {
	vec2 dir = normalize(direcao_vento);
	float altura = clamp(VERTEX.y * 0.45, 0.0, 3.0);

	// A fase viaja no espaço mundial ao longo da direção do vento:
	// A rajada de vento varre a fileira de árvores como uma onda real
	float fase = dot(NODE_POSITION_WORLD.xz, dir) * 0.12;

	// Rajada de corpo: inclina o topo da árvore na direção do vento
	float rajada = sin(TIME * velocidade_rajada + fase) * 0.5 + 0.5;
	vec2 inclinacao = dir * (rajada * forca_rajada * altura);

	// Flutter rápido nas pontas das folhas
	float flutter = sin(TIME * velocidade_flutter + NODE_POSITION_WORLD.x * 2.5 + VERTEX.y * 1.5) * forca_flutter * altura;
	vec2 tremor = dir * flutter;

	VERTEX.x += inclinacao.x + tremor.x;
	VERTEX.z += inclinacao.y + tremor.y;
	VERTEX.y -= (rajada * forca_rajada * altura) * 0.12; // Leve curvatura natural para baixo com o peso do vento
}

void fragment() {
	vec4 tex = texture(texture_albedo, UV);
	ALBEDO = tex.rgb;
	ALPHA = tex.a;
	ALPHA_SCISSOR_THRESHOLD = alpha_scissor_threshold;
	ROUGHNESS = 0.95;
}