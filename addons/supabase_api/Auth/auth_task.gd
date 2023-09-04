@tool
extends RefCounted
class_name AuthTask


signal completed(task)

enum METHODS {
	NONE,
	SIGNUP,
	SIGNUPPHONEPASSWORD,
	SIGNIN,
	SIGNINANONYM,
	SIGNINOTP,
	MAGICLINK,
	LOGOUT,
	USER,
	UPDATE,
	RECOVER,
	REFRESH,
	INVITE,
	VERIFYOTP
}

var code : int
var method : int
var endpoint : String
var headers : PackedStringArray
var payload : Dictionary

# EXPOSED VARIABLES ---------------------------------------------------------
var data
var response_code : int
var error : Dictionary
# ---------------------------------------------------------------------------

var handler : HTTPRequest


func _init(_code : int, _endpoint : String, _headers : PackedStringArray, _payload : Dictionary = {}) -> void:
	code = _code
	endpoint = _endpoint
	headers = _headers
	payload = _payload
	method = match_code(code)


func match_code(code : int) -> int:
	match code:
		METHODS.SIGNIN, METHODS.SIGNUP, METHODS.LOGOUT, METHODS.MAGICLINK, METHODS.RECOVER, METHODS.REFRESH, METHODS.INVITE:
			return HTTPClient.METHOD_POST
		METHODS.UPDATE:
			return HTTPClient.METHOD_PUT
		_, METHODS.USER:
			return HTTPClient.METHOD_GET


func push_request(httprequest : HTTPRequest) -> void:
	handler = httprequest
	handler.request_completed.connect(_on_task_completed)
	handler.request(endpoint, headers, method, JSON.stringify(payload))


func _on_task_completed(result : int, _response_code : int, headers : PackedStringArray, body : PackedByteArray) -> void:
	response_code = _response_code
	var result_body
	if body.size() > 0 and body.get_string_from_utf8() != null:
		result_body = JSON.parse_string(body.get_string_from_utf8())
	match response_code:
		0, 200, 201, 204:
			data = result_body
		_:
			error = result_body
			printerr(result_body)
	if handler != null:
		handler.queue_free()
	completed.emit(self)
