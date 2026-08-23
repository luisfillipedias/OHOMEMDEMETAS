shader_type sky;

// ===================================================================
// CÉU DE TEMPESTADE REALISTA 3D - HOMEM DE METAS (FEARS TO FATHOM)
// Zero distorção polar, Zero buraco no zênite, Nuvens volumosas 100% visíveis
// ===================================================================

// Cores do Céu de Fundo (17:50 - Crepúsculo Nublado)
uniform vec3 horizon_sky  : source_color = vec3(0.72, 0.30, 0.20);  // Rosa/âmbar poeirento no horizonte
uniform vec3 mid_sky      : source_color = vec3(0.20, 0.15, 0.22);  // Cinza-chumbo no meio
uniform vec3 zenith_sky   : source_color = vec3(0.08, 0.08, 0.13);  // Azul-ardósia crepuscular escuro no topo

// Nuvens Volumosas (Visíveis e contrastadas em todo o céu, inclusive no topo)
uniform vec3 cloud_light  : source_color = vec3(0.38, 0.35, 0.42);  // Iluminação superior da nuvem (cinza-claro volumoso)
uniform vec3 cloud_dark   : source_color = vec3(0.12, 0.10, 0.15);  // Base escura e densa da nuvem de tempestade
uniform vec3 sunset_glow  : source_color = vec3(0.88, 0.42, 0.24);  // Realce quente nas nuvens baixas do horizonte

uniform float cloud_speed   : hint_range(0.0, 0.1) = 0.016;
uniform float cloud_scale   : hint_range(0.5, 6.0) = 2.2;
uniform float cloud_density : hint_range(0.0, 1.0) = 0.82;

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

	// 1. Degradê de Fundo da Atmosfera
	vec3 sky_bg = mix(horizon_sky, mid_sky, smoothstep(0.0, 0.35, y));
	sky_bg = mix(sky_bg, zenith_sky, smoothstep(0.30, 0.85, y));

	// 2. Amostragem 3D DIRETA no vetor esférico da câmera (EYEDIR)
	vec3 p = EYEDIR * cloud_scale;
	vec3 wind = vec3(TIME * cloud_speed, 0.0, TIME * cloud_speed * 0.4);

	float n1 = fbm3D(p + wind);
	float n2 = fbm3D((p + wind * 1.25) * 1.9 + vec3(2.4, 0.8, 3.7));
	float cloud_shape = n1 * 0.65 + n2 * 0.35;

	// Cobertura de nuvens densa e volumosa em todo o domo (inclusive no zênite)
	float coverage = 0.32;
	float cloud_alpha = smoothstep(coverage, coverage + 0.32, cloud_shape) * cloud_density * above;

	// 3. Iluminação Volumétrica Bidirecional (Garante relevo e contraste no topo do céu)
	// As partes mais espessas/altas da nuvem ficam claras (cloud_light), as bases ficam escuras (cloud_dark)
	float cloud_shading = smoothstep(coverage, coverage + 0.35, n1);
	vec3 cloud_col = mix(cloud_dark, cloud_light, cloud_shading);

	// 4. Realce de Pôr do Sol/Crepúsculo apenas próximo ao horizonte
	float horizon_factor = pow(clamp(1.0 - y * 1.5, 0.0, 1.0), 1.8);
	float rim = smoothstep(coverage, coverage + 0.15, cloud_shape) * (1.0 - smoothstep(coverage + 0.15, coverage + 0.35, cloud_shape));
	cloud_col = mix(cloud_col, sunset_glow, clamp(rim * 1.4 * horizon_factor + horizon_factor * 0.35, 0.0, 1.0));

	// 5. Composição Final
	vec3 final_color = mix(sky_bg, cloud_col, cloud_alpha);

	// Solo abaixo do horizonte
	vec3 ground_col = zenith_sky * 0.4;
	COLOR = mix(ground_col, final_color, above);
}