shader_type sky;

// Cores do ceu (17:50 - Tempestade ao entardecer, estilo Silent Hill / Fears to Fathom)
uniform vec3 horizon_color : source_color = vec3(0.82, 0.34, 0.22);  // Rosa/ambar crepuscular suave no horizonte
uniform vec3 mid_color     : source_color = vec3(0.26, 0.17, 0.22);  // Lavanda/cinza-chumbo tempestuoso no meio
uniform vec3 zenith_color  : source_color = vec3(0.11, 0.10, 0.15);  // Cinza-ardosia escuro no topo (sem buraco preto)

// Nuvens
uniform float cloud_speed : hint_range(0.0, 0.1) = 0.018;
uniform float cloud_scale : hint_range(0.5, 6.0) = 2.5;
uniform float cloud_density : hint_range(0.0, 1.0) = 0.80;
uniform vec3 cloud_body    : source_color = vec3(0.13, 0.11, 0.15);  // Corpo volumoso da nuvem (cinza tempestade)
uniform vec3 cloud_highlight : source_color = vec3(0.88, 0.42, 0.26); // Iluminacao suave do poente nas bordas

const float PI_VAL = 3.14159265359;

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

	// 1. Degradê de fundo contínuo em todo o domo (sem buraco preto no zênite)
	vec3 sky_bg = mix(horizon_color, mid_color, smoothstep(0.0, 0.35, y));
	sky_bg = mix(sky_bg, zenith_color, smoothstep(0.30, 0.85, y));

	// 2. Projeção uniforme em 3D (elimina a singularidade e o buraco no topo)
	// Projeta o vetor de visão em uma cúpula plana infinita com altura suave
	vec2 sky_pos = EYEDIR.xz / (sqrt(y * y + 0.18));
	vec2 wind = vec2(TIME * cloud_speed, TIME * cloud_speed * 0.35);

	vec2 uv1 = sky_pos * cloud_scale * 0.7 + wind;
	vec2 uv2 = sky_pos * cloud_scale * 1.5 + wind * 1.4 + vec2(5.2, 1.7);

	float n1 = fbm(uv1);
	float n2 = fbm(uv2);
	float cloud_shape = mix(n1, n2, 0.40);

	// Cobertura homogênea em todo o céu
	float coverage = 0.35;
	float cloud_alpha = smoothstep(coverage, coverage + 0.30, cloud_shape) * cloud_density * above;

	// Iluminação das nuvens (poente suave no horizonte, textura cinza-escura no topo)
	float rim = smoothstep(coverage, coverage + 0.12, cloud_shape) * (1.0 - smoothstep(coverage + 0.12, coverage + 0.32, cloud_shape));
	float sunset_fade = pow(clamp(1.0 - y * 1.2, 0.0, 1.0), 1.5);
	vec3 cloud_col = mix(cloud_body, cloud_highlight, clamp(rim * 1.2 * sunset_fade + sunset_fade * 0.3, 0.0, 1.0));

	// 3. Mistura final: o céu inteiro possui nuvens e transições suaves
	vec3 final_color = mix(sky_bg, cloud_col, cloud_alpha);

	// Abaixo do horizonte
	vec3 ground_col = zenith_color * 0.5;
	COLOR = mix(ground_col, final_color, above);
}