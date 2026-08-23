shader_type sky;

// ===================================================================
// CÉU DE TEMPESTADE REALISTA 3D - HOMEM DE METAS (FEARS TO FATHOM)
// Nuvens correndo rápido no vento, tons escuros de tempestade (sem branco de dia)
// ===================================================================

// Cores do Céu de Fundo (17:50 - Crepúsculo Nublado)
uniform vec3 horizon_sky  : source_color = vec3(0.68, 0.28, 0.18);  // Âmbar/rosa crepuscular no horizonte
uniform vec3 mid_sky      : source_color = vec3(0.16, 0.12, 0.18);  // Cinza-chumbo no meio
uniform vec3 zenith_sky   : source_color = vec3(0.06, 0.06, 0.10);  // Céu chumbo profundo no topo

// Nuvens Volumosas Escuras de Tempestade (Sem nuvens brancas)
uniform vec3 cloud_light  : source_color = vec3(0.20, 0.17, 0.23);  // Cinza-chumbo tempestuoso (sem branco!)
uniform vec3 cloud_dark   : source_color = vec3(0.08, 0.07, 0.11);  // Base densa e escura da tempestade
uniform vec3 sunset_glow  : source_color = vec3(0.76, 0.35, 0.22);  // Realce sutil poente nas bordas baixas

uniform float cloud_speed   : hint_range(0.0, 0.1) = 0.032; // Nuvens correndo no vendaval
uniform float cloud_scale   : hint_range(0.5, 6.0) = 2.0;
uniform float cloud_density : hint_range(0.0, 1.0) = 0.85;

// Hash 3D
float hash3D(vec3 p) {
	p = fract(p * 0.3183099 + vec3(0.1, 0.1, 0.1));
	p *= 17.0;
	return fract(p.x * p.y * p.z * (p.x + p.y + p.z));
}

// Ruído 3D cúbico contínuo na esfera (Zero distorção, sem polo ou costura)
float noise3D(vec3 x) {
	vec3 i = floor(x);
	vec3 f = fract(x);
	f = f * f * (3.0 - 2.0 * f);

	return mix(
		mix(
			mix(hash3D(i + vec3(0.0, 0.0, 0.0)), hash3D(i + vec3(1.0, 0.0, 0.0)), f.x),
			mix(hash3D(i + vec3(0.0, 1.0, 0.0)), hash3D(i + vec3(1.0, 1.0, 0.0)), f.x),
			f.y
		),
		mix(
			mix(hash3D(i + vec3(0.0, 0.0, 1.0)), hash3D(i + vec3(1.0, 0.0, 1.0)), f.x),
			mix(hash3D(i + vec3(0.0, 1.0, 1.0)), hash3D(i + vec3(1.0, 1.0, 1.0)), f.x),
			f.y
		),
		f.z
	);
}

float fbm3D(vec3 p) {
	float v = 0.0;
	float a = 0.5;
	for (int i = 0; i < 4; i++) {
		v += a * noise3D(p);
		p = p * 2.08 + vec3(1.7, 3.2, 5.1);
		a *= 0.5;
	}
	return v;
}

void sky() {
	float y = clamp(EYEDIR.y, 0.0, 1.0);
	float above = step(-0.02, EYEDIR.y);

	// 1. Degradê de Fundo da Atmosfera Sombria
	vec3 sky_bg = mix(horizon_sky, mid_sky, smoothstep(0.0, 0.35, y));
	sky_bg = mix(sky_bg, zenith_sky, smoothstep(0.30, 0.85, y));

	// 2. Amostragem 3D com deslocamento rápido de vendaval
	vec3 p = EYEDIR * cloud_scale;
	vec3 wind = vec3(TIME * cloud_speed, 0.0, TIME * cloud_speed * 0.35);

	float n1 = fbm3D(p + wind);
	float n2 = fbm3D((p + wind * 1.25) * 1.9 + vec3(2.4, 0.8, 3.7));
	float cloud_shape = n1 * 0.65 + n2 * 0.35;

	// Cobertura de nuvens densa e pesada de tempestade
	float coverage = 0.30;
	float cloud_alpha = smoothstep(coverage, coverage + 0.32, cloud_shape) * cloud_density * above;

	// 3. Sombreamento Volumétrico Escuro de Tempestade
	float cloud_shading = smoothstep(coverage, coverage + 0.32, n1);
	vec3 cloud_col = mix(cloud_dark, cloud_light, cloud_shading);

	// 4. Realce Crepuscular sutil apenas no horizonte
	float horizon_factor = pow(clamp(1.0 - y * 1.6, 0.0, 1.0), 1.8);
	float rim = smoothstep(coverage, coverage + 0.15, cloud_shape) * (1.0 - smoothstep(coverage + 0.15, coverage + 0.35, cloud_shape));
	cloud_col = mix(cloud_col, sunset_glow, clamp(rim * 1.2 * horizon_factor + horizon_factor * 0.25, 0.0, 1.0));

	// 5. Composição Final
	vec3 final_color = mix(sky_bg, cloud_col, cloud_alpha);

	// Solo abaixo do horizonte
	vec3 ground_col = zenith_sky * 0.4;
	COLOR = mix(ground_col, final_color, above);
}