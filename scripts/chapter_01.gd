extends Node3D

# ============================================================
# CHAPTER 01: O HOMEM DE METAS -- CEFET-MG & A PERSEGUIÇÃO
# ============================================================

@onready var player: CharacterBody3D = get_node_or_null("PlayerController")
@onready var camera_mount: Node3D = get_node_or_null("PlayerController/CameraMount")
@onready var dialogue_ui: CanvasLayer = get_node_or_null("DialogueUI")
@onready var celular_ui: CanvasLayer = get_node_or_null("CelularUI")
@onready var audio_amb: AudioStreamPlayer = get_node_or_null("AudioAmbience")
@onready var audio_sfx: AudioStreamPlayer = get_node_or_null("AudioSFX")
@onready var world_env: WorldEnvironment = get_node_or_null("WorldEnvironment")
@onready var sun_light: DirectionalLight3D = get_node_or_null("SunLight")
var clima_manager: ClimaManager = null

# HUD Elements
@onready var hud: CanvasLayer = get_node_or_null("HUD")
@onready var objective_panel: Control = get_node_or_null("HUD/ObjectivePanel")
@onready var objective_label: Label = get_node_or_null("HUD/ObjectivePanel/ObjectiveLabel")
@onready var timecard_panel: Control = get_node_or_null("HUD/Timecard")
@onready var timecard_label: Label = get_node_or_null("HUD/Timecard/TimecardLabel")
@onready var interact_hint: Label = get_node_or_null("HUD/InteractHint")
@onready var memory_popup: PanelContainer = get_node_or_null("HUD/MemoryPopup")
@onready var memory_label: Label = get_node_or_null("HUD/MemoryPopup/MemoryLabel")
@onready var fade_rect: ColorRect = get_node_or_null("HUD/FadeRect")
@onready var fade_label: Label = get_node_or_null("HUD/FadeRect/FadeLabel")
@onready var flash_rect: ColorRect = get_node_or_null("HUD/FlashRect")

# State Machine Flags
var doc_pegou: bool = false
var doc_entregue: bool = false
var otavio_falou: bool = false
var pode_falar_atendente: bool = false
var matricula_feita: bool = false
var portao_aberto: bool = false
var elevador_chamado: bool = false
var stalker_sms_visto: bool = false
var quarto_trancado: bool = false
var is_paused: bool = false

func _ready() -> void:
	Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)
	_setup_pause_menu()
	
	# Garante que o som de vento e tempestade rode em loop infinito contínuo
	if audio_amb:
		if not audio_amb.playing:
			audio_amb.play()
		if not audio_amb.finished.is_connected(audio_amb.play):
			audio_amb.finished.connect(audio_amb.play)
	
	# Instancia o Gerenciador de Clima (Vento e Névoa)
	clima_manager = ClimaManager.new()
	add_child(clima_manager)
	
	# Aplica o shader de vento automaticamente em todas as 30+ árvores da cena
	_aplicar_vento_automatico_em_todas_arvores()
	
	# Transição inicial suave estilo fita VHS / Fears to Fathom
	if fade_rect:
		fade_rect.color = Color(0, 0, 0, 1)
		fade_rect.show()
		var tw := create_tween()
		tw.tween_property(fade_rect, "color:a", 0.0, 1.8).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
		tw.tween_callback(fade_rect.hide)
	
	# Início da Cena 1: CEFET Campus 1, Crepúsculo Ventoso (17:50)
	_show_timecard("CEFET-MG  -  CAMPUS 1", "17:50")
	_set_objective("Vá até o prédio administrativo\ne faça sua matrícula.")

func _setup_pause_menu() -> void:
	var pause_menu = get_node_or_null("HUD/PauseMenu")
	if not pause_menu:
		return
	pause_menu.hide()
	var btn_resume = get_node_or_null("HUD/PauseMenu/VCRBox/VBox/BtnResume")
	if btn_resume and not btn_resume.pressed.is_connected(_on_resume_pressed):
		btn_resume.pressed.connect(_on_resume_pressed)
	var btn_main_menu = get_node_or_null("HUD/PauseMenu/VCRBox/VBox/BtnMainMenu")
	if btn_main_menu and not btn_main_menu.pressed.is_connected(_on_main_menu_pressed):
		btn_main_menu.pressed.connect(_on_main_menu_pressed)

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		_toggle_pause()

func _toggle_pause() -> void:
	var pause_menu = get_node_or_null("HUD/PauseMenu")
	if not pause_menu:
		return
	is_paused = not is_paused
	pause_menu.visible = is_paused
	if is_paused:
		Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
	else:
		Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)

func _on_resume_pressed() -> void:
	_toggle_pause()

func _on_main_menu_pressed() -> void:
	Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
	get_tree().change_scene_to_file("res://scenes/ui/title_screen.tscn")

func _show_timecard(local_text: String, hora_text: String) -> void:
	if not timecard_panel: return
	if timecard_label:
		timecard_label.text = local_text + "\n" + hora_text
	timecard_panel.modulate.a = 1.0
	timecard_panel.show()
	var tween = create_tween()
	tween.tween_interval(5.0)
	tween.tween_property(timecard_panel, "modulate:a", 0.0, 1.5)
	tween.tween_callback(timecard_panel.hide)

func _set_objective(text: String) -> void:
	if not objective_panel: return
	if objective_label:
		objective_label.text = "OBJETIVO:\n" + text
	objective_panel.modulate.a = 0.0
	objective_panel.show()
	var tween = create_tween()
	tween.tween_property(objective_panel, "modulate:a", 1.0, 1.0)

func show_interact_hint(text: String) -> void:
	if not interact_hint: return
	interact_hint.text = text
	interact_hint.show()

func hide_interact_hint() -> void:
	if not interact_hint: return
	interact_hint.hide()

func _aplicar_vento_automatico_em_todas_arvores() -> void:
	var wind_shader = load("res://shaders/vento_arvore.gdshader") as Shader
	if not wind_shader:
		return
	
	var mesh_instances = find_children("*", "MeshInstance3D", true, false)
	for m in mesh_instances:
		var mi := m as MeshInstance3D
		var full_name = (mi.name + " " + mi.get_parent().name).to_lower()
		if "tree" in full_name or "arvore" in full_name or "palm" in full_name or "palmeira" in full_name or "bosquinho" in full_name or "folha" in full_name or "branch" in full_name or "commontree" in full_name or "bush" in full_name or "arbusto" in full_name or "vegetat" in full_name:
			var mat_count = mi.get_surface_override_material_count()
			if mat_count == 0 and mi.mesh:
				mat_count = mi.mesh.get_surface_count()
			
			for s in range(max(1, mat_count)):
				var active_mat = mi.get_active_material(s)
				var albedo_tex: Texture2D = null
				if active_mat is BaseMaterial3D and active_mat.albedo_texture:
					albedo_tex = active_mat.albedo_texture
				
				var sm := ShaderMaterial.new()
				sm.shader = wind_shader
				if albedo_tex:
					sm.set_shader_parameter("texture_albedo", albedo_tex)
				sm.set_shader_parameter("velocidade_vento", 3.2)
				sm.set_shader_parameter("forca_vento", 0.38)
				sm.set_shader_parameter("turbulencia", 0.5)
				
				mi.set_surface_override_material(s, sm)
				if clima_manager:
					clima_manager.tree_materials.append(sm)
