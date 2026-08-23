shader_type sky;

// Cores do ceu (17:50 - Tempestade crepuscular nebulosa, estilo Fears to Fathom / Silent Hill)
uniform vec3 horizon_color : source_color = vec3(0.78, 0.32, 0.22);  // Rosa/ambar crepuscular suave no horizonte
uniform vec3 mid_color     : source_color = vec3(0.24, 0.16, 0.22);  // Cinza-chumbo / lavanda tempestuoso no meio
uniform vec3 zenith_color  : source_color = vec3(0.11, 0.10, 0.15);  // Cinza-ardosia escuro no topo (sem buraco preto)

// Nuvens
uniform float cloud_speed : hint_range(0.0, 0.1) = 0.016;
uniform float cloud_scale : hint_range(0.5, 6.0) = 2.2;
uniform float cloud_density : hint_range(0.0, 1.0) = 0.82;
uniform vec3 cloud_body    : source_color = vec3(0.12, 0.10, 0.14);  // Corpo volumoso da nuvem (cinza tempestade)
uniform vec3 cloud_highlight : source_color = vec3(0.85, 0.40, 0.26); // Iluminacao suave do poente nas bordas

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
		p = rot * p * 2.05;
		a *= 0.5;
	}
	return v;
}

void sky() {
	float y = clamp(EYEDIR.y, 0.0, 1.0);
	float above = step(-0.02, EYEDIR.y);

	// 1. Degradê de fundo contínuo em todo o domo celeste (sem buraco preto no zênite)
	vec3 sky_bg = mix(horizon_color, mid_color, smoothstep(0.0, 0.35, y));
	sky_bg = mix(sky_bg, zenith_color, smoothstep(0.28, 0.85, y));

	// 2. Projeção uniforme em cúpula hemisférica completa (sem singularidade no zênite)
	vec2 sky_pos = EYEDIR.xz / (sqrt(y * y + 0.22));
	vec2 wind = vec2(TIME * cloud_speed, TIME * cloud_speed * 0.35);

	vec2 uv1 = sky_pos * cloud_scale * 0.65 + wind;
	vec2 uv2 = sky_pos * cloud_scale * 1.45 + wind * 1.35 + vec2(4.2, 1.9);

	float n1 = fbm(uv1);
	float n2 = fbm(uv2);
	float cloud_shape = mix(n1, n2, 0.40);

	// Cobertura homogênea das nuvens em 100% da esfera
	float coverage = 0.34;
	float cloud_alpha = smoothstep(coverage, coverage + 0.32, cloud_shape) * cloud_density * above;

	// Iluminação de poente apenas perto da borda do horizonte
	float rim = smoothstep(coverage, coverage + 0.12, cloud_shape) * (1.0 - smoothstep(coverage + 0.12, coverage + 0.32, cloud_shape));
	float sunset_fade = pow(clamp(1.0 - y * 1.3, 0.0, 1.0), 1.6);
	vec3 cloud_col = mix(cloud_body, cloud_highlight, clamp(rim * 1.2 * sunset_fade + sunset_fade * 0.3, 0.0, 1.0));

	// 3. Mistura final
	vec3 final_color = mix(sky_bg, cloud_col, cloud_alpha);

	// Abaixo do horizonte
	vec3 ground_col = zenith_color * 0.5;
	COLOR = mix(ground_col, final_color, above);
}