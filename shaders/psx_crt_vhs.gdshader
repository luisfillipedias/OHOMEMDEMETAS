shader_type canvas_item;

// ============================================================
// PSX / CRT / VHS RETRO SHADER -- Fears to Fathom Style
// ============================================================

uniform sampler2D screen_texture : hint_screen_texture, filter_linear_mipmap;
uniform float pixel_size : hint_range(1.0, 6.0) = 1.6;
uniform float scanline_strength : hint_range(0.0, 0.4) = 0.08;
uniform float aberration : hint_range(0.0, 0.008) = 0.0012;
uniform float vignette_strength : hint_range(0.0, 1.0) = 0.42;
uniform float grain_strength : hint_range(0.0, 0.1) = 0.035;
uniform float curvature : hint_range(0.0, 0.1) = 0.018;
uniform float corner_radius : hint_range(0.0, 0.2) = 0.035;
uniform float dither_depth : hint_range(8.0, 64.0) = 32.0;

vec2 curve_uv(vec2 uv) {
	vec2 delta = uv - 0.5;
	float dist_sq = dot(delta, delta);
	return uv + delta * (dist_sq * curvature);
}

float rand(vec2 co) {
	return fract(sin(dot(co, vec2(12.9898, 78.233))) * 43758.5453);
}

const mat4 bayer4x4 = mat4(
	vec4( 0.0,  8.0,  2.0, 10.0),
	vec4(12.0,  4.0, 14.0,  6.0),
	vec4( 3.0, 11.0,  1.0,  9.0),
	vec4(15.0,  7.0, 13.0,  5.0)
) / 16.0;

void fragment() {
	vec2 curved = curve_uv(SCREEN_UV);
	
	vec2 corner_dist = max(abs(curved - 0.5) - (0.5 - corner_radius), 0.0);
	float corner_factor = length(corner_dist);
	if (curved.x < 0.0 || curved.x > 1.0 || curved.y < 0.0 || curved.y > 1.0 || corner_factor > corner_radius) {
		COLOR = vec4(0.015, 0.015, 0.02, 1.0);
	} else {
		vec2 ps = SCREEN_PIXEL_SIZE * pixel_size;
		vec2 uv = floor(curved / ps) * ps;
		
		float dist_from_center = length(curved - 0.5);
		vec2 ab_offset = (curved - 0.5) * (aberration * dist_from_center * 2.0);
		
		float r = texture(screen_texture, uv + ab_offset).r;
		float g = texture(screen_texture, uv).g;
		float b = texture(screen_texture, uv - ab_offset).b;
		vec3 col = vec3(r, g, b);
		
		ivec2 dither_pos = ivec2(mod(FRAGCOORD.xy, 4.0));
		float dither_val = (bayer4x4[dither_pos.x][dither_pos.y] - 0.5) / dither_depth;
		col = floor((col + dither_val) * dither_depth) / dither_depth;
		
		float scanline = sin(curved.y * 360.0) * 0.5 + 0.5;
		col *= 1.0 - scanline_strength * (1.0 - scanline);
		
		float noise = rand(curved + vec2(TIME * 0.06, TIME * 0.03)) * 2.0 - 1.0;
		col += noise * grain_strength;
		
		vec2 vig = curved * (1.0 - curved.yx);
		float vignette = clamp(pow(vig.x * vig.y * 14.0, vignette_strength), 0.0, 1.0);
		col *= vignette;
		
		COLOR = vec4(col, 1.0);
	}
}