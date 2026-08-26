extends Node3D

# ============================================================
# CHAPTER 01: O HOMEM DE METAS -- CEFET-MG & A PERSEGUIÇÃO
# ============================================================

@onready var player: CharacterBody3D = get_node_or_null("PlayerController")
@onready var camera_mount: Node3D = get_node_or_null("PlayerController/CameraMount")
@onready var dialogue_ui: CanvasLayer = get_node_or_null("DialogueUI")
@onready var celular_ui: CanvasLayer = get_node_or_null("CelularUI")
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
var is_paused: bool = false
var _docs_popup_com_objetivo: bool = true

var pause_menu_control: Control = null
var font_retro: Font = null
var _objective_typing_token: int = 0

# Audio Players do Sistema de Sons
var audio_typewriter: AudioStreamPlayer = null
var audio_ui_select: AudioStreamPlayer = null
var audio_ui_cursor: AudioStreamPlayer = null
var audio_ui_cancel: AudioStreamPlayer = null
var audio_ui_resume: AudioStreamPlayer = null
var audio_ui_close_pause: AudioStreamPlayer = null
var audio_ui_back: AudioStreamPlayer = null
var audio_obj_appear: AudioStreamPlayer = null
var audio_obj_shrink: AudioStreamPlayer = null
var audio_obj_solved: AudioStreamPlayer = null
var audio_save_game: AudioStreamPlayer = null
var audio_wrong_obj: AudioStreamPlayer = null

# Sistema de Ambience com Crossfade Suave (Dois Players)
var audio_amb_a: AudioStreamPlayer = null
var audio_amb_b: AudioStreamPlayer = null
var _active_amb_is_a: bool = true
var _ambience_playlist: Array[AudioStream] = []
var _ambience_queue: Array[AudioStream] = []
var _last_ambience_stream: AudioStream = null
var _is_ambience_crossfading: bool = false

# Sistema Centralizado de Vento Dinâmico Reativo ao Áudio Real
var _wind_direction: Vector2 = Vector2(1.0, 0.35).normalized()
var _wind_audio_energy: float = 0.35  # Seguidor de envelope do áudio de vento em tempo real [0.0 .. 1.0]
var _wind_bus_idx: int = -1
var audio_wind: AudioStreamPlayer = null
var _tree_materials: Array[ShaderMaterial] = []
var _wind_leaves_mat: ParticleProcessMaterial = null

var _parents_car: Node3D = null
var _audio_car_idle: AudioStreamPlayer = null
var _audio_car_road: AudioStreamPlayer = null
var _intro_lock: bool = true
var _inside_car_audio: bool = false

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
	
	# Inicializa gerenciador de SFX e UI
	_setup_audio_system()
	
	_setup_hud_styling()
	_setup_pause_menu()
	
	# Gerenciador de Clima
	clima_manager = ClimaManager.new()
	add_child(clima_manager)
	
	# Configuração de playlist dinâmica de ambience e vento com crossfade contínuo
	_setup_ambience_system()
	_setup_wind_audio_system()
	_setup_wind_particles()
	
	# Aplica shader de vento nas árvores
	_aplicar_vento_automatico_em_todas_arvores()
	
	# Inicia sistema de rajadas dinâmicas ocasionais de vento
	_start_dynamic_wind_system()
	
	_setup_parents_car()
	_play_opening_sequence()

# ============================================================
# SISTEMA DE ÁUDIO CENTRALIZADO (SFX, TYPEWRITER, UI, OBJETIVOS)
# ============================================================

func _setup_audio_system() -> void:
	# 1. Typewriter SFX (Imediato)
	audio_typewriter = AudioStreamPlayer.new()
	audio_typewriter.name = "AudioTypewriter"
	audio_typewriter.volume_db = -1.0
	var typing_paths := [
		"res://assets/audio/menu/Text-typing.ogg",
		"res://assets/audio/menu/text-typing.ogg",
		"res://assets/audio/menu/typewriter.ogg",
	]
	for p in typing_paths:
		if ResourceLoader.exists(p):
			audio_typewriter.stream = load(p) as AudioStream
			break
	add_child(audio_typewriter)

	# 2. UI Click / Select
	audio_ui_select = AudioStreamPlayer.new()
	audio_ui_select.name = "AudioUISelect"
	audio_ui_select.process_mode = Node.PROCESS_MODE_ALWAYS
	audio_ui_select.volume_db = -2.0
	if ResourceLoader.exists("res://assets/audio/menu/UI/ogg/JDSherbert - Ultimate UI SFX Pack - Select - 1.ogg"):
		audio_ui_select.stream = load("res://assets/audio/menu/UI/ogg/JDSherbert - Ultimate UI SFX Pack - Select - 1.ogg")
	add_child(audio_ui_select)

	# 3. UI Hover / Cursor
	audio_ui_cursor = AudioStreamPlayer.new()
	audio_ui_cursor.name = "AudioUICursor"
	audio_ui_cursor.process_mode = Node.PROCESS_MODE_ALWAYS
	audio_ui_cursor.volume_db = -10.0
	if ResourceLoader.exists("res://assets/audio/menu/UI/ogg/JDSherbert - Ultimate UI SFX Pack - Cursor - 1.ogg"):
		audio_ui_cursor.stream = load("res://assets/audio/menu/UI/ogg/JDSherbert - Ultimate UI SFX Pack - Cursor - 1.ogg")
	add_child(audio_ui_cursor)

	# 4. UI Cancel / Close (Cursor - 2)
	audio_ui_cancel = AudioStreamPlayer.new()
	audio_ui_cancel.name = "AudioUICancel"
	audio_ui_cancel.process_mode = Node.PROCESS_MODE_ALWAYS
	audio_ui_cancel.volume_db = -2.0
	if ResourceLoader.exists("res://assets/audio/menu/UI/ogg/JDSherbert - Ultimate UI SFX Pack - Cursor - 2.ogg"):
		audio_ui_cancel.stream = load("res://assets/audio/menu/UI/ogg/JDSherbert - Ultimate UI SFX Pack - Cursor - 2.ogg")
	add_child(audio_ui_cancel)

	# 4b. UI Retomar / Voltar (Select - 2, mais suave)
	audio_ui_resume = AudioStreamPlayer.new()
	audio_ui_resume.name = "AudioUIResume"
	audio_ui_resume.process_mode = Node.PROCESS_MODE_ALWAYS
	audio_ui_resume.volume_db = -1.0
	if ResourceLoader.exists("res://assets/audio/menu/UI/ogg/JDSherbert - Ultimate UI SFX Pack - Cursor - 5.ogg"):
		audio_ui_resume.stream = load("res://assets/audio/menu/UI/ogg/JDSherbert - Ultimate UI SFX Pack - Cursor - 5.ogg")
	add_child(audio_ui_resume)

	# 4c. UI Back / Menu Principal (Select - 2)
	audio_ui_back = AudioStreamPlayer.new()
	audio_ui_back.name = "AudioUIBack"
	audio_ui_back.process_mode = Node.PROCESS_MODE_ALWAYS
	audio_ui_back.volume_db = -6.0
	if ResourceLoader.exists("res://assets/audio/menu/UI/ogg/JDSherbert - Ultimate UI SFX Pack - Select - 2.ogg"):
		audio_ui_back.stream = load("res://assets/audio/menu/UI/ogg/JDSherbert - Ultimate UI SFX Pack - Select - 2.ogg")
	add_child(audio_ui_back)

	# 5. Objetivo Aparecendo (PICK UP OBJECT)
	audio_obj_appear = AudioStreamPlayer.new()
	audio_obj_appear.name = "AudioObjAppear"
	audio_obj_appear.volume_db = -2.0
	if ResourceLoader.exists("res://assets/audio/ambience/pack itchio PSX/pack itchio PSX/sfx/Objects & Interaction/PICK UP OBJECT.wav"):
		audio_obj_appear.stream = load("res://assets/audio/ambience/pack itchio PSX/pack itchio PSX/sfx/Objects & Interaction/PICK UP OBJECT.wav")
	add_child(audio_obj_appear)

	# 6. Objetivo Diminuindo / Encolhendo (Select - 2)
	audio_obj_shrink = AudioStreamPlayer.new()
	audio_obj_shrink.name = "AudioObjShrink"
	audio_obj_shrink.volume_db = -3.0
	if ResourceLoader.exists("res://assets/audio/menu/UI/ogg/JDSherbert - Ultimate UI SFX Pack - Select - 2.ogg"):
		audio_obj_shrink.stream = load("res://assets/audio/menu/UI/ogg/JDSherbert - Ultimate UI SFX Pack - Select - 2.ogg")
	add_child(audio_obj_shrink)

	# 7. Objetivo Concluído (PUZZLE SOLVED)
	audio_obj_solved = AudioStreamPlayer.new()
	audio_obj_solved.name = "AudioObjSolved"
	audio_obj_solved.volume_db = -2.0
	if ResourceLoader.exists("res://assets/audio/ambience/pack itchio PSX/pack itchio PSX/sfx/Objects & Interaction/PUZZLE SOLVED.wav"):
		audio_obj_solved.stream = load("res://assets/audio/ambience/pack itchio PSX/pack itchio PSX/sfx/Objects & Interaction/PUZZLE SOLVED.wav")
	add_child(audio_obj_solved)

	# 8. Jogo Salvo (SAVE GAME)
	audio_save_game = AudioStreamPlayer.new()
	audio_save_game.name = "AudioSaveGame"
	audio_save_game.volume_db = -3.0
	if ResourceLoader.exists("res://assets/audio/ambience/pack itchio PSX/pack itchio PSX/sfx/Objects & Interaction/SAVE GAME.wav"):
		audio_save_game.stream = load("res://assets/audio/ambience/pack itchio PSX/pack itchio PSX/sfx/Objects & Interaction/SAVE GAME.wav")
	add_child(audio_save_game)

	# 9. Erro / Ação Inválida (WRONG OBJECT)
	audio_wrong_obj = AudioStreamPlayer.new()
	audio_wrong_obj.name = "AudioWrongObj"
	audio_wrong_obj.volume_db = -4.0
	if ResourceLoader.exists("res://assets/audio/ambience/pack itchio PSX/pack itchio PSX/sfx/Objects & Interaction/WRONG OBJECT.wav"):
		audio_wrong_obj.stream = load("res://assets/audio/ambience/pack itchio PSX/pack itchio PSX/sfx/Objects & Interaction/WRONG OBJECT.wav")
	add_child(audio_wrong_obj)

func play_sfx_select() -> void:
	if is_instance_valid(audio_ui_select) and audio_ui_select.stream:
		audio_ui_select.pitch_scale = randf_range(0.97, 1.03)
		audio_ui_select.play()

func play_sfx_cursor() -> void:
	if is_instance_valid(audio_ui_cursor) and audio_ui_cursor.stream:
		audio_ui_cursor.pitch_scale = randf_range(0.97, 1.03)
		audio_ui_cursor.play()

func play_sfx_cancel() -> void:
	if is_instance_valid(audio_ui_cancel) and audio_ui_cancel.stream:
		audio_ui_cancel.play()

func play_sfx_resume() -> void:
	if is_instance_valid(audio_ui_resume) and audio_ui_resume.stream:
		audio_ui_resume.pitch_scale = randf_range(0.98, 1.02)
		audio_ui_resume.play()

func play_sfx_back() -> void:
	if is_instance_valid(audio_ui_back) and audio_ui_back.stream:
		audio_ui_back.pitch_scale = randf_range(0.98, 1.02)
		audio_ui_back.play()

func play_sfx_objective_shrink() -> void:
	if is_instance_valid(audio_obj_shrink) and audio_obj_shrink.stream:
		audio_obj_shrink.pitch_scale = randf_range(0.98, 1.02)
		audio_obj_shrink.play()

func play_objective_completed() -> void:
	if is_instance_valid(audio_obj_solved) and audio_obj_solved.stream:
		audio_obj_solved.play()

func play_game_saved() -> void:
	if is_instance_valid(audio_save_game) and audio_save_game.stream:
		audio_save_game.play()

func play_wrong_action() -> void:
	if is_instance_valid(audio_wrong_obj) and audio_wrong_obj.stream:
		audio_wrong_obj.play()

# ============================================================
# SISTEMA DE AMBIENCE PLAYLIST COM CROSSFADE SUAVE
# ============================================================

func _setup_ambience_system() -> void:
	audio_amb_a = AudioStreamPlayer.new()
	audio_amb_a.name = "AudioAmbienceA"
	audio_amb_a.volume_db = -80.0
	add_child(audio_amb_a)

	audio_amb_b = AudioStreamPlayer.new()
	audio_amb_b.name = "AudioAmbienceB"
	audio_amb_b.volume_db = -80.0
	add_child(audio_amb_b)

	var ambience_paths := [
		"res://assets/audio/ambience/newambiences/soundescape/CalmCozyCityNight.mp3",
		"res://assets/audio/ambience/newambiences/soundescape/Citystreet_distant_siren.mp3",
		"res://assets/audio/ambience/newambiences/soundescape/NightTImeNoSiren.mp3",
		"res://assets/audio/ambience/newambiences/soundescape/Lowkeybizarrenight.mp3",
		"res://assets/audio/ambience/newambiences/soundescape/SoundCityNightWithPoliceSirens.mp3",
		"res://assets/audio/ambience/pack itchio PSX/pack itchio PSX/Soundtracks/Ambience/AMBIENCE WIND.wav",
	]

	_ambience_playlist.clear()
	for p in ambience_paths:
		if ResourceLoader.exists(p):
			var stream = load(p) as AudioStream
			if stream:
				_ambience_playlist.append(stream)

	var storm = get_node_or_null("AudioAmbience") as AudioStreamPlayer
	if storm:
		storm.autoplay = false
		storm.stop()
		storm.volume_db = -80.0

func _get_next_ambience_stream() -> AudioStream:
	if _ambience_playlist.is_empty():
		return null
	if _ambience_playlist.size() == 1:
		return _ambience_playlist[0]
	
	# Quando a fila acaba, re-embaralha e garante que a 1a não seja igual a última que tocou
	if _ambience_queue.is_empty():
		_ambience_queue = _ambience_playlist.duplicate()
		_ambience_queue.shuffle()
		if _ambience_queue[0] == _last_ambience_stream and _ambience_queue.size() > 1:
			var first_item = _ambience_queue.pop_front()
			_ambience_queue.push_back(first_item)
	
	var next_stream = _ambience_queue.pop_front()
	_last_ambience_stream = next_stream
	return next_stream

func _play_next_ambience_crossfade() -> void:
	if _is_ambience_crossfading:
		return
	_is_ambience_crossfading = true

	var stream = _get_next_ambience_stream()
	if not stream:
		_is_ambience_crossfading = false
		return

	var incoming: AudioStreamPlayer = audio_amb_b if _active_amb_is_a else audio_amb_a
	var outgoing: AudioStreamPlayer = audio_amb_a if _active_amb_is_a else audio_amb_b
	_active_amb_is_a = not _active_amb_is_a

	incoming.stream = stream
	incoming.volume_db = -40.0 # Piso inicial de -40dB (sem tempo morto de -80dB)
	incoming.pitch_scale = randf_range(0.98, 1.02)
	incoming.play()

	# Fallback automático: caso a faixa termine inesperadamente, aciona o próximo crossfade
	if not incoming.finished.is_connected(_on_ambience_finished_fallback):
		incoming.finished.connect(_on_ambience_finished_fallback)

	var duration: float = 6.0
	var target_base_db: float = -14.0 if _inside_car_audio else -6.0
	var target_gain: float = db_to_linear(target_base_db)

	# CROSSFADE DE POTÊNCIA CONSTANTE (EQUAL-POWER: sin² + cos² = 1.0)
	# Garante energia sonora ininterrupta sem buraco ou vale de silêncio!
	var tw = create_tween()
	tw.tween_method(func(prog: float):
		var in_gain: float = sin(prog * PI * 0.5) * target_gain
		var out_gain: float = cos(prog * PI * 0.5) * target_gain
		
		if is_instance_valid(incoming):
			incoming.volume_db = max(-40.0, linear_to_db(in_gain)) if in_gain > 0.0001 else -40.0
		if is_instance_valid(outgoing) and outgoing.playing:
			outgoing.volume_db = max(-40.0, linear_to_db(out_gain)) if out_gain > 0.0001 else -40.0
	, 0.0, 1.0, duration)

	tw.finished.connect(func():
		if is_instance_valid(outgoing):
			outgoing.stop()
			outgoing.volume_db = -40.0
		_is_ambience_crossfading = false
	)

func _on_ambience_finished_fallback() -> void:
	if is_instance_valid(self) and not _is_ambience_crossfading:
		_play_next_ambience_crossfade()

# ============================================================
# SISTEMA DE VENTO COM CROSSFADE SUAVE
# ============================================================

func _setup_wind_audio_system() -> void:
	# Cria ou obtém barramento de áudio dedicado 'Wind' para análise de envelope limpa
	_wind_bus_idx = AudioServer.get_bus_index("Wind")
	if _wind_bus_idx == -1:
		AudioServer.add_bus()
		_wind_bus_idx = AudioServer.bus_count - 1
		AudioServer.set_bus_name(_wind_bus_idx, "Wind")
		AudioServer.set_bus_send(_wind_bus_idx, "Master")
	
	audio_wind = AudioStreamPlayer.new()
	audio_wind.name = "AudioWindSeamless"
	audio_wind.volume_db = 0.0 # Volume pleno no bus, controlado pelo master
	audio_wind.bus = "Wind"
	audio_wind.process_mode = Node.PROCESS_MODE_ALWAYS
	add_child(audio_wind)

	# Loop infinito garantido sem pausas
	audio_wind.finished.connect(func():
		if is_instance_valid(audio_wind):
			audio_wind.play()
	)

	var p = "res://assets/audio/Free PSX Wind Ambience/Wind 1.wav"
	if ResourceLoader.exists(p):
		var st = load(p) as AudioStream
		if st:
			audio_wind.stream = st
			audio_wind.play()
	elif ResourceLoader.exists("res://assets/audio/Free PSX Wind Ambience/Wind 3.wav"):
		var st3 = load("res://assets/audio/Free PSX Wind Ambience/Wind 3.wav") as AudioStream
		if st3:
			audio_wind.stream = st3
			audio_wind.play()

# ============================================================
# ESTILIZAÇÃO E CALIBRAÇÃO DINÂMICA DO HUD (VHS OSD)
# ============================================================

func _setup_hud_styling() -> void:
	if not hud:
		return
	
	# Garante que o CRTOverlay fique em z_index = 0 e os elementos do HUD em z_index = 20
	# para que o shader CRT filtre apenas o 3D e todos os textos do HUD fiquem 100% nítidos e limpos
	var crt = hud.get_node_or_null("CRTOverlay") as CanvasItem
	if crt:
		crt.z_index = 0
	if objective_panel:
		objective_panel.z_index = 20
	if timecard_panel:
		timecard_panel.z_index = 20
	if interact_hint:
		interact_hint.z_index = 20
	
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
	_resolver_refs_objetivo()
	if objective_panel:
		var empty_style := StyleBoxEmpty.new()
		objective_panel.add_theme_stylebox_override("panel", empty_style)
		objective_panel.set_anchors_preset(Control.PRESET_TOP_LEFT)
		objective_panel.offset_left = 36.0
		objective_panel.offset_top = 28.0
		objective_panel.offset_right = 420.0
		objective_panel.offset_bottom = 128.0
		objective_panel.pivot_offset = Vector2(0, 0)
		objective_panel.scale = Vector2(1.0, 1.0)
		objective_panel.modulate.a = 0.0
		objective_panel.hide()
	if objective_label:
		objective_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
		objective_label.vertical_alignment = VERTICAL_ALIGNMENT_TOP
		objective_label.autowrap_mode = TextServer.AUTOWRAP_OFF
		objective_label.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
		if font_retro:
			objective_label.add_theme_font_override("font", font_retro)
		objective_label.add_theme_font_size_override("font_size", 18)
		objective_label.add_theme_color_override("font_color", Color(0.95, 0.95, 0.97, 1.0))
		objective_label.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 1.0))
		objective_label.add_theme_constant_override("shadow_offset_x", 2)
		objective_label.add_theme_constant_override("shadow_offset_y", 2)
		objective_label.add_theme_constant_override("line_spacing", 0)

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
		
		# Fundo semitransparente escurecido que consome cliques (impede travamento do mouse)
		var dark_dim = ColorRect.new()
		dark_dim.color = Color(0.0, 0.0, 0.0, 0.65)
		dark_dim.set_anchors_preset(Control.PRESET_FULL_RECT)
		dark_dim.mouse_filter = Control.MOUSE_FILTER_STOP
		pause_menu_control.mouse_filter = Control.MOUSE_FILTER_STOP
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
		btn_resume.text = "► RETOMAR JOGO"
		btn_resume.alignment = HORIZONTAL_ALIGNMENT_LEFT
		btn_resume.process_mode = Node.PROCESS_MODE_ALWAYS
		if font_retro:
			btn_resume.add_theme_font_override("font", font_retro)
		btn_resume.add_theme_font_size_override("font_size", 18)
		btn_resume.add_theme_color_override("font_color", Color(1, 1, 1, 1))
		btn_resume.add_theme_color_override("font_hover_color", Color(1, 0.3, 0.3, 1))
		btn_resume.flat = true
		btn_resume.mouse_entered.connect(play_sfx_cursor)
		btn_resume.pressed.connect(func():
			play_sfx_back()
			_toggle_pause()
		)
		vbox.add_child(btn_resume)
		
		# Slider Volume Geral
		var lbl_vol = Label.new()
		lbl_vol.text = "VOLUME GERAL"
		if font_retro:
			lbl_vol.add_theme_font_override("font", font_retro)
		lbl_vol.add_theme_font_size_override("font_size", 15)
		lbl_vol.add_theme_color_override("font_color", Color(0.9, 0.9, 0.9, 1))
		vbox.add_child(lbl_vol)
		
		var slider_vol = HSlider.new()
		slider_vol.min_value = 0.0
		slider_vol.max_value = 1.0
		slider_vol.step = 0.05
		slider_vol.value = db_to_linear(AudioServer.get_bus_volume_db(AudioServer.get_bus_index("Master")))
		slider_vol.mouse_entered.connect(play_sfx_cursor)
		slider_vol.value_changed.connect(func(v: float):
			AudioServer.set_bus_volume_db(AudioServer.get_bus_index("Master"), linear_to_db(v))
		)
		vbox.add_child(slider_vol)
		
		# Slider SFX
		var lbl_sfx = Label.new()
		lbl_sfx.text = "VOLUME DE EFEITOS (SFX)"
		if font_retro:
			lbl_sfx.add_theme_font_override("font", font_retro)
		lbl_sfx.add_theme_font_size_override("font_size", 15)
		lbl_sfx.add_theme_color_override("font_color", Color(0.9, 0.9, 0.9, 1))
		vbox.add_child(lbl_sfx)
		
		var slider_sfx = HSlider.new()
		slider_sfx.min_value = 0.0
		slider_sfx.max_value = 1.0
		slider_sfx.step = 0.05
		slider_sfx.value = 0.8
		slider_sfx.mouse_entered.connect(play_sfx_cursor)
		slider_sfx.drag_ended.connect(func(_val): play_sfx_select())
		vbox.add_child(slider_sfx)
		
		# Opção Tela Cheia
		var check_fs = CheckBox.new()
		check_fs.text = " TELA CHEIA (FULLSCREEN)"
		if font_retro:
			check_fs.add_theme_font_override("font", font_retro)
		check_fs.add_theme_font_size_override("font_size", 15)
		check_fs.add_theme_color_override("font_color", Color(0.9, 0.9, 0.9, 1))
		check_fs.button_pressed = (DisplayServer.window_get_mode() == DisplayServer.WINDOW_MODE_FULLSCREEN)
		check_fs.mouse_entered.connect(play_sfx_cursor)
		check_fs.toggled.connect(func(b: bool):
			play_sfx_select()
			if b:
				DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN)
			else:
				DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
		)
		vbox.add_child(check_fs)
		
		var sep2 = HSeparator.new()
		vbox.add_child(sep2)
		
		# Botão Menu Principal
		var btn_main = Button.new()
		btn_main.text = "► MENU PRINCIPAL"
		btn_main.alignment = HORIZONTAL_ALIGNMENT_LEFT
		btn_main.process_mode = Node.PROCESS_MODE_ALWAYS
		if font_retro:
			btn_main.add_theme_font_override("font", font_retro)
		btn_main.add_theme_font_size_override("font_size", 18)
		btn_main.add_theme_color_override("font_color", Color(0.85, 0.85, 0.85, 1))
		btn_main.add_theme_color_override("font_hover_color", Color(1, 0.3, 0.3, 1))
		btn_main.flat = true
		btn_main.mouse_entered.connect(play_sfx_cursor)
		btn_main.pressed.connect(func():
			play_sfx_back()
			_on_main_menu_pressed()
		)
		vbox.add_child(btn_main)
		
		hud.add_child(pause_menu_control)
		pause_menu_control.hide()

func _input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel") or (event is InputEventKey and event.pressed and event.keycode == KEY_ESCAPE):
		# Se o inventário estiver aberto, NÃO abre o menu de pausa! O inventário fecha sozinho.
		var p = get_node_or_null("PlayerController")
		if is_instance_valid(p) and "_inventario_aberto" in p and p._inventario_aberto:
			return
		_toggle_pause()

func _toggle_pause() -> void:
	if not pause_menu_control:
		return
	is_paused = not is_paused
	pause_menu_control.visible = is_paused
	get_tree().paused = is_paused
	if is_paused:
		play_sfx_cursor()
		Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
	else:
		Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)

func _on_main_menu_pressed() -> void:
	get_tree().paused = false
	get_tree().change_scene_to_file("res://scenes/ui/title_screen.tscn")

# ============================================================
# HUD / TIMECARD / OBJETIVOS - ESTÉTICA VHS RETRÔ PROFISSIONAL
# ============================================================

func _show_timecard(local_text: String, hora_text: String, duration: float = 6.0) -> void:
	if not timecard_panel or not timecard_label:
		return
	
	if font_retro:
		timecard_label.add_theme_font_override("font", font_retro)
	timecard_label.add_theme_font_size_override("font_size", 22)
	timecard_label.add_theme_color_override("font_color", Color(0.88, 0.90, 0.94, 1.0))
	timecard_label.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 1.0))
	timecard_label.add_theme_constant_override("shadow_offset_x", 2)
	timecard_label.add_theme_constant_override("shadow_offset_y", 2)
	timecard_label.add_theme_constant_override("line_spacing", 4)
	
	timecard_label.text = local_text.to_upper() + "\n" + hora_text
	timecard_panel.modulate.a = 0.0
	timecard_panel.show()
	
	var tween = create_tween()
	tween.tween_property(timecard_panel, "modulate:a", 1.0, 0.4)
	tween.tween_interval(duration)
	tween.tween_property(timecard_panel, "modulate:a", 0.0, 0.8)
	tween.tween_callback(timecard_panel.hide)


var _popup_documentos: CanvasLayer = null

func _resolver_refs_objetivo() -> void:
	if not is_instance_valid(objective_panel) and is_instance_valid(hud):
		objective_panel = hud.get_node_or_null("ObjectivePanel")
	if not is_instance_valid(objective_label) and is_instance_valid(hud):
		objective_label = hud.find_child("ObjectiveLabel", true, false) as Label

func _mostrar_popup_documentos() -> void:
	var inv = get_node_or_null("/root/Inventario")
	if not inv or inv.itens.is_empty():
		return
	if not is_instance_valid(_popup_documentos):
		var popup_scene: PackedScene = load("res://scenes/ui/item_pickup_popup.tscn")
		if popup_scene:
			_popup_documentos = popup_scene.instantiate()
			get_tree().root.add_child(_popup_documentos)
	if is_instance_valid(_popup_documentos) and _popup_documentos.has_method("mostrar"):
		_popup_documentos.mostrar(inv.itens[0])

func _esconder_popup_documentos() -> void:
	if is_instance_valid(_popup_documentos) and _popup_documentos.has_method("esconder"):
		_popup_documentos.esconder()

func _set_objective(text: String, transition: bool = true) -> void:
	_resolver_refs_objetivo()
	if not objective_panel or not objective_label: return
	_objective_typing_token += 1
	var my_token = _objective_typing_token
	
	var clean_text = text.strip_edges()
	if clean_text.to_upper().begins_with("OBJETIVO:"):
		clean_text = clean_text.substr(9).strip_edges()
	
	if font_retro:
		objective_label.add_theme_font_override("font", font_retro)
	objective_label.add_theme_font_size_override("font_size", 18)
	objective_label.add_theme_color_override("font_color", Color(0.95, 0.95, 0.97, 1.0))
	objective_label.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 1.0))
	objective_label.add_theme_constant_override("shadow_offset_x", 2)
	objective_label.add_theme_constant_override("shadow_offset_y", 2)
	objective_label.add_theme_constant_override("line_spacing", 0)
	objective_label.autowrap_mode = TextServer.AUTOWRAP_OFF
	objective_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	objective_label.vertical_alignment = VERTICAL_ALIGNMENT_TOP
	objective_label.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	objective_panel.pivot_offset = Vector2(0, 0)
	
	# Exibe o painel PRIMEIRO — som dispara no mesmo frame que fica visivel
	objective_panel.scale = Vector2(1.0, 1.0)
	objective_panel.position = Vector2(36.0, 28.0)
	objective_panel.modulate.a = 1.0
	objective_panel.show()
	
	# Popup do item inicial no mesmo instante do objetivo (some junto no shrink de 10s)
	if _docs_popup_com_objetivo:
		_docs_popup_com_objetivo = false
		_mostrar_popup_documentos()
	
	# 10s a partir do momento em que objetivo + popup aparecem
	_start_objective_idle_shrink(my_token)
	
	# Som dispara logo apos o painel aparecer
	if is_instance_valid(audio_obj_appear):
		audio_obj_appear.play()
	
	if not transition:
		objective_label.text = "OBJETIVO:\n" + clean_text.to_upper()
		return
	
	# Efeito Profissional de Digitação VHS / Typewriter IMEDIATO (sem delay de apagar)
	objective_label.text = "OBJETIVO:\n"
	
	# Inicia som de máquina de escrever sincronizado com o 1o caractere digitado
	if is_instance_valid(audio_typewriter):
		audio_typewriter.pitch_scale = randf_range(0.98, 1.02)
		audio_typewriter.play()
	
	# Digita novo conteúdo caractere por caractere
	var target_body = clean_text.to_upper()
	var typed = ""
	for i in range(target_body.length()):
		if my_token != _objective_typing_token:
			if is_instance_valid(audio_typewriter):
				audio_typewriter.stop()
			return
		typed += target_body[i]
		objective_label.text = "OBJETIVO:\n" + typed
		await get_tree().create_timer(0.035).timeout
	
	# Para o som da máquina de escrever exatamente ao terminar a digitação
	if is_instance_valid(audio_typewriter):
		audio_typewriter.stop()

func _start_objective_idle_shrink(token: int) -> void:
	await get_tree().create_timer(10.0).timeout
	if token == _objective_typing_token and is_instance_valid(objective_panel):
		_esconder_popup_documentos()
		# Toca o som quando o objetivo for encolher (Select - 2)
		play_sfx_objective_shrink()
		
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
# SISTEMA DE VEGETAÇÃO E VENTO REALISTA (SHADERS + RAJADAS)
# ============================================================

func _aplicar_vento_automatico_em_todas_arvores() -> void:
	var wind_shader = load("res://shaders/vento_arvore.gdshader") as Shader
	if not wind_shader:
		return
	
	_tree_materials.clear()
	var mat_cache := {}
	var mesh_instances = find_children("*", "MeshInstance3D", true, false)
	
	var tree_idx: int = 0
	for m in mesh_instances:
		var mi := m as MeshInstance3D
		var full_name = (mi.name + " " + mi.get_parent().name).to_lower()
		
		# IGNORA POSTES, LUZES DE RUA (street_light), SEMÁFOROS E LÂMPADAS
		if "street" in full_name or "post" in full_name or "light" in full_name or "lamp" in full_name or "semaforo" in full_name or "traffic" in full_name:
			continue
		
		if "tree" in full_name or "arvore" in full_name or "palm" in full_name or \
		   "palmeira" in full_name or "bosquinho" in full_name or "folha" in full_name or \
		   "branch" in full_name or "commontree" in full_name or "grass_p" in full_name or \
		   "bush" in full_name or "arbusto" in full_name or "vegetat" in full_name:
			
			# CLASSIFICAÇÃO POR PERFIL DE ESPÉCIE
			# 0 = Conífera/Pinheiro (rígido, uniforme)
			# 1 = Árvore Larga/Copada (tronco firme, copa viva)
			# 2 = Árvore Fina/Palmeira/Arbusto (haste flexível)
			var tipo: int = 1
			if "tree_rt" in full_name or "pinheiro" in full_name or "pine" in full_name:
				tipo = 0
			elif "small" in full_name or "palm" in full_name or "palmeira" in full_name or "bush" in full_name or "arbusto" in full_name or "grass" in full_name:
				tipo = 2
			
			var mat_count = mi.get_surface_override_material_count()
			if mat_count == 0 and mi.mesh:
				mat_count = mi.mesh.get_surface_count()
			
			tree_idx += 1
			# Distribui seeds e variações para evitar sincronização mecânica ("puxar corda")
			var seed_bucket = (tree_idx % 5)
			
			for s in range(max(1, mat_count)):
				var active_mat = mi.get_active_material(s)
				var albedo_tex: Texture2D = null
				if active_mat is BaseMaterial3D and active_mat.albedo_texture:
					albedo_tex = active_mat.albedo_texture
				
				var tex_key = albedo_tex.resource_path if albedo_tex else ("mat_" + str(mi.name) + "_" + str(s))
				var cache_key = tex_key + "_t" + str(tipo) + "_s" + str(seed_bucket)
				var sm: ShaderMaterial
				if mat_cache.has(cache_key):
					sm = mat_cache[cache_key]
				else:
					sm = ShaderMaterial.new()
					sm.shader = wind_shader
					if albedo_tex:
						sm.set_shader_parameter("texture_albedo", albedo_tex)
					sm.set_shader_parameter("direcao_vento", _wind_direction)
					sm.set_shader_parameter("tipo_arvore", tipo)
					sm.set_shader_parameter("seed_individual", float(seed_bucket) * 7.3)
					sm.set_shader_parameter("velocidade_vento", 0.35)
					sm.set_shader_parameter("forca_vento", 0.85)
					sm.set_shader_parameter("forca_flutter", 0.025)
					mat_cache[cache_key] = sm
					_tree_materials.append(sm)
					if clima_manager:
						clima_manager.tree_materials.append(sm)
				
				mi.set_surface_override_material(s, sm)

func _setup_wind_particles() -> void:
	# Partículas de Folhas Voando no Vento (Sincronizadas com direção e intensidade real)
	var leaves_particles := GPUParticles3D.new()
	leaves_particles.name = "WindLeavesParticles"
	leaves_particles.amount = 110
	leaves_particles.lifetime = 4.0
	leaves_particles.preprocess = 2.0
	leaves_particles.explosiveness = 0.0
	leaves_particles.randomness = 0.4
	
	_wind_leaves_mat = ParticleProcessMaterial.new()
	_wind_leaves_mat.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
	_wind_leaves_mat.emission_box_extents = Vector3(28.0, 8.0, 28.0)
	_wind_leaves_mat.direction = Vector3(_wind_direction.x, -0.15, _wind_direction.y).normalized()
	_wind_leaves_mat.spread = 15.0
	_wind_leaves_mat.initial_velocity_min = 12.0
	_wind_leaves_mat.initial_velocity_max = 20.0
	_wind_leaves_mat.gravity = Vector3(_wind_direction.x * 0.6, -1.1, _wind_direction.y * 0.6)
	_wind_leaves_mat.scale_min = 0.08
	_wind_leaves_mat.scale_max = 0.22
	_wind_leaves_mat.color = Color(0.85, 0.45, 0.12, 0.85)
	
	leaves_particles.process_material = _wind_leaves_mat
	
	var quad := QuadMesh.new()
	quad.size = Vector2(0.18, 0.18)
	var quad_mat := StandardMaterial3D.new()
	quad_mat.shading_mode = StandardMaterial3D.SHADING_MODE_UNSHADED
	quad_mat.albedo_color = Color(0.88, 0.48, 0.15, 0.88)
	quad_mat.billboard_mode = StandardMaterial3D.BILLBOARD_PARTICLES
	quad.material = quad_mat
	leaves_particles.draw_pass_1 = quad
	
	if player:
		player.add_child(leaves_particles)
		leaves_particles.position = Vector3(0.0, 4.5, 0.0)
	else:
		add_child(leaves_particles)
		leaves_particles.position = Vector3(0.0, 4.5, 0.0)

# ============================================================
# CONTROLADOR DE RAJADAS DINÂMICAS DE VENTO (Espaçadas e Raras)
# ============================================================

func _process(delta: float) -> void:
	_update_wind_systems(delta)
	_monitor_ambience_playback(delta)

func _monitor_ambience_playback(_delta: float) -> void:
	if _is_ambience_crossfading:
		return
	
	var cur_player: AudioStreamPlayer = audio_amb_a if _active_amb_is_a else audio_amb_b
	if is_instance_valid(cur_player) and cur_player.playing:
		var st: AudioStream = cur_player.stream
		if st:
			var total_len: float = st.get_length() if st.has_method("get_length") else 0.0
			if total_len > 12.0:
				var cur_pos: float = cur_player.get_playback_position()
				# Inicia o crossfade suave quando faltarem 6.5s para terminar a faixa real
				if total_len - cur_pos <= 6.5:
					_play_next_ambience_crossfade()

func _start_dynamic_wind_system() -> void:
	# O sistema agora é 100% reativo ao áudio real do arquivo de vento (Opção A)
	pass

func _update_wind_systems(delta: float) -> void:
	# LÊ A ENERGIA REAL DO ÁUDIO DE VENTO EM TEMPO REAL
	var peak_db: float = -24.0
	if _wind_bus_idx >= 0 and _wind_bus_idx < AudioServer.bus_count:
		var p_left: float = AudioServer.get_bus_peak_volume_left_db(_wind_bus_idx, 0)
		var p_right: float = AudioServer.get_bus_peak_volume_right_db(_wind_bus_idx, 0)
		peak_db = max(p_left, p_right)
	
	# Mapeamento calibrado com a faixa real do arquivo de som (-24.0 dB calmo .. -12.5 dB rajada máxima)
	var raw_energy: float = clamp((peak_db - (-24.0)) / 11.5, 0.0, 1.0)
	
	# Filtro de Inércia de Massa de Ar: Ataque orgânico (3.2) e retorno lento (1.6)
	if raw_energy > _wind_audio_energy:
		_wind_audio_energy = lerp(_wind_audio_energy, raw_energy, delta * 3.2)
	else:
		_wind_audio_energy = lerp(_wind_audio_energy, raw_energy, delta * 1.6)
	
	var energy: float = clamp(_wind_audio_energy, 0.0, 1.0)
	
	# 1. SHADER DAS ÁRVORES: Amplitude forte e dramática (Fears to Fathom Storm)
	# Vento base constante: 0.85 (balanço bem evidente). Rajada forte: 2.35 (envergadura profunda e dramática)
	var cur_forca: float = lerp(0.85, 2.35, energy)
	var cur_flutter: float = lerp(0.015, 0.045, energy)
	
	for sm in _tree_materials:
		if is_instance_valid(sm):
			sm.set_shader_parameter("forca_vento", cur_forca)
			sm.set_shader_parameter("forca_flutter", cur_flutter)
	
	# 2. PARTÍCULAS DE FOLHAS: Folhas voam rápido e longe
	if _wind_leaves_mat:
		_wind_leaves_mat.initial_velocity_min = lerp(12.0, 32.0, energy)
		_wind_leaves_mat.initial_velocity_max = lerp(20.0, 48.0, energy)

# ============================================================
# PRÓLOGO — TELA PRETA / INTERIOR DO CARRO / VHS
# ============================================================

func _play_opening_sequence() -> void:
	print("[Prologue] INIT — Ordem: 1s silêncio -> diálogo -> 3s silêncio -> sair do carro -> (libera controle) -> VHS -> carro ir embora")
	_intro_lock = true
	if fade_rect:
		fade_rect.color = Color(0, 0, 0, 1)
		fade_rect.show()
	if objective_panel:
		objective_panel.hide()
	if timecard_panel:
		timecard_panel.hide()
	
	_set_world_audio_for_car_interior(true)
	_start_car_interior_ambience()
	
	# 1 segundo apenas de ambiente do carro parado + tela preta, sem ninguém falando
	await get_tree().create_timer(1.0).timeout
	print("[Prologue] Passou 1s. Disparando diálogo do prólogo.")
	await _play_prologue_dialogue()
	print("[Prologue] Diálogo ACABOU. Esperando 3s de silêncio do motor ligado.")
	await get_tree().create_timer(3.0).timeout
	
	print("[Prologue] Tocando som de saindo do carro (abrir/fechar porta).")
	await _play_leaving_car_sfx()
	
	# Fade out da tela preta = Alice está lá fora. LIBERA CONTROLE IMEDIATAMENTE.
	_intro_lock = false
	if player and player.has_method("unfreeze"):
		player.unfreeze()
		print("[Prologue] Alice LIBERADA (unfreeze) ANTES do VHS. Câmera e mouse livres.")
	if fade_rect:
		var fade_tw := create_tween()
		fade_tw.tween_property(fade_rect, "color:a", 0.0, 0.55)
		fade_tw.tween_callback(fade_rect.hide)
	
	print("[Prologue] Disparando boot VHS, HUD aparece (controle já está livre).")
	await _play_vhs_intro_sequence()
	print("[Prologue] VHS acabou. Dirigindo embora.")
	_set_world_audio_for_car_interior(false)
	_drive_parents_car_away()
	await get_tree().create_timer(1.4).timeout
	print("[Prologue] Disparando pensamentos da Alice na calçada.")
	await _play_alice_sidewalk_thoughts()
	print("[Prologue] FIM TOTAL DO PRÓLOGO.")

func _prologue_lines() -> Array:
	return [
		{"speaker": "Mãe", "text": "Você pode ir fazer a matrícula agora, Alice?"},
		{"speaker": "Pai", "text": "Meio que…"},
		{"speaker": "Pai", "text": "Sua mãe e eu precisamos buscar seu irmão agora…"},
		{"speaker": "Alice", "text": "Aff…"},
		{"speaker": "Alice", "text": "Não é possível que vocês me deixem fazer isso sozinha…"},
		{"speaker": "Mãe", "text": "Filha, você já tem que começar a assumir responsabilidades..."},
		{"speaker": "Alice", "text": "De novo isso, mãe?"},
		{"speaker": "Mãe", "text": "A gente precisa buscar o Bob na escola agora."},
		{"speaker": "Mãe", "text": "Não tem outra escolha."},
		{"speaker": "Alice", "text": "Tá bom então, mãe…"},
		{"speaker": "Alice", "text": "É que tá muito estranho aqui."},
		{"speaker": "Alice", "text": "Sério, olha isso."},
		{"speaker": "Alice", "text": "(aponta pra fora)", "thought": true},
		{"speaker": "Alice", "text": "Tá muito escuro e ventando demais, tá totalmente uncanny!"},
		{"speaker": "Alice", "text": "Por que a gente não faz isso amanhã?"},
		{"speaker": "Pai", "text": "Coloca essa blusa e desce logo."},
		{"speaker": "Pai", "text": "Quanto mais rápido for, mais rápido acaba."},
		{"speaker": "Pai", "text": "Quando você terminar, liga pra gente."},
		{"speaker": "Pai", "text": "Aí eu passo aqui pra te buscar, ok?"},
		{"speaker": "Alice", "text": "Tá bom então, eu aviso. Tô descendo…"},
		{"speaker": "Mãe", "text": "Se cuida, filha!"},
		{"speaker": "Alice", "text": "Vou me cuidar, mãe. Fica tranquila."},
		{"speaker": "Pai", "text": "Tá com os documentos?"},
		{"speaker": "Alice", "text": "Quase tinha esquecido."},
		{"speaker": "Alice", "text": "(risada disfarçada)", "thought": true},
		{"speaker": "Mãe", "text": "Tchau, te amo!"},
		{"speaker": "Mãe", "text": "A gente se vê daqui a pouquinho!"},
		{"speaker": "Pai", "text": "Tchau, filha. Qualquer coisa, liga."},
		{"speaker": "Alice", "text": "Tchau, mãe. Te amo."},
		{"speaker": "Alice", "text": "Tchau, pai. Te amo."},
		{"speaker": "Alice", "text": "Até daqui a pouco!"},
	]

func _await_dialogue_with_timeout(timeout_s: float = 300.0) -> void:
	if not dialogue_ui:
		return
	var timed_out := false
	var finished_emitted := false
	var timeout_timer = get_tree().create_timer(timeout_s, false)
	timeout_timer.timeout.connect(func():
		timed_out = true
		print("[Prologue] ⚠️ TIMEOUT do diálogo disparado após ", timeout_s, "s — forçando continuação.")
	)
	while dialogue_ui and dialogue_ui.has_method("is_active") and dialogue_ui.is_active() and not timed_out:
		await dialogue_ui.dialogue_finished
		finished_emitted = true
		break
	if timed_out and dialogue_ui and dialogue_ui.has_method("_finish_dialogue"):
		dialogue_ui._finish_dialogue()
		finished_emitted = true
	print("[Prologue] Diálogo terminou. finished_emitted=", finished_emitted, " timeout=", timed_out)

func _play_prologue_dialogue() -> void:
	if not dialogue_ui or not dialogue_ui.has_method("start_dialogue"):
		print("[Prologue] ⚠️ DialogueUI não tem start_dialogue! Pulando diálogo.")
		return
	print("[Prologue] Chamando dialogue_ui.start_dialogue prologue com black_screen=true")
	dialogue_ui.start_dialogue(_prologue_lines(), true)
	await _await_dialogue_with_timeout(300.0)

func _play_alice_sidewalk_thoughts() -> void:
	if not dialogue_ui or not dialogue_ui.has_method("start_dialogue"):
		print("[Prologue] ⚠️ DialogueUI não tem start_dialogue! Pulando pensamentos.")
		return
	print("[Prologue] Chamando dialogue_ui.start_dialogue pensamentos calçada")
	dialogue_ui.start_dialogue([
		{"speaker": "Alice", "text": "(É rapidinho…)", "thought": true},
		{"speaker": "Alice", "text": "(só entregar os documentos…)", "thought": true},
		{"speaker": "Alice", "text": "('Documentos' é uma palavra engraçada.)", "thought": true},
	], false)
	await _await_dialogue_with_timeout(60.0)

func _ensure_audio_bus(bus_name: String, cutoff_hz: float = -1.0) -> void:
	var idx := AudioServer.get_bus_index(bus_name)
	if idx == -1:
		AudioServer.add_bus()
		idx = AudioServer.bus_count - 1
		AudioServer.set_bus_name(idx, bus_name)
		AudioServer.set_bus_send(idx, "Master")
	if cutoff_hz > 0.0:
		var lp_fx: AudioEffectLowPassFilter = null
		for i in range(AudioServer.get_bus_effect_count(idx)):
			var fx = AudioServer.get_bus_effect(idx, i)
			if fx is AudioEffectLowPassFilter:
				lp_fx = fx as AudioEffectLowPassFilter
				break
		if lp_fx == null:
			lp_fx = AudioEffectLowPassFilter.new()
			AudioServer.add_bus_effect(idx, lp_fx)
		lp_fx.cutoff_hz = cutoff_hz
		lp_fx.resonance = 0.42

func _loop_stream_if_possible(stream: AudioStream) -> void:
	if stream == null:
		return
	if stream is AudioStreamOggVorbis:
		(stream as AudioStreamOggVorbis).loop = true
	elif stream is AudioStreamWAV:
		(stream as AudioStreamWAV).loop_mode = AudioStreamWAV.LOOP_FORWARD
	elif stream is AudioStreamMP3:
		(stream as AudioStreamMP3).loop = true

func _start_car_interior_ambience() -> void:
	_ensure_audio_bus("CarInterior", 1400.0)
	
	_audio_car_idle = AudioStreamPlayer.new()
	_audio_car_idle.name = "PrologueCarIdle"
	_audio_car_idle.volume_db = -11.0
	var idle_path := "res://assets/models/car/psx/Sound effects/Car_Engine_Loop.ogg"
	if ResourceLoader.exists(idle_path):
		var idle_st = load(idle_path) as AudioStream
		_loop_stream_if_possible(idle_st)
		_audio_car_idle.stream = idle_st
	add_child(_audio_car_idle)
	_audio_car_idle.play()

func _fade_out_player(player_node: AudioStreamPlayer, duration: float = 1.2) -> void:
	if not is_instance_valid(player_node):
		return
	var tw := create_tween()
	tw.tween_property(player_node, "volume_db", -50.0, duration)
	await tw.finished
	if is_instance_valid(player_node):
		player_node.stop()
		player_node.queue_free()

func _play_leaving_car_sfx() -> void:
	# O MOTOR CONTINUA LIGADO! Pais só desligam depois que já foram embora.
	# Removemos o fade_out do _audio_car_idle aqui; ele só para com o carro.
	if is_instance_valid(_audio_car_road):
		_fade_out_player(_audio_car_road, 1.0)
	
	var door_path := "res://assets/audio/things/CarDoorOpen.mp3"
	if not ResourceLoader.exists(door_path):
		door_path = "res://assets/models/car/psx/Sound effects/Car_Door_Open.ogg"
	if ResourceLoader.exists(door_path):
		var sfx_door := AudioStreamPlayer.new()
		sfx_door.name = "CarDoorAudio"
		sfx_door.stream = load(door_path)
		sfx_door.volume_db = 0.0
		add_child(sfx_door)
		sfx_door.play()
		await sfx_door.finished
		sfx_door.queue_free()
	
	var close_path := "res://assets/models/car/psx/Sound effects/Car_Door_Close.ogg"
	if ResourceLoader.exists(close_path):
		var sfx_close := AudioStreamPlayer.new()
		sfx_close.stream = load(close_path)
		sfx_close.volume_db = -2.0
		add_child(sfx_close)
		sfx_close.play()
		await sfx_close.finished
		sfx_close.queue_free()
	
	await get_tree().create_timer(0.4).timeout

func _set_world_audio_for_car_interior(inside: bool) -> void:
	_inside_car_audio = inside
	# Mundo lá fora: grave abafado, agudos cortados, como se passasse pela lataria.
	_ensure_audio_bus("WorldOutside", 780.0 if inside else 12000.0)
	var outside_idx := AudioServer.get_bus_index("WorldOutside")
	if outside_idx >= 0:
		AudioServer.set_bus_volume_db(outside_idx, -10.0 if inside else 0.0)
	var world_bus := "WorldOutside" if inside else "Master"
	
	var storm = get_node_or_null("AudioAmbience") as AudioStreamPlayer
	if storm:
		storm.bus = world_bus
		storm.volume_db = -16.0 if inside else -6.0
		if not storm.playing:
			storm.play()
	if is_instance_valid(audio_amb_a):
		audio_amb_a.bus = world_bus
	if is_instance_valid(audio_amb_b):
		audio_amb_b.bus = world_bus
	if _wind_bus_idx >= 0 and _wind_bus_idx < AudioServer.bus_count:
		AudioServer.set_bus_send(_wind_bus_idx, "WorldOutside" if inside else "Master")
	if is_instance_valid(audio_wind):
		audio_wind.volume_db = -8.0 if inside else 0.0
		if not audio_wind.playing:
			audio_wind.play()
	if not _is_ambience_crossfading and not _ambience_playlist.is_empty():
		if is_instance_valid(audio_amb_a) and not audio_amb_a.playing and is_instance_valid(audio_amb_b) and not audio_amb_b.playing:
			_play_next_ambience_crossfade()

func _setup_parents_car() -> void:
	var dummy = get_node_or_null("CefetExterior/ParentsCar")
	if dummy:
		dummy.visible = false
		if dummy is CSGShape3D:
			(dummy as CSGShape3D).use_collision = false
	
	var packed: PackedScene = null
	if ResourceLoader.exists("res://scenes/vehicles/car_01_gray.tscn"):
		packed = load("res://scenes/vehicles/car_01_gray.tscn") as PackedScene
	elif ResourceLoader.exists("res://scenes/vehicles/car_01_default.tscn"):
		packed = load("res://scenes/vehicles/car_01_default.tscn") as PackedScene
	if packed == null:
		return
	
	_parents_car = packed.instantiate()
	_parents_car.name = "ParentsCarReal"
	var exterior = get_node_or_null("CefetExterior")
	if exterior:
		exterior.add_child(_parents_car)
	else:
		add_child(_parents_car)
	
	# Alice na calçada (~z 16.5). Carro PARADO NA FAIXA (não no passeio),
	# do lado direito da rua, ela acabou de descer. Sentido do tráfego: +X
	# (rua acima). Capô do mesh aponta para +Z local; look_at aponta -Z do
	# objeto para o alvo, então para o capô ficar virado para +X, fazemos
	# look_at mirar para o lado OPOSTO do movimento (-X) => -Z do carro
	# aponta para -X => +Z do carro (capô) aponta para +X = CORRETO.
	var street_pos := Vector3(37.8, 0.22, 23.4)
	if player:
		street_pos = Vector3(player.global_position.x - 3.6, 0.22, max(21.8, player.global_position.z + 5.8))
	_parents_car.global_position = street_pos
	_parents_car.look_at(street_pos + Vector3(-1.0, 0.0, 0.0), Vector3.UP)
	
	# RayCast3D na frente do capô (+Z local) para detectar carros/obstáculos
	# e frear antes de atravessar.
	var rc := RayCast3D.new()
	rc.name = "ParentsCarFrontRay"
	rc.target_position = Vector3(0.0, 0.6, 7.5)
	rc.collision_mask = 4294967295
	rc.debug_shape_custom_color = Color(1, 0.3, 0.3, 1)
	_parents_car.add_child(rc)
	rc.enabled = true
	for cs in _parents_car.find_children("*", "CollisionShape3D", true, false):
		if cs.has_method("get_shape_owner_rids"):
			rc.add_exception(cs)
	for cpoly in _parents_car.find_children("*", "CollisionPolygon3D", true, false):
		rc.add_exception(cpoly)
	for co in _parents_car.find_children("*", "CollisionObject3D", true, false):
		rc.add_exception(co)
	if _parents_car is CollisionObject3D:
		rc.add_exception(_parents_car)
	
	var engine = _parents_car.get_node_or_null("EngineAudio") as AudioStreamPlayer3D
	if engine:
		engine.autoplay = false
		engine.stop()
		_loop_stream_if_possible(engine.stream)

func _drive_parents_car_away() -> void:
	if not is_instance_valid(_parents_car):
		return
	
	# 1) PAUSA TODO O GERENCIADOR DE CARROS para não spawnar nada na nossa rota
	var cm: Node = get_node_or_null("/root/CarroManager") as Node
	var cm_old_process_mode: int = Node.PROCESS_MODE_INHERIT
	if cm:
		cm_old_process_mode = cm.process_mode
		cm.process_mode = Node.PROCESS_MODE_DISABLED
	# Também desativa TODAS as Path3D de rota de carro por garantia
	var paths_paused: Array[NodePath] = []
	for p in get_tree().get_nodes_in_group("car_route"):
		if p and p is Path3D:
			paths_paused.append(p.get_path())
			p.process_mode = Node.PROCESS_MODE_DISABLED
	
	var startup_path := "res://assets/models/car/psx/Sound effects/Car_Engine_Start_Up.ogg"
	if ResourceLoader.exists(startup_path):
		var sfx := AudioStreamPlayer3D.new()
		sfx.stream = load(startup_path)
		sfx.volume_db = -16.0
		sfx.unit_size = 28.0
		sfx.max_distance = 120.0
		_parents_car.add_child(sfx)
		sfx.play()
	
	var engine = _parents_car.get_node_or_null("EngineAudio") as AudioStreamPlayer3D
	if engine:
		engine.volume_db = -8.0
		engine.play()
	
	var accel_path := "res://assets/models/car/psx/Sound effects/Car_Acceleration.ogg"
	if ResourceLoader.exists(accel_path):
		var acc := AudioStreamPlayer3D.new()
		acc.stream = load(accel_path)
		acc.volume_db = -12.0
		acc.unit_size = 32.0
		_parents_car.add_child(acc)
		acc.play()
	
	for light_name in ["TaillightL", "TaillightR"]:
		var tl = _parents_car.get_node_or_null(light_name) as OmniLight3D
		if tl:
			tl.light_energy = 1.6
			tl.omni_range = 3.2
	
	var start_pos: Vector3 = _parents_car.global_position
	var end_x: float = 145.0
	var x_now: float = start_pos.x
	var phase1_end_x: float = start_pos.x + 18.0
	var t: float = 0.0
	var rc = _parents_car.get_node_or_null("ParentsCarFrontRay") as RayCast3D
	var car_ref: Node3D = _parents_car
	
	while is_instance_valid(car_ref) and x_now < end_x:
		var dt: float = get_process_delta_time()
		t += dt
		var blocked: bool = false
		if rc and rc.enabled:
			if rc.is_colliding():
				var col = rc.get_collider()
				# Freia APENAS se bater em outro carro, CharacterBody3D (Alice), ou RigidBody.
				# Não freia para chão (StaticBody baixo).
				if col and (col.is_in_group("carro") or col.name.to_lower().contains("carro") or col.name.to_lower().contains("car") or col is CharacterBody3D or col is RigidBody3D):
					blocked = true
		if blocked:
			await get_tree().process_frame
			continue
		
		var speed: float
		if x_now < phase1_end_x:
			# Primeira fase: saída lenta, ~18m em 2.6s → ~6.9 m/s (25 km/h)
			var u: float = clamp((x_now - start_pos.x) / max(0.001, phase1_end_x - start_pos.x), 0.0, 1.0)
			speed = lerp(0.5, 8.0, u)
		else:
			# Segunda fase: aceleração suave, 77m totais / 9.1s totais → ~11 m/s médio (40 km/h)
			var u2: float = clamp((x_now - phase1_end_x) / max(0.001, end_x - phase1_end_x), 0.0, 1.0)
			speed = lerp(8.0, 14.5, u2)
		
		# Move em X (frente da rua)
		var step: float = speed * dt
		x_now = min(end_x, x_now + step)
		var new_pos: Vector3 = Vector3(x_now, start_pos.y, start_pos.z)
		car_ref.global_position = new_pos
		await get_tree().process_frame
	
	# Chegou ao destino, some
	if is_instance_valid(car_ref):
		car_ref.queue_free()
	# Desliga também o som de idle do motor (interior), o carro já foi embora
	if is_instance_valid(_audio_car_idle):
		_fade_out_player(_audio_car_idle, 0.9)
	# Restaura CarroManager e rotas
	if cm and is_instance_valid(cm):
		cm.process_mode = cm_old_process_mode
	for np in paths_paused:
		var pth := get_node_or_null(np) as Path3D
		if pth:
			pth.process_mode = Node.PROCESS_MODE_INHERIT

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
	
	# ► PLAY Amarelo Retrô VCR (z_index 50 para ficar puro acima de qualquer overlay)
	var vcr_label := Label.new()
	vcr_label.text = "► PLAY   SP   17:52:31"
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
			vcr_label.text = "► PLAY   SP   17:52:" + sec_str
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
	
	# 5. Após o PLAY e o TIMECARD sumirem juntos, inicia digitação do objetivo
	#    (quebras manuais compactas — sem autowrap espaçando as linhas)
	_set_objective("VÁ ATÉ O PRÉDIO\nADMINISTRATIVO E FAÇA\nSUA MATRÍCULA.", true)
