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


# Custom JSON parser to preserve int/float distinction
class JSONParser:
	# Parse a JSON string and preserve int/float distinction
	static func parse_string(json_string: String) -> Variant:
		# If string is empty or null, return null
		if json_string.is_empty():
			return null
			
		var json = JSON.new()
		var error = json.parse(json_string)
		if error != OK:
			push_error("JSON Parse Error: " + json.get_error_message() + " at line " + str(json.get_error_line()))
			return null
		
		var parsed_data = json.get_data()
		return _process_value(parsed_data)
	
	# Process each value to preserve type information
	static func _process_value(value: Variant) -> Variant:
		match typeof(value):
			TYPE_DICTIONARY:
				var dict = {}
				for key in value:
					dict[key] = _process_value(value[key])
				return dict
			TYPE_ARRAY:
				var array = []
				for item in value:
					array.append(_process_value(item))
				return array
			TYPE_STRING:
				# Check if it represents a number
				if value.is_valid_int():
					return int(value)
				elif value.is_valid_float():
					var float_val = float(value)
					if float_val == floor(float_val) and !value.contains("."):
						return int(float_val)
					return float_val
				return value
			TYPE_FLOAT:
				# Preserve integer if the float is actually an integer
				if value == floor(value):
					return int(value)
				return value
			_:
				# Other types (boolean, integer, null) remain unchanged
				return value


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


# Utility function to display types
func _print_parsed_types(value: Variant, indent: String = "") -> void:
	match typeof(value):
		TYPE_DICTIONARY:
			print(indent + "Dictionary:")
			for key in value:
				print(indent + "  " + str(key) + " (" + type_to_string(typeof(key)) + "):")
				_print_parsed_types(value[key], indent + "    ")
		TYPE_ARRAY:
			print(indent + "Array:")
			var index = 0
			for item in value:
				print(indent + "  [" + str(index) + "] (" + type_to_string(typeof(item)) + "):")
				_print_parsed_types(item, indent + "    ")
				index += 1
		_:
			print(indent + str(value) + " (" + type_to_string(typeof(value)) + ")")

# Convert type code to string
func type_to_string(type_code: int) -> String:
	match type_code:
		TYPE_NIL: return "null"
		TYPE_BOOL: return "bool"
		TYPE_INT: return "int"
		TYPE_FLOAT: return "float"
		TYPE_STRING: return "string"
		TYPE_VECTOR2: return "Vector2"
		TYPE_VECTOR2I: return "Vector2i"
		TYPE_RECT2: return "Rect2"
		TYPE_RECT2I: return "Rect2i"
		TYPE_VECTOR3: return "Vector3"
		TYPE_VECTOR3I: return "Vector3i"
		TYPE_TRANSFORM2D: return "Transform2D"
		TYPE_VECTOR4: return "Vector4"
		TYPE_VECTOR4I: return "Vector4i"
		TYPE_PLANE: return "Plane"
		TYPE_QUATERNION: return "Quaternion"
		TYPE_AABB: return "AABB"
		TYPE_BASIS: return "Basis"
		TYPE_TRANSFORM3D: return "Transform3D"
		TYPE_PROJECTION: return "Projection"
		TYPE_COLOR: return "Color"
		TYPE_STRING_NAME: return "StringName"
		TYPE_NODE_PATH: return "NodePath"
		TYPE_RID: return "RID"
		TYPE_OBJECT: return "Object"
		TYPE_CALLABLE: return "Callable"
		TYPE_SIGNAL: return "Signal"
		TYPE_DICTIONARY: return "Dictionary"
		TYPE_ARRAY: return "Array"
		TYPE_PACKED_BYTE_ARRAY: return "PackedByteArray"
		TYPE_PACKED_INT32_ARRAY: return "PackedInt32Array"
		TYPE_PACKED_INT64_ARRAY: return "PackedInt64Array"
		TYPE_PACKED_FLOAT32_ARRAY: return "PackedFloat32Array"
		TYPE_PACKED_FLOAT64_ARRAY: return "PackedFloat64Array"
		TYPE_PACKED_STRING_ARRAY: return "PackedStringArray"
		TYPE_PACKED_VECTOR2_ARRAY: return "PackedVector2Array"
		TYPE_PACKED_VECTOR3_ARRAY: return "PackedVector3Array"
		TYPE_PACKED_COLOR_ARRAY: return "PackedColorArray"
		_: return "unknown_type"
