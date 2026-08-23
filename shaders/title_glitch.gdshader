shader_type canvas_item;

uniform vec4 text_color : source_color = vec4(0.85, 0.08, 0.08, 1.0);

// Chromatic split
uniform float chroma_split : hint_range(0.0, 0.02) = 0.004;

// Ruído fino sobre a própria letra
uniform float grain_amount : hint_range(0.0, 1.0) = 0.35;

// Deslocamento por linha fina
uniform float glitch_amount : hint_range(0.0, 0.03) = 0.01;
uniform float scanline_density : hint_range(100.0, 800.0) = 400.0;
uniform float glitch_speed : hint_range(1.0, 20.0) = 10.0;

// Glitch em BLOCO
uniform float block_glitch_chance : hint_range(0.0, 1.0) = 0.06;
uniform float block_glitch_strength : hint_range(0.0, 0.1) = 0.035;

// Flicker geral de brilho
uniform float flicker_amount : hint_range(0.0, 0.5) = 0.15;

float rand(vec2 co) {
	return fract(sin(dot(co, vec2(12.9898, 78.233))) * 43758.5453);
}

void fragment() {
	vec2 uv = UV;
	float time_step = floor(TIME * glitch_speed);

	// ---- 1) Glitch em bloco ----
	float block_id = floor(uv.y * 8.0);
	float block_time = floor(TIME * (glitch_speed * 0.5));
	float block_noise = rand(vec2(block_id, block_time));
	float block_shift = 0.0;
	if (block_noise > (1.0 - block_glitch_chance)) {
		block_shift = (rand(vec2(block_time, block_id * 3.1)) - 0.5) * block_glitch_strength;
	}
	uv.x += block_shift;

	// ---- 2) Jitter fino por linha ----
	float line_id = floor(uv.y * 60.0);
	float noise = rand(vec2(line_id, time_step));
	float shift = 0.0;
	if (noise > 0.78) {
		shift = (rand(vec2(time_step, line_id)) - 0.5) * glitch_amount;
	}

	// ---- 3) Chromatic aberration ----
	float split = chroma_split * (0.6 + 0.4 * rand(vec2(time_step, 91.0)));
	float a_r = texture(TEXTURE, uv - vec2(shift * 1.5 + split, 0.0)).a;
	float a_g = texture(TEXTURE, uv - vec2(shift, 0.0)).a;
	float a_b = texture(TEXTURE, uv + vec2(shift * 1.2 - split, 0.0)).a;

	float a_bleed_l = texture(TEXTURE, uv - vec2(shift * 2.0, 0.0)).a;
	float a_bleed_r = texture(TEXTURE, uv + vec2(shift * 1.8, 0.0)).a;

	float alpha_center = a_g;
	float final_alpha = max(alpha_center, max(a_bleed_l * 0.5, a_bleed_r * 0.7));

	// ---- 4) Grão/estática por cima da própria letra ----
	float grain = rand(uv * vec2(400.0, 400.0) + TIME * 37.0);
	float grain_mask = mix(1.0, grain, grain_amount * 0.5);

	// ---- 5) Scanlines CRT ----
	float scanline = sin(uv.y * scanline_density) * 0.12 + 0.88;

	// ---- 6) Flicker geral ----
	float flicker = 1.0 - flicker_amount * rand(vec2(time_step * 0.5, 5.0));

	// ---- 7) Cor final (Ajustada para fechar no vermelho puro) ----
	vec3 col;
	col.r = text_color.r * max(a_g, a_r * 1.1); // Reforça o vermelho sem clarear
	col.g = text_color.g * a_g * 0.05;         // Minimiza canal verde
	col.b = text_color.b * a_b * 0.02;         // Remove adição de azul/ciano que causava o tom rosa

	col *= scanline * flicker * grain_mask;

	COLOR = vec4(col, final_alpha * text_color.a);
}