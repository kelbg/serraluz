extends Node

var messages = []

func _ready():
	$HTTPRequest.request_completed.connect(_on_request_completed)
	# $HTTPRequest.request("https://api.github.com/repos/godotengine/godot/releases/latest")
	
	var cfg = ConfigFile.new()
	cfg.load("environment.cfg")
	var json = JSON.parse_string(FileAccess.open("endpoints.json", FileAccess.READ).get_as_text())
	var url = json["OpenAI"]["url"]
	var headers = ["Content-Type: application/json", "Authorization: Bearer %s" % cfg.get_value("", "OpenAI_API_Key")]

	# var user_msg = "Explique o significado da vida em exatamente 10 palavras."
	# print_rich("[color=green]You[/color]: %s" % user_msg)

	# messages.append({"role": "user", "content": user_msg})
	# $HTTPRequest.request(url, headers, HTTPClient.METHOD_POST, JSON.stringify({
	# 	"model": "gpt-4o-mini",
	# 	"temperature": 0.7,
	# 	"max_tokens": 200,
	# 	"messages": messages
	# }))


func _on_request_completed(result, response_code, headers, body):
	var json = JSON.parse_string(body.get_string_from_utf8())
	var model = json["model"]
	print_rich("[color=cyan]%s[/color]: %s" % [model, json["choices"][0]["message"]["content"]])
	print("\n%s" % json)
	# print(json["name"])

# 	var cfg = ConfigFile.new()
# 	cfg.load("environment.cfg")

# 	var json = JSON.parse_string(FileAccess.open("endpoints.json", FileAccess.READ).get_as_text())
# 	var url = json["OpenAI"]["url"]
# 	var headers = ["Content-Type: application/json", "Authorization: Bearer %s" % cfg.get_value("", "OpenAI_API_Key")]

# 	print_rich("[color=green]URL: %s[/color]" % url)
# 	print_rich("[color=blue]Headers: %s[/color]" % str(headers))
# 	send_message("Explain the meaning of life in exactly 10 words", url, headers)

# func send_message(user_message, url, headers):
# 	messages.append({"role": "user", "content": user_message})

# 	var body = JSON.stringify({
# 		"model": "gpt-4o-mini",
# 		"temperature": 0.7,
# 		"max_tokens": 200,
# 		"messages": messages
# 	})

# 	var new_request = HTTPRequest.new()
# 	var send_request = new_request.request(url, headers, HTTPClient.METHOD_POST, body)
# 	new_request.connect("request_completed", _on_request_completed)

# 	if send_request != OK:
# 		print_rich("[color=red]Error sending request (error code %s)[/color]" % send_request)

# func _on_request_completed(result, response_code, headers, body):
# 	var json = JSON.new()
# 	json.parse(body.get_string_from_utf8())
# 	var message = json.get_data()["choices"][0]["message"]["content"]

# 	print_rich("[color=cyan]%s[/color]" % message)
