extends Control

@onready var btn_jogar = $VBox/BtnJogar
@onready var btn_continuar = $VBox/BtnContinuar
@onready var btn_creditos = $VBox/BtnCreditos
@onready var btn_sair = $VBox/BtnSair
@onready var logo = $Logo

func _ready() -> void:
	btn_jogar.pressed.connect(_jogar)
	btn_continuar.pressed.connect(_continuar)
	btn_sair.pressed.connect(get_tree().quit)
	Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)

	# Animação de pulse no logo
	var tw = create_tween().set_loops()
	tw.tween_property(logo, "scale", Vector2(1.03, 1.03), 1.2)
	tw.tween_property(logo, "scale", Vector2(1.0, 1.0), 1.2)

func _jogar() -> void:
	GameManager.change_scene("res://scenes/chapter_01.tscn")

func _continuar() -> void:
	if GameManager.get_flag("chapter_1_completed"):
		GameManager.change_scene("res://scenes/chapter_01.tscn")
