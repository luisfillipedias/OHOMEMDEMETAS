extends CharacterBody3D

# ============================================================
# PLAYER CONTROLLER -- 1a Pessoa com step assist, head bobbing
#                      e passos realistas por tipo de solo
# ============================================================

const WALK_SPEED := 3.8
const GRAVITY := 12.0
const BOB_FREQ := 2.2
const BOB_AMP := 0.032
var MOUSE_SENS := 0.0018
const MAX_STEP_HEIGHT := 0.35

@onready var camera_mount: Node3D = $CameraMount
@onready var camera: Camera3D = $CameraMount/Camera3D
@onready var interact_ray: RayCast3D = $CameraMount/Camera3D/InteractRay

var is_frozen: bool = false
var bob_time: float = 0.0
var camera_base_y: float = 0.65

# Sistema de Sons de Passos
var _step_timer: float = 0.0
const STEP_INTERVAL: float = 0.44
var _audio_footstep: AudioStreamPlayer = null
var _snd_step_concrete: AudioStream = null
var _snd_step_grass: AudioStream = null
var _snd_step_dirt: AudioStream = null
var _snd_step_wood: AudioStream = null

func _ready() -> void:
	add_to_group("player")
	Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)
	camera_base_y = camera_mount.position.y
	floor_snap_length = 0.4
	floor_max_angle = deg_to_rad(50.0)
	_setup_footstep_audio()

func _setup_footstep_audio() -> void:
	_audio_footstep = AudioStreamPlayer.new()
	_audio_footstep.name = "PlayerFootstepAudio"
	_audio_footstep.volume_db = -10.0
	add_child(_audio_footstep)

	if ResourceLoader.exists("res://assets/audio/ambience/pack itchio PSX/pack itchio PSX/sfx/footsteps/tunnel steps.wav"):
		_snd_step_concrete = load("res://assets/audio/ambience/pack itchio PSX/pack itchio PSX/sfx/footsteps/tunnel steps.wav")
	elif ResourceLoader.exists("res://assets/audio/footstep.wav"):
		_snd_step_concrete = load("res://assets/audio/footstep.wav")

	if ResourceLoader.exists("res://assets/audio/ambience/pack itchio PSX/pack itchio PSX/sfx/footsteps/tall grass steps.wav"):
		_snd_step_grass = load("res://assets/audio/ambience/pack itchio PSX/pack itchio PSX/sfx/footsteps/tall grass steps.wav")

	if ResourceLoader.exists("res://assets/audio/ambience/pack itchio PSX/pack itchio PSX/sfx/footsteps/mud steps.wav"):
		_snd_step_dirt = load("res://assets/audio/ambience/pack itchio PSX/pack itchio PSX/sfx/footsteps/mud steps.wav")
	elif ResourceLoader.exists("res://assets/audio/ambience/pack itchio PSX/pack itchio PSX/sfx/footsteps/forest steps.wav"):
		_snd_step_dirt = load("res://assets/audio/ambience/pack itchio PSX/pack itchio PSX/sfx/footsteps/forest steps.wav")

func _input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed:
		if not is_frozen and Input.get_mouse_mode() != Input.MOUSE_MODE_CAPTURED:
			Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)
	if is_frozen:
		return
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

	if dir.length() > 0.01:
		dir = dir.normalized()
		velocity.x = dir.x * WALK_SPEED
		velocity.z = dir.z * WALK_SPEED
		bob_time += delta

		# Step assist para subir calçadas e meios-fios suavemente
		_handle_step_assist(dir)
		
		# Processa passos na superfície
		if is_on_floor():
			_step_timer += delta
			if _step_timer >= STEP_INTERVAL:
				_step_timer = 0.0
				_play_footstep_sound()
	else:
		velocity.x = lerp(velocity.x, 0.0, delta * 9.0)
		velocity.z = lerp(velocity.z, 0.0, delta * 9.0)
		_step_timer = STEP_INTERVAL * 0.8 # Deixa pronto para o primeiro passo ao andar

	move_and_slide()

	# Head bobbing
	var target_y: float = camera_base_y
	if dir.length() > 0.01 and is_on_floor():
		target_y += sin(bob_time * BOB_FREQ) * BOB_AMP
	camera_mount.position.y = lerp(camera_mount.position.y, target_y, delta * 8.0)

	# Interação
	_check_interaction()

func _play_footstep_sound() -> void:
	if not _audio_footstep:
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
	
	var stream_to_play: AudioStream = _snd_step_concrete
	if surface_type == "grass" and _snd_step_grass:
		stream_to_play = _snd_step_grass
	elif surface_type == "dirt" and _snd_step_dirt:
		stream_to_play = _snd_step_dirt
	
	if stream_to_play:
		_audio_footstep.stream = stream_to_play
		_audio_footstep.pitch_scale = randf_range(0.92, 1.08)
		_audio_footstep.volume_db = randf_range(-12.0, -9.0)
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