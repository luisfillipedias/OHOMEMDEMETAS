extends Node3D

# ============================================================
# CATRACA_TRANSICAO.GD
# Transição cinematográfica e fluida da Catraca do CEFET.
# Alice pisa no trigger, continua andando normalmente enquanto
# a tela escurece suavemente, toca o som da catraca girando,
# e reaparece dentro do CEFET sem travar a movimentação!
# ============================================================

@export_group("Configurações de Áudio")
@export var som_catraca: AudioStream = preload("res://assets/audio/things/Catraca.mp3")
@export var volume_som_db: float = 0.0

@export_group("Configurações de Transição")
## Duração do fade para preto (em segundos)
@export var duracao_fade_out: float = 0.35
## Tempo de espera com tela preta enquanto toca o som
@export var duracao_espera_som: float = 0.85
## Duração do fade clareando de volta (em segundos)
@export var duracao_fade_in: float = 0.45

@export_group("Coordenadas de Teleporte (Altere aqui se precisar ajustar a posição!)")
## Posição de chegada DENTRO do CEFET (X, Y, Z)
## OBS: Y = 2.0 coloca a Alice em pé sobre o chão sem afundar!
@export var ponto_dentro: Vector3 = Vector3(-18.5, 2.0, -1.8)

## Posição de chegada FORA do CEFET (X, Y, Z) caso queira sair
@export var ponto_fora: Vector3 = Vector3(-18.5, 2.0, 6.0)

## Rotação (yaw em graus) para onde a Alice olha ao entrar (180 = olhando para frente dentro do CEFET)
@export var direcao_olhar_dentro_graus: float = 180.0
## Rotação (yaw em graus) ao sair
@export var direcao_olhar_fora_graus: float = 0.0
## Permitir que a catraca também transporte de volta para fora?
@export var permitir_saida: bool = true

var _audio_player: AudioStreamPlayer
var _em_transicao: bool = false
var _cooldown_msec: int = -999999
var _fade_layer: CanvasLayer
var _fade_rect: ColorRect


func _ready() -> void:
	_setup_audio()
	_setup_fade_overlay()
	_conectar_areas()


func _setup_audio() -> void:
	_audio_player = AudioStreamPlayer.new()
	_audio_player.name = "AudioCatraca"
	_audio_player.bus = "Master"
	_audio_player.volume_db = volume_som_db
	if som_catraca:
		_audio_player.stream = som_catraca
	add_child(_audio_player)


func _setup_fade_overlay() -> void:
	_fade_layer = CanvasLayer.new()
	_fade_layer.name = "CatracaFadeLayer"
	_fade_layer.layer = 95
	
	_fade_rect = ColorRect.new()
	_fade_rect.name = "FadeBlackRect"
	_fade_rect.color = Color(0, 0, 0, 0)
	_fade_rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	_fade_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_fade_rect.visible = false
	
	_fade_layer.add_child(_fade_rect)
	add_child(_fade_layer)


func _conectar_areas() -> void:
	for child in get_children():
		if child is Area3D:
			child.collision_layer = 0
			child.collision_mask = 2 # Detecta PlayerController (Layer 2)
			child.body_entered.connect(_on_area_body_entered)


func _on_area_body_entered(body: Node3D) -> void:
	if not body.is_in_group("player") or _em_transicao:
		return

	var now := Time.get_ticks_msec()
	# Cooldown de 2.5 segundos para não disparar em loop
	if now - _cooldown_msec < 2500:
		return

	executar_transicao_fluida(body)


## Executa a transição contínua SEM travar/freezar o jogador
func executar_transicao_fluida(jogador: Node3D) -> void:
	if _em_transicao or not is_instance_valid(jogador):
		return
	_em_transicao = true
	_cooldown_msec = Time.get_ticks_msec()

	# Decide destino baseado na posição atual da Alice:
	# Se Z > 2.5 (lado de fora na calçada), o destino é DENTRO
	var indo_para_dentro: bool = (jogador.global_position.z > 2.5)
	if not permitir_saida and not indo_para_dentro:
		_em_transicao = false
		return

	var destino_pos: Vector3 = ponto_dentro if indo_para_dentro else ponto_fora
	var destino_yaw: float = direcao_olhar_dentro_graus if indo_para_dentro else direcao_olhar_fora_graus

	# 1. Fade Out para Preto enquanto o jogador continua caminhando
	_fade_rect.visible = true
	_fade_rect.color = Color(0, 0, 0, 0)
	var tw_out := create_tween()
	tw_out.tween_property(_fade_rect, "color:a", 1.0, duracao_fade_out)
	await tw_out.finished

	# 2. Toca o som característico da catraca
	if is_instance_valid(_audio_player) and _audio_player.stream:
		_audio_player.play()

	# 3. Teleporta a Alice para dentro (ou fora) mantendo o fluxo
	if is_instance_valid(jogador):
		jogador.global_position = destino_pos
		jogador.rotation.y = deg_to_rad(destino_yaw)

	# Aguarda o efeito do som com a tela preta
	await get_tree().create_timer(duracao_espera_som).timeout

	# 4. Fade In clareando a tela de volta suavemente
	var tw_in := create_tween()
	tw_in.tween_property(_fade_rect, "color:a", 0.0, duracao_fade_in)
	await tw_in.finished
	_fade_rect.visible = false

	_em_transicao = false
