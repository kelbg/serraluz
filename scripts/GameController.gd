extends Node

@export var max_retries: int

signal request_sent()
signal text_stream_started()
signal text_stream_data_received(data: String)
signal text_stream_finished(full_response: String)

var endpoint: Dictionary
var client: HTTPClient

func _ready() -> void:
	endpoint = setup_endpoint("OpenAI")
	client = await setup_client()

func setup_client(retry_count: int = 0) -> HTTPClient:
	var new_client := HTTPClient.new()
	var host: String = endpoint["base_url"]
	print("Estabelecendo conexão com host '%s'..." % host)
	var error_code := new_client.connect_to_host(host)

	if error_code != OK and retry_count < max_retries:
		return await check_connection(new_client, true, retry_count)

	while (new_client.get_status() == HTTPClient.STATUS_CONNECTING
	or new_client.get_status() == HTTPClient.STATUS_RESOLVING):
		new_client.poll()
		await get_tree().process_frame

	if new_client.get_status() != HTTPClient.STATUS_CONNECTED and retry_count < max_retries:
		return await check_connection(new_client, true, retry_count)

	print("Conectado")
	return new_client

func check_connection(some_client: HTTPClient, retry: bool = true, retry_count: int = 0) -> HTTPClient:
	some_client.poll()
	var status := some_client.get_status()
	print("Status da conexão: %s" % status)

	if status == HTTPClient.STATUS_CONNECTED:
		return some_client

	if !retry:
		print("Conexão não estabelecida (retry: false).")
		return some_client

	print("Tentando restabecer conexão...")
	return await setup_client(retry_count + 1)

func setup_endpoint(service: String) -> Dictionary:
	print("Configurando endpoint para '%s'..." % service)
	var new_endpoint: Dictionary = JSON.parse_string(FileAccess.open("res://config/endpoints.json", FileAccess.READ).get_as_text())[service]
	new_endpoint["headers"] += [
		"Content-Type: application/json",
		"Authorization: Bearer %s" % get_api_key(service)
	]

	print("Endpoint configurado")
	return new_endpoint

func get_api_key(service: String) -> String:
	var cfg: ConfigFile = ConfigFile.new()
	cfg.load("res://config/environment.cfg")
	return cfg.get_value("", "%s_API_KEY" % service)

func send_request_stream(model: String, msg_history: Array = []) -> void:
	client = await check_connection(client)
	endpoint["params"]["model"] = model
	endpoint["params"]["messages"] = msg_history
	endpoint["params"]["stream"] = true

	var approx_token_count := str(msg_history).length() / 4.0
	print("Enviando requisição. Contexto (~%d tokens):\n%s" % [approx_token_count, "\n".join(msg_history)])

	var error_code := client.request(
		HTTPClient.METHOD_POST,
		endpoint["chat_endpoint"],
		endpoint["headers"],
		JSON.stringify(endpoint["params"]),
	)

	assert(error_code == OK)
	print("Requisição enviada. Aguardando resposta...")
	request_sent.emit()
	handle_server_response()

func handle_server_response() -> void:
	while (client.get_status() == HTTPClient.STATUS_REQUESTING):
		client.poll()
		await get_tree().process_frame

	assert(client.get_status() == HTTPClient.STATUS_BODY
		or client.get_status() == HTTPClient.STATUS_CONNECTED)

	if !client.has_response():
		print("Não foi possível obter uma resposta.")
		return

	print("Resposta recebida. Aguardando dados...")
	stream_server_response()

func stream_server_response() -> void:
	var read_buffer := PackedByteArray()
	var has_started := false
	var content := ""

	while client.get_status() == HTTPClient.STATUS_BODY:
		client.poll()
		var chunk := client.read_response_body_chunk()
		if chunk.size() == 0:
			await get_tree().process_frame
			continue

		if !has_started:
			has_started = true
			text_stream_started.emit()
			print("Iniciando streaming de dados...")

		read_buffer += chunk
		var chunk_text := chunk.get_string_from_utf8()
		content += parse_chunk(chunk_text)
		text_stream_data_received.emit(parse_chunk(chunk_text))
		# print(chunk_text)

	print("Conteúdo completo da resposta:\n%s" % content)
	print("Bytes recebidos: ", read_buffer.size())
	text_stream_finished.emit(content)

# Extrai o conteúdo de um chunk, que pode ter mais de um conjunto de dados (separados por \n)
func parse_chunk(chunk_text: String) -> String:
	var output := ""
	var lines := chunk_text.split("\n")
	for line in lines:
		if !line.begins_with("data: "):
			continue

		line = line.replace("data: ", "")
		if line == "[DONE]":
			break

		var json: Dictionary = JSON.parse_string(line)
		if !json["choices"][0]["delta"].has("content"):
			continue

		output += json["choices"][0]["delta"]["content"]

	return output

func _on_player_message_submitted(msg_history: Array) -> void:
	send_request_stream("gpt-4o-2024-11-20", msg_history)
	# send_request_stream("gpt-3.5-turbo-0125", msg_history)
	# send_request_stream("gpt-4o-mini", msg_history)
