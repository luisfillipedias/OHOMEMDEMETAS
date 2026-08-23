extends CanvasLayer

# ============================================================
# SMARTPHONE INTERFACE — Fears to Fathom Style
# Simula WhatsApp para contatos e Discord para o Miguel
# ============================================================

signal phone_closed
signal stalker_message_read

@onready var phone_container = $PhoneContainer
@onready var contacts_list = $PhoneContainer/PhoneBody/ContactsList
@onready var chat_view = $PhoneContainer/PhoneBody/ChatView
@onready var chat_title = $PhoneContainer/PhoneBody/ChatView/Header/ChatContactName
@onready var messages_container = $PhoneContainer/PhoneBody/ChatView/Scroll/MessagesVBox
@onready var back_btn = $PhoneContainer/PhoneBody/ChatView/Header/BackBtn
@onready var close_btn = $PhoneContainer/PhoneBody/TopBar/ClosePhoneBtn
@onready var notification_banner = $NotificationBanner
@onready var notif_text = $NotificationBanner/Margin/HBox/NotifText
@onready var notif_btn = $NotificationBanner/Margin/HBox/NotifBtn
@onready var audio_msg = $AudioMessage
@onready var audio_notif = $AudioNotif

var current_contact_id: String = ""
var stalker_sms_arrived: bool = false
var is_open: bool = false

var contacts_data = {
	"miguel": {
		"name": "Miguel (Discord)",
		"is_discord": true,
		"preview": "Vamo call?",
		"messages": [
			{"from_me": false, "user": "Miguel", "time": "20:30", "text": "e aí caloura do cefet!! vamo call?"},
			{"from_me": true, "user": "alice", "time": "20:32", "text": "mamae e papai foram no mercado ;)"},
			{"from_me": true, "user": "alice", "time": "20:33", "text": "ja ja eu chego em casa, eles me deixaram aqui perto..."},
			{"from_me": false, "user": "Miguel", "time": "20:34", "text": "kkkkk se você quiser eu pego um cometa aqui de uberaba agora só pra ir segurar sua mão no primeiro dia 😂"},
			{"from_me": true, "user": "alice", "time": "20:35", "text": "cê é doido miguel kkkk 8 horas de viagem"}
		]
	},
	"mae": {
		"name": "Mãe ❤️",
		"is_discord": false,
		"preview": "Filha, a orquestra da polícia...",
		"messages": [
			{"from_me": false, "time": "14:10", "text": "Oi meu amor! Chegou bem no CEFET?"},
			{"from_me": true, "time": "14:15", "text": "cheguei sim mae! to na fila agora"},
			{"from_me": false, "time": "14:16", "text": "Que bom! Seu pai falou que mês que vem na orquestra da PM ele vai tocar trompete em homenagem à sua matrícula! kkkk"},
			{"from_me": true, "time": "14:18", "text": "kkkkk meu deus avisa ele pra nao passar vergonha"},
			{"from_me": false, "time": "14:20", "text": "Cuidado com essa chuva, vem direto pra casa depois."}
		]
	},
	"pai": {
		"name": "Pai 👮",
		"is_discord": false,
		"preview": "Fica esperta com gente estranha",
		"messages": [
			{"from_me": false, "time": "13:40", "text": "Alice, tudo certo aí no CEFET?"},
			{"from_me": true, "time": "13:45", "text": "tudo certo pai, so fila grande"},
			{"from_me": false, "time": "13:46", "text": "Ótimo. Não fica moscando com o celular na rua na saída não. Olho vivo em volta sempre, BH tá perigosa."},
			{"from_me": true, "time": "13:50", "text": "pode deixar pai to esperta"}
		]
	},
	"serena": {
		"name": "Serena 🍄🧚",
		"is_discord": false,
		"preview": "apaguei todas nossas mensagens sem querer kkkkkk",
		"messages": [
			{"from_me": true, "time": "12:00", "text": "apaguei todas nossas mensagens sem querer kkkkkk"},
			{"from_me": false, "time": "12:05", "text": "ALICEEEE sabia que se você der um nome carinhoso pra uma vaca ela produz 20% mais leite? É a energia do amor"},
			{"from_me": true, "time": "12:08", "text": "serena do ceu de onde voce tirou isso kkkk"}
		]
	},
	"bob": {
		"name": "Bob (Irmãozinho) 🚌",
		"is_discord": false,
		"preview": "[Foto] Terminei o ônibus 1502 de LEGO!",
		"messages": [
			{"from_me": false, "time": "16:20", "text": "Alice olha isso aqui que eu montei: o 1502 Vista Alegre de LEGO!"},
			{"from_me": true, "time": "16:22", "text": "mano ficou identico ate com adesivo da bhtrans kkkk"}
		]
	},
	"eu": {
		"name": "Eu (Anotações)",
		"is_discord": false,
		"preview": "[Encaminhado] como socializar em escola nova",
		"messages": [
			{"from_me": true, "time": "08:00", "text": "lembrar de comprar caderno quadriculado e caneta preta"},
			{"from_me": true, "time": "08:01", "text": "[link encaminhado] 10 dicas de psicologia para fazer amigos sem parecer esquisita no 1o dia"}
		]
	},
	"stalker": {
		"name": "+55 (31) 98744-XXXX",
		"is_discord": false,
		"preview": "Te vejo na sala 305.",
		"messages": [
			{"from_me": false, "time": "20:42", "text": "Parabéns pela matrícula no CEFET hoje, Alice..."},
			{"from_me": false, "time": "20:43", "text": "Você fica bonita de jaqueta preta. Chuva boa em BH né?"},
			{"from_me": false, "time": "20:44", "text": "Te vejo na sala 305. 😊"}
		]
	}
}

func _ready() -> void:
	phone_container.hide()
	notification_banner.hide()
	chat_view.hide()
	back_btn.pressed.connect(_on_back_pressed)
	close_btn.pressed.connect(close_phone)
	if notif_btn:
		notif_btn.pressed.connect(_on_notif_clicked)

func toggle_phone() -> void:
	if is_open:
		close_phone()
	else:
		open_phone()

func open_phone() -> void:
	is_open = true
	phone_container.show()
	contacts_list.show()
	chat_view.hide()
	Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
	_build_contacts_list()

func close_phone() -> void:
	is_open = false
	phone_container.hide()
	notification_banner.hide()
	Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)
	phone_closed.emit()

func _build_contacts_list() -> void:
	var vbox = contacts_list.get_node("Scroll/VBox")
	for child in vbox.get_children():
		child.queue_free()

	for contact_id in contacts_data.keys():
		if contact_id == "stalker" and not stalker_sms_arrived:
			continue

		var contact = contacts_data[contact_id]
		var btn = Button.new()
		var prefix = "💬 "
		if contact.get("is_discord", false):
			prefix = "🎮 "
		btn.text = prefix + contact["name"] + "\n  " + contact["preview"]
		btn.alignment = HORIZONTAL_ALIGNMENT_LEFT
		btn.custom_minimum_size = Vector2(0, 50)
		btn.add_theme_font_size_override("font_size", 13)
		
		if contact.get("is_discord", false):
			btn.add_theme_color_override("font_color", Color(0.45, 0.7, 1.0, 1))
		else:
			btn.add_theme_color_override("font_color", Color(0.9, 0.9, 0.9, 1))

		var cid = contact_id
		btn.pressed.connect(func(): _open_chat(cid))
		vbox.add_child(btn)

func _open_chat(contact_id: String) -> void:
	current_contact_id = contact_id
	var contact = contacts_data[contact_id]
	chat_title.text = contact["name"]
	contacts_list.hide()
	chat_view.show()

	for child in messages_container.get_children():
		child.queue_free()

	var is_discord = contact.get("is_discord", false)

	for msg in contact["messages"]:
		var label = Label.new()
		label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		label.custom_minimum_size = Vector2(250, 0)
		
		if is_discord:
			var user = msg.get("user", "User")
			var time = msg.get("time", "")
			label.text = user + " [" + time + "]:\n" + msg["text"]
			if msg["from_me"]:
				label.add_theme_color_override("font_color", Color(0.6, 0.9, 1.0, 1))
			else:
				label.add_theme_color_override("font_color", Color(0.9, 0.85, 0.6, 1))
		else:
			if msg["from_me"]:
				label.text = msg["text"]
				label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
				label.add_theme_color_override("font_color", Color(0.6, 1.0, 0.7, 1))
			else:
				label.text = msg["text"]
				label.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
				label.add_theme_color_override("font_color", Color(0.95, 0.95, 0.95, 1))
		
		messages_container.add_child(label)

	if contact_id == "stalker":
		stalker_message_read.emit()

func _on_back_pressed() -> void:
	chat_view.hide()
	contacts_list.show()
	_build_contacts_list()

func trigger_stalker_sms() -> void:
	stalker_sms_arrived = true
	notif_text.text = "💬 Nova Mensagem de Número Desconhecido:\n'Parabéns pela matrícula no CEFET hoje, Alice...'"
	notification_banner.show()
	if audio_notif:
		audio_notif.play()

	var tw = create_tween()
	tw.tween_property(notification_banner, "position:y", 20.0, 0.4)

func _on_notif_clicked() -> void:
	notification_banner.hide()
	open_phone()
	_open_chat("stalker")
