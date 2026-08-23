shader_type spatial;
render_mode blend_mix, depth_draw_opaque, cull_disabled, diffuse_lambert, specular_schlick_ggx;

uniform sampler2D texture_albedo : source_color, filter_nearest_mipmap;
uniform float alpha_scissor_threshold : hint_range(0.0, 1.0) = 0.5;

uniform float wind_speed : hint_range(0.0, 5.0) = 1.8;
uniform float wind_strength : hint_range(0.0, 1.0) = 0.15;
uniform float wind_turbulence : hint_range(0.0, 2.0) = 0.6;
uniform vec2 wind_direction = vec2(1.0, 0.4);

void vertex() {
	// Apenas vértices acima do chão balançam (máscara de altura)
	float height_factor = clamp(VERTEX.y * 0.35, 0.0, 1.0);
	
	vec2 dir = normalize(wind_direction);
	float wave1 = sin(TIME * wind_speed + VERTEX.x * 0.8 + VERTEX.y * 1.2);
	float wave2 = cos(TIME * (wind_speed * 1.4) + VERTEX.z * 1.1) * wind_turbulence;
	
	float total_sway = (wave1 + wave2) * wind_strength * height_factor;
	
	VERTEX.x += dir.x * total_sway;
	VERTEX.z += dir.y * total_sway;
}

void fragment() {
	vec4 albedo_tex = texture(texture_albedo, UV);
	ALBEDO = albedo_tex.rgb;
	ALPHA = albedo_tex.a;
	ALPHA_SCISSOR_THRESHOLD = alpha_scissor_threshold;
	ROUGHNESS = 0.9;
	SPECULAR = 0.1;
}