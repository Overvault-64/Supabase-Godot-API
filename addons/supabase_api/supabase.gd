@tool
extends Node


const ENVIRONMENT_VARIABLES := "supabase/config"

var Auth : SupabaseAuth
var Database : SupabaseDatabase
var Realtime : SupabaseRealtime
var Storage : SupabaseStorage

var config := {
	"supabaseUrl": "",
	"supabaseKey": ""
}

var header : PackedStringArray = [
	"Content-Type: application/json",
	"Accept: application/json"
]

var debug := false #set to true to debug print some messages coming from around the api


# Call this to initialize the API
func load_config(_config : Dictionary) -> void:
	config = _config
	header.append("apikey: %s" % [config.supabaseKey])
	
	Auth = SupabaseAuth.new()
	Database = SupabaseDatabase.new()
	Realtime = SupabaseRealtime.new()
	Storage = SupabaseStorage.new()
	add_child(Auth)
	add_child(Database)
	add_child(Realtime)
	add_child(Storage)
	
	Database.header += header


func _print_debug(msg: String) -> void:
	if debug:
		print_debug(msg)
