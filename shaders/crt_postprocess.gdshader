shader_type canvas_item;

uniform float scanline_intensity : hint_range(0.0, 1.0) = 0.15;
uniform float grain_intensity : hint_range(0.0, 1.0) = 0.08;
uniform float aberration_strength : hint_range(0.0, 0.02) = 0.004;
uniform float vignette_strength : hint_range(0.0, 3.0) = 1.2;
uniform float vignette_softness : hint_range(0.0, 1.0) = 0.45;
uniform float brightness : hint_range(0.0, 2.0) = 0.95;
uniform float contrast : hint_range(0.0, 2.0) = 1.05;
uniform float saturation : hint_range(0.0, 2.0) = 0.9;
uniform float time_val = 0.0;
uniform float pixel_size : hint_range(1.0, 8.0) = 2.0;

uniform sampler2D SCREEN_TEXTURE : hint_screen_texture, filter_linear_mipmap;

float rand(vec2 co) {
	return fract(sin(dot(co.xy, vec2(12.9898, 78.233))) * 43758.5453);
}

void fragment() {
	vec2 uv = SCREEN_UV;

	// Aberração cromática
	float r = texture(SCREEN_TEXTURE, uv + vec2(aberration_strength, 0.0)).r;
	float g = texture(SCREEN_TEXTURE, uv).g;
	float b = texture(SCREEN_TEXTURE, uv - vec2(aberration_strength, 0.0)).b;
	vec4 col = vec4(r, g, b, 1.0);

	// Scanlines
	float scanline = sin(uv.y * 800.0) * 0.5 + 0.5;
	col.rgb -= scanline * scanline_intensity;

	// Grain
	float noise = rand(uv + fract(time_val * 0.1));
	col.rgb += (noise - 0.5) * grain_intensity;

	// Brightness / contrast / saturation
	col.rgb = (col.rgb - 0.5) * contrast + 0.5;
	col.rgb *= brightness;
	float lum = dot(col.rgb, vec3(0.299, 0.587, 0.114));
	col.rgb = mix(vec3(lum), col.rgb, saturation);

	// Vignette
	vec2 vig_uv = uv * (1.0 - uv.yx);
	float vig = vig_uv.x * vig_uv.y * 15.0;
	vig = pow(vig, vignette_softness);
	col.rgb *= mix(1.0 - vignette_strength * 0.5, 1.0, vig);

	COLOR = col;
}
