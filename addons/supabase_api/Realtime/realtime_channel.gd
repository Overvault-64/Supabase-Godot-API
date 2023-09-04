@tool
extends RefCounted
class_name RealtimeChannel


signal delete(data : Dictionary)
signal insert(data : Dictionary)
signal update(data : Dictionary)
signal all(data : Dictionary)

var client : RealtimeClient
var topic : String
var subscribed : bool


func _init(_topic : String, _client) -> void:
	topic = _topic
	client = _client


func _publish(message : Dictionary) -> void:
	if !subscribed: return
	match message.event:
		client.SupabaseEvents.DELETE:
			delete.emit({"old_record" : message.payload.old_record})
		client.SupabaseEvents.UPDATE:
			update.emit({"old_record" : message.payload.old_record, "new_record" : message.payload.record})
		client.SupabaseEvents.INSERT:
			insert.emit({"new_record" : message.payload.record})
	all.emit({"old_record" : message.payload.get("old_record", {}), "new_record" : message.payload.get("record", {})})


func on(event : String, callable : Callable) -> RealtimeChannel:
	connect(event, callable)
	return self
			
			
func subscribe() -> RealtimeChannel:
	if subscribed: 
		client._error("Already subscribed to topic: %s" % topic)
		return self
	client.send_message({
		"topic" : topic,
		"event" : client.PhxEvents.JOIN,
		"payload" : {},
		"ref" : null
	})
	subscribed = true
	return self

			
func unsubscribe() -> RealtimeChannel:
	if !subscribed: 
		client._error("Already unsubscribed from topic: %s" % topic)
		return self
	client.send_message({
		"topic" : topic,
		"event" : client.PhxEvents.LEAVE,
		"payload" : {},
		"ref" : null
	})
	subscribed = false
	return self
	
	
func close() -> void:
	client._remove_channel(self)
