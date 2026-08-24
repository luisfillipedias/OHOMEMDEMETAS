extends Control

# ============================================================
# TITLE SCREEN -- O Homem De Metas (Menu com Áudio & VHS Boot)
# ============================================================

@onready var background: TextureRect = $Background
@onready var title_label: Label = $MenuContainer/Title
@onready var btn_jogar: Button = $MenuContainer/Options/BtnJogar
@onready var btn_continuar: Button = $MenuContainer/Options/BtnContinuar
@onready var btn_config: Button = $MenuContainer/Options/BtnConfig
@onready var btn_sair: Button = $MenuContainer/Options/BtnSair
@onready var settings_panel: Control = $SettingsPanel
@onready var btn_close_settings: Button = $SettingsPanel/VBox/BtnCloseSettings
@onready var master_slider: HSlider = $SettingsPanel/VBox/MasterSlider
@onready var sfx_slider: HSlider = $SettingsPanel/VBox/SFXSlider
@onready var btn_fullscreen: CheckBox = $SettingsPanel/VBox/CheckFullscreen
@onready var vhs_turn_on_overlay: ColorRect = $VHSTurnOnOverlay
@onready var fade_overlay: ColorRect = $FadeOverlay

# Audio Stream Players
@onready var audio_game_start: AudioStreamPlayer = $AudioGameStart
@onready var audio_vhs_hum: AudioStreamPlayer = $AudioVHSHum
@onready var audio_play_load: AudioStreamPlayer = $AudioPlayLoad
@onready var audio_text_glitch: AudioStreamPlayer = $AudioTextGlitch
@onready var audio_rare_glitch: AudioStreamPlayer = $AudioRareGlitch
@onready var audio_menu_music: AudioStreamPlayer = $AudioMenuMusic

var music_track_1 = preload("res://assets/audio/menu/music/titlescreenmusic1.mp3")
var music_track_2 = preload("res://assets/audio/menu/music/titlescreenmusic2.mp3")


var audio_ui_select: AudioStreamPlayer = null
var audio_ui_cursor: AudioStreamPlayer = null
var audio_ui_cancel: AudioStreamPlayer = null
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
	btn_close_settings.pressed.connect(_on_close_settings_pressed)

	master_slider.value_changed.connect(_on_master_volume_changed)
	sfx_slider.value_changed.connect(_on_sfx_volume_changed)
	btn_fullscreen.toggled.connect(_on_fullscreen_toggled)

	for i in range(buttons.size()):
		var idx: int = i
		buttons[i].mouse_entered.connect(func(): _on_mouse_enter_button(idx))

	_update_button_visuals()

	# Inicia sequência de boot de VHS e áudios
	_play_vhs_boot_sequence()

	next_glitch_time = randf_range(4.0, 8.0)
	next_rare_glitch_time = randf_range(25.0, 50.0)

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
		next_glitch_time = randf_range(5.0, 10.0)
		_trigger_title_glitch()

	# Glitch sonoro raro no menu
	rare_glitch_timer += delta
	if rare_glitch_timer >= next_rare_glitch_time:
		rare_glitch_timer = 0.0
		next_rare_glitch_time = randf_range(30.0, 60.0)
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
	play_ui_cancel()
	settings_panel.hide()

func _on_sair_pressed() -> void:
	play_ui_select()
	get_tree().quit()

func _on_master_volume_changed(val: float) -> void:
	AudioServer.set_bus_volume_db(AudioServer.get_bus_index("Master"), linear_to_db(val))

func _on_sfx_volume_changed(_val: float) -> void:
	pass

func _on_fullscreen_toggled(button_pressed: bool) -> void:
	play_ui_select()
	if button_pressed:
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN)
	else:
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)

func _setup_ui_sounds() -> void:
	audio_ui_select = AudioStreamPlayer.new()
	audio_ui_select.name = "AudioUISelect"
	audio_ui_select.volume_db = -6.0
	if ResourceLoader.exists("res://assets/audio/menu/UI/ogg/JDSherbert - Ultimate UI SFX Pack - Select - 1.ogg"):
		audio_ui_select.stream = load("res://assets/audio/menu/UI/ogg/JDSherbert - Ultimate UI SFX Pack - Select - 1.ogg")
	add_child(audio_ui_select)

	audio_ui_cursor = AudioStreamPlayer.new()
	audio_ui_cursor.name = "AudioUICursor"
	audio_ui_cursor.volume_db = -12.0
	if ResourceLoader.exists("res://assets/audio/menu/UI/ogg/JDSherbert - Ultimate UI SFX Pack - Cursor - 1.ogg"):
		audio_ui_cursor.stream = load("res://assets/audio/menu/UI/ogg/JDSherbert - Ultimate UI SFX Pack - Cursor - 1.ogg")
	add_child(audio_ui_cursor)

	audio_ui_cancel = AudioStreamPlayer.new()
	audio_ui_cancel.name = "AudioUICancel"
	audio_ui_cancel.volume_db = -6.0
	if ResourceLoader.exists("res://assets/audio/menu/UI/ogg/JDSherbert - Ultimate UI SFX Pack - Cancel - 1.ogg"):
		audio_ui_cancel.stream = load("res://assets/audio/menu/UI/ogg/JDSherbert - Ultimate UI SFX Pack - Cancel - 1.ogg")
	add_child(audio_ui_cancel)

func play_ui_select() -> void:
	if is_instance_valid(audio_ui_select) and audio_ui_select.stream:
		audio_ui_select.pitch_scale = randf_range(0.96, 1.04)
		audio_ui_select.play()

func play_ui_cursor() -> void:
	if is_instance_valid(audio_ui_cursor) and audio_ui_cursor.stream:
		audio_ui_cursor.pitch_scale = randf_range(0.96, 1.04)
		audio_ui_cursor.play()

func play_ui_cancel() -> void:
	if is_instance_valid(audio_ui_cancel) and audio_ui_cancel.stream:
		audio_ui_cancel.play()
