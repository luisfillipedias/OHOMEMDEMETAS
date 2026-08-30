extends Control

# ============================================================
# TITLE SCREEN CONTROLLER - VHS PSX HORROR MENU COM UI AUDIO
# ============================================================

@onready var background: TextureRect = $Background
@onready var title_label: Label = $MenuContainer/Title
@onready var btn_jogar: Button = $MenuContainer/Options/BtnJogar
@onready var btn_continuar: Button = $MenuContainer/Options/BtnContinuar
@onready var btn_config: Button = $MenuContainer/Options/BtnConfig
@onready var btn_sair: Button = $MenuContainer/Options/BtnSair
@onready var settings_panel: ColorRect = $SettingsPanel
@onready var btn_close_settings: Button = $SettingsPanel/Margin/VBox/BtnCloseSettings
@onready var master_slider: HSlider = $SettingsPanel/Margin/VBox/MasterSlider
@onready var sfx_slider: HSlider = $SettingsPanel/Margin/VBox/SFXSlider
@onready var btn_fullscreen: CheckBox = $SettingsPanel/Margin/VBox/CheckFullscreen
@onready var sensitivity_label: Label = $SettingsPanel/Margin/VBox/SensitivityLabel
@onready var sensitivity_slider: HSlider = $SettingsPanel/Margin/VBox/SensitivitySlider
@onready var vhs_turn_on_overlay: ColorRect = $VHSTurnOnOverlay
@onready var fade_overlay: ColorRect = $FadeOverlay
@onready var brightness_label: Label = $SettingsPanel/Margin/VBox/BrightnessLabel
@onready var brightness_slider: HSlider = $SettingsPanel/Margin/VBox/BrightnessSlider

# Audio Stream Players
@onready var audio_game_start: AudioStreamPlayer = $AudioGameStart
@onready var audio_vhs_hum: AudioStreamPlayer = $AudioVHSHum
@onready var audio_play_load: AudioStreamPlayer = $AudioPlayLoad
@onready var audio_text_glitch: AudioStreamPlayer = $AudioTextGlitch
@onready var audio_rare_glitch: AudioStreamPlayer = $AudioRareGlitch
@onready var audio_menu_music: AudioStreamPlayer = $AudioMenuMusic

var audio_ui_select: AudioStreamPlayer = null
var audio_ui_cursor: AudioStreamPlayer = null
var audio_ui_back: AudioStreamPlayer = null
var audio_ui_close_settings: AudioStreamPlayer = null

var snd_select = preload("res://assets/audio/menu/UI/ogg/JDSherbert - Ultimate UI SFX Pack - Select - 1.ogg")
var snd_cursor = preload("res://assets/audio/menu/UI/ogg/JDSherbert - Ultimate UI SFX Pack - Cursor - 1.ogg")
var snd_back_settings = preload("res://assets/audio/menu/UI/ogg/JDSherbert - Ultimate UI SFX Pack - Select - 2.ogg")
var snd_close_settings = preload("res://assets/audio/menu/UI/ogg/JDSherbert - Ultimate UI SFX Pack - Cursor - 2.ogg")

var music_track_1 = preload("res://assets/audio/menu/music/titlescreenmusic1.mp3")
var music_track_2 = preload("res://assets/audio/menu/music/titlescreenmusic2.mp3")

var buttons: Array = []
var selected_index: int = 0
var _titles := ["JOGAR", "CONTINUAR", "CONFIGURAÇÕES", "SAIR"]
var has_save_game: bool = false
var base_bg_pos: Vector2 = Vector2(-40, -25)
var parallax_time: float = 0.0

var glitch_timer: float = 0.0
var next_glitch_time: float = 5.0

var rare_glitch_timer: float = 0.0
var next_rare_glitch_time: float = 30.0

func _ready() -> void:
	Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
	settings_panel.hide()
	base_bg_pos = background.position

	# Brilho: inicializa com valor salvo no GameManager
	if brightness_slider:
		brightness_slider.min_value = 0.5
		brightness_slider.max_value = 2.0
		brightness_slider.step = 0.05
		brightness_slider.value = GameManager.brightness
		brightness_slider.value_changed.connect(_on_brightness_changed)
		_update_brightness_label(GameManager.brightness)
	
	_setup_ui_sounds()

	# Verifica se há save game: arquivo + flag de progresso
	if GameManager:
		var save_existe: bool = FileAccess.file_exists("user://save.json")
		var progresso: int = GameManager.get_flag("chapter_progress", 0)
		var capitulo: int = GameManager.current_chapter
		has_save_game = save_existe and (progresso > 0 or capitulo > 0)
	
	btn_continuar.disabled = not has_save_game

	buttons = [btn_jogar, btn_continuar, btn_config, btn_sair]

	btn_jogar.pressed.connect(_on_jogar_pressed)
	btn_continuar.pressed.connect(_on_continuar_pressed)
	btn_config.pressed.connect(_on_config_pressed)
	btn_sair.pressed.connect(_on_sair_pressed)
	
	# Configurações & Controles
	btn_close_settings.pressed.connect(_on_close_settings_pressed)
	btn_close_settings.mouse_entered.connect(play_ui_cursor)

	master_slider.value_changed.connect(_on_master_volume_changed)
	master_slider.mouse_entered.connect(play_ui_cursor)
	
	sfx_slider.value_changed.connect(_on_sfx_volume_changed)
	sfx_slider.mouse_entered.connect(play_ui_cursor)
	sfx_slider.drag_ended.connect(func(_val): play_ui_select())
	
	btn_fullscreen.toggled.connect(_on_fullscreen_toggled)
	btn_fullscreen.mouse_entered.connect(play_ui_cursor)

	sensitivity_slider.value = GameState.mouse_sensitivity
	_update_sensitivity_label(GameState.mouse_sensitivity)
	sensitivity_slider.value_changed.connect(_on_sensitivity_changed)
	sensitivity_slider.mouse_entered.connect(play_ui_cursor)
	sensitivity_slider.drag_ended.connect(func(_val): play_ui_select())

	for i in range(buttons.size()):
		var idx: int = i
		buttons[i].mouse_entered.connect(func(): _on_mouse_enter_button(idx))

	_update_button_visuals()

	# Inicia sequência de boot de VHS e áudios
	_play_vhs_boot_sequence()

	next_glitch_time = randf_range(22.0, 40.0)
	next_rare_glitch_time = randf_range(60.0, 120.0)

func _setup_ui_sounds() -> void:
	audio_ui_select = AudioStreamPlayer.new()
	audio_ui_select.name = "AudioUISelect"
	audio_ui_select.process_mode = Node.PROCESS_MODE_ALWAYS
	audio_ui_select.volume_db = -1.0
	audio_ui_select.stream = snd_select
	add_child(audio_ui_select)

	# Volume mais suave para hover
	audio_ui_cursor = AudioStreamPlayer.new()
	audio_ui_cursor.name = "AudioUICursor"
	audio_ui_cursor.process_mode = Node.PROCESS_MODE_ALWAYS
	audio_ui_cursor.volume_db = -16.0
	audio_ui_cursor.stream = snd_cursor
	add_child(audio_ui_cursor)

	# Som de voltar em Settings (Select - 2)
	audio_ui_back = AudioStreamPlayer.new()
	audio_ui_back.name = "AudioUIBack"
	audio_ui_back.process_mode = Node.PROCESS_MODE_ALWAYS
	audio_ui_back.volume_db = -2.0
	audio_ui_back.stream = snd_back_settings
	add_child(audio_ui_back)

	# Som de fechar settings (Cursor - 2)
	audio_ui_close_settings = AudioStreamPlayer.new()
	audio_ui_close_settings.name = "AudioUICloseSettings"
	audio_ui_close_settings.process_mode = Node.PROCESS_MODE_ALWAYS
	audio_ui_close_settings.volume_db = -2.0
	audio_ui_close_settings.stream = snd_close_settings
	add_child(audio_ui_close_settings)

func play_ui_select() -> void:
	if is_instance_valid(audio_ui_select) and audio_ui_select.stream:
		audio_ui_select.pitch_scale = randf_range(0.97, 1.03)
		audio_ui_select.play()

func play_ui_cursor() -> void:
	if is_instance_valid(audio_ui_cursor) and audio_ui_cursor.stream:
		audio_ui_cursor.pitch_scale = randf_range(0.97, 1.03)
		audio_ui_cursor.play()

func play_ui_back() -> void:
	if is_instance_valid(audio_ui_back) and audio_ui_back.stream:
		audio_ui_back.pitch_scale = randf_range(0.98, 1.02)
		audio_ui_back.play()

func play_ui_close_settings() -> void:
	if is_instance_valid(audio_ui_close_settings) and audio_ui_close_settings.stream:
		audio_ui_close_settings.pitch_scale = randf_range(0.98, 1.02)
		audio_ui_close_settings.play()

func _play_vhs_boot_sequence() -> void:
	# 1. Som de ligar TV / VHS
	if audio_game_start:
		audio_game_start.play()

	# 2. Som contínuo de fita VHS no fundo
	if audio_vhs_hum:
		audio_vhs_hum.finished.connect(func(): audio_vhs_hum.play())
		audio_vhs_hum.play()

	# 3. Shader animado: efeito de tubo CRT ligando (boot VHS procedural)
	if vhs_turn_on_overlay and vhs_turn_on_overlay.material:
		var mat := vhs_turn_on_overlay.material as ShaderMaterial
		vhs_turn_on_overlay.show()
		mat.set_shader_parameter("turn_on_progress", 0.0)
		var tw = create_tween()
		tw.tween_method(func(val: float): mat.set_shader_parameter("turn_on_progress", val),
			0.0, 1.0, 1.8)
		await tw.finished
		# Fade out do overlay de boot
		var tw2 = create_tween()
		tw2.tween_property(vhs_turn_on_overlay, "modulate:a", 0.0, 0.4)
		await tw2.finished
		vhs_turn_on_overlay.hide()
		vhs_turn_on_overlay.modulate.a = 1.0

	# 4. Música tema do menu entra suavemente após a inicialização
	if audio_menu_music:
		if randf() > 0.5:
			audio_menu_music.stream = music_track_1
		else:
			audio_menu_music.stream = music_track_2
		audio_menu_music.finished.connect(func(): audio_menu_music.play())
		audio_menu_music.volume_db = -28.0
		audio_menu_music.play()
		var tw_mus = create_tween()
		tw_mus.tween_property(audio_menu_music, "volume_db", -10.0, 2.0)

func _process(delta: float) -> void:
	parallax_time += delta

	# Efeito Parallax 2.5D suave
	var viewport_size = get_viewport_rect().size
	if viewport_size.x > 0 and viewport_size.y > 0:
		var mouse_pos = get_viewport().get_mouse_position()
		var norm_x = (mouse_pos.x / viewport_size.x) - 0.5
		var norm_y = (mouse_pos.y / viewport_size.y) - 0.5
		
		var breath_x = sin(parallax_time * 0.4) * 3.0
		var breath_y = cos(parallax_time * 0.3) * 2.0
		var target_pos = base_bg_pos + Vector2(norm_x * -30.0 + breath_x, norm_y * -20.0 + breath_y)
		background.position = background.position.lerp(target_pos, delta * 3.0)

	# Glitch periódico sincronizado no Título
	glitch_timer += delta
	if glitch_timer >= next_glitch_time:
		glitch_timer = 0.0
		next_glitch_time = randf_range(22.0, 40.0)
		_trigger_title_glitch()

	# Glitch sonoro raro no menu
	rare_glitch_timer += delta
	if rare_glitch_timer >= next_rare_glitch_time:
		rare_glitch_timer = 0.0
		next_rare_glitch_time = randf_range(60.0, 120.0)
		_trigger_rare_glitch()

func _trigger_title_glitch() -> void:
	if audio_text_glitch:
		audio_text_glitch.pitch_scale = randf_range(0.9, 1.15)
		audio_text_glitch.play()
	
	if title_label and title_label.material:
		var mat = title_label.material as ShaderMaterial
		if mat:
			mat.set_shader_parameter("glitch_intensity", 0.9)
			await get_tree().create_timer(0.35).timeout
			mat.set_shader_parameter("glitch_intensity", 0.35)

func _trigger_rare_glitch() -> void:
	if audio_rare_glitch:
		audio_rare_glitch.play()

func _input(event: InputEvent) -> void:
	if settings_panel.visible:
		if event.is_action_pressed("ui_cancel") or (event is InputEventKey and event.pressed and event.keycode == KEY_ESCAPE):
			_on_close_settings_pressed()
		return
	if event.is_action_pressed("ui_up") or (event is InputEventKey and event.pressed and event.keycode == KEY_W):
		_navigate_menu(-1)
	elif event.is_action_pressed("ui_down") or (event is InputEventKey and event.pressed and event.keycode == KEY_S):
		_navigate_menu(1)
	elif event.is_action_pressed("ui_accept") or (event is InputEventKey and event.pressed and event.keycode == KEY_ENTER):
		if not buttons[selected_index].disabled:
			play_ui_select()
			buttons[selected_index].emit_signal("pressed")

func _navigate_menu(dir: int) -> void:
	var new_idx = (selected_index + dir + buttons.size()) % buttons.size()
	if new_idx == 1 and not has_save_game:
		new_idx = (new_idx + dir + buttons.size()) % buttons.size()
	selected_index = new_idx
	_update_button_visuals()
	play_ui_cursor()

func _on_mouse_enter_button(index: int) -> void:
	if index == 1 and not has_save_game:
		return
	selected_index = index
	_update_button_visuals()
	play_ui_cursor()

func _update_button_visuals() -> void:
	for i in range(buttons.size()):
		if i == 1 and not has_save_game:
			buttons[i].text = "    " + _titles[i]
			buttons[i].add_theme_color_override("font_color", Color(0.40, 0.40, 0.40, 0.8))
			continue

		if i == selected_index:
			buttons[i].text = "►  " + _titles[i]
			buttons[i].add_theme_color_override("font_color", Color(1.0, 1.0, 1.0, 1.0))
		else:
			buttons[i].text = "    " + _titles[i]
			buttons[i].add_theme_color_override("font_color", Color(0.70, 0.70, 0.70, 1.0))

func _on_jogar_pressed() -> void:
	play_ui_select()
	if audio_menu_music:
		var tw_mus = create_tween()
		tw_mus.tween_property(audio_menu_music, "volume_db", -40.0, 1.5)

	if audio_play_load:
		audio_play_load.play()

	fade_overlay.show()
	var tw := create_tween()
	tw.tween_property(fade_overlay, "color:a", 1.0, 1.8)
	await tw.finished
	get_tree().change_scene_to_file("res://scenes/chapter_01.tscn")

func _on_continuar_pressed() -> void:
	if has_save_game:
		_on_jogar_pressed()

func _on_config_pressed() -> void:
	play_ui_select()
	settings_panel.show()

func _on_close_settings_pressed() -> void:
	# Som de voltar em settings (Select - 2) e fechar (Cursor - 2)
	play_ui_back()
	settings_panel.hide()
	GameManager.save_settings()  # Persiste brilho e demais configs

func _on_sair_pressed() -> void:
	play_ui_select()
	get_tree().quit()

func _on_master_volume_changed(val: float) -> void:
	var db: float = linear_to_db(val) if val > 0.0 else -80.0
	AudioServer.set_bus_volume_db(AudioServer.get_bus_index("Master"), db)

func _on_sfx_volume_changed(val: float) -> void:
	var db: float = linear_to_db(val) if val > 0.0 else -80.0
	var sfx_bus: int = AudioServer.get_bus_index("SFX")
	if sfx_bus >= 0:
		AudioServer.set_bus_volume_db(sfx_bus, db)

func _on_fullscreen_toggled(button_pressed: bool) -> void:
	play_ui_select()
	if button_pressed:
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN)
	else:
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)

func _on_sensitivity_changed(val: float) -> void:
	GameState.set_mouse_sensitivity(val)
	_update_sensitivity_label(val)

func _update_sensitivity_label(val: float) -> void:
	sensitivity_label.text = "SENSIBILIDADE DO MOUSE (%d%%)" % GameState.get_mouse_sensitivity_percent()

func _on_brightness_changed(val: float) -> void:
	GameManager.brightness = val
	_update_brightness_label(val)

func _update_brightness_label(val: float) -> void:
	if not brightness_label:
		return
	var pct := int(round((val - 0.5) / 1.5 * 100.0))
	brightness_label.text = "BRILHO (%d%%)" % pct
