shader_type sky;

uniform vec3 color_horizon : source_color = vec3(0.85, 0.22, 0.10);
uniform vec3 color_mid : source_color = vec3(0.30, 0.10, 0.18);
uniform vec3 color_top : source_color = vec3(0.05, 0.04, 0.09);

uniform float cloud_speed : hint_range(0.0, 0.2) = 0.020;
uniform float cloud_density : hint_range(0.0, 1.0) = 0.60;
uniform float cloud_coverage : hint_range(0.0, 1.0) = 0.68;
uniform vec3 cloud_color_lit : source_color = vec3(0.90, 0.38, 0.22);
uniform vec3 cloud_color_shadow : source_color = vec3(0.05, 0.03, 0.07);

float hash(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

float noise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	float a = hash(i);
	float b = hash(i + vec2(1.0, 0.0));
	float c = hash(i + vec2(0.0, 1.0));
	float d = hash(i + vec2(1.0, 1.0));
	vec2 u = f * f * (3.0 - 2.0 * f);
	return mix(a, b, u.x) + (c - a) * u.y * (1.0 - u.x) + (d - b) * u.x * u.y;
}

float fbm(vec2 p) {
	float value = 0.0;
	float amp = 0.5;
	for (int i = 0; i < 5; i++) {
		value += amp * noise(p);
		p *= 2.02;
		amp *= 0.5;
	}
	return value;
}

void sky() {
	float t = clamp(EYEDIR.y, 0.0, 1.0);

	// Gradiente vertical: horizonte vermelho -> meio vinaceo -> topo quase preto
	vec3 grad = mix(color_horizon, color_mid, smoothstep(0.0, 0.35, t));
	grad = mix(grad, color_top, smoothstep(0.25, 1.0, t));

	// Nuvens so no hemisferio superior (sem return, usa mix)
	float above = step(0.0, EYEDIR.y);

	vec2 cloud_uv = EYEDIR.xz / max(EYEDIR.y + 0.15, 0.05);
	cloud_uv *= 0.55;
	cloud_uv += vec2(TIME * cloud_speed, TIME * cloud_speed * 0.38);

	float clouds = fbm(cloud_uv * 3.0);
	clouds = smoothstep(1.0 - cloud_coverage, 1.0, clouds) * above;

	vec3 cloud_col = mix(cloud_color_shadow, cloud_color_lit, clamp(1.0 - t * 1.2, 0.0, 1.0));
	vec3 sky_color = mix(grad, cloud_col, clouds * cloud_density * (1.0 - t * 0.55));

	// Abaixo do horizonte: terra escura
	vec3 below_col = color_top * 0.3;
	COLOR = mix(below_col, sky_color, above);
}