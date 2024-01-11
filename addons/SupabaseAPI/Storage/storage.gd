@tool
extends Node
class_name SupabaseStorage


signal listed_buckets(buckets)
signal got_bucket(details)
signal created_bucket(details)
signal updated_bucket(details)
signal emptied_bucket(details)
signal deleted_bucket(details)
signal error(error)

const _rest_endpoint := "/storage/v1/"

var header : PackedStringArray = ["Content-type: application/json"]

var _pooled_tasks := []


func get_task(code : int, endpoint : String, headers : PackedStringArray, payload := "") -> StorageTask:
	var task := StorageTask.new(code, endpoint, headers, payload)
	_process_task(task)
	return task


func list_buckets() -> StorageTask:
	var endpoint : String = Supabase.config.supabaseUrl + _rest_endpoint + "bucket"
	return get_task(StorageTask.METHODS.LIST_BUCKETS, endpoint, header + Supabase.Auth.bearer)


func get_bucket(id : String) -> StorageTask:
	var endpoint : String = Supabase.config.supabaseUrl + _rest_endpoint + "bucket/" + id
	return get_task(StorageTask.METHODS.GET_BUCKET, endpoint, header + Supabase.Auth.bearer)


func create_bucket(_name : String, id : String, public := false) -> StorageTask:
	var endpoint : String = Supabase.config.supabaseUrl + _rest_endpoint + "bucket"
	return get_task(StorageTask.METHODS.CREATE_BUCKET, endpoint, header + Supabase.Auth.bearer, JSON.stringify({"name" : _name, id : id, public : public}))


func update_bucket(id : String, public : bool) -> StorageTask:
	var endpoint : String = Supabase.config.supabaseUrl + _rest_endpoint + "bucket/" + id
	return get_task(StorageTask.METHODS.UPDATE_BUCKET, endpoint, header + Supabase.Auth.bearer, JSON.stringify({public = public}))


func empty_bucket(id : String) -> StorageTask:
	var endpoint : String = Supabase.config.supabaseUrl + _rest_endpoint + "bucket/" + id + "/empty"
	return get_task(StorageTask.METHODS.EMPTY_BUCKET, endpoint, Supabase.Auth.bearer)


func delete_bucket(id : String) -> StorageTask:
	var endpoint : String = Supabase.config.supabaseUrl + _rest_endpoint + "bucket/" + id 
	return get_task(StorageTask.METHODS.DELETE_BUCKET, endpoint, Supabase.Auth.bearer)


func from(id : String) -> StorageBucket:
	for bucket in get_children():
		if bucket.id == id:
			return bucket
	var storage_bucket := StorageBucket.new(id)
	add_child(storage_bucket)
	return storage_bucket

# ---

func _process_task(task : StorageTask) -> void:
	var httprequest := HTTPRequest.new()
	httprequest.process_mode = Node.PROCESS_MODE_ALWAYS
	add_child(httprequest)
	task.completed.connect(_on_task_completed)
	task.push_request(httprequest)
	_pooled_tasks.append(task)


# .............. HTTPRequest completed
func _on_task_completed(task : StorageTask) -> void:
	if task.handler:
		task.handler.queue_free()
	if task.data != null and !task.data.is_empty():
		match task.code:
			StorageTask.METHODS.LIST_BUCKETS:
				listed_buckets.emit(task.data)
			StorageTask.METHODS.GET_BUCKET:
				got_bucket.emit(task.data)
			StorageTask.METHODS.CREATE_BUCKET:
				created_bucket.emit(from(task.data.name))
			StorageTask.METHODS.UPDATE_BUCKET:
				updated_bucket.emit(from(task.data.name))
			StorageTask.METHODS.EMPTY_BUCKET:
				emptied_bucket.emit(from(task.data.name))
			StorageTask.METHODS.DELETE_BUCKET:
				deleted_bucket.emit(task.data)
	elif task.error != {}:
		error.emit(task.error)
	_pooled_tasks.erase(task)
