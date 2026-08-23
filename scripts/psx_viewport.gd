extends SubViewportContainer

# ─── Filtro PSX ─────────────────────────────────────────────
# Este nó envolve o SubViewport e aplica o shader PSX em cima.
# É instanciado como filho do nó raiz (após o WorldEnvironment).
# Não interfere com a câmera do player, só com o render final.

@onready var viewport = $SubViewport

func _ready() -> void:
	# Garantir que o SubViewport tem a resolução pixelizada
	var base_size = DisplayServer.window_get_size()
	viewport.size = Vector2i(int(base_size.x / 3), int(base_size.y / 3))
	stretch = true
	stretch_shrink = 3
	
	# Aplicar shader PSX ao container
	var mat = ShaderMaterial.new()
	var shader = load("res://shaders/psx_filter.gdshader")
	if shader:
		mat.shader = shader
		mat.set_shader_parameter("pixel_size", 3.0)
		mat.set_shader_parameter("scanline_strength", 0.08)
		mat.set_shader_parameter("aberration", 0.002)
		mat.set_shader_parameter("vignette_strength", 0.4)
		mat.set_shader_parameter("grain_strength", 0.035)
		mat.set_shader_parameter("saturation", 0.82)
		material = mat
