@tool
extends RefCounted
class_name StorageTask


signal completed(task : StorageTask)

enum METHODS {
	LIST_BUCKETS,
	GET_BUCKET,
	CREATE_BUCKET,
	UPDATE_BUCKET,
	EMPTY_BUCKET,
	DELETE_BUCKET,
	
	LIST_OBJECTS,
	UPLOAD_OBJECT,
	UPDATE_OBJECT,
	MOVE_OBJECT,
	CREATE_SIGNED_URL,
	DOWNLOAD,
	GET_PUBLIC_URL,
	REMOVE
}

var code : int
var method : int
var endpoint : String
var headers : PackedStringArray
var payload : String
var bytepayload : PackedByteArray

# EXPOSED VARIABLES ---------------------------------------------------------
var data
var response_code : int
var error
# ---------------------------------------------------------------------------

var handler : HTTPRequest = null


func _init(_code : int, _endpoint : String, _headers : PackedStringArray, _payload := "", _bytepayload : PackedByteArray = []) -> void:
	code = _code
	endpoint = _endpoint
	headers = _headers
	payload = _payload
	bytepayload = _bytepayload
	method = match_code(_code)


func match_code(_code : int) -> int:
	match _code:
		METHODS.LIST_BUCKETS, METHODS.GET_BUCKET, METHODS.DOWNLOAD:
			return HTTPClient.METHOD_GET
		METHODS.CREATE_BUCKET, METHODS.UPDATE_BUCKET, METHODS.EMPTY_BUCKET, \
		METHODS.LIST_OBJECTS, METHODS.UPLOAD_OBJECT, METHODS.MOVE_OBJECT, \
		METHODS.CREATE_SIGNED_URL:
			return HTTPClient.METHOD_POST
		METHODS.UPDATE_OBJECT:
			return HTTPClient.METHOD_PUT
		METHODS.DELETE_BUCKET, METHODS.REMOVE:
			return HTTPClient.METHOD_DELETE
		_:
			return HTTPClient.METHOD_GET


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
		if code == METHODS.DOWNLOAD:
			data = body
		else:
			data = result_body
	else:
		error = result_body
		printerr(result_body)
	if handler != null:
		handler.queue_free()
	completed.emit(self)
