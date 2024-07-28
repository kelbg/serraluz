extends Node

@export var message_template: PackedScene
@export var default_char_icon: Texture2D
@export var chat_container: VBoxContainer
@export var input: LineEdit
@export var scroll_container: ScrollContainer

@onready var scrollbar = scroll_container.get_v_scroll_bar()

func _ready():
	input.grab_focus()
	scrollbar.changed.connect(_on_scrollbar_changed)

func display_message(char_name: String, msg: String, icon: Texture2D=default_char_icon):
	var new_msg = message_template.instantiate()
	new_msg.get_node("TextContainer/CharacterMessage").text = msg
	new_msg.get_node("CharacterInfoContainer/CharacterName").text = char_name
	new_msg.get_node("CharacterInfoContainer/CharacterIconContainer/CharacterIcon").texture = icon
	chat_container.add_child(new_msg)

func toggle_input(enabled: bool):
	input.editable = enabled
	input.placeholder_text = "Digite sua mensagem" if enabled else "Aguardando resposta..."

func _on_message_submitted(text):
	if text.strip_edges() == "":
		return

	display_message("Você", text)
	input.clear()
	toggle_input(false)

func _on_clear_pressed():
	toggle_input(true)
	for msg in chat_container.get_children():
		msg.queue_free()

func _on_message_received(char, msg, icon=default_char_icon):
	await get_tree().create_timer(0.001).timeout # Evita erros na ordem dos sinais
	display_message(char, msg, icon)
	toggle_input(true)

# Move a barra de rolagem para o final sempre que novas mensagens forem adicionadas
func _on_scrollbar_changed():
	scroll_container.scroll_vertical = scrollbar.max_value
