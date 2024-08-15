extends Node

@export var player: Character
@export var character: Character
@export var chars_per_second: int
@export var message_template: PackedScene
@export var default_placeholder_text: String
@export var awaiting_response_placeholder_text: String
@export var chat_container: VBoxContainer
@export var input: LineEdit
@export var scroll_container: ScrollContainer
@export var audio_player: AudioStreamPlayer
@export var response_length_display: Label

@onready var scrollbar: VScrollBar = scroll_container.get_v_scroll_bar()

# Referência ao node do chat que irá receber a mensagem via text streaming da API
var text_stream_chat_msg: Node

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

func add_chat_message(chat_character: Character, msg: String) -> Node:
	var new_msg: Node = message_template.instantiate()
	new_msg.get_node("TextContainer/CharacterMessage").text = msg
	new_msg.get_node("CharacterInfoContainer/CharacterName").text = chat_character.name
	new_msg.get_node("CharacterInfoContainer/CharacterIconContainer/CharacterIcon").texture = chat_character.icon
	chat_container.add_child(new_msg)
	return new_msg

# Habilitar impede que o jogador envie novas msgs antes de receber uma resposta
func toggle_input(enabled: bool) -> void:
	input.editable = enabled
	input.placeholder_text = default_placeholder_text if enabled else awaiting_response_placeholder_text

# Anima o texto, exibindo um caractere de cada vez
func animate_text(chat_msg: Node) -> void:
	toggle_input(false)
	typing_started.emit()

	var text_field: MarkdownLabel = chat_msg.get_node("TextContainer/CharacterMessage")
	while text_field.visible_characters < text_field.text.length():
		text_field.visible_characters += 1
		typing_char_added.emit()
		await get_tree().create_timer(1.0 / chars_per_second).timeout


	typing_finished.emit()

func update_response_length_display() -> void:
	if text_stream_chat_msg == null:
		response_length_display.text = "-/-"
		return

	var visible_chars: int = text_stream_chat_msg.get_node("TextContainer/CharacterMessage").visible_characters
	var total_chars: int = text_stream_chat_msg.get_node("TextContainer/CharacterMessage").text.length()

	response_length_display.text = "%s/%s" % [visible_chars, total_chars]

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
	# toggle_input(false)
	input.clear()
	player_message_submitted.emit(text, character)


func _on_clear_pressed() -> void:
	toggle_input(true)
	for msg in chat_container.get_children():
		msg.queue_free()

	text_stream_chat_msg = null
	update_response_length_display()

# Move a barra de rolagem para o final sempre que novas mensagens forem adicionadas
func _on_scrollbar_changed() -> void:
	scroll_container.scroll_vertical = int(scrollbar.max_value)

func _on_request_sent() -> void:
	# Evita que a resposta seja exibida antes da msg do jogador
	await get_tree().process_frame 
	# Texto inicialmente vazio pois a msg ainda será transmitida aos poucos via text streaming
	text_stream_chat_msg = add_chat_message(character, "")
	text_stream_chat_msg.get_node("TextContainer/CharacterMessage").visible_characters = 0
	toggle_input(false)

func _on_text_stream_started() -> void:
	# Aguarda até que seja transmitido texto suficiente para não finalizar a animação antes da hora
	await get_tree().create_timer(0.2).timeout
	animate_text(text_stream_chat_msg)

func _on_text_stream_data_received(msg: String) -> void:
	text_stream_chat_msg.get_node("TextContainer/CharacterMessage").markdown_text += msg

func _on_text_stream_finished() -> void:
	pass

func _on_typing_started() -> void:
	audio_player.play()

func _on_typing_char_added() -> void:
	update_response_length_display()

func _on_typing_finished() -> void:
	# text_stream_chat_msg = null
	toggle_input(true)
	await audio_player.finished
	audio_player.stop()
