@tool
extends EditorPlugin


func _enter_tree() -> void:
	add_autoload_singleton("Supabase", "res://addons/supabase_api/supabase.gd")


func _exit_tree() -> void:
	remove_autoload_singleton("Supabase")
