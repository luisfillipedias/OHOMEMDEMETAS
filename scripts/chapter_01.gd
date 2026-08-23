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
var settings_subpanel: Control = null
var audio_wind_extra: AudioStreamPlayer = null

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	add_to_group("chapter")
	Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)
	
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
	
	# Camada extra de áudio de vento e uivos PSX
	_setup_extra_wind_audio()
	
	# Partículas de folhas voando
	_setup_wind_particles()
	
	# Aplica shader de vento nas árvores com cache (60 FPS estáveis)
	_aplicar_vento_automatico_em_todas_arvores()
	
	# Sequência cinematográfica de Boot VHS / Tubo CRT ligando
	_play_vhs_intro_sequence()

# ============================================================
# SISTEMA DE PAUSA E CONFIGURAÇÕES [ESC]
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
		
		# Fundo escuro
		var bg = ColorRect.new()
		bg.color = Color(0.02, 0.02, 0.04, 0.88)
		bg.set_anchors_preset(Control.PRESET_FULL_RECT)
		pause_menu_control.add_child(bg)
		
		var vbox = VBoxContainer.new()
		vbox.set_anchors_preset(Control.PRESET_CENTER)
		vbox.custom_minimum_size = Vector2(380, 320)
		vbox.add_theme_constant_override("separation", 14)
		pause_menu_control.add_child(vbox)
		
		var title = Label.new()
		title.text = "PAUSA  //  [ESC]"
		title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		title.add_theme_font_size_override("font_size", 22)
		title.add_theme_color_override("font_color", Color(1, 0.9, 0.4, 1))
		vbox.add_child(title)
		
		var btn_resume = Button.new()
		btn_resume.text = "RETOMAR JOGO"
		btn_resume.custom_minimum_size = Vector2(0, 38)
		btn_resume.pressed.connect(func(): toggle_pause_menu())
		vbox.add_child(btn_resume)
		
		var btn_settings = Button.new()
		btn_settings.text = "CONFIGURAÇÕES"
		btn_settings.custom_minimum_size = Vector2(0, 38)
		btn_settings.pressed.connect(func(): _toggle_settings_panel())
		vbox.add_child(btn_settings)
		
		settings_subpanel = VBoxContainer.new()
		settings_subpanel.add_theme_constant_override("separation", 8)
		settings_subpanel.hide()
		
		var lbl_vol = Label.new()
		lbl_vol.text = "Volume Geral:"
		settings_subpanel.add_child(lbl_vol)
		
		var slider_vol = HSlider.new()
		slider_vol.min_value = 0.0
		slider_vol.max_value = 1.0
		slider_vol.step = 0.05
		slider_vol.value = db_to_linear(AudioServer.get_bus_volume_db(0))
		slider_vol.value_changed.connect(func(v): AudioServer.set_bus_volume_db(0, linear_to_db(v)))
		settings_subpanel.add_child(slider_vol)
		
		var check_fs = CheckBox.new()
		check_fs.text = "Tela Cheia"
		check_fs.button_pressed = (DisplayServer.window_get_mode() == DisplayServer.WINDOW_MODE_FULLSCREEN)
		check_fs.toggled.connect(func(toggled):
			if toggled:
				DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN)
			else:
				DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
		)
		settings_subpanel.add_child(check_fs)
		vbox.add_child(settings_subpanel)
		
		var btn_main_menu = Button.new()
		btn_main_menu.text = "MENU PRINCIPAL"
		btn_main_menu.custom_minimum_size = Vector2(0, 38)
		btn_main_menu.pressed.connect(_on_main_menu_pressed)
		vbox.add_child(btn_main_menu)
		
		hud.add_child(pause_menu_control)
	
	pause_menu_control.hide()

func _toggle_settings_panel() -> void:
	if settings_subpanel:
		settings_subpanel.visible = not settings_subpanel.visible

func _input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel") or (event is InputEventKey and event.pressed and event.keycode == KEY_ESCAPE):
		toggle_pause_menu()

func toggle_pause_menu() -> void:
	_toggle_pause()

func _toggle_pause() -> void:
	if not pause_menu_control:
		_setup_pause_menu()
	if not pause_menu_control:
		return
	is_paused = not is_paused
	pause_menu_control.visible = is_paused
	get_tree().paused = is_paused
	if is_paused:
		Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
	else:
		Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)

func _on_resume_pressed() -> void:
	toggle_pause_menu()

func _on_main_menu_pressed() -> void:
	get_tree().paused = false
	Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
	get_tree().change_scene_to_file("res://scenes/ui/title_screen.tscn")

# ============================================================
# HUD / TIMECARD / OBJETIVOS
# ============================================================

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

# ============================================================
# SISTEMA DE VEGETAÇÃO E VENTO
# ============================================================

func _aplicar_vento_automatico_em_todas_arvores() -> void:
	var wind_shader = load("res://shaders/vento_arvore.gdshader") as Shader
	if not wind_shader:
		return
	
	var mat_cache := {}
	var mesh_instances = find_children("*", "MeshInstance3D", true, false)
	for m in mesh_instances:
		var mi := m as MeshInstance3D
		var full_name = (mi.name + " " + mi.get_parent().name).to_lower()
		
		if "tree" in full_name or "arvore" in full_name or "palm" in full_name or "palmeira" in full_name or "bosquinho" in full_name or "folha" in full_name or "branch" in full_name or "commontree" in full_name or "grass_p" in full_name or "bush" in full_name or "arbusto" in full_name or "vegetat" in full_name:
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
	var particles := GPUParticles3D.new()
	particles.name = "WindLeavesParticles"
	particles.amount = 90
	particles.lifetime = 3.0
	particles.preprocess = 1.5
	particles.visibility_aabb = AABB(Vector3(-40, -15, -40), Vector3(80, 30, 80))
	
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
	
	particles.process_material = mat
	
	var quad := QuadMesh.new()
	quad.size = Vector2(0.22, 0.16)
	var quad_mat := StandardMaterial3D.new()
	quad_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	quad_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	quad_mat.albedo_color = Color(0.42, 0.32, 0.20, 0.9)
	quad_mat.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	quad.material = quad_mat
	particles.draw_pass_1 = quad
	
	if player:
		player.add_child(particles)
		particles.position = Vector3(-10.0, 4.0, -10.0)
	else:
		add_child(particles)
		particles.position = Vector3(0.0, 5.0, 0.0)

# ============================================================
# TRANSIÇÃO CINEMATOGRÁFICA DE BOOT VHS / TUBO CRT
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
	vhs_overlay.z_index = 20
	
	var vhs_shader := load("res://shaders/vhs_turn_on.gdshader") as Shader
	var sm := ShaderMaterial.new()
	sm.shader = vhs_shader
	sm.set_shader_parameter("turn_on_progress", 0.0)
	sm.set_shader_parameter("static_noise_intensity", 1.0)
	vhs_overlay.material = sm
	hud.add_child(vhs_overlay)
	
	var vcr_label := Label.new()
	vcr_label.text = "▶ PLAY   SP   17:50:00"
	vcr_label.position = Vector2(36, 28)
	vcr_label.add_theme_color_override("font_color", Color(0.25, 1.0, 0.45, 1.0))
	vcr_label.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.95))
	vcr_label.add_theme_constant_override("shadow_offset_x", 2)
	vcr_label.add_theme_constant_override("shadow_offset_y", 2)
	vcr_label.add_theme_font_size_override("font_size", 18)
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
	
	var tw := create_tween()
	tw.tween_method(func(val: float): sm.set_shader_parameter("turn_on_progress", val), 0.0, 1.0, 1.6).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	
	var tw_txt := create_tween()
	tw_txt.tween_property(vcr_label, "modulate:a", 1.0, 0.2)
	tw_txt.tween_interval(1.8)
	tw_txt.tween_property(vcr_label, "modulate:a", 0.0, 0.5)
	
	await tw.finished
	
	var tw_fade := create_tween()
	tw_fade.tween_property(vhs_overlay, "modulate:a", 0.0, 0.5)
	await tw_fade.finished
	vhs_overlay.queue_free()
	vcr_label.queue_free()
	
	_show_timecard("CEFET-MG  -  CAMPUS 1", "17:50")
	_set_objective("Vá até o prédio administrativo\ne faça sua matrícula.")
