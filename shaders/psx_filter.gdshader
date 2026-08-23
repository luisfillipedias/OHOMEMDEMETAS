shader_type canvas_item;

uniform sampler2D screen_texture : hint_screen_texture, filter_nearest;
uniform float pixel_size : hint_range(1.0, 8.0) = 2.0;
uniform float scanline_strength : hint_range(0.0, 0.5) = 0.06;
uniform float aberration : hint_range(0.0, 0.01) = 0.002;
uniform float vignette_strength : hint_range(0.0, 1.0) = 0.35;
uniform float grain_strength : hint_range(0.0, 0.15) = 0.03;

float rand(vec2 co) {
    return fract(sin(dot(co, vec2(12.9898, 78.233))) * 43758.5453);
}

void fragment() {
    vec2 ps = SCREEN_PIXEL_SIZE * pixel_size;
    vec2 uv = floor(SCREEN_UV / ps) * ps;
    
    vec2 ab_offset = (SCREEN_UV - 0.5) * aberration;
    float r = texture(screen_texture, uv + ab_offset).r;
    float g = texture(screen_texture, uv).g;
    float b = texture(screen_texture, uv - ab_offset).b;
    
    vec3 col = vec3(r, g, b);
    
    // Scanline sutil
    float scanline = sin(SCREEN_UV.y * 380.0) * 0.5 + 0.5;
    col *= 1.0 - scanline_strength * (1.0 - scanline);
    
    // Granulado analógico
    float noise = rand(SCREEN_UV + vec2(TIME * 0.05, TIME * 0.03)) * 2.0 - 1.0;
    col += noise * grain_strength;
    
    // Vignette nas bordas
    vec2 vig = SCREEN_UV * (1.0 - SCREEN_UV.yx);
    float vignette = clamp(pow(vig.x * vig.y * 15.0, vignette_strength), 0.0, 1.0);
    col *= vignette;
    
    COLOR = vec4(col, 1.0);
}
