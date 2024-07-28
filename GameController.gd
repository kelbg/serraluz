extends Node

@export var char_icon: Texture2D

signal message_received(char: String, msg: String)

var url
var headers
var messages = []

func _ready():
	$HTTPRequest.request_completed.connect(_on_request_completed)
	setup_endpoint("OpenAI")
	load_system_prompt("character.txt")

func load_system_prompt(file_path:String):
	var file = FileAccess.open(file_path, FileAccess.READ)
	messages.append({"role": "system", "content": file.get_as_text()})

func setup_endpoint(endpoint:String):
	var cfg = ConfigFile.new()
	cfg.load("environment.cfg")
	var endpoints = JSON.parse_string(FileAccess.open("endpoints.json", FileAccess.READ).get_as_text())
	url = endpoints[endpoint]["url"]
	headers = ["Content-Type: application/json", "Authorization: Bearer %s" % cfg.get_value("", "%s_API_Key" % endpoint)]

func send_request(role:String, content:String, model:String):
	messages.append({"role": role, "content": content})
	$HTTPRequest.request(url, headers, HTTPClient.METHOD_POST, JSON.stringify({
		"model": model,
		"temperature": 0.7,
		"max_tokens": 200,
		"messages": messages
	}))

func _on_request_completed(result, response_code, headers, body):
	var json = JSON.parse_string(body.get_string_from_utf8())
	print("\n%s" % json)
	emit_signal("message_received", "ChatGPT", json["choices"][0]["message"]["content"], char_icon)

func _on_message_submitted(message):
	send_request("user", message, "gpt-4o-mini")


func _on_clear_pressed():
	messages.clear()
	load_system_prompt("character.txt")
