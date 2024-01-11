@tool
extends Node
class_name SupabaseDatabase


signal rpc_completed(query_result)
signal selected(query_result)
signal inserted(query_result)
signal updated(query_result)
signal deleted(query_result)
signal error(body)

const _rest_endpoint := "/rest/v1/"

var header : PackedStringArray = ["Prefer: return=representation"]

var _pooled_tasks : Array = []


# Issue a query on your database
func query(supabase_query : SupabaseQuery) -> DatabaseTask:
	var endpoint : String = Supabase.config.supabaseUrl + _rest_endpoint + supabase_query.build_query()
	var task := DatabaseTask.new(supabase_query, supabase_query.request, endpoint, header + Supabase.Auth.bearer + supabase_query.header, supabase_query.body)
	_process_task(task)
	return task


# Issue an rpc() call to a function
func call_rpc(function_name : String, arguments := {}, supabase_query : SupabaseQuery = null) -> DatabaseTask:
	var endpoint : String = Supabase.config.supabaseUrl + _rest_endpoint + "rpc/{function}".format({function = function_name}) + (supabase_query.build_query() if supabase_query != null else "")
	var task := DatabaseTask.new(supabase_query, -2, endpoint, header + Supabase.Auth.bearer, JSON.stringify(arguments))
	_process_task(task)
	return task


func _process_task(task : DatabaseTask) -> void:
	var httprequest := HTTPRequest.new()
	httprequest.process_mode = Node.PROCESS_MODE_ALWAYS
	add_child(httprequest)
	task.completed.connect(_on_task_completed)
	task.push_request(httprequest)
	_pooled_tasks.append(task)


# .............. HTTPRequest completed
func _on_task_completed(task : DatabaseTask) -> void:
	if task.handler != null:
		task.handler.queue_free()
	if task.data != null and !task.data.is_empty():
		match task.code:
			SupabaseQuery.REQUESTS.SELECT:
				selected.emit(task.data)
			SupabaseQuery.REQUESTS.INSERT:
				inserted.emit(task.data)
			SupabaseQuery.REQUESTS.UPDATE:
				updated.emit(task.data)
			SupabaseQuery.REQUESTS.DELETE:
				deleted.emit(task.data)
			_:
				rpc_completed.emit(task.data)
	elif task.error != {}:
		error.emit(task.error)
	_pooled_tasks.erase(task)
