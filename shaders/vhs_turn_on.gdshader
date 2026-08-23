shader_type canvas_item;

uniform float turn_on_progress : hint_range(0.0, 1.0) = 1.0;
uniform float static_noise_intensity : hint_range(0.0, 1.0) = 1.0;

float rand(vec2 co) {
	return fract(sin(dot(co, vec2(12.9898, 78.233))) * 43758.5453);
}

void fragment() {
	vec2 uv = UV;

	if (turn_on_progress < 0.001) {
		// Tela completamente preta antes de ligar
		COLOR = vec4(0.0, 0.0, 0.0, 1.0);
	} else if (turn_on_progress < 0.35) {
		// Fase 1: Tubo CRT abrindo - feixe horizontal de luz
		float p = turn_on_progress / 0.35;
		float open_y = clamp(p * p * 1.4, 0.002, 1.0);
		float open_x = clamp(p * 2.5, 0.05, 1.0);
		float dist_y = abs(uv.y - 0.5);
		float dist_x = abs(uv.x - 0.5);

		if (dist_x > open_x * 0.5 || dist_y > open_y * 0.5) {
			COLOR = vec4(0.0, 0.0, 0.0, 1.0);
		} else {
			float line_glow = 1.0 - smoothstep(0.0, open_y * 0.5, dist_y);
			float noise = rand(uv + vec2(TIME * 20.0, TIME * 10.0));
			vec3 beam_col = mix(vec3(0.1, 0.3, 0.8), vec3(1.0, 1.0, 1.0), line_glow) * (0.8 + 0.4 * noise);
			COLOR = vec4(beam_col, 1.0);
		}
	} else {
		// Fase 2: Estática VHS estabilizando
		float p2 = (turn_on_progress - 0.35) / 0.65;
		float static_fade = 1.0 - p2;

		float tracking_bar = sin(uv.y * 8.0 - TIME * 12.0);
		float bar_mask = smoothstep(0.7, 0.95, tracking_bar) * static_fade;

		float n = rand(vec2(floor(uv.x * 240.0), floor(uv.y * 180.0) + TIME * 30.0));
		vec3 static_col = vec3(n * 0.9, n * 0.85, n);

		if (bar_mask > 0.3) {
			static_col += vec3(0.2, 0.2, 0.4);
		}

		float alpha = clamp(static_fade * static_noise_intensity * 0.95, 0.0, 1.0);
		COLOR = vec4(static_col, alpha);
	}
}