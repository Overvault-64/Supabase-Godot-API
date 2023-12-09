@tool
extends Node
class_name StorageBucket


const MIME_TYPES := {
	"bmp" : "image/bmp",
	"css" : "text/css",
	"csv" : "text/csv",
	"gd" : "text/plain",
	"htm" : "text/html",
	"html" : "text/html",
	"jpeg" : "image/jpeg",
	"jpg" : "image/jpeg",
	"json" : "application/json",
	"mp3" : "audio/mpeg",
	"mpeg" : "video/mpeg",
	"ogg" : "audio/ogg",
	"ogv" : "video/ogg",
	"pdf" : "application/pdf",
	"png" : "image/png",
	"res" : "text/plain",
	"shader" : "text/plain",
	"svg" : "image/svg+xml",
	"tif" : "image/tiff",
	"tiff" : "image/tiff",
	"tres" : "text/plain",
	"tscn" : "text/plain",
	"txt" : "text/script",
	"wav" : "audio/wav",
	"webm" : "video/webm",
	"webp" : "video/webm",
	"xml" : "text/xml",
}

signal listed_objects(details)
signal uploaded_object(details)
signal updated_object(details)
signal moved_object(details)
signal removed_objects(details)
signal created_signed_url(details)
signal downloaded_object(details)
signal error(error)

const _rest_endpoint := "/storage/v1/object/"

var header : PackedStringArray = ["Content-Type: %s", "Content-Disposition: attachment"]

var _pooled_tasks := []

var _http_client := HTTPClient.new()
var _current_task : StorageTask = null

var _reading_body := false
var requesting_raw := false
var _response_headers : PackedStringArray
var _response_data : PackedByteArray
var _content_length : int
var _response_code : int

var id : String


func _init(_id : String) -> void:
	id = _id
	name = "Bucket_" + _id
	set_process_internal(false)


func get_task(method : int, endpoint : String, headers : PackedStringArray, payload : String, process_params := {}, bytepayload : PackedByteArray = []) -> StorageTask:
	var task := StorageTask.new(method, endpoint.replace(" ", "%20"), headers, payload, bytepayload)
	_process_task(task, process_params)
	return task


func list(prefix := "", limit := 100, offset : int = 0, sort_by := {column = "name", order = "asc"} ) -> StorageTask:
	var method := StorageTask.METHODS.LIST_OBJECTS
	var endpoint : String = Supabase.config.supabaseUrl + _rest_endpoint + "list/" + id
	var _header : PackedStringArray = [header[0] % "application/json"]
	var headers : PackedStringArray = _header + Supabase.Auth.bearer
	var payload := JSON.stringify({prefix = prefix, limit = limit, offset = offset, sort_by = sort_by})
	return get_task(method, endpoint, headers, payload)


func upload(object : String, file_path : String, upsert := false) -> StorageTask:
	requesting_raw = true
	var method := StorageTask.METHODS.UPLOAD_OBJECT
	var endpoint : String = Supabase.config.supabaseUrl + _rest_endpoint + id + "/" + object
	
	var file := FileAccess.open(file_path, FileAccess.READ)
	if file == null:
		printerr("Unable to open file")
		return StorageTask.new(0, "", []) # empty task, should be enough
	
	var _header : PackedStringArray = [header[0] % MIME_TYPES.get(file_path.get_extension(), "application/octet-stream")]
	_header.append("Content-Length: %s" % file.get_length())
	_header.append("x-upsert: %s" % upsert)
	var headers = _header + Supabase.Auth.bearer
	
	var bytepayload := file.get_buffer(file.get_length())
	
	var task = get_task(method, endpoint, headers, "", {}, bytepayload)

	_current_task = task
	set_process_internal(requesting_raw)
	return task


func update(bucket_path : String, file_path : String) -> StorageTask:
	requesting_raw = true
	var method := StorageTask.METHODS.UPDATE_OBJECT
	var endpoint : String = Supabase.config.supabaseUrl + _rest_endpoint + id + "/" + bucket_path

	var file := FileAccess.open(file_path, FileAccess.READ)
	if file == null:
		printerr("Unable to open file")
		return StorageTask.new(0, "", [])
		
	var _header : PackedStringArray = [header[0] % MIME_TYPES.get(file_path.get_extension(), "application/octet-stream")]
	_header.append("Content-Length: %s" % file.get_length())
	var headers : PackedStringArray = _header + Supabase.Auth.bearer
	
	var bytepayload : PackedByteArray = file.get_buffer(file.get_length())
	
	var task = get_task(method, endpoint, headers, "", {}, bytepayload)
	_current_task = task
	set_process_internal(requesting_raw)
	return task


func move(source_path : String, destination_path : String) -> StorageTask:
	var method := StorageTask.METHODS.MOVE_OBJECT
	var endpoint : String = Supabase.config.supabaseUrl + _rest_endpoint + "move"
	var _header : PackedStringArray = [header[0] % "application/json"]
	var payload := JSON.stringify({bucketId = id, sourceKey = source_path, destinationKey = destination_path})
	var headers : PackedStringArray = _header + Supabase.Auth.bearer
	return get_task(method, endpoint, headers, payload) 


func create_signed_url(object : String, expires_in : int = 60000) -> StorageTask:
	var method := StorageTask.METHODS.CREATE_SIGNED_URL
	var endpoint : String = Supabase.config.supabaseUrl + _rest_endpoint + "sign/" + id + "/" + object
	var _header : PackedStringArray = [header[0] % "application/json"]
	var payload := JSON.stringify({expiresIn = expires_in})
	var headers : PackedStringArray = _header + Supabase.Auth.bearer
	return get_task(method, endpoint, headers, payload)


func download(object : String, to_path : String, public := false) -> StorageTask:
	var method := StorageTask.METHODS.DOWNLOAD
	var endpoint : String = Supabase.config.supabaseUrl + _rest_endpoint + "public/" + id + "/" + object if public else Supabase.config.supabaseUrl + _rest_endpoint + "authenticated/" + id + "/" + object
	var _header : PackedStringArray = [header[0] % "application/json"]
	var headers : PackedStringArray = _header + Supabase.Auth.bearer
	return get_task(method, endpoint, headers, "", {download_file = to_path})


func get_public_url(object : String) -> String:
	return Supabase.config.supabaseUrl + _rest_endpoint + "public/" + id + "/" + object


func remove(objects : PackedStringArray) -> StorageTask:
	var method := StorageTask.METHODS.REMOVE
	var endpoint : String = Supabase.config.supabaseUrl + _rest_endpoint + id + ("/" + objects[0] if objects.size() == 1 else "")
	var _header : PackedStringArray = [header[0] % "application/json"]
	var headers : PackedStringArray = _header + Supabase.Auth.bearer
	var payload = JSON.stringify({prefixes = objects}) if objects.size() > 1 else ""
	return get_task(method, endpoint, headers, payload)


func _notification(what : int) -> void:
	if what == NOTIFICATION_INTERNAL_PROCESS:
		_internal_process(get_process_delta_time())


func _internal_process(_delta : float) -> void:
	if !requesting_raw:
		set_process_internal(false)
		return
	
	var task : StorageTask = _current_task
	
	match _http_client.get_status():
		HTTPClient.STATUS_DISCONNECTED:
			_http_client.connect_to_host(Supabase.config.supabaseUrl, 443)
		
		HTTPClient.STATUS_RESOLVING, HTTPClient.STATUS_REQUESTING, HTTPClient.STATUS_CONNECTING:
			_http_client.poll()

		HTTPClient.STATUS_CONNECTED:
			var err : int = _http_client.request_raw(task.method, task.endpoint.replace(Supabase.config.supabaseUrl, ""), task.headers, task.bytepayload)
			if err :
				task.error = {"statusCode" : HTTPRequest.RESULT_CONNECTION_ERROR}
				_on_task_completed(task)
		
		HTTPClient.STATUS_BODY:
			if _http_client.has_response() or _reading_body:
				_reading_body = true
				
				# If there is a response...
				if _response_headers.is_empty():
					_response_headers = _http_client.get_response_headers() # Get response headers.
					_response_code = _http_client.get_response_code()
					
					for header in _response_headers:
						if "Content-Length" in header:
							_content_length = header.trim_prefix("Content-Length: ").to_int()
				
				_http_client.poll()
				var chunk : PackedByteArray = _http_client.read_response_body_chunk() # Get a chunk.
				if chunk.size() == 0:
					# Got nothing, wait for buffers to fill a bit.
					pass
				else:
					_response_data += chunk # Append to read buffer.
					if _content_length != 0:
						pass
				if _http_client.get_status() != HTTPClient.STATUS_BODY:
					task._on_task_completed(0, _response_code, _response_headers, [])
			else:
				task._on_task_completed(0, _response_code, _response_headers, [])
				
		HTTPClient.STATUS_CANT_CONNECT:
			task.error = {"statusCode" : HTTPRequest.RESULT_CANT_CONNECT}
		HTTPClient.STATUS_CANT_RESOLVE:
			task.error = {"statusCode" : HTTPRequest.RESULT_CANT_RESOLVE}
		HTTPClient.STATUS_CONNECTION_ERROR:
			task.error = {"statusCode" : HTTPRequest.RESULT_CONNECTION_ERROR}
		HTTPClient.STATUS_TLS_HANDSHAKE_ERROR:
			task.error = {"statusCode" : HTTPRequest.RESULT_TLS_HANDSHAKE_ERROR}


# ---

func _process_task(task : StorageTask, _params : Dictionary = {}) -> void:
	var httprequest := HTTPRequest.new()
	add_child(httprequest)
	if !_params.is_empty():
		httprequest.download_file = _params.get("download_file", "")
	task.completed.connect(_on_task_completed)
	task.push_request(httprequest)
	_pooled_tasks.append(task)


# .............. HTTPRequest completed
func _on_task_completed(task : StorageTask) -> void:
	if task.handler :
		task.handler.queue_free()
	if requesting_raw:
		_clear_raw_request()
	if task.data != null and !task.data.is_empty():
		match task.code:
			task.METHODS.LIST_OBJECTS:
				listed_objects.emit(task.data)
			task.METHODS.UPLOAD_OBJECT:
				uploaded_object.emit(task.data)
			task.METHODS.UPDATE_OBJECT:
				updated_object.emit(task.data)
			task.METHODS.MOVE_OBJECT:
				moved_object.emit(task.data)
			task.METHODS.REMOVE:
				removed_objects.emit(task.data)
			task.METHODS.CREATE_SIGNED_URL:
				created_signed_url.emit(task.data)
			task.METHODS.DOWNLOAD:
				downloaded_object.emit(task.data)
	elif task.error != {}:
		error.emit(task.error)
	_pooled_tasks.erase(task)


func _clear_raw_request() -> void:
	requesting_raw = false
	_current_task = null
	_reading_body = false
	_response_headers = []
	_response_data = []
	_content_length = -1
	_response_code = -1
	set_process_internal(requesting_raw)
	_http_client.close()
