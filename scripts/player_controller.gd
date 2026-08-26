extends CharacterBody3D

# ============================================================
# PLAYER CONTROLLER -- 1a Pessoa com sistema de passos por
#                      deslocamento físico real contínuo & Zoom
# ============================================================

const WALK_SPEED := 3.2
const GRAVITY := 12.0
const MAX_STEP_HEIGHT := 0.35

# Head Bobbing e Passos Físicos
const STEP_DISTANCE: float = 1.25 # Metros entre cada passo (1.25m = cadência humana natural)
const BOB_VERTICAL_AMP: float = 0.022
const BOB_HORIZONTAL_AMP: float = 0.010

# Mecânica de Zoom (Estilo Fears to Fathom - Segurar Botão Direito)
@export_group("Zoom / Foco")
@export var zoom_fov: float = 38.0
@export var zoom_speed: float = 9.5

@onready var camera_mount: Node3D = $CameraMount
@onready var camera: Camera3D = $CameraMount/Camera3D
@onready var interact_ray: RayCast3D = $CameraMount/Camera3D/InteractRay

var is_frozen: bool = false
var _inventario_aberto: bool = false
var _inventario_ui: CanvasLayer = null
var camera_base_y: float = 0.65
var default_fov: float = 72.0
var is_zooming: bool = false

# Head bobbing fase contínua (sem dupla suavização)
var _bob_phase: float = 0.0
var _bob_blend: float = 0.0
var _last_step_phase_id: int = 0
var _idle_time: float = 0.0
const BOB_FREQUENCY: float = PI / STEP_DISTANCE
var _audio_footstep: AudioStreamPlayer = null

# Banco de sons de passos de alta qualidade (.ogg)
var _snds_floor: Array[AudioStream] = []
var _snds_tiles: Array[AudioStream] = []
var _snds_dirt: Array[AudioStream] = []
var _snds_gravel: Array[AudioStream] = []
var _snds_wood: Array[AudioStream] = []
var _snds_carpet: Array[AudioStream] = []

func _ready() -> void:
	add_to_group("player")
	Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)
	camera_base_y = camera_mount.position.y
	default_fov = camera.fov
	floor_snap_length = 0.4
	floor_max_angle = deg_to_rad(50.0)
	
	camera.current = true
	var listener := AudioListener3D.new()
	listener.name = "PlayerAudioListener3D"
	camera.add_child(listener)
	listener.make_current()

	_setup_footstep_audio()

func _setup_footstep_audio() -> void:
	_audio_footstep = AudioStreamPlayer.new()
	_audio_footstep.name = "PlayerFootstepAudio"
	_audio_footstep.volume_db = -16.0
	add_child(_audio_footstep)

	_carregar_amostras_pasta("Floor",  _snds_floor,  21)
	_carregar_amostras_pasta("Tiles",  _snds_tiles,  22)
	_carregar_amostras_pasta("Dirt",   _snds_dirt,   21)
	_carregar_amostras_pasta("Gravel", _snds_gravel, 21)
	_carregar_amostras_pasta("Wood",   _snds_wood,   21)
	_carregar_amostras_pasta("Carpet", _snds_carpet, 21)

func _carregar_amostras_pasta(pasta: String, array_destino: Array[AudioStream], max_count: int) -> void:
	for i in range(1, max_count + 1):
		var num_str = "%03d" % i
		var p = "res://assets/audio/pegadas/%s/Steps_%s-%s.ogg" % [pasta, pasta.to_lower(), num_str]
		if ResourceLoader.exists(p):
			var st = load(p) as AudioStream
			if st:
				array_destino.append(st)

func _input(event: InputEvent) -> void:
	if is_frozen:
		return
	var chapter = get_tree().get_first_node_in_group("chapter")
	if (chapter and "is_paused" in chapter and chapter.is_paused) or get_tree().paused:
		return

	if event is InputEventMouseButton and event.pressed:
		if Input.get_mouse_mode() != Input.MOUSE_MODE_CAPTURED:
			Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)
	
	if event is InputEventMouseMotion and Input.get_mouse_mode() == Input.MOUSE_MODE_CAPTURED:
		# Sensibilidade ajustada proporcionalmente ao FOV atual (zoom mais suave e estável)
		var fov_ratio: float = camera.fov / default_fov if default_fov > 0.0 else 1.0
		var base_sens: float = GameState.mouse_sensitivity if GameState else 0.0018
		var current_sens: float = base_sens * clamp(fov_ratio, 0.45, 1.0)
		rotate_y(-event.relative.x * current_sens)
		camera_mount.rotate_x(-event.relative.y * current_sens)
		camera_mount.rotation.x = clamp(camera_mount.rotation.x, -1.2, 1.2)
		
	if event.is_action_pressed("throw_item") or (event is InputEventKey and event.pressed and event.keycode == KEY_G):
		if GameManager:
			GameManager.set_flag("held_item", "")

func _physics_process(delta: float) -> void:

	if is_frozen:
		return

	if not is_on_floor():
		velocity.y -= GRAVITY * delta

	_process_zoom(delta)

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
		var move_speed: float = WALK_SPEED * (0.85 if is_zooming else 1.0)
		velocity.x = dir.x * move_speed
		velocity.z = dir.z * move_speed
		_handle_step_assist(dir)
	else:
		velocity.x = lerp(velocity.x, 0.0, delta * 12.0)
		velocity.z = lerp(velocity.z, 0.0, delta * 12.0)

	move_and_slide()
	_process_footsteps_and_headbob(delta, is_moving)
	_check_interaction()

func _process_zoom(delta: float) -> void:
	var chapter = get_tree().get_first_node_in_group("chapter")
	var is_paused: bool = (chapter and "is_paused" in chapter and chapter.is_paused) or get_tree().paused
	
	if not is_frozen and not is_paused and Input.get_mouse_mode() == Input.MOUSE_MODE_CAPTURED:
		is_zooming = Input.is_mouse_button_pressed(MOUSE_BUTTON_RIGHT)
	else:
		is_zooming = false

	var target_fov: float = zoom_fov if is_zooming else default_fov
	camera.fov = lerp(camera.fov, target_fov, delta * zoom_speed)

func _process_footsteps_and_headbob(delta: float, is_moving: bool) -> void:
	var horiz_speed: float = Vector2(velocity.x, velocity.z).length()
	var on_ground: bool = is_on_floor()
	var moving: bool = on_ground and horiz_speed > 0.1

	# Suaviza amplitude do bobbing (durante zoom reduz sutilmente para manter foco tenso)
	var bob_scale: float = 0.55 if is_zooming else 1.0
	var target_blend: float = (1.0 * bob_scale) if moving else 0.0
	_bob_blend = lerp(_bob_blend, target_blend, delta * 8.0)

	if moving:
		_idle_time = 0.0
		# Fase avança continuamente proporcional à distância real percorrida
		_bob_phase += horiz_speed * delta * BOB_FREQUENCY

		# Dispara passo exatamente 1x por meia-volta de fase
		var phase_id: int = int(_bob_phase / PI)
		if phase_id != _last_step_phase_id:
			_last_step_phase_id = phase_id
			_play_footstep_sound()
	else:
		_idle_time += delta

	var vertical_offset: float = -abs(sin(_bob_phase)) * BOB_VERTICAL_AMP * _bob_blend
	var horizontal_offset: float = sin(_bob_phase * 0.5) * BOB_HORIZONTAL_AMP * _bob_blend
	camera_mount.position.y = camera_base_y + vertical_offset
	camera_mount.position.x = horizontal_offset

func _play_footstep_sound() -> void:
	if not _audio_footstep or not is_on_floor():
		return
	
	var space_state := get_world_3d().direct_space_state
	var ray_query := PhysicsRayQueryParameters3D.create(
		global_position + Vector3(0, 0.5, 0),
		global_position + Vector3(0, -1.2, 0)
	)
	ray_query.exclude = [self]
	var hit := space_state.intersect_ray(ray_query)
	
	var pool: Array[AudioStream] = _snds_floor
	
	if not hit.is_empty() and hit.has("collider"):
		var col: Object = hit["collider"]
		var col_name: String = col.name.to_lower()
		if col.get_parent():
			col_name += " " + col.get_parent().name.to_lower()
		
		if "tile" in col_name or "piso" in col_name or "predio" in col_name or "admin" in col_name or "sala" in col_name or "interno" in col_name:
			pool = _snds_tiles if not _snds_tiles.is_empty() else _snds_floor
		elif "grass" in col_name or "grama" in col_name or "gravel" in col_name or "cascalho" in col_name or "jardim" in col_name:
			pool = _snds_gravel if not _snds_gravel.is_empty() else _snds_floor
		elif "mud" in col_name or "dirt" in col_name or "terra" in col_name or "lama" in col_name:
			pool = _snds_dirt if not _snds_dirt.is_empty() else _snds_floor
		elif "wood" in col_name or "madeira" in col_name or "tabua" in col_name:
			pool = _snds_wood if not _snds_wood.is_empty() else _snds_floor
		elif "carpet" in col_name or "tapete" in col_name:
			pool = _snds_carpet if not _snds_carpet.is_empty() else _snds_floor
	
	if not pool.is_empty():
		var stream_to_play: AudioStream = pool[randi() % pool.size()]
		_audio_footstep.stream = stream_to_play
		_audio_footstep.pitch_scale = randf_range(0.95, 1.05)
		_audio_footstep.volume_db = randf_range(-17.0, -15.0)
		_audio_footstep.play()

func _handle_step_assist(dir: Vector3) -> void:
	if not is_on_floor():
		return
	if is_on_wall():
		var space_state := get_world_3d().direct_space_state
		var step_origin := global_position + Vector3(0, MAX_STEP_HEIGHT, 0)
		var query := PhysicsRayQueryParameters3D.create(step_origin, step_origin + dir * 0.5)
		query.exclude = [self]
		var result := space_state.intersect_ray(query)
		if result.is_empty():
			global_position.y += 0.12

func _check_interaction() -> void:
	var chapter := get_tree().get_first_node_in_group("chapter")
	if not interact_ray.is_colliding():
		if chapter and chapter.has_method("hide_interact_hint"):
			chapter.hide_interact_hint()
		return
	var col: CollisionObject3D = interact_ray.get_collider() as CollisionObject3D
	if col and col.is_in_group("interactable"):
		var hint_text := "INTERAGIR"
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


func _unhandled_key_input(event: InputEvent) -> void:
	if not (event is InputEventKey): return
	if event.pressed and not event.echo:
		if event.keycode == KEY_TAB:
			if _inventario_aberto:
				# Fechar se ja aberto: o inventario_ui trata ESC/Tab internamente,
				# mas aqui garantimos via player
				var inv = _get_inventario_ui()
				if is_instance_valid(inv) and inv.has_method("fechar"):
					inv.fechar()
			elif not is_frozen:
				_abrir_inventario()
			get_viewport().set_input_as_handled()

func freeze() -> void:
	is_frozen = true

func unfreeze() -> void:
	is_frozen = false

func _get_inventario_ui() -> CanvasLayer:
	if not is_instance_valid(_inventario_ui):
		var scene: PackedScene = load("res://scenes/ui/inventario_ui.tscn")
		if scene:
			_inventario_ui = scene.instantiate()
			get_tree().root.add_child(_inventario_ui)
			if _inventario_ui.has_signal("fechou"):
				_inventario_ui.fechou.connect(_on_inventario_fechou)
	return _inventario_ui

func _on_inventario_fechou() -> void:
	_inventario_aberto = false
	is_frozen = false
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED

func _abrir_inventario() -> void:
	_inventario_aberto = true
	is_frozen = true
	var inv = _get_inventario_ui()
	if is_instance_valid(inv) and inv.has_method("abrir"):
		inv.abrir()
