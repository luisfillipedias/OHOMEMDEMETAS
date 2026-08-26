extends CanvasLayer

signal dialogue_finished
signal choice_made(index: int)

var root: Control = null
var speaker_label: Label = null
var text_label: Label = null
var choices_container: VBoxContainer = null
var continue_hint: Label = null
var black_overlay: ColorRect = null
var _pixel_font: Font = null

const COLOR_SPEAKER := Color(1, 0.96, 0.62, 1.0)
const COLOR_BODY := Color(1, 1, 1, 1.0)
const COLOR_THOUGHT := Color(0.82, 0.82, 0.84, 1.0)
const COLOR_CHOICE := Color(0.92, 0.84, 0.56, 1.0)

var _queue: Array = []
var _current_index: int = 0
var _typing: bool = false
var _current_text: String = ""
var _shown_text: String = ""
var _choices: Array = []
var _waiting_choice: bool = false
var _is_thought: bool = false
var _type_token: int = 0
var _dialogue_active: bool = false

var _audio_typing: AudioStreamPlayer = null
var _audio_voice: AudioStreamPlayer = null

var _voice_clip_cache: Dictionary = {}
var _auto_advance_timer: Timer = null
var _current_voice_speaker: String = ""
var _line_pitch_scale: float = 1.0

func _ready() -> void:
	layer = 80
	if ResourceLoader.exists("res://assets/fonts/LEDpixel-Square.otf"):
		_pixel_font = load("res://assets/fonts/LEDpixel-Square.otf") as Font
	elif ResourceLoader.exists("res://assets/fonts/text_font.ttf"):
		_pixel_font = load("res://assets/fonts/text_font.ttf") as Font
	_resolve_nodes()
	if root:
		root.hide()
	if black_overlay:
		black_overlay.hide()
	_setup_audio()
	_setup_auto_advance()

func _resolve_nodes() -> void:
	black_overlay = find_child("BlackOverlay", true, false) as ColorRect
	root = find_child("DialogueRoot", true, false) as Control
	var dbox: Node = find_child("DialogueBox", true, false) as Node
	if dbox:
		speaker_label = dbox.find_child("SpeakerLabel", true, false) as Label
		text_label = dbox.find_child("DialogueText", true, false) as Label
		choices_container = dbox.find_child("ChoicesContainer", true, false) as VBoxContainer
		continue_hint = dbox.find_child("ContinueHint", true, false) as Label
	_apply_pixel_font()

func _apply_pixel_font() -> void:
	if _pixel_font == null:
		return
	for lab in [speaker_label, text_label, continue_hint]:
		if lab:
			lab.add_theme_font_override("font", _pixel_font)
			lab.uppercase = false
	if speaker_label:
		speaker_label.uppercase = true

func _setup_audio() -> void:
	_audio_typing = AudioStreamPlayer.new()
	_audio_typing.name = "TypingSFX"
	_audio_typing.volume_db = 3.0
	var typing_paths: Array = [
		"res://assets/audio/menu/Text-typing.ogg",
		"res://assets/audio/menu/text-typing.ogg",
		"res://assets/audio/menu/typewriter.ogg",
	]
	for p in typing_paths:
		if ResourceLoader.exists(p):
			_audio_typing.stream = load(p) as AudioStream
			break
	add_child(_audio_typing)

	_audio_voice = AudioStreamPlayer.new()
	_audio_voice.name = "UndertaleVoice"
	_audio_voice.volume_db = 1.5
	add_child(_audio_voice)

	_preload_voice_clips()

func _preload_voice_clips() -> void:
	var map: Dictionary = {
		"alice": "res://assets/audio/voices/torieldialogue.mp3",
		"mãe": "res://assets/audio/voices/asrieldialogue.mp3",
		"mae": "res://assets/audio/voices/asrieldialogue.mp3",
		"pai": "res://assets/audio/voices/dialogueArgore.mp3",
	}
	for key in map.keys():
		var p: String = map[key] as String
		if ResourceLoader.exists(p):
			_voice_clip_cache[key] = load(p) as AudioStream
	if not _voice_clip_cache.has("__generic__"):
		if ResourceLoader.exists("res://assets/audio/voices/generic2.mp3"):
			_voice_clip_cache["__generic__"] = load("res://assets/audio/voices/generic2.mp3") as AudioStream

func _voice_for_speaker(raw: String) -> AudioStream:
	if _voice_clip_cache.is_empty():
		return null
	var k: String = raw.strip_edges().to_lower()
	if _voice_clip_cache.has(k):
		return _voice_clip_cache[k]
	if k == "mãe" or k == "mae":
		return _voice_clip_cache.get("mae", _voice_clip_cache.get("__generic__", null))
	return _voice_clip_cache.get("__generic__", null)

func _pitch_for_speaker(raw: String) -> float:
	var k: String = raw.strip_edges().to_upper()
	match k:
		"ALICE":
			return float(randf_range(1.18, 1.24))
		"MÃE", "MAE":
			return float(randf_range(1.06, 1.12))
		"PAI":
			return float(randf_range(0.78, 0.84))
		_:
			return float(randf_range(0.98, 1.04))

func _setup_auto_advance() -> void:
	_auto_advance_timer = Timer.new()
	_auto_advance_timer.name = "AutoAdvanceTimer"
	_auto_advance_timer.wait_time = 20.2
	_auto_advance_timer.one_shot = true
	_auto_advance_timer.autostart = false
	_auto_advance_timer.process_mode = Node.PROCESS_MODE_ALWAYS
	_auto_advance_timer.timeout.connect(_on_auto_advance)
	add_child(_auto_advance_timer)

func _cancel_auto_advance() -> void:
	if _auto_advance_timer and _auto_advance_timer.is_stopped() == false:
		_auto_advance_timer.stop()

func _restart_auto_advance() -> void:
	if _waiting_choice:
		return
	_cancel_auto_advance()
	if _auto_advance_timer:
		var extra: float = float(clamp(float(_current_text.length()) * 0.018, 0.0, 5.0))
		_auto_advance_timer.wait_time = 18.8 + extra
		_auto_advance_timer.start()

func _on_auto_advance() -> void:
	if _typing:
		_force_end_typing()
		return
	if _dialogue_active and not _waiting_choice:
		_current_index += 1
		_show_current()

func start_dialogue(entries: Array, black_screen: bool = false) -> void:
	_resolve_nodes()
	_dialogue_active = true
	_queue = entries
	_current_index = 0
	_waiting_choice = false
	_cancel_auto_advance()
	if black_overlay:
		black_overlay.visible = black_screen
		black_overlay.color = Color(0, 0, 0, 1)
	if root:
		root.show()
	_show_current()

func is_active() -> bool:
	return _dialogue_active and (root == null or root.visible)

func _show_current() -> void:
	_cancel_auto_advance()
	if _current_index >= _queue.size():
		_finish_dialogue()
		return

	var entry: Variant = _queue[_current_index]
	_choices = []
	_waiting_choice = false
	_is_thought = false
	if choices_container:
		choices_container.visible = false
		for child in choices_container.get_children():
			child.queue_free()

	var speaker: String = ""
	if entry is String:
		var parts: Array = entry.split(": ", true, 1)
		if parts.size() == 2:
			speaker = str(parts[0]).strip_edges()
			_current_text = str(parts[1]).trim_prefix("'").trim_suffix("'")
		else:
			_current_text = entry
	elif entry is Dictionary:
		speaker = str(entry.get("speaker", "")).strip_edges()
		_current_text = str(entry.get("text", ""))
		_choices = entry.get("choices", [])
		_is_thought = bool(entry.get("thought", false))
	else:
		_current_text = str(entry)

	_current_text = _current_text.strip_edges()
	if not _is_thought and (_current_text.begins_with("(") and _current_text.ends_with(")")):
		_is_thought = true

	if speaker_label:
		if _is_thought or speaker == "":
			speaker_label.text = ""
			speaker_label.hide()
		else:
			speaker_label.show()
			speaker_label.text = _display_speaker(speaker)
			speaker_label.add_theme_color_override("font_color", COLOR_SPEAKER)

	if text_label:
		text_label.add_theme_color_override("font_color", COLOR_THOUGHT if _is_thought else COLOR_BODY)

	_shown_text = ""
	if continue_hint:
		continue_hint.visible = false
	if text_label:
		text_label.text = ""
	_typing = true
	_type_token += 1
	_line_pitch_scale = _pitch_for_speaker(speaker)
	_start_typing_sfx()
	_start_voice(speaker)
	_type_next_char(_type_token, speaker)

func _display_speaker(raw: String) -> String:
	var key: String = raw.strip_edges().to_upper()
	match key:
		"MAE", "MÃE", "MÃE:":
			return "MÃE"
		"PAI":
			return "PAI"
		"ALICE":
			return "ALICE"
		_:
			if raw.length() == 0:
				return ""
			return raw.strip_edges().to_upper()

func _start_typing_sfx() -> void:
	if is_instance_valid(_audio_typing) and _audio_typing.stream:
		_audio_typing.stop()
		_audio_typing.pitch_scale = float(randf_range(0.99, 1.03))
		_audio_typing.play()

func _stop_typing_sfx() -> void:
	if is_instance_valid(_audio_typing):
		_audio_typing.stop()

func _enable_stream_loop(clip: AudioStream, should_loop: bool) -> void:
	if clip is AudioStreamMP3:
		(clip as AudioStreamMP3).loop = should_loop
	elif clip is AudioStreamOggVorbis:
		(clip as AudioStreamOggVorbis).loop = should_loop
	elif clip is AudioStreamWAV:
		(clip as AudioStreamWAV).loop_mode = AudioStreamWAV.LOOP_FORWARD if should_loop else AudioStreamWAV.LOOP_DISABLED

func _start_voice(speaker: String) -> void:
	if not is_instance_valid(_audio_voice):
		return
	if _is_thought or speaker.strip_edges().is_empty() or _current_text.is_empty():
		_stop_voice()
		return
	var clip: AudioStream = _voice_for_speaker(speaker)
	if clip == null:
		_stop_voice()
		return
	# Clip curto (beep estilo Undertale) faz loop durante a digitação.
	# Clip longo toca do início e é cortado quando a digitação acaba.
	var clip_len: float = clip.get_length()
	_enable_stream_loop(clip, clip_len > 0.0 and clip_len < 0.5)
	_audio_voice.stop()
	_audio_voice.stream = clip
	_audio_voice.pitch_scale = _line_pitch_scale
	_current_voice_speaker = speaker.strip_edges().to_lower()
	_audio_voice.play()

func _stop_voice() -> void:
	if is_instance_valid(_audio_voice):
		_audio_voice.stop()

func _force_end_typing() -> void:
	if not _typing:
		return
	_typing = false
	_shown_text = _current_text
	if is_instance_valid(text_label):
		text_label.text = _shown_text
	_stop_typing_sfx()
	_stop_voice()
	if _choices.size() > 0:
		_show_choices()
	elif continue_hint:
		continue_hint.visible = true
	_restart_auto_advance()

func _type_next_char(token: int, speaker: String) -> void:
	if token != _type_token or not _typing:
		return
	if _shown_text.length() < _current_text.length():
		var next_ch: String = _current_text[_shown_text.length()]
		_shown_text += next_ch
		if text_label:
			text_label.text = _shown_text
		if _shown_text.length() >= _current_text.length():
			_stop_voice()
			_stop_typing_sfx()
		var delay: float = 0.032
		if next_ch == "." or next_ch == "?" or next_ch == "!":
			delay = 0.14
		elif next_ch == "," or next_ch == "…" or next_ch == "—":
			delay = 0.07
		get_tree().create_timer(delay).timeout.connect(func(): _type_next_char(token, speaker), CONNECT_ONE_SHOT)
	else:
		_typing = false
		_stop_typing_sfx()
		_stop_voice()
		if _choices.size() > 0:
			_show_choices()
		elif continue_hint:
			continue_hint.visible = true
		_restart_auto_advance()

func _show_choices() -> void:
	if not choices_container:
		return
	choices_container.visible = true
	Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)

	for i in range(_choices.size()):
		var choice_data: Variant = _choices[i]
		var raw_text: String = ""
		if choice_data is Dictionary:
			raw_text = str(choice_data.get("text", ""))
		else:
			raw_text = str(choice_data)
		var clean_text: String = raw_text.replace("[A]", "").replace("[B]", "").replace("[1]", "").replace("[2]", "").strip_edges()

		var btn: Button = Button.new()
		btn.text = "■  " + clean_text.to_upper()
		btn.alignment = HORIZONTAL_ALIGNMENT_CENTER
		btn.custom_minimum_size = Vector2(0, 28)
		if _pixel_font:
			btn.add_theme_font_override("font", _pixel_font)
		btn.add_theme_color_override("font_color", COLOR_CHOICE)
		btn.add_theme_color_override("font_hover_color", Color(1.0, 0.96, 0.72, 1))
		btn.add_theme_color_override("font_focus_color", Color(1.0, 0.96, 0.72, 1))
		btn.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 1))
		btn.add_theme_constant_override("shadow_offset_x", 2)
		btn.add_theme_constant_override("shadow_offset_y", 2)
		btn.add_theme_font_size_override("font_size", 18)
		btn.flat = true
		var idx: int = i
		var cdata: Variant = choice_data
		btn.pressed.connect(func(): _on_choice(idx, cdata))
		choices_container.add_child(btn)

	_waiting_choice = true
	_cancel_auto_advance()

func _on_choice(idx: int, _choice_data: Variant = null) -> void:
	choice_made.emit(idx)
	_waiting_choice = false
	Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)
	if choices_container:
		for child in choices_container.get_children():
			child.queue_free()
		choices_container.visible = false
	_current_index += 1
	_show_current()

func _finish_dialogue() -> void:
	_cancel_auto_advance()
	_typing = false
	_waiting_choice = false
	_dialogue_active = false
	_stop_typing_sfx()
	_stop_voice()
	if root:
		root.hide()
	if black_overlay:
		black_overlay.hide()
	if speaker_label:
		speaker_label.text = ""
	if text_label:
		text_label.text = ""
	Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)
	dialogue_finished.emit()

func _input(event: InputEvent) -> void:
	if not root or not root.visible:
		return

	if _waiting_choice:
		if event is InputEventKey and event.pressed:
			if event.keycode == KEY_1 and _choices.size() >= 1:
				_on_choice(0, _choices[0])
				return
			elif event.keycode == KEY_2 and _choices.size() >= 2:
				_on_choice(1, _choices[1])
				return
			elif event.keycode == KEY_3 and _choices.size() >= 3:
				_on_choice(2, _choices[2])
				return
		return

	var advance: bool = false
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_SPACE or event.keycode == KEY_E or event.keycode == KEY_ENTER or event.keycode == KEY_KP_ENTER:
			advance = true
	elif event is InputEventMouseButton and event.pressed and (event.button_index == MOUSE_BUTTON_LEFT or event.button_index == MOUSE_BUTTON_RIGHT):
		advance = true

	if not advance:
		return

	get_viewport().set_input_as_handled()
	if _typing:
		_force_end_typing()
	else:
		_cancel_auto_advance()
		_current_index += 1
		_show_current()
