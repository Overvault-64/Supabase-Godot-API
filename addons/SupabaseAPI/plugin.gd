@tool
extends EditorPlugin


func _enter_tree() -> void:
	add_autoload_singleton("Supabase", "res://addons/SupabaseAPI/supabase.gd")


func _exit_tree() -> void:
	remove_autoload_singleton("Supabase")
