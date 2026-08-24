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

var pause_menu_control: Control = null
var audio_wind_extra: AudioStreamPlayer = null
var font_retro: Font = null
var _objective_typing_token: int = 0

# Referências para Rajadas Dinâmicas de Vento
var _tree_materials: Array[ShaderMaterial] = []
var _wind_leaves_mat: ParticleProcessMaterial = null

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	add_to_group("chapter")
	Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)
	
	# Auto-salva ao entrar no capítulo 1 para habilitar o botão CONTINUAR no menu
	if GameManager:
		GameManager.set_flag("chapter_progress", 1)
		GameManager.current_chapter = 1
		GameManager.save_game()
	
	if ResourceLoader.exists("res://assets/fonts/text_font.ttf"):
		font_retro = load("res://assets/fonts/text_font.ttf") as Font
	
	_setup_hud_styling()
	_setup_pause_menu()
	
	# Som de vento e tempestade contínuo em loop
	if audio_amb:
		if not audio_amb.playing:
			audio_amb.play()
		if not audio_amb.finished.is_connected(audio_amb.play):
			audio_amb.finished.connect(audio_amb.play)
	
	# Gerenciador de Clima
	clima_manager = ClimaManager.new()
	add_child(clima_manager)
	
	# Áudio de vento direcional e partículas (folhas + poeira de chão)
	_setup_extra_wind_audio()
	_setup_wind_particles()
	
	# Aplica shader de vento nas árvores
	_aplicar_vento_automatico_em_todas_arvores()
	
	# Inicia sistema de rajadas dinâmicas ocasionais de vento
	_start_dynamic_wind_system()
	
	# Boot VHS
	_play_vhs_intro_sequence()

# ============================================================
# ESTILIZAÇÃO E CALIBRAÇÃO DINÂMICA DO HUD (VHS OSD)
# ============================================================

func _setup_hud_styling() -> void:
	if not hud:
		return
	
	# 1. Configura Timecard (Canto inferior esquerdo, tamanho 22, cor limpa e sombra)
	if timecard_panel:
		timecard_panel.set_anchors_preset(Control.PRESET_BOTTOM_LEFT)
		timecard_panel.offset_left = 36.0
		timecard_panel.offset_top = -110.0
		timecard_panel.offset_right = 550.0
		timecard_panel.offset_bottom = -28.0
		timecard_panel.modulate.a = 0.0
		timecard_panel.hide()
	if timecard_label:
		timecard_label.text = "CEFET-MG  -  CAMPUS 1\n17:52 - 10/01/2024"
		if font_retro:
			timecard_label.add_theme_font_override("font", font_retro)
		timecard_label.add_theme_font_size_override("font_size", 22)
		timecard_label.add_theme_color_override("font_color", Color(0.88, 0.90, 0.94, 1.0))
		timecard_label.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 1.0))
		timecard_label.add_theme_constant_override("shadow_offset_x", 2)
		timecard_label.add_theme_constant_override("shadow_offset_y", 2)
		timecard_label.add_theme_constant_override("line_spacing", 4)

	# 2. Configura Objective (Canto superior esquerdo, SEM fundo cinza e com pivot no topo-esquerdo)
	if objective_panel:
		var empty_style := StyleBoxEmpty.new()
		objective_panel.add_theme_stylebox_override("panel", empty_style)
		objective_panel.set_anchors_preset(Control.PRESET_TOP_LEFT)
		objective_panel.offset_left = 36.0
		objective_panel.offset_top = 28.0
		objective_panel.offset_right = 520.0
		objective_panel.offset_bottom = 220.0
		objective_panel.pivot_offset = Vector2(0, 0)
		objective_panel.scale = Vector2(1.0, 1.0)
		objective_panel.modulate.a = 0.0
		objective_panel.hide()
	if objective_label:
		objective_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
		objective_label.vertical_alignment = VERTICAL_ALIGNMENT_TOP
		if font_retro:
			objective_label.add_theme_font_override("font", font_retro)
		objective_label.add_theme_font_size_override("font_size", 18)
		objective_label.add_theme_color_override("font_color", Color(0.92, 0.92, 0.95, 1.0))
		objective_label.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 1.0))
		objective_label.add_theme_constant_override("shadow_offset_x", 2)
		objective_label.add_theme_constant_override("shadow_offset_y", 2)
		objective_label.add_theme_constant_override("line_spacing", 4)

	# 3. Configura InteractHint (Centro inferior, Amarelo retrô VCR)
	if interact_hint:
		interact_hint.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
		interact_hint.anchor_left = 0.5
		interact_hint.anchor_right = 0.5
		interact_hint.anchor_top = 1.0
		interact_hint.anchor_bottom = 1.0
		interact_hint.offset_left = -250.0
		interact_hint.offset_top = -65.0
		interact_hint.offset_right = 250.0
		interact_hint.offset_bottom = -25.0
		interact_hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		interact_hint.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		if font_retro:
			interact_hint.add_theme_font_override("font", font_retro)
		interact_hint.add_theme_font_size_override("font_size", 22)
		interact_hint.add_theme_color_override("font_color", Color(0.96, 0.85, 0.22, 1.0))
		interact_hint.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 1.0))
		interact_hint.add_theme_constant_override("shadow_offset_x", 2)
		interact_hint.add_theme_constant_override("shadow_offset_y", 2)
		interact_hint.hide()



# ============================================================
# SISTEMA DE PAUSA RETRO VHS / TV AZUL [ESC] EM PORTUGUÊS
# ============================================================

func _setup_pause_menu() -> void:
	if not hud:
		return
	
	pause_menu_control = hud.get_node_or_null("PauseMenu") as Control
	if not pause_menu_control:
		pause_menu_control = Control.new()
		pause_menu_control.name = "PauseMenu"
		pause_menu_control.process_mode = Node.PROCESS_MODE_ALWAYS
		pause_menu_control.set_anchors_preset(Control.PRESET_FULL_RECT)
		pause_menu_control.z_index = 100
		
		# Fundo semitransparente escurecido
		var dark_dim = ColorRect.new()
		dark_dim.color = Color(0.0, 0.0, 0.0, 0.65)
		dark_dim.set_anchors_preset(Control.PRESET_FULL_RECT)
		pause_menu_control.add_child(dark_dim)
		
		# Caixa Azul Retrô VCR (CONFIGURAÇÕES)
		var vcr_box = ColorRect.new()
		vcr_box.name = "VCRBox"
		vcr_box.color = Color(0.10, 0.16, 0.58, 0.98)
		vcr_box.set_anchors_preset(Control.PRESET_CENTER)
		vcr_box.custom_minimum_size = Vector2(530, 430)
		vcr_box.offset_left = -265
		vcr_box.offset_top = -215
		vcr_box.offset_right = 265
		vcr_box.offset_bottom = 215
		pause_menu_control.add_child(vcr_box)
		
		# Borda branca VCR
		var border = ReferenceRect.new()
		border.border_color = Color(0.92, 0.92, 0.92, 1.0)
		border.border_width = 3.0
		border.set_anchors_preset(Control.PRESET_FULL_RECT)
		vcr_box.add_child(border)
		
		var margin = MarginContainer.new()
		margin.set_anchors_preset(Control.PRESET_FULL_RECT)
		margin.add_theme_constant_override("margin_left", 32)
		margin.add_theme_constant_override("margin_top", 24)
		margin.add_theme_constant_override("margin_right", 32)
		margin.add_theme_constant_override("margin_bottom", 24)
		vcr_box.add_child(margin)
		
		var vbox = VBoxContainer.new()
		vbox.add_theme_constant_override("separation", 16)
		margin.add_child(vbox)
		
		# Título VCR
		var lbl_title = Label.new()
		lbl_title.text = "CONFIGURAÇÕES"
		lbl_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		if font_retro:
			lbl_title.add_theme_font_override("font", font_retro)
		lbl_title.add_theme_font_size_override("font_size", 24)
		lbl_title.add_theme_color_override("font_color", Color(1, 1, 1, 1))
		lbl_title.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 1))
		lbl_title.add_theme_constant_override("shadow_offset_x", 2)
		lbl_title.add_theme_constant_override("shadow_offset_y", 2)
		vbox.add_child(lbl_title)
		
		var sep = HSeparator.new()
		vbox.add_child(sep)
		
		# Botão Retomar
		var btn_resume = Button.new()
		btn_resume.text = "→ RETOMAR JOGO"
		btn_resume.alignment = HORIZONTAL_ALIGNMENT_LEFT
		btn_resume.process_mode = Node.PROCESS_MODE_ALWAYS
		if font_retro:
			btn_resume.add_theme_font_override("font", font_retro)
		btn_resume.add_theme_font_size_override("font_size", 18)
		btn_resume.add_theme_color_override("font_color", Color(1, 1, 1, 1))
		btn_resume.add_theme_color_override("font_hover_color", Color(1, 0.3, 0.3, 1))
		btn_resume.flat = true
		btn_resume.pressed.connect(func(): toggle_pause_menu())
		vbox.add_child(btn_resume)
		
		# Volume Master
		var lbl_vol = Label.new()
		lbl_vol.text = "VOLUME GERAL"
		if font_retro:
			lbl_vol.add_theme_font_override("font", font_retro)
		lbl_vol.add_theme_font_size_override("font_size", 15)
		lbl_vol.add_theme_color_override("font_color", Color(0.85, 0.85, 0.85, 1))
		vbox.add_child(lbl_vol)
		
		var slider_vol = HSlider.new()
		slider_vol.process_mode = Node.PROCESS_MODE_ALWAYS
		slider_vol.min_value = 0.0
		slider_vol.max_value = 1.0
		slider_vol.step = 0.05
		slider_vol.value = db_to_linear(AudioServer.get_bus_volume_db(AudioServer.get_bus_index("Master")))
		slider_vol.value_changed.connect(func(v: float):
			AudioServer.set_bus_volume_db(AudioServer.get_bus_index("Master"), linear_to_db(v))
		)
		vbox.add_child(slider_vol)
		
		# Volume SFX
		var lbl_sfx = Label.new()
		lbl_sfx.text = "VOLUME DE EFEITOS (SFX)"
		if font_retro:
			lbl_sfx.add_theme_font_override("font", font_retro)
		lbl_sfx.add_theme_font_size_override("font_size", 15)
		lbl_sfx.add_theme_color_override("font_color", Color(0.85, 0.85, 0.85, 1))
		vbox.add_child(lbl_sfx)
		
		var slider_sfx = HSlider.new()
		slider_sfx.process_mode = Node.PROCESS_MODE_ALWAYS
		slider_sfx.min_value = 0.0
		slider_sfx.max_value = 1.0
		slider_sfx.step = 0.05
		slider_sfx.value = 0.8
		vbox.add_child(slider_sfx)
		
		# Tela Cheia
		var check_fs = CheckBox.new()
		check_fs.process_mode = Node.PROCESS_MODE_ALWAYS
		check_fs.text = " TELA CHEIA (FULLSCREEN)"
		if font_retro:
			check_fs.add_theme_font_override("font", font_retro)
		check_fs.add_theme_font_size_override("font_size", 15)
		check_fs.add_theme_color_override("font_color", Color(0.9, 0.9, 0.9, 1))
		check_fs.button_pressed = (DisplayServer.window_get_mode() == DisplayServer.WINDOW_MODE_FULLSCREEN)
		check_fs.toggled.connect(func(b: bool):
			if b:
				DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN)
			else:
				DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
		)
		vbox.add_child(check_fs)
		
		# Menu Principal
		var btn_main = Button.new()
		btn_main.text = "→ MENU PRINCIPAL"
		btn_main.alignment = HORIZONTAL_ALIGNMENT_LEFT
		btn_main.process_mode = Node.PROCESS_MODE_ALWAYS
		if font_retro:
			btn_main.add_theme_font_override("font", font_retro)
		btn_main.add_theme_font_size_override("font_size", 18)
		btn_main.add_theme_color_override("font_color", Color(0.85, 0.85, 0.85, 1))
		btn_main.add_theme_color_override("font_hover_color", Color(1, 0.3, 0.3, 1))
		btn_main.flat = true
		btn_main.pressed.connect(_on_main_menu_pressed)
		vbox.add_child(btn_main)
		
		hud.add_child(pause_menu_control)
		pause_menu_control.hide()

func _process(_delta: float) -> void:
	if Input.is_action_just_pressed("ui_cancel") or (Input.is_key_pressed(KEY_ESCAPE) and Input.is_action_just_pressed("ui_cancel")):
		toggle_pause_menu()

func toggle_pause_menu() -> void:
	_toggle_pause()

func _toggle_pause() -> void:
	if not pause_menu_control:
		return
	is_paused = not is_paused
	pause_menu_control.visible = is_paused
	get_tree().paused = is_paused
	if is_paused:
		Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
	else:
		Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)

func _on_main_menu_pressed() -> void:
	get_tree().paused = false
	Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
	get_tree().change_scene_to_file("res://scenes/ui/title_screen.tscn")

# ============================================================
# HUD / TIMECARD / OBJETIVOS - ESTÉTICA VHS RETRÔ PROFISSIONAL
# ============================================================

func _show_timecard(local_text: String, hora_text: String, duration: float = 6.0) -> void:
	if not timecard_panel: return
	if timecard_label:
		timecard_label.text = local_text.to_upper() + "\n" + hora_text
		if font_retro:
			timecard_label.add_theme_font_override("font", font_retro)
		timecard_label.add_theme_font_size_override("font_size", 22)
		timecard_label.add_theme_color_override("font_color", Color(0.88, 0.90, 0.94, 1.0))
		timecard_label.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 1.0))
		timecard_label.add_theme_constant_override("shadow_offset_x", 2)
		timecard_label.add_theme_constant_override("shadow_offset_y", 2)
	timecard_panel.modulate.a = 0.0
	timecard_panel.show()
	var tween = create_tween()
	tween.tween_property(timecard_panel, "modulate:a", 1.0, 0.4)
	tween.tween_interval(duration)
	tween.tween_property(timecard_panel, "modulate:a", 0.0, 0.8)
	tween.tween_callback(timecard_panel.hide)

func _set_objective(text: String, transition: bool = true) -> void:
	if not objective_panel or not objective_label: return
	_objective_typing_token += 1
	var my_token = _objective_typing_token
	
	var clean_text = text.strip_edges()
	if clean_text.to_upper().begins_with("OBJETIVO:"):
		clean_text = clean_text.substr(9).strip_edges()
	
	if font_retro:
		objective_label.add_theme_font_override("font", font_retro)
	objective_label.add_theme_font_size_override("font_size", 18)
	objective_label.add_theme_color_override("font_color", Color(0.92, 0.92, 0.95, 1.0))
	objective_label.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 1.0))
	objective_label.add_theme_constant_override("shadow_offset_x", 2)
	objective_label.add_theme_constant_override("shadow_offset_y", 2)
	objective_label.add_theme_constant_override("line_spacing", 4)
	objective_panel.pivot_offset = Vector2(0, 0)
	objective_panel.modulate.a = 1.0
	objective_panel.show()
	
	# Resize Smooth para o Modo Destaque (Tamanho 100% normal)
	var tw_grow = create_tween().set_parallel(true)
	tw_grow.tween_property(objective_panel, "scale", Vector2(1.0, 1.0), 0.35).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	tw_grow.tween_property(objective_panel, "position", Vector2(36.0, 28.0), 0.35).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	
	if not transition:
		objective_label.text = "OBJETIVO:\n" + clean_text.to_upper()
		_start_objective_idle_shrink(my_token)
		return
	
	# Efeito Profissional de Digitação VHS / Typewriter (espaço elegante e natural de 1 linha)
	var current_text = objective_label.text
	if current_text != "" and current_text != "OBJETIVO:" and current_text != "OBJETIVO:\n":
		var newline_pos = current_text.find("\n")
		if newline_pos != -1:
			var body_content = current_text.substr(newline_pos + 1)
			while body_content.length() > 0 and my_token == _objective_typing_token:
				body_content = body_content.substr(0, body_content.length() - 1)
				objective_label.text = "OBJETIVO:\n" + body_content
				await get_tree().create_timer(0.015).timeout
	
	if my_token != _objective_typing_token:
		return
	
	objective_label.text = "OBJETIVO:\n"
	await get_tree().create_timer(0.15).timeout
	
	# Digita novo conteúdo caractere por caractere
	var target_body = clean_text.to_upper()
	var typed = ""
	for i in range(target_body.length()):
		if my_token != _objective_typing_token:
			return
		typed += target_body[i]
		objective_label.text = "OBJETIVO:\n" + typed
		await get_tree().create_timer(0.03).timeout
	
	# Inicia contagem de 10 segundos para encolher suavemente se não houver novas mudanças
	_start_objective_idle_shrink(my_token)

func _start_objective_idle_shrink(token: int) -> void:
	await get_tree().create_timer(10.0).timeout
	if token == _objective_typing_token and is_instance_valid(objective_panel):
		# Resize Smooth para o Modo Compacto / Encolhido no canto superior esquerdo
		var tw_shrink = create_tween().set_parallel(true)
		tw_shrink.tween_property(objective_panel, "scale", Vector2(0.76, 0.76), 0.7).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
		tw_shrink.tween_property(objective_panel, "position", Vector2(20.0, 16.0), 0.7).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)

func show_interact_hint(text: String) -> void:
	if not interact_hint: return
	interact_hint.text = text.to_upper()
	if font_retro:
		interact_hint.add_theme_font_override("font", font_retro)
	interact_hint.add_theme_font_size_override("font_size", 22)
	interact_hint.add_theme_color_override("font_color", Color(0.96, 0.85, 0.22, 1.0))
	interact_hint.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 1.0))
	interact_hint.add_theme_constant_override("shadow_offset_x", 2)
	interact_hint.add_theme_constant_override("shadow_offset_y", 2)
	interact_hint.show()

func hide_interact_hint() -> void:
	if not interact_hint: return
	interact_hint.hide()

# ============================================================
# SISTEMA DE VEGETAÇÃO, VENTO E POEIRA REALISTA
# ============================================================

func _aplicar_vento_automatico_em_todas_arvores() -> void:
	var wind_shader = load("res://shaders/vento_arvore.gdshader") as Shader
	if not wind_shader:
		return
	
	_tree_materials.clear()
	var mat_cache := {}
	var mesh_instances = find_children("*", "MeshInstance3D", true, false)
	for m in mesh_instances:
		var mi := m as MeshInstance3D
		var full_name = (mi.name + " " + mi.get_parent().name).to_lower()
		
		if "tree" in full_name or "arvore" in full_name or "palm" in full_name or \
		   "palmeira" in full_name or "bosquinho" in full_name or "folha" in full_name or \
		   "branch" in full_name or "commontree" in full_name or "grass_p" in full_name or \
		   "bush" in full_name or "arbusto" in full_name or "vegetat" in full_name:
			var mat_count = mi.get_surface_override_material_count()
			if mat_count == 0 and mi.mesh:
				mat_count = mi.mesh.get_surface_count()
			
			for s in range(max(1, mat_count)):
				var active_mat = mi.get_active_material(s)
				var albedo_tex: Texture2D = null
				if active_mat is BaseMaterial3D and active_mat.albedo_texture:
					albedo_tex = active_mat.albedo_texture
				
				var cache_key = albedo_tex.resource_path if albedo_tex else "default_tree_mat"
				var sm: ShaderMaterial
				if mat_cache.has(cache_key):
					sm = mat_cache[cache_key]
				else:
					sm = ShaderMaterial.new()
					sm.shader = wind_shader
					if albedo_tex:
						sm.set_shader_parameter("texture_albedo", albedo_tex)
					sm.set_shader_parameter("direcao_vento", Vector2(1.0, 0.35))
					sm.set_shader_parameter("velocidade_rajada", 0.85)
					sm.set_shader_parameter("forca_rajada", 0.28)
					sm.set_shader_parameter("velocidade_flutter", 7.5)
					sm.set_shader_parameter("forca_flutter", 0.04)
					mat_cache[cache_key] = sm
					_tree_materials.append(sm)
					if clima_manager:
						clima_manager.tree_materials.append(sm)
				
				mi.set_surface_override_material(s, sm)

func _setup_extra_wind_audio() -> void:
	audio_wind_extra = AudioStreamPlayer.new()
	audio_wind_extra.name = "AudioWindExtra"
	var wind_stream = load("res://assets/audio/Free PSX Wind Ambience/Wind 2.wav") as AudioStream
	if wind_stream:
		audio_wind_extra.stream = wind_stream
		audio_wind_extra.volume_db = -5.0
		add_child(audio_wind_extra)
		audio_wind_extra.play()
		audio_wind_extra.finished.connect(func():
			var next_stream = load("res://assets/audio/Free PSX Wind Ambience/Wind 3.wav") as AudioStream
			if audio_wind_extra.stream == next_stream:
				audio_wind_extra.stream = load("res://assets/audio/Free PSX Wind Ambience/Wind 2.wav") as AudioStream
			else:
				audio_wind_extra.stream = next_stream
			audio_wind_extra.play()
		)

func _setup_wind_particles() -> void:
	# Partículas de Folhas Voando no Vento (Vento laranja / outono original)
	var leaves_particles := GPUParticles3D.new()
	leaves_particles.name = "WindLeavesParticles"
	leaves_particles.amount = 90
	leaves_particles.lifetime = 3.0
	leaves_particles.preprocess = 1.5
	leaves_particles.visibility_aabb = AABB(Vector3(-40, -15, -40), Vector3(80, 30, 80))
	
	var mat := ParticleProcessMaterial.new()
	mat.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
	mat.emission_box_extents = Vector3(30.0, 10.0, 30.0)
	mat.direction = Vector3(1.0, -0.12, 0.35).normalized()
	mat.spread = 12.0
	mat.initial_velocity_min = 9.0
	mat.initial_velocity_max = 16.0
	mat.gravity = Vector3(0.0, -1.0, 0.0)
	mat.angular_velocity_min = -220.0
	mat.angular_velocity_max = 220.0
	mat.scale_min = 0.08
	mat.scale_max = 0.22
	mat.color = Color(0.38, 0.29, 0.20, 0.85)
	leaves_particles.process_material = mat
	_wind_leaves_mat = mat
	
	var quad := QuadMesh.new()
	quad.size = Vector2(0.22, 0.16)
	var quad_mat := StandardMaterial3D.new()
	quad_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	quad_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	quad_mat.albedo_color = Color(0.42, 0.32, 0.20, 0.9)
	quad_mat.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	quad.material = quad_mat
	leaves_particles.draw_pass_1 = quad
	
	if player:
		player.add_child(leaves_particles)
		leaves_particles.position = Vector3(-10.0, 4.0, -10.0)
	else:
		add_child(leaves_particles)
		leaves_particles.position = Vector3(0.0, 5.0, 0.0)

# ============================================================
# CONTROLADOR DE RAJADAS DINÂMICAS DE VENTO (Espaçadas e Raras)
# ============================================================

func _start_dynamic_wind_system() -> void:
	# Loop de rajadas raras e atmosféricas (a cada 25-45 segundos)
	while is_instance_valid(self) and not is_queued_for_deletion():
		var wait_time = randf_range(25.0, 45.0)
		await get_tree().create_timer(wait_time).timeout
		if not is_instance_valid(self) or is_queued_for_deletion():
			break
		_trigger_wind_gust()

func _trigger_wind_gust() -> void:
	var gust_duration = randf_range(4.0, 5.5)
	var peak_wind_force = randf_range(0.46, 0.58)
	var peak_flutter = randf_range(11.0, 14.0)
	
	# 1. Aumenta balanço das árvores
	var tw = create_tween().set_parallel(true)
	for sm in _tree_materials:
		if is_instance_valid(sm):
			tw.tween_property(sm, "shader_parameter/forca_rajada", peak_wind_force, gust_duration * 0.4).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
			tw.tween_property(sm, "shader_parameter/velocidade_flutter", peak_flutter, gust_duration * 0.4).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	
	# 2. Som do vento ruge na rajada
	if is_instance_valid(audio_wind_extra):
		tw.tween_property(audio_wind_extra, "volume_db", -1.5, gust_duration * 0.4).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
		tw.tween_property(audio_wind_extra, "pitch_scale", 1.10, gust_duration * 0.4).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	
	# 3. Folhas de vento aceleram no pico da rajada
	if _wind_leaves_mat:
		tw.tween_property(_wind_leaves_mat, "initial_velocity_min", 14.0, gust_duration * 0.3)
		tw.tween_property(_wind_leaves_mat, "initial_velocity_max", 22.0, gust_duration * 0.3)
	
	await get_tree().create_timer(gust_duration * 0.45).timeout
	if not is_instance_valid(self) or is_queued_for_deletion():
		return
	
	# Volta suavemente ao vento normal
	var tw_back = create_tween().set_parallel(true)
	for sm in _tree_materials:
		if is_instance_valid(sm):
			tw_back.tween_property(sm, "shader_parameter/forca_rajada", 0.28, gust_duration * 0.6).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
			tw_back.tween_property(sm, "shader_parameter/velocidade_flutter", 7.5, gust_duration * 0.6).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	
	if is_instance_valid(audio_wind_extra):
		tw_back.tween_property(audio_wind_extra, "volume_db", -5.0, gust_duration * 0.6).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
		tw_back.tween_property(audio_wind_extra, "pitch_scale", 1.0, gust_duration * 0.6).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	
	if _wind_leaves_mat:
		tw_back.tween_property(_wind_leaves_mat, "initial_velocity_min", 9.0, gust_duration * 0.6)
		tw_back.tween_property(_wind_leaves_mat, "initial_velocity_max", 16.0, gust_duration * 0.6)

# ============================================================
# BOOT VHS - ESTÉTICA AUTÊNTICA VHS / OSD
# ============================================================

func _play_vhs_intro_sequence() -> void:
	if not hud:
		return
	
	if fade_rect:
		fade_rect.color = Color(0, 0, 0, 1)
		fade_rect.show()
	
	var vhs_overlay := ColorRect.new()
	vhs_overlay.name = "VHSIntroOverlay"
	vhs_overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	vhs_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	vhs_overlay.z_index = 10
	
	var vhs_shader := load("res://shaders/vhs_turn_on.gdshader") as Shader
	var sm := ShaderMaterial.new()
	sm.shader = vhs_shader
	sm.set_shader_parameter("turn_on_progress", 0.0)
	sm.set_shader_parameter("static_noise_intensity", 1.0)
	vhs_overlay.material = sm
	hud.add_child(vhs_overlay)
	
	# ▶ PLAY Amarelo Retrô VCR (z_index 50 para ficar puro acima de qualquer overlay)
	var vcr_label := Label.new()
	vcr_label.text = "▶ PLAY   SP   17:52:31"
	vcr_label.position = Vector2(36, 28)
	vcr_label.z_index = 50
	if font_retro:
		vcr_label.add_theme_font_override("font", font_retro)
	vcr_label.add_theme_color_override("font_color", Color(0.96, 0.85, 0.22, 1.0))
	vcr_label.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 1.0))
	vcr_label.add_theme_constant_override("shadow_offset_x", 2)
	vcr_label.add_theme_constant_override("shadow_offset_y", 2)
	vcr_label.add_theme_font_size_override("font_size", 22)
	vcr_label.modulate.a = 0.0
	hud.add_child(vcr_label)
	
	var sfx_boot := AudioStreamPlayer.new()
	var boot_audio = load("res://assets/audio/menu/music/GAMESTARTSOUND.mp3") as AudioStream
	if boot_audio:
		sfx_boot.stream = boot_audio
		sfx_boot.volume_db = -2.0
		add_child(sfx_boot)
		sfx_boot.play()
	
	await get_tree().process_frame
	await get_tree().process_frame
	
	if fade_rect:
		fade_rect.hide()
	
	# 1. Abre tubo CRT
	var tw := create_tween()
	tw.tween_method(func(val: float): sm.set_shader_parameter("turn_on_progress", val), 0.0, 1.0, 1.6).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	
	# 2. Exibe o PLAY e o TIMECARD simultaneamente com fade-in sincronizado
	if timecard_panel:
		timecard_panel.modulate.a = 0.0
		timecard_panel.show()
	
	var tw_in := create_tween().set_parallel(true)
	tw_in.tween_property(vcr_label, "modulate:a", 1.0, 0.3)
	if timecard_panel:
		tw_in.tween_property(timecard_panel, "modulate:a", 1.0, 0.3)
	
	# 3. Contagem real de segundos correndo no PLAY (17:52:31 até 17:52:36 - exatamente 6 segundos)
	for sec in range(31, 37):
		if is_instance_valid(vcr_label):
			var sec_str = "%02d" % sec
			vcr_label.text = "▶ PLAY   SP   17:52:" + sec_str
		await get_tree().create_timer(1.0).timeout
	
	# 4. Fade out 100% SINCRONIZADO do PLAY e do TIMECARD ao mesmo tempo
	var tw_fade_both := create_tween().set_parallel(true)
	if is_instance_valid(vcr_label):
		tw_fade_both.tween_property(vcr_label, "modulate:a", 0.0, 0.8)
	if is_instance_valid(timecard_panel):
		tw_fade_both.tween_property(timecard_panel, "modulate:a", 0.0, 0.8)
	if is_instance_valid(vhs_overlay):
		tw_fade_both.tween_property(vhs_overlay, "modulate:a", 0.0, 0.8)
	
	await tw_fade_both.finished
	
	if is_instance_valid(vcr_label):
		vcr_label.queue_free()
	if is_instance_valid(timecard_panel):
		timecard_panel.hide()
	if is_instance_valid(vhs_overlay):
		vhs_overlay.queue_free()
	
	# 5. Após o PLAY e o TIMECARD sumirem juntos, inicia digitação do objetivo no canto superior esquerdo
	_set_objective("VÁ ATÉ O PRÉDIO\nADMINISTRATIVO E FAÇA\nSUA MATRÍCULA.", true)