@tool
extends Node
class_name SupabaseRealtime


func client(url : String, apikey : String, timeout : float) -> RealtimeClient:
	var realtime_client := RealtimeClient.new(url, apikey, timeout)
	add_child(realtime_client)
	return realtime_client


func connected_client(url : String = Supabase.config.supabaseUrl, apikey : String = Supabase.config.supabaseKey, timeout : float = 30) -> RealtimeClient:
	var _client = client(url, apikey, timeout)
	_client.connect_client()
	await _client.connected
	return _client
