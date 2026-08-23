shader_type spatial;
render_mode unshaded, cull_back, depth_draw_always;

// ============================================================
// SHADER PSX — Homem De Metas
// Vertex snapping + affine texture mapping = look PS1 autêntico
// ============================================================

uniform sampler2D texture_albedo : source_color, filter_nearest, repeat_enable;
uniform float snap_resolution : hint_range(1.0, 512.0) = 128.0;
uniform float affine_intensity : hint_range(0.0, 1.0) = 0.8;
uniform vec4 modulate_color : source_color = vec4(1.0, 1.0, 1.0, 1.0);
uniform float fog_density : hint_range(0.0, 1.0) = 0.15;
uniform vec4 fog_color : source_color = vec4(0.05, 0.03, 0.08, 1.0);

varying vec3 vertex_world;
varying float affine_w;
varying vec2 affine_uv;

void vertex() {
	// === Vertex Snapping (wobble característico do PS1) ===
	vec4 snap_pos = PROJECTION_MATRIX * MODELVIEW_MATRIX * vec4(VERTEX, 1.0);
	snap_pos.xyz = snap_pos.xyz / snap_pos.w;
	snap_pos.xy = floor(snap_pos.xy * snap_resolution) / snap_resolution;
	snap_pos.xyz *= snap_pos.w;
	POSITION = snap_pos;

	// === Affine Texture Mapping (textura "nadando") ===
	affine_w = POSITION.w;
	affine_uv = UV * POSITION.w;

	vertex_world = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

void fragment() {
	// Affine UV
	vec2 uv = mix(UV, affine_uv / affine_w, affine_intensity);
	vec4 tex = texture(texture_albedo, uv);

	// Fog baseado em distância
	float dist = length(VERTEX);
	float fog_factor = clamp(dist * fog_density * 0.1, 0.0, 1.0);

	vec4 final_color = mix(tex * modulate_color, fog_color, fog_factor);
	ALBEDO = final_color.rgb;
	ALPHA = final_color.a;
}
