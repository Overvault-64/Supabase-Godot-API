@tool
extends RefCounted
class_name DatabaseTask


signal completed(task)

var code : int
var method : int
var endpoint : String
var headers : PackedStringArray
var payload : String
var query : SupabaseQuery

# EXPOSED VARIABLES ---------------------------------------------------------
var data
var response_code : int
var error : Dictionary
# ---------------------------------------------------------------------------

var handler : HTTPRequest


func _init(_query : SupabaseQuery, _code : int, _endpoint : String, _headers : PackedStringArray, _payload := "") -> void:
	query = _query
	code = _code
	endpoint = _endpoint
	headers = _headers
	payload = _payload
	method = match_code(_code)


func match_code(_code : int) -> int:
	match _code:
		SupabaseQuery.REQUESTS.INSERT:
			return HTTPClient.METHOD_POST
		SupabaseQuery.REQUESTS.SELECT:
			return HTTPClient.METHOD_GET
		SupabaseQuery.REQUESTS.UPDATE:
			return HTTPClient.METHOD_PATCH
		SupabaseQuery.REQUESTS.DELETE:
			return HTTPClient.METHOD_DELETE
		_:
			return HTTPClient.METHOD_POST


func push_request(httprequest : HTTPRequest) -> void:
	handler = httprequest
	httprequest.request_completed.connect(_on_task_completed)
	httprequest.request(endpoint, headers, method, payload)


func _on_task_completed(_result : int, _response_code : int, _headers : PackedStringArray, body : PackedByteArray) -> void:
	var result_body
	if body.size() > 0 and body.get_string_from_utf8() != null:
		result_body = JSON.parse_string(body.get_string_from_utf8())
	response_code = _response_code
	if response_code in [200, 201, 204]:
		data = result_body
	else:
		error = result_body
		printerr(result_body)
	if query != null:
		query.clean()
	if handler != null:
		handler.queue_free()
	completed.emit(self)
