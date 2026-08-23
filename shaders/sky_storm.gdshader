shader_type sky;

// Cores da tempestade ao entardecer (17:50 - Estilo Silent Hill / Fears to Fathom)
// Paleta: Horizonte rosa-acinzentado/crepúsculo -> Meio ardósia/vinho enevoado -> Zênite cinza-chumbo/índigo
uniform vec3 horizon_color : source_color = vec3(0.78, 0.28, 0.20);  // Rosa-queimado / crepúsculo suave no horizonte
uniform vec3 mid_color     : source_color = vec3(0.24, 0.15, 0.22);  // Cinza-ardósia / vinho enevoado
uniform vec3 upper_color   : source_color = vec3(0.14, 0.11, 0.16);  // Chumbo tempestuoso
uniform vec3 zenith_color  : source_color = vec3(0.09, 0.08, 0.12);  // Índigo escuro / noite no topo (NÃO preto puro)

// Nuvens de tempestade densas e volumosas
uniform float cloud_speed   : hint_range(0.0, 0.1) = 0.020;
uniform float cloud_scale   : hint_range(0.5, 6.0) = 1.6;
uniform float cloud_density : hint_range(0.0, 1.0) = 0.85;
uniform vec3 cloud_dark     : source_color = vec3(0.12, 0.10, 0.14);  // Corpo volumoso da nuvem (cinza-chumbo)
uniform vec3 cloud_lit      : source_color = vec3(0.82, 0.38, 0.25);  // Bordas iluminadas pelo crepúsculo suave

float hash(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453123);
}

float noise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	vec2 u = f * f * (3.0 - 2.0 * f);
	float a = hash(i);
	float b = hash(i + vec2(1.0, 0.0));
	float c = hash(i + vec2(0.0, 1.0));
	float d = hash(i + vec2(1.0, 1.0));
	return mix(mix(a, b, u.x), mix(c, d, u.x), u.y);
}

float fbm(vec2 p) {
	float v = 0.0;
	float a = 0.5;
	mat2 rot = mat2(vec2(0.8, 0.6), vec2(-0.6, 0.8));
	for (int i = 0; i < 5; i++) {
		v += a * noise(p);
		p = rot * p * 2.08;
		a *= 0.5;
	}
	return v;
}

void sky() {
	float y = clamp(EYEDIR.y, 0.0, 1.0);
	float above = step(-0.02, EYEDIR.y);

	// 1. Degradê de fundo suave e enevoado (sem buraco preto no topo)
	vec3 sky_bg = mix(horizon_color, mid_color, smoothstep(0.0, 0.25, y));
	sky_bg = mix(sky_bg, upper_color, smoothstep(0.20, 0.60, y));
	sky_bg = mix(sky_bg, zenith_color, smoothstep(0.55, 1.0, y));

	// 2. Coordenadas esféricas estáveis para o domo inteiro de nuvens
	vec2 uv = EYEDIR.xz / (y + 0.40) * cloud_scale;
	vec2 wind = vec2(TIME * cloud_speed, TIME * cloud_speed * 0.35);

	// 3. Multi-camada de nuvens tempestuosas densas
	float n_base = fbm(uv + wind);
	float n_detail = fbm((uv + wind * 1.3) * 2.1 + vec2(4.2, 8.1));
	float cloud_val = n_base * 0.62 + n_detail * 0.38;

	// Cobertura pesada de tempestade
	float coverage_threshold = 0.32;
	float cloud_alpha = smoothstep(coverage_threshold, coverage_threshold + 0.36, cloud_val) * cloud_density;
	cloud_alpha *= above;

	// 4. Iluminação nas fendas e bordas inferiores das nuvens
	float edge_rim = smoothstep(coverage_threshold, coverage_threshold + 0.12, cloud_val) * (1.0 - smoothstep(coverage_threshold + 0.12, coverage_threshold + 0.34, cloud_val));
	float twilight_influence = pow(clamp(1.0 - y * 1.4, 0.0, 1.0), 1.2);
	vec3 cloud_color = mix(cloud_dark, cloud_lit, clamp(edge_rim * 1.3 * twilight_influence + twilight_influence * 0.22, 0.0, 1.0));

	// 5. Composição final
	vec3 final_sky = mix(sky_bg, cloud_color, cloud_alpha);

	// Abaixo do horizonte: terra escura
	vec3 ground_col = zenith_color * 0.5;
	COLOR = mix(ground_col, final_sky, above);
}