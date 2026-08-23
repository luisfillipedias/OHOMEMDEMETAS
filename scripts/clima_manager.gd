extends Node
class_name ClimaManager

# ============================================================
# CLIMA MANAGER -- Homem de Metas: Vento e Atmosfera Dinâmica
# ============================================================

@export var world_env: WorldEnvironment
var tree_materials: Array[ShaderMaterial] = []

var current_forca_vento: float = 0.38
var current_velocidade_vento: float = 3.2

func _ready() -> void:
	if not world_env:
		world_env = get_tree().current_scene.get_node_or_null("WorldEnvironment") as WorldEnvironment

## 1. Início: CEFET-MG Campus 1 (17:50) - Vento moderado e névoa silenciosa
func set_clima_inicio_cefet(duration: float = 2.0) -> void:
	_transicionar_vento(0.38, 3.2, duration)
	_transicionar_nevoa(0.018, Color(0.14, 0.12, 0.16, 1), duration)

## 2. Gatilho Pós-Auditório / Devolução do Documento: A tempestade se aproxima
func set_clima_tempestade_chuva(duration: float = 3.5) -> void:
	_transicionar_vento(0.48, 4.8, duration)
	_transicionar_nevoa(0.024, Color(0.12, 0.10, 0.14, 1), duration)

## 3. Gatilho Cena 2: Rua noturna deserta no Prado - Rajadas fortes de vendaval
func set_clima_rua_noite(duration: float = 2.5) -> void:
	_transicionar_vento(0.55, 6.0, duration)
	_transicionar_nevoa(0.022, Color(0.08, 0.07, 0.10, 1), duration)

func _transicionar_vento(forca_alvo: float, vel_alvo: float, duration: float) -> void:
	var tw = create_tween().set_parallel(true)
	tw.tween_method(_set_forca_vento, current_forca_vento, forca_alvo, duration).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	tw.tween_method(_set_velocidade_vento, current_velocidade_vento, vel_alvo, duration).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	current_forca_vento = forca_alvo
	current_velocidade_vento = vel_alvo

func _set_forca_vento(value: float) -> void:
	for mat in tree_materials:
		if is_instance_valid(mat):
			mat.set_shader_parameter("forca_vento", value)

func _set_velocidade_vento(value: float) -> void:
	for mat in tree_materials:
		if is_instance_valid(mat):
			mat.set_shader_parameter("velocidade_vento", value)

func _transicionar_nevoa(densidade_alvo: float, cor_alvo: Color, duration: float) -> void:
	if not world_env or not world_env.environment:
		return
	var env = world_env.environment
	var tw = create_tween().set_parallel(true)
	tw.tween_property(env, "fog_density", densidade_alvo, duration).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	tw.tween_property(env, "fog_light_color", cor_alvo, duration).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)