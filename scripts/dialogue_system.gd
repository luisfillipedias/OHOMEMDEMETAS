extends CanvasLayer

# ============================================================
# DIALOGUE SYSTEM -- Fears to Fathom
# Texto pixelado, frase normal (não CAIXA ALTA), sem caixa,
# opções em amarelo + ■, typewriter igual ao dos objetivos.
# ============================================================

signal dialogue_finished
signal choice_made(index: int)

var root: Control = null
var speaker_label: Label = null
var text_label: Label = null
var choices_container: VBoxContainer = null
var continue_hint: Label = null
var black_overlay: ColorRect = null
var _pixel_font: Font = null

const COLOR_SPEAKER := Color(0.96, 0.88, 0.55, 1.0)
const COLOR_BODY := Color(0.96, 0.96, 0.94, 1.0)
const COLOR_THOUGHT := Color(0.78, 0.78, 0.76, 1.0)
const COLOR_CHOICE := Color(0.86, 0.78, 0.48, 1.0)

var _queue: Array = []
var _current_index: int = 0
var _typing: bool = false
var _current_text: String = ""
var _shown_text: String = ""
var _choices: Array = []
var _waiting_choice: bool = false
var _is_thought: bool = false
var _type_token: int = 0
var _audio_tick: AudioStreamPlayer = null
var _dialogue_active: bool = false

func _ready() -> void:
	layer = 80
	if ResourceLoader.exists("res://assets/fonts/text_font.ttf"):
		_pixel_font = load("res://assets/fonts/text_font.ttf") as Font
	_resolve_nodes()
	if root:
		root.hide()
	if black_overlay:
		black_overlay.hide()
	_setup_typewriter_audio()

func _resolve_nodes() -> void:
	black_overlay = find_child("BlackOverlay", true, false) as ColorRect
	root = find_child("DialogueRoot", true, false) as Control
	var dbox = find_child("DialogueBox", true, false)
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

func _load_typing_stream() -> AudioStream:
	var paths := [
		"res://assets/audio/menu/Text-typing.ogg",
		"res://assets/audio/menu/Text-typing.OGG",
		"res://assets/audio/menu/text-typing.ogg",
		"res://assets/audio/menu/typewriter.ogg",
	]
	for p in paths:
		if ResourceLoader.exists(p):
			return load(p) as AudioStream
	return null

func _setup_typewriter_audio() -> void:
	_audio_tick = AudioStreamPlayer.new()
	_audio_tick.name = "DialogueTypewriter"
	_audio_tick.volume_db = -4.0
	_audio_tick.stream = _load_typing_stream()
	add_child(_audio_tick)

func start_dialogue(entries: Array, black_screen: bool = false) -> void:
	_resolve_nodes()
	_dialogue_active = true
	_queue = entries
	_current_index = 0
	_waiting_choice = false
	if black_overlay:
		black_overlay.visible = black_screen
		black_overlay.color = Color(0, 0, 0, 1)
	if root:
		root.show()
	_show_current()

func is_active() -> bool:
	return _dialogue_active and (root == null or root.visible)

func _show_current() -> void:
	if _current_index >= _queue.size():
		_finish_dialogue()
		return

	var entry = _queue[_current_index]
	_choices = []
	_waiting_choice = false
	_is_thought = false
	if choices_container:
		choices_container.visible = false
		for child in choices_container.get_children():
			child.queue_free()

	var speaker := ""
	if entry is String:
		var parts = entry.split(": ", true, 1)
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
	_start_typing_sfx()
	_type_next_char(_type_token)

func _display_speaker(raw: String) -> String:
	var key := raw.strip_edges().to_upper()
	match key:
		"MAE", "MÃE", "MÃE:":
			return "Mãe"
		"PAI":
			return "Pai"
		"ALICE":
			return "Alice"
		_:
			if raw.length() == 0:
				return ""
			return raw.substr(0, 1).to_upper() + raw.substr(1)

func _start_typing_sfx() -> void:
	if not is_instance_valid(_audio_tick) or _audio_tick.stream == null:
		return
	_audio_tick.stop()
	_audio_tick.pitch_scale = randf_range(0.98, 1.02)
	_audio_tick.play()

func _stop_typing_sfx() -> void:
	if is_instance_valid(_audio_tick):
		_audio_tick.stop()

func _type_next_char(token: int) -> void:
	if token != _type_token or not _typing:
		return
	if _shown_text.length() < _current_text.length():
		_shown_text += _current_text[_shown_text.length()]
		if text_label:
			text_label.text = _shown_text
		var delay := 0.035
		var last_ch := _shown_text[_shown_text.length() - 1]
		if last_ch == "." or last_ch == "?" or last_ch == "!":
			delay = 0.12
		elif last_ch == "," or last_ch == "…" or last_ch == "—":
			delay = 0.06
		get_tree().create_timer(delay).timeout.connect(func(): _type_next_char(token), CONNECT_ONE_SHOT)
	else:
		_typing = false
		_stop_typing_sfx()
		if _choices.size() > 0:
			_show_choices()
		elif continue_hint:
			continue_hint.visible = true

func _show_choices() -> void:
	if not choices_container:
		return
	choices_container.visible = true
	Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)

	for i in range(_choices.size()):
		var choice_data = _choices[i]
		var raw_text = ""
		if choice_data is Dictionary:
			raw_text = choice_data.get("text", "")
		else:
			raw_text = str(choice_data)
		var clean_text = raw_text.replace("[A]", "").replace("[B]", "").replace("[1]", "").replace("[2]", "").strip_edges()

		var btn = Button.new()
		btn.text = "■  " + clean_text.to_upper()
		btn.alignment = HORIZONTAL_ALIGNMENT_CENTER
		btn.custom_minimum_size = Vector2(0, 28)
		if _pixel_font:
			btn.add_theme_font_override("font", _pixel_font)
		btn.add_theme_color_override("font_color", COLOR_CHOICE)
		btn.add_theme_color_override("font_hover_color", Color(1.0, 0.95, 0.72, 1))
		btn.add_theme_color_override("font_focus_color", Color(1.0, 0.95, 0.72, 1))
		btn.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 1))
		btn.add_theme_constant_override("shadow_offset_x", 2)
		btn.add_theme_constant_override("shadow_offset_y", 2)
		btn.add_theme_font_size_override("font_size", 18)
		btn.flat = true
		var idx = i
		var cdata = choice_data
		btn.pressed.connect(func(): _on_choice(idx, cdata))
		choices_container.add_child(btn)

	_waiting_choice = true

func _on_choice(idx: int, _choice_data = null) -> void:
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
	_typing = false
	_waiting_choice = false
	_dialogue_active = false
	_stop_typing_sfx()
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

	var advance := false
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_SPACE or event.keycode == KEY_E or event.keycode == KEY_ENTER or event.keycode == KEY_KP_ENTER:
			advance = true
	elif event is InputEventMouseButton and event.pressed and (event.button_index == MOUSE_BUTTON_LEFT or event.button_index == MOUSE_BUTTON_RIGHT):
		advance = true

	if not advance:
		return

	get_viewport().set_input_as_handled()
	if _typing:
		_typing = false
		_stop_typing_sfx()
		_shown_text = _current_text
		if text_label:
			text_label.text = _shown_text
		if _choices.size() > 0:
			_show_choices()
		elif continue_hint:
			continue_hint.visible = true
	else:
		_current_index += 1
		_show_current()
