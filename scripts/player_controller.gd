extends CharacterBody3D

# ============================================================
# PLAYER CONTROLLER -- 1a Pessoa com step assist, head bobbing
#                      100% sincronizado com sons de passos
# ============================================================

const WALK_SPEED := 3.6
const GRAVITY := 12.0
const BOB_FREQUENCY := 8.2 # Frequência de passos (rad/s)
const BOB_VERTICAL_AMP := 0.028 # Altura do balanço da cabeça
const BOB_HORIZONTAL_AMP := 0.014 # Balanço lateral suave
var MOUSE_SENS := 0.0018
const MAX_STEP_HEIGHT := 0.35

@onready var camera_mount: Node3D = $CameraMount
@onready var camera: Camera3D = $CameraMount/Camera3D
@onready var interact_ray: RayCast3D = $CameraMount/Camera3D/InteractRay

var is_frozen: bool = false
var bob_time: float = 0.0
var camera_base_y: float = 0.65
var last_step_sign: float = 1.0

# Sistema de Sons de Passos
var _audio_footstep: AudioStreamPlayer = null
var _snds_concrete: Array[AudioStream] = []
var _snds_grass: Array[AudioStream] = []
var _snds_dirt: Array[AudioStream] = []

func _ready() -> void:
	add_to_group("player")
	Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)
	camera_base_y = camera_mount.position.y
	floor_snap_length = 0.4
	floor_max_angle = deg_to_rad(50.0)
	
	# Configura AudioListener3D ativo para Áudio Espacial 3D real
	camera.current = true
	var listener := AudioListener3D.new()
	listener.name = "PlayerAudioListener3D"
	camera.add_child(listener)
	listener.make_current()

	_setup_footstep_audio()

func _setup_footstep_audio() -> void:
	_audio_footstep = AudioStreamPlayer.new()
	_audio_footstep.name = "PlayerFootstepAudio"
	_audio_footstep.volume_db = -6.0
	add_child(_audio_footstep)

	# Carrega amostras individuais de passos (sem corte abrupto)
	for i in range(1, 5):
		var p = "res://assets/audio/footsteps_single/concrete_%d.wav" % i
		if ResourceLoader.exists(p):
			_snds_concrete.append(load(p))
	
	for i in range(1, 4):
		var p_grass = "res://assets/audio/footsteps_single/grass_%d.wav" % i
		if ResourceLoader.exists(p_grass):
			_snds_grass.append(load(p_grass))
		
		var p_mud = "res://assets/audio/footsteps_single/mud_%d.wav" % i
		if ResourceLoader.exists(p_mud):
			_snds_dirt.append(load(p_mud))

func _input(event: InputEvent) -> void:
	if is_frozen:
		return
	
	# Se o jogo estiver pausado ou menu de pausa aberto, NUNCA captura o mouse no clique!
	var chapter = get_tree().get_first_node_in_group("chapter")
	if (chapter and "is_paused" in chapter and chapter.is_paused) or get_tree().paused:
		return

	if event is InputEventMouseButton and event.pressed:
		if Input.get_mouse_mode() != Input.MOUSE_MODE_CAPTURED:
			Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)
	
	if event is InputEventMouseMotion and Input.get_mouse_mode() == Input.MOUSE_MODE_CAPTURED:
		rotate_y(-event.relative.x * MOUSE_SENS)
		camera_mount.rotate_x(-event.relative.y * MOUSE_SENS)
		camera_mount.rotation.x = clamp(camera_mount.rotation.x, -1.2, 1.2)
		
	if event.is_action_pressed("throw_item") or (event is InputEventKey and event.pressed and event.keycode == KEY_G):
		if GameManager:
			GameManager.set_flag("held_item", "")

func _physics_process(delta: float) -> void:
	if is_frozen:
		return

	# Gravidade
	if not is_on_floor():
		velocity.y -= GRAVITY * delta

	var dir: Vector3 = Vector3.ZERO
	var fwd: Vector3 = -global_transform.basis.z
	fwd.y = 0
	fwd = fwd.normalized()
	var right: Vector3 = global_transform.basis.x
	right.y = 0
	right = right.normalized()

	if Input.is_action_pressed("move_forward") or Input.is_key_pressed(KEY_W) or Input.is_key_pressed(KEY_UP): dir += fwd
	if Input.is_action_pressed("move_backward") or Input.is_key_pressed(KEY_S) or Input.is_key_pressed(KEY_DOWN): dir -= fwd
	if Input.is_action_pressed("move_left") or Input.is_key_pressed(KEY_A) or Input.is_key_pressed(KEY_LEFT): dir -= right
	if Input.is_action_pressed("move_right") or Input.is_key_pressed(KEY_D) or Input.is_key_pressed(KEY_RIGHT): dir += right

	var is_moving: bool = dir.length() > 0.01

	if is_moving:
		dir = dir.normalized()
		velocity.x = dir.x * WALK_SPEED
		velocity.z = dir.z * WALK_SPEED

		# Step assist para subir calçadas e meios-fios suavemente
		_handle_step_assist(dir)
	else:
		velocity.x = lerp(velocity.x, 0.0, delta * 10.0)
		velocity.z = lerp(velocity.z, 0.0, delta * 10.0)

	move_and_slide()

	# Head bobbing e detecção de passos 100% sincronizada
	_process_head_bob_and_footsteps(delta, is_moving)

	# Interação
	_check_interaction()

func _process_head_bob_and_footsteps(delta: float, is_moving: bool) -> void:
	var horiz_vel := Vector2(velocity.x, velocity.z).length()
	
	if is_moving and is_on_floor() and horiz_vel > 0.5:
		var speed_factor = clamp(horiz_vel / WALK_SPEED, 0.4, 1.2)
		var prev_bob = bob_time
		bob_time += delta * BOB_FREQUENCY * speed_factor
		
		# Curva natural de passos (cabeça desce no momento em que o pé atinge o chão)
		var current_step_cycle = sin(bob_time)
		
		# Dispara som de passo exatamente no ponto mais baixo do impacto do pé
		if current_step_cycle < 0.0 and last_step_sign >= 0.0:
			_play_footstep_sound()
		elif current_step_cycle >= 0.0 and last_step_sign < 0.0:
			_play_footstep_sound()
		
		last_step_sign = current_step_cycle
		
		var target_y = camera_base_y - abs(sin(bob_time)) * BOB_VERTICAL_AMP
		var target_x = sin(bob_time * 0.5) * BOB_HORIZONTAL_AMP
		camera_mount.position.y = lerp(camera_mount.position.y, target_y, delta * 12.0)
		camera_mount.position.x = lerp(camera_mount.position.x, target_x, delta * 12.0)
	else:
		# Retorno suave ao centro quando parado
		bob_time = 0.0
		last_step_sign = 1.0
		camera_mount.position.y = lerp(camera_mount.position.y, camera_base_y, delta * 8.0)
		camera_mount.position.x = lerp(camera_mount.position.x, 0.0, delta * 8.0)

func _play_footstep_sound() -> void:
	if not _audio_footstep or not is_on_floor():
		return
	
	# Detecta tipo de superfície abaixo do jogador via Raycast
	var space_state = get_world_3d().direct_space_state
	var ray_query = PhysicsRayQueryParameters3D.create(global_position + Vector3(0, 0.5, 0), global_position + Vector3(0, -1.2, 0))
	ray_query.exclude = [self]
	var hit = space_state.intersect_ray(ray_query)
	
	var surface_type := "concrete"
	if not hit.is_empty() and hit.has("collider"):
		var col = hit["collider"]
		var col_name = col.name.to_lower()
		if col.get_parent():
			col_name += " " + col.get_parent().name.to_lower()
		
		if "grass" in col_name or "grama" in col_name or "folha" in col_name or "jardim" in col_name or "vegetat" in col_name:
			surface_type = "grass"
		elif "mud" in col_name or "dirt" in col_name or "terra" in col_name or "lama" in col_name:
			surface_type = "dirt"
	
	var pool: Array[AudioStream] = _snds_concrete
	if surface_type == "grass" and not _snds_grass.is_empty():
		pool = _snds_grass
	elif surface_type == "dirt" and not _snds_dirt.is_empty():
		pool = _snds_dirt
	
	if not pool.is_empty():
		var stream_to_play: AudioStream = pool[randi() % pool.size()]
		_audio_footstep.stream = stream_to_play
		_audio_footstep.pitch_scale = randf_range(0.95, 1.05)
		_audio_footstep.volume_db = randf_range(-7.0, -5.0)
		_audio_footstep.play()

func _handle_step_assist(dir: Vector3) -> void:
	if not is_on_floor():
		return
	if is_on_wall():
		var space_state = get_world_3d().direct_space_state
		var step_origin = global_position + Vector3(0, MAX_STEP_HEIGHT, 0)
		var query = PhysicsRayQueryParameters3D.create(step_origin, step_origin + dir * 0.5)
		query.exclude = [self]
		var result = space_state.intersect_ray(query)
		if result.is_empty():
			global_position.y += 0.12

func _check_interaction() -> void:
	var chapter = get_tree().get_first_node_in_group("chapter")
	if not interact_ray.is_colliding():
		if chapter and chapter.has_method("hide_interact_hint"):
			chapter.hide_interact_hint()
		return
	var col := interact_ray.get_collider()
	if col and col.is_in_group("interactable"):
		var hint_text = "INTERAGIR"
		if "interaction_hint" in col and str(col.interaction_hint).strip_edges() != "":
			hint_text = str(col.interaction_hint).to_upper()
		if chapter and chapter.has_method("show_interact_hint"):
			chapter.show_interact_hint("E - " + hint_text)
		
		if Input.is_action_just_pressed("interact") or (Input.is_key_pressed(KEY_E) and not is_frozen):
			if col.has_method("interact"):
				col.interact()
	else:
		if chapter and chapter.has_method("hide_interact_hint"):
			chapter.hide_interact_hint()

func freeze() -> void:
	is_frozen = true

func unfreeze() -> void:
	is_frozen = false
