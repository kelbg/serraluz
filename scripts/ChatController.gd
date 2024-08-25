extends Node

@export var player: Character
@export var characters: Array[Character]
@export var chars_per_second: int
@export var default_placeholder_text: String
@export var awaiting_response_placeholder_text: String
@export_multiline var intro_message: String
@export_multiline var link_template: String
@export_multiline var prev_interactions_instructions: String

@export var message_template: PackedScene
@export var system_message_template: PackedScene
@export var chat_container: VBoxContainer
@export var input: LineEdit
@export var scroll_container: ScrollContainer
@export var audio_player: AudioStreamPlayer
@export var response_length_display: Label

@onready var scrollbar: VScrollBar = scroll_container.get_v_scroll_bar()

# Mensagens armazenadas no formato usado pela API
var messages: Array
# Node do chat que irá receber a mensagem via text streaming da API
var text_stream_chat_msg: Node
# Personagem com o qual o jogador está interagindo
var current_character: Character

signal player_message_submitted(msg: String, to: Character)
signal typing_started
signal typing_char_added
signal typing_finished

func _ready() -> void:
	scrollbar.changed.connect(_on_scrollbar_changed)
	audio_player.finished.connect(_on_audio_player_finished)
	input.text_submitted.connect(_on_input_text_submitted)
	
	input.placeholder_text = default_placeholder_text
	input.grab_focus()
	toggle_input(false, "Selecione uma ação acima")
	var intro_msg := load_intro_message()
	add_chat_actions(intro_msg, [
		{
		"type": "chat",
		"target": "Lirian \"Chama Branda\"",
		"text": "【 IR ATÉ A TARVERNA 】"
		},
		{
		"type": "chat",
		"target": "Graldor Pedratorvo",
		"text": "【 IR ATÉ A FORJA 】"
		}
	])

# Retorna uma msg no formato que é usado pela maioria das APIs
func new_message(role: String, msg: String) -> Dictionary:
	return {"role": role, "content": msg}

func add_chat_message(from: Character, msg: String) -> Node:
	var role := get_role(from)
	messages.append(new_message(role, msg))

	var new_msg: Node
	if role == "system":
		new_msg = system_message_template.instantiate()
	else:
		new_msg = message_template.instantiate()
		new_msg.get_node("VBoxContainer/CharacterName").text = from.name.to_upper()
		new_msg.get_node("VBoxContainer/HBoxContainer/CharacterIcon").texture = from.icon

	new_msg.get_node("VBoxContainer/HBoxContainer/CharacterMessage").text = msg
	chat_container.add_child(new_msg)
	return new_msg

# Define o papel com base no personagem
func get_role(character: Character) -> String:
	if character == player:
		return "user"
	if characters.has(character):
		return "assistant"
	return "system"

# Habilitar impede que o jogador envie novas msgs antes de receber uma resposta
func toggle_input(enabled: bool, placeholder_text: String = "") -> void:
	input.editable = enabled

	if placeholder_text != "":
		input.placeholder_text = placeholder_text
		return

	input.placeholder_text = default_placeholder_text if enabled else awaiting_response_placeholder_text

# Anima o texto, exibindo um caractere de cada vez
func animate_text(chat_msg: Node) -> void:
	toggle_input(false)
	typing_started.emit()

	var text_field: RichTextLabel = chat_msg.get_node("VBoxContainer/HBoxContainer/CharacterMessage")
	while text_field.visible_characters < text_field.text.length():
		text_field.visible_characters += 1
		typing_char_added.emit()
		await get_tree().create_timer(1.0 / chars_per_second).timeout

	typing_finished.emit()

func update_response_length_display() -> void:
	if text_stream_chat_msg == null:
		response_length_display.text = "-/-"
		return

	var chat_msg := text_stream_chat_msg.get_node("VBoxContainer/HBoxContainer/CharacterMessage")
	var visible_chars: int = chat_msg.visible_characters
	var total_chars: int = chat_msg.text.length()

	response_length_display.text = "%s/%s" % [visible_chars, total_chars]

func start_new_chat(character: Character) -> void:
	clear_chat()
	load_system_prompt(character)
	current_character = character
	toggle_input(true)
	print("Novo chat iniciado com '%s'. Carregando prompt." % character.name)

func clear_chat() -> void:
	toggle_input(true)
	for msg in chat_container.get_children():
		msg.queue_free()

	messages.clear()
	text_stream_chat_msg = null
	update_response_length_display()

func load_system_prompt(character: Character) -> void:
	messages.append(new_message("system", character.get_prompt()))

	if character.previous_interactions.size() > 0:
		messages.append(new_message(
			"system",
			prev_interactions_instructions +
			"\n\n".join(character.previous_interactions)
		))

func load_intro_message() -> Node:
	var msg := add_chat_message(null, intro_message)
	return msg

# Adiciona links que o jogador pode clicar para executar uma ação no chat
func add_chat_actions(chat_msg_container: Node, actions: Array) -> void:
	var msg := chat_msg_container.get_node("VBoxContainer/HBoxContainer/CharacterMessage")

	if !msg.is_connected("meta_clicked", _on_meta_clicked):
		msg.connect("meta_clicked", _on_meta_clicked)

	var urls := []
	for action: Dictionary in actions:
		urls.append("[url=%s]%s[/url]" % [action, action.text])

	var new_action := link_template.replace("{{action}}", "\t\t".join(urls))
	msg.text += "\n\n" + new_action

func get_char_by_name(char_name: String) -> Character:
	for character in characters:
		if character.name == char_name:
			return character
	return null

func _on_audio_player_finished() -> void:
	# Altera levemente o pitch do som para criar um efeito mais dinâmico
	audio_player.pitch_scale = randf_range(0.9, 1.0)

	audio_player.play()
	await typing_char_added

# Valida a entrada do jogador, adiciona a mensagem no chat e sinaliza o evento
func _on_input_text_submitted(text: String) -> void:
	if text.strip_edges() == "":
		return

	add_chat_message(player, text)
	toggle_input(false)
	input.clear()
	player_message_submitted.emit(messages)

func _on_clear_pressed() -> void:
	if current_character == null:
		return

	start_new_chat(current_character)

func _on_send_pressed() -> void:
	_on_input_text_submitted(input.text)

# Move a barra de rolagem para o final sempre que novas mensagens forem adicionadas
func _on_scrollbar_changed() -> void:
	scroll_container.scroll_vertical = int(scrollbar.max_value)

func _on_request_sent() -> void:
	# Texto inicialmente vazio pois a msg ainda será transmitida aos poucos via text streaming
	text_stream_chat_msg = add_chat_message(current_character, "")
	text_stream_chat_msg.get_node("VBoxContainer/HBoxContainer/CharacterMessage").visible_characters = 0
	toggle_input(false)

func _on_text_stream_started() -> void:
	# Aguarda até que seja transmitido texto suficiente para não finalizar a animação antes da hora
	await get_tree().create_timer(0.2).timeout
	animate_text(text_stream_chat_msg)

func _on_text_stream_data_received(chunk: String) -> void:
	text_stream_chat_msg.get_node("VBoxContainer/HBoxContainer/CharacterMessage").text += chunk
	messages[-1]["content"] += chunk

func _on_text_stream_finished(_full_response: String) -> void:
	pass

func _on_typing_started() -> void:
	audio_player.play()

func _on_typing_char_added() -> void:
	update_response_length_display()

func _on_typing_finished() -> void:
	toggle_input(true)
	await audio_player.finished
	audio_player.stop()

# Acionado quando o jogador clicar em algum link no chat
func _on_meta_clicked(meta: String) -> void:
	print("Meta: %s" % meta)

	var action: Dictionary = JSON.parse_string(meta)
	if action.type == "chat":
		var character := get_char_by_name(action.target)
		if character != null:
			start_new_chat(character)
		else:
			print("Personagem '%s' não encontrado." % action.target)