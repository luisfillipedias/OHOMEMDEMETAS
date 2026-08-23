shader_type canvas_item;

uniform sampler2D screen_texture : hint_screen_texture, filter_linear;
uniform float scanline_strength : hint_range(0.0, 0.3) = 0.04;
uniform float grain_strength : hint_range(0.0, 0.1) = 0.018;
uniform float vignette_strength : hint_range(0.0, 1.0) = 0.30;
uniform float curvature : hint_range(0.0, 0.1) = 0.012;
uniform float corner_radius : hint_range(0.0, 0.2) = 0.03;

vec2 curve_uv(vec2 uv) {
	vec2 delta = uv - 0.5;
	float dist_sq = dot(delta, delta);
	return uv + delta * (dist_sq * curvature);
}

float rand(vec2 co) {
	return fract(sin(dot(co, vec2(12.9898, 78.233))) * 43758.5453);
}

void fragment() {
	vec2 curved = curve_uv(SCREEN_UV);
	
	vec2 corner_dist = max(abs(curved - 0.5) - (0.5 - corner_radius), 0.0);
	float corner_factor = length(corner_dist);
	if (curved.x < 0.0 || curved.x > 1.0 || curved.y < 0.0 || curved.y > 1.0 || corner_factor > corner_radius) {
		COLOR = vec4(0.01, 0.01, 0.015, 1.0);
	} else {
		vec3 col = texture(screen_texture, curved).rgb;
		
		// Scanlines suaves
		float scanline = sin(curved.y * 420.0) * 0.5 + 0.5;
		col *= 1.0 - scanline_strength * (1.0 - scanline);
		
		// Granulado sutil de fita VHS
		float noise = rand(curved + vec2(TIME * 0.05, TIME * 0.02)) * 2.0 - 1.0;
		col += noise * grain_strength;
		
		// Vinheta suave nas bordas
		vec2 vig = curved * (1.0 - curved.yx);
		float vignette = clamp(pow(vig.x * vig.y * 15.0, vignette_strength), 0.0, 1.0);
		col *= vignette;
		
		COLOR = vec4(col, 1.0);
	}
}