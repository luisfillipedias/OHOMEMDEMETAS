extends CanvasLayer

# ============================================================
# DIALOGUE SYSTEM -- Fears to Fathom Style
# ============================================================

signal dialogue_finished
signal choice_made(index: int)

@onready var root = $DialogueRoot
@onready var speaker_label = $DialogueRoot/DialogueBox/SpeakerLabel
@onready var text_label = $DialogueRoot/DialogueBox/TextPanel/DialogueText
@onready var choices_container = $DialogueRoot/DialogueBox/ChoicesContainer
@onready var continue_hint = $DialogueRoot/DialogueBox/ContinueHint

var _queue: Array = []
var _current_index: int = 0
var _typing: bool = false
var _current_text: String = ""
var _shown_text: String = ""
var _choices: Array = []
var _waiting_choice: bool = false

func _ready() -> void:
	root.hide()

func start_dialogue(entries: Array) -> void:
	_queue = entries
	_current_index = 0
	root.show()
	_show_current()

func _show_current() -> void:
	if _current_index >= _queue.size():
		root.hide()
		_waiting_choice = false
		Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)
		dialogue_finished.emit()
		return

	var entry = _queue[_current_index]
	_choices = []
	_waiting_choice = false
	choices_container.visible = false
	for child in choices_container.get_children():
		child.queue_free()

	if entry is String:
		var parts = entry.split(": ", true, 1)
		if parts.size() == 2:
			speaker_label.text = "[" + parts[0].to_upper() + "]"
			_current_text = parts[1].trim_prefix("'").trim_suffix("'")
		else:
			speaker_label.text = ""
			_current_text = entry
	elif entry is Dictionary:
		var spk = entry.get("speaker", "")
		if spk != "":
			speaker_label.text = "[" + spk.to_upper() + "]"
		else:
			speaker_label.text = ""
		_current_text = entry.get("text", "")
		_choices = entry.get("choices", [])

	_shown_text = ""
	continue_hint.visible = false
	text_label.text = ""
	_typing = true
	_type_next_char()

func _type_next_char() -> void:
	if not _typing:
		return
	if _shown_text.length() < _current_text.length():
		_shown_text += _current_text[_shown_text.length()]
		text_label.text = _shown_text
		get_tree().create_timer(0.018).timeout.connect(_type_next_char, CONNECT_ONE_SHOT)
	else:
		_typing = false
		if _choices.size() > 0:
			_show_choices()
		else:
			continue_hint.visible = true

func _show_choices() -> void:
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
		# Estilo Fears to Fathom: quadrado amarelo dourado + texto maiúsculo
		btn.text = "■  " + clean_text.to_upper()
		btn.alignment = HORIZONTAL_ALIGNMENT_LEFT
		btn.custom_minimum_size = Vector2(0, 32)
		btn.add_theme_color_override("font_color", Color(0.92, 0.82, 0.32, 1)) # Amarelo dourado Fears to Fathom
		btn.add_theme_color_override("font_hover_color", Color(1.0, 0.95, 0.6, 1))
		btn.add_theme_color_override("font_focus_color", Color(1.0, 0.95, 0.6, 1))
		btn.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.95))
		btn.add_theme_constant_override("shadow_offset_x", 2)
		btn.add_theme_constant_override("shadow_offset_y", 2)
		btn.add_theme_font_size_override("font_size", 17)
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
	for child in choices_container.get_children():
		child.queue_free()
	choices_container.visible = false
	_current_index += 1
	_show_current()

func _input(event: InputEvent) -> void:
	if not root.visible:
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

	if (event is InputEventKey and event.pressed and (event.keycode == KEY_SPACE or event.keycode == KEY_E or event.keycode == KEY_ENTER or event.keycode == KEY_KP_ENTER)) or \
	   (event is InputEventMouseButton and event.pressed and (event.button_index == MOUSE_BUTTON_LEFT or event.button_index == MOUSE_BUTTON_RIGHT)):
		if _typing:
			_typing = false
			_shown_text = _current_text
			text_label.text = _shown_text
			if _choices.size() > 0:
				_show_choices()
			else:
				continue_hint.visible = true
		else:
			_current_index += 1
			_show_current()
