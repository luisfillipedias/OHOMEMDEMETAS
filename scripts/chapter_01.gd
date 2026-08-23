extends Node3D

# ============================================================
# CHAPTER 01: O HOMEM DE METAS -- CEFET-MG & A PERSEGUIÇÃO
# ============================================================

@onready var player: CharacterBody3D = $PlayerController
@onready var camera_mount: Node3D = $PlayerController/CameraMount
@onready var dialogue_ui: CanvasLayer = $DialogueUI
@onready var celular_ui: CanvasLayer = $CelularUI
@onready var audio_amb: AudioStreamPlayer = $AudioAmbience
@onready var audio_sfx: AudioStreamPlayer = $AudioSFX
@onready var world_env: WorldEnvironment = $WorldEnvironment
@onready var sun_light: DirectionalLight3D = $SunLight

# HUD Elements
@onready var hud: CanvasLayer = $HUD
@onready var objective_panel: Control = $HUD/ObjectivePanel
@onready var objective_label: Label = $HUD/ObjectivePanel/ObjectiveLabel
@onready var timecard_panel: Control = $HUD/Timecard
@onready var timecard_label: Label = $HUD/Timecard/TimecardLabel
@onready var interact_hint: Label = $HUD/InteractHint
@onready var memory_popup: PanelContainer = $HUD/MemoryPopup
@onready var memory_label: Label = $HUD/MemoryPopup/MemoryLabel
@onready var fade_rect: ColorRect = $HUD/FadeRect
@onready var fade_label: Label = $HUD/FadeRect/FadeLabel
@onready var flash_rect: ColorRect = $HUD/FlashRect

# Pause Menu (VCR Blue Function OSD)
@onready var pause_menu: Control = $HUD/PauseMenu
@onready var btn_resume: Button = $HUD/PauseMenu/VCRBox/VBox/BtnResume
@onready var sens_slider: HSlider = $HUD/PauseMenu/VCRBox/VBox/SensSlider
@onready var vol_slider: HSlider = $HUD/PauseMenu/VCRBox/VBox/VolSlider
@onready var btn_main_menu: Button = $HUD/PauseMenu/VCRBox/VBox/BtnMainMenu

# Props & Triggers
@onready var lost_document: Area3D = $CefetExterior/LostDocument
@onready var stalker_mesh: Node3D = $CefetInterior/MatriculaNode/PillarStalkerNode
@onready var stalker_spot: SpotLight3D = $CefetInterior/MatriculaNode/PillarStalkerSpot
@onready var rain_particles: GPUParticles3D = $RainParticles

# Checkpoints
@onready var start_ext: Marker3D = $CefetExterior/StartMarker
@onready var start_int: Marker3D = $CefetInterior/StartMarker
@onready var start_lobby: Marker3D = $PredioAlice/LobbyStart
@onready var start_bed: Marker3D = $PredioAlice/BedroomStart

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
	
	if stalker_mesh: stalker_mesh.hide()
	if stalker_spot: stalker_spot.hide()
	if rain_particles: rain_particles.emitting = false

	# Início da Cena 1: CEFET Campus 1, Crepúsculo Ventoso (17:50)
	_show_timecard("CEFET-MG  -  CAMPUS 1", "17:50")
	_set_objective("Vá até o prédio administrativo\ne faça sua matrícula.")

	# Diálogo de abertura de Alice
	await get_tree().create_timer(1.2).timeout
	dialogue_ui.start_dialogue([
		"Alice: 'Ufa, cheguei no CEFET a tempo.'",
		"Alice: 'O vento tá ficando muito forte e o céu tá fechando... melhor entrar logo no prédio administrativo antes que comece a chover.'"
	])

func _setup_pause_menu() -> void:
	if not pause_menu:
		return
	pause_menu.hide()
	if btn_resume:
		btn_resume.pressed.connect(toggle_pause_menu)
	if btn_main_menu:
		btn_main_menu.pressed.connect(func():
			get_tree().paused = false
			Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
			get_tree().change_scene_to_file("res://scenes/ui/title_screen.tscn")
		)
	if sens_slider and player:
		sens_slider.value = player.mouse_sensitivity
		sens_slider.value_changed.connect(func(v: float):
			player.mouse_sensitivity = v
		)
	if vol_slider:
		var bus_idx = AudioServer.get_bus_index("Master")
		vol_slider.value = db_to_linear(AudioServer.get_bus_volume_db(bus_idx))
		vol_slider.value_changed.connect(func(v: float):
			AudioServer.set_bus_volume_db(bus_idx, linear_to_db(v))
		)

func _input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and event.keycode == KEY_ESCAPE:
		toggle_pause_menu()

func toggle_pause_menu() -> void:
	if not pause_menu:
		return
	is_paused = not is_paused
	pause_menu.visible = is_paused
	get_tree().paused = is_paused
	if is_paused:
		Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
	else:
		Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)

func _set_objective(text: String) -> void:
	if objective_label:
		objective_label.text = "OBJETIVO:\n" + text.to_upper()
	if objective_panel:
		objective_panel.show()

func _show_timecard(local_name: String, time_str: String) -> void:
	if timecard_label:
		timecard_label.text = local_name + "\n" + time_str
	if timecard_panel:
		timecard_panel.show()

func _show_memory_popup(text: String) -> void:
	if memory_label:
		memory_label.text = "[" + text + "]"
	if memory_popup:
		memory_popup.show()
		var tw = create_tween()
		tw.tween_interval(3.5)
		tw.tween_callback(func(): memory_popup.hide())

func _play_sfx(path: String) -> void:
	if audio_sfx:
		audio_sfx.stream = load(path)
		audio_sfx.play()

func _flash(color: Color, duration: float = 0.3) -> void:
	if flash_rect:
		flash_rect.color = color
		var tw = create_tween()
		tw.tween_property(flash_rect, "color:a", 0.0, duration)

func _fade_out(text: String = "", duration: float = 1.0) -> void:
	if fade_rect:
		fade_label.text = text
		var tw = create_tween()
		tw.tween_property(fade_rect, "color:a", 1.0, duration)
		await tw.finished

func _fade_in(duration: float = 1.0) -> void:
	if fade_rect:
		var tw = create_tween()
		tw.tween_property(fade_rect, "color:a", 0.0, duration)
		await tw.finished
		fade_label.text = ""

func _freeze_player() -> void:
	if player and player.has_method("set_frozen"):
		player.set_frozen(true)

func _unfreeze_player() -> void:
	if player and player.has_method("set_frozen"):
		player.set_frozen(false)

func _move_player_to(marker: Marker3D) -> void:
	if player and marker:
		player.global_position = marker.global_position
		player.rotation = marker.rotation

# ============================================================
# TRANSIÇÃO DINÂMICA: TEMPESTADE NOTURNA (BH)
# ============================================================

func _transition_to_night_storm() -> void:
	if rain_particles:
		rain_particles.emitting = true
	
	if audio_amb:
		audio_amb.volume_db = -2.0
	
	if world_env and world_env.environment:
		var env = world_env.environment
		var tw = create_tween()
		tw.tween_property(env, "ambient_light_energy", 0.15, 3.0)
		tw.tween_property(env, "volumetric_fog_density", 0.06, 3.0)
		tw.tween_property(env, "fog_density", 0.035, 3.0)

	if sun_light:
		var tw_sun = create_tween()
		tw_sun.tween_property(sun_light, "light_energy", 0.1, 3.0)

# ============================================================
# FASE 1 & 2: EXTERIOR CEFET & DOCUMENTO PERDIDO
# ============================================================

func _on_lost_doc_trigger(body: Node3D) -> void:
	if body != player or doc_pegou:
		return
	doc_pegou = true
	_freeze_player()
	if lost_document:
		lost_document.hide()
	
	dialogue_ui.start_dialogue([
		"Alice: 'Olha... alguém deixou cair uma pasta de documentos aqui no chão.'",
		"Alice: 'Tem o nome de um aluno: Otávio Silva... curso de Informática.'",
		"Alice: 'Vou levar até a recepção dentro do prédio para devolver.'"
	])
	await dialogue_ui.dialogue_finished
	_unfreeze_player()
	_set_objective("Entre no prédio administrativo\ne entregue o documento na recepção.")

func _on_enter_building_trigger(body: Node3D) -> void:
	if body != player:
		return
	_freeze_player()
	await _fade_out("Entrando no Prédio Administrativo...")
	await get_tree().create_timer(1.0).timeout
	_move_player_to(start_int)
	_fade_in()
	_show_timecard("CEFET-MG  -  GUICHÊS DE MATRÍCULA", "18:05")
	if doc_pegou:
		_set_objective("Fale com a recepcionista no balcão\npara devolver os documentos.")
	else:
		_set_objective("Vá até a fila de matrícula.")
	_unfreeze_player()

# ============================================================
# FASE 3: AUDITÓRIO & RECEPÇÃO (ENTREGA DO DOCUMENTO)
# ============================================================

func _on_reception_trigger(body: Node3D) -> void:
	if body != player:
		return
	if not doc_pegou:
		dialogue_ui.start_dialogue([
			{"speaker": "Recepcionista", "text": "Boa tarde! Se veio fazer a matrícula, a fila fica logo ali à direita."}
		])
		return
	if doc_entregue:
		return

	doc_entregue = true
	_freeze_player()
	dialogue_ui.start_dialogue([
		{"speaker": "Alice", "text": "Boa tarde! Eu achei esses documentos caídos perto da entrada... são de um tal de Otávio Silva."},
		{"speaker": "Recepcionista", "text": "Ah, muito obrigada, garota! Ele acabou de passar aqui desesperado procurando a pasta."},
		{"speaker": "Recepcionista", "text": "Vou guardar aqui no balcão pra ele. Pode ir lá pra fila do auditório fazer sua matrícula!"}
	])
	await dialogue_ui.dialogue_finished
	
	# Transição da tempestade lá fora
	_transition_to_night_storm()
	
	_unfreeze_player()
	_set_objective("Vá até a fila de matrícula\nno corredor dos guichês.")

# ============================================================
# FASE 4: FILA DE MATRÍCULA & ENCONTRO COM OTÁVIO / STALKER
# ============================================================

func _on_queue_otavio_trigger(body: Node3D) -> void:
	if body != player or otavio_falou:
		return
	otavio_falou = true
	_freeze_player()

	dialogue_ui.start_dialogue([
		{"speaker": "Voz Atrás", "text": "Ei... você também é do 1º ano de Informática?"},
		"Alice: '[Alice se vira e vê um rapaz alto, pálido, com um sorriso estranho]'",
		{"speaker": "Otávio", "text": "Meu nome é Otávio. Eu vi você lá fora pegando a minha pasta... obrigado por não ter jogado fora."},
		{"speaker": "Alice", "text": "De nada... era o certo a fazer."},
		{"speaker": "Otávio", "text": "Eu vi seu nome na etiqueta da mochila. Alice, né? Nome bonito..."},
		{"speaker": "Otávio", "text": "A gente vai estudar na mesma sala. Você mora muito longe daqui? Quer que eu te acompanhe até em casa?"},
		{
			"speaker": "Alice",
			"text": "...",
			"choices": [
				{"text": "Muito obrigada, mas meus pais já vieram me buscar de carro."},
				{"text": "Não... prefiro ir sozinha, com licença."}
			]
		}
	])
	await dialogue_ui.dialogue_finished
	_show_memory_popup("Ele vai se lembrar disso...")

	# Clímax da tensão: Stalker na pilastra
	await get_tree().create_timer(1.8).timeout

	if stalker_mesh: stalker_mesh.show()
	if stalker_spot: stalker_spot.show()

	var target_pos: Vector3 = $CefetInterior/MatriculaNode/PillarStalkerNode.global_position
	var dir_to_stalker: Vector3 = (target_pos - camera_mount.global_position).normalized()
	var tw = create_tween()
	tw.tween_property(player, "rotation:y", atan2(-dir_to_stalker.x, -dir_to_stalker.z), 1.0)
	await get_tree().create_timer(1.0).timeout

	dialogue_ui.start_dialogue([
		"Alice: 'Aquele cara no canto... encostado na pilastra. Tá me olhando fixamente.'",
		"Alice: 'Ele não tá na fila de matrícula... só tá me encarando sem piscar.'"
	])
	await dialogue_ui.dialogue_finished

	# Jumpscare / Estalo de raio + Trovão + Clarão
	_play_sfx("res://assets/audio/jumpscare.wav")
	_flash(Color(1, 1, 1, 1), 0.35)
	await get_tree().create_timer(0.05).timeout

	if stalker_mesh: stalker_mesh.hide()
	if stalker_spot: stalker_spot.hide()

	dialogue_ui.start_dialogue([
		"Alice: 'Ué... pra onde ele foi?! Que barulho de raio foi esse?!'",
		"Alice: 'É a minha vez no guichê de atendimento!'"
	])
	await dialogue_ui.dialogue_finished

	pode_falar_atendente = true
	_unfreeze_player()
	_set_objective("Vá até o guichê da atendente\ne faça sua matrícula.")

func _on_clerk_trigger(body: Node3D) -> void:
	if body != player:
		return
	if not pode_falar_atendente:
		dialogue_ui.start_dialogue([
			"Alice: '(Preciso aguardar minha vez na fila de matrícula...)'"
		])
		return
	if matricula_feita:
		dialogue_ui.start_dialogue([
			{"speaker": "Atendente", "text": "Sua matrícula já foi concluída, Alice. Boas aulas no CEFET!"}
		])
		return

	matricula_feita = true
	_freeze_player()
	dialogue_ui.start_dialogue([
		{"speaker": "Atendente", "text": "Boa tarde, garota. Bem-vinda ao CEFET! Pode me passar seus documentos, por favor."},
		{"speaker": "Alice", "text": "[Entrega RG, histórico escolar e comprovante de residência]"},
		{"speaker": "Alice", "text": "[Assina o Termo de Confirmação de Matrícula]"},
		{"speaker": "Atendente", "text": "Documentos OK. Matrícula confirmada na Turma de Informática. Boas-vindas ao CEFET-MG!"},
		{"speaker": "Alice", "text": "Muito obrigada!"},
		"Alice: 'Pronto! Agora vou sair pelo hall e ir pro carro dos meus pais no estacionamento.'"
	])
	await dialogue_ui.dialogue_finished
	_unfreeze_player()
	_set_objective("Saia pelo hall e entre no carro\ndos seus pais no estacionamento.")

func _on_exit_to_ext_trigger(body: Node3D) -> void:
	if body != player:
		return
	_freeze_player()
	await _fade_out("Subindo as escadas para o estacionamento...")
	await get_tree().create_timer(1.0).timeout
	_move_player_to(start_ext)
	_fade_in()
	if matricula_feita:
		_set_objective("Entre no carro dos seus pais\nno estacionamento.")
	else:
		_set_objective("Entre no prédio administrativo.")
	_unfreeze_player()

func _on_parents_car_trigger(body: Node3D) -> void:
	if body != player:
		return
	if not matricula_feita:
		dialogue_ui.start_dialogue([
			"Alice: 'Ainda preciso fazer minha matrícula no prédio antes de ir embora.'"
		])
		return
	_freeze_player()
	_go_to_building()

# ============================================================
# FASE 5: CHEGADA AO PRÉDIO DA ALICE & ELEVADOR
# ============================================================

func _go_to_building() -> void:
	await _fade_out("Voltando de carro para casa sob a tempestade de BH...")
	await get_tree().create_timer(2.5).timeout
	_move_player_to(start_lobby)
	_fade_in()
	_show_timecard("EDIFÍCIO RESIDENCIAL  -  HALL", "18 DE AGOSTO  -  21:40")
	_set_objective("Abra o portão de ferro na calçada com a chave.")
	dialogue_ui.start_dialogue([
		"Alice: 'Cheguei em casa. A rua tá deserta e esse temporal não para.'"
	])
	await dialogue_ui.dialogue_finished
	_unfreeze_player()

func _on_gate_trigger(body: Node3D) -> void:
	if body != player or portao_aberto:
		return
	portao_aberto = true
	_freeze_player()
	_play_sfx("res://assets/audio/door_slam.wav")
	dialogue_ui.start_dialogue([
		"Alice: '[Girando a chave no portão de ferro...]'",
		"Alice: 'Pronto, destrancou. Vou atravessar o jardim até a entrada.'"
	])
	await dialogue_ui.dialogue_finished
	_unfreeze_player()
	_set_objective("Atravesse o jardim e chame\no elevador no hall.")

func _on_elevator_trigger(body: Node3D) -> void:
	if body != player or elevador_chamado or not portao_aberto:
		return
	elevador_chamado = true
	_freeze_player()
	dialogue_ui.start_dialogue([
		"Alice: 'A escada tá interditada com fita de manutenção. Apertei o botão do elevador...'"
	])
	await dialogue_ui.dialogue_finished

	await get_tree().create_timer(2.0).timeout

	_play_sfx("res://assets/audio/door_slam.wav")
	_flash(Color(0.8, 0.15, 0.15, 0.4))

	dialogue_ui.start_dialogue([
		"Alice: 'Nossa! Que barulho de porta se fechando foi esse atrás de mim no hall?!'",
		"Alice: 'O elevador abriu... entra rápido e sobe até o 4º andar!'"
	])
	await dialogue_ui.dialogue_finished
	_go_to_bedroom()

# ============================================================
# FASE 6: QUARTO DA ALICE & CLÍMAX (CELULAR & STALKER)
# ============================================================

func _go_to_bedroom() -> void:
	await _fade_out("Subindo até o 4º andar...")
	await get_tree().create_timer(2.0).timeout
	_move_player_to(start_bed)
	_fade_in()
	_show_timecard("APARTAMENTO 402  -  QUARTO", "18 DE AGOSTO  -  21:48")
	_set_objective("Sente no colchão e abra o celular.")
	dialogue_ui.start_dialogue([
		"Alice: 'Enfim no meu quarto sã e salva. Que dia exaustivo...'",
		"Alice: 'Vou ver as mensagens no celular antes de dormir.'"
	])
	await dialogue_ui.dialogue_finished
	_unfreeze_player()

func _on_phone_trigger(body: Node3D) -> void:
	if body != player or stalker_sms_visto:
		return
	_freeze_player()

	if celular_ui:
		celular_ui.open_phone()

	dialogue_ui.start_dialogue([
		"Alice: '[Desbloqueando o celular...]'",
		"Alice: 'Mensagem de quem é esse número desconhecido?'"
	])
	await dialogue_ui.dialogue_finished

	await get_tree().create_timer(2.0).timeout

	_play_sfx("res://assets/audio/jumpscare.wav")
	_flash(Color(1, 0.1, 0.1, 0.6))
	await get_tree().create_timer(0.1).timeout

	if celular_ui:
		celular_ui.trigger_stalker_sms()

	stalker_sms_visto = true

	dialogue_ui.start_dialogue([
		"MENSAGEM DESCONHECIDA: 'Parabéns pela matrícula no CEFET hoje, Alice... Você fica linda de jaqueta preta. Te vejo na sala de aula. 👁️'",
		"Alice: 'QUEM É ESSA PESSOA?! ESSE NÚMERO NÃO É DE NINGUÉM QUE EU CONHEÇO!'",
		"Alice: 'Como ele sabe meu nome, minha roupa, que eu tava lá?!'",
		"Alice: 'Aquele cara na pilastra... ERA ELE! ELE ME SEGUIU ATÉ AQUI!'",
		"Alice: 'PRECISO TRANCAR A PORTA DO QUARTO AGORA!'"
	])
	await dialogue_ui.dialogue_finished

	if celular_ui:
		celular_ui.close_phone()

	_unfreeze_player()
	_set_objective("Corra e tranque a porta\ndo quarto com a chave!")

func _on_bedroom_door_trigger(body: Node3D) -> void:
	if body != player or not stalker_sms_visto or quarto_trancado:
		return
	quarto_trancado = true
	_freeze_player()
	_play_sfx("res://assets/audio/door_slam.wav")
	_flash(Color(1, 1, 1, 0.5))

	dialogue_ui.start_dialogue([
		"Alice: '[Girando a chave e passando o ferrolho da porta...]'",
		"Alice: 'Trancado. Tô morrendo de medo... quem é esse cara?!'"
	])
	await dialogue_ui.dialogue_finished

	_finish_chapter()

func _finish_chapter() -> void:
	objective_panel.hide()
	await _fade_out("FIM DO CAPÍTULO 1\n\n1º Dia de Aula se aproxima...", 2.0)
	await get_tree().create_timer(5.0).timeout
	GameManager.set_flag("chapter_1_completed", true)
	GameManager.save_game()
	GameManager.change_scene("res://scenes/ui/title_screen.tscn")

func _process(_delta: float) -> void:
	if rain_particles and is_instance_valid(player) and rain_particles.emitting:
		rain_particles.global_position.x = player.global_position.x
		rain_particles.global_position.z = player.global_position.z
