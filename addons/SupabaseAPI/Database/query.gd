@tool
extends RefCounted
class_name SupabaseQuery


var query_struct := {
	table = "",
	select = PackedStringArray([]),
	order = PackedStringArray([]),
	Or = PackedStringArray([]),
	eq = PackedStringArray([]),
	neq = PackedStringArray([]),
	gt = PackedStringArray([]),
	lt = PackedStringArray([]),
	gte = PackedStringArray([]),
	lte = PackedStringArray([]),
	like = PackedStringArray([]),
	ilike = PackedStringArray([]),
	Is = PackedStringArray([]),
	In = PackedStringArray([]),
	fts = PackedStringArray([]),
	plfts = PackedStringArray([]),
	phfts = PackedStringArray([]),
	wfts = PackedStringArray([])
}

var query := ""
var raw_query := ""
var header : PackedStringArray = []
var request : int
var body := ""


enum REQUESTS {
	NONE,
	SELECT,
	INSERT,
	UPDATE,
	DELETE
}

enum DIRECTIONS {ASCENDING, DESCENDING}

enum NULLSORDER {FIRST, LAST}

enum FILTERS {
	EQUAL,
	NOT_EQUAL,
	GREATER_THAN,
	LESS_THAN,
	GREATER_THAN_OR_EQUAL,
	LESS_THAN_OR_EQUAL,
	LIKE,
	ILIKE,
	IS,
	IN,
	FTS,
	PLFTS,
	PHFTS,
	WFTS,
	OR,
	ORDER
}


func _init(_raw_query := "", _raw_type : int = -1, _raw_header : PackedStringArray = [], _raw_body := "") -> void:
	if _raw_query != "":
		raw_query = _raw_query
		query = _raw_query
		request = _raw_type
		header = _raw_header as PackedStringArray
		body = _raw_body


# Build the query from the scrut
func build_query() -> String:
	if raw_query == "" and query == raw_query:
		for key in query_struct:
			if query_struct[key].is_empty():
				continue
			if query.length() > 0 : if !query[query.length()-1] in ["/", "?"]:
				query += "&"
			match key:
				"table":
					query += query_struct[key]
				"select", "order":
					if query_struct[key].is_empty():
						continue
					query += key + "=" + ",".join(PackedStringArray(query_struct[key]))
				"eq", "neq", "lt", "gt", "lte", "gte", "like", "ilike", "Is", "in", "fts", "plfts", "phfts", "wfts":
					query += "&".join(PackedStringArray(query_struct[key]))
				"Or":
					query += "or=(%s)" % [query_struct[key].join(",")]
	return query


func from(table_name : String) -> SupabaseQuery:
	query_struct.table = table_name + "?"
	return self


# Insert new Row
func insert(fields : Array, upsert := false) -> SupabaseQuery:
	request = REQUESTS.INSERT
	body = JSON.stringify(fields)
	if upsert : header += PackedStringArray(["Prefer: resolution=merge-duplicates"])
	return self


# Select Rows
func select(columns := PackedStringArray(["*"])) -> SupabaseQuery:
	request = REQUESTS.SELECT
	query_struct.select += columns
	return self


# Update Rows
func update(fields : Dictionary) -> SupabaseQuery:
	request = REQUESTS.UPDATE
	body = JSON.stringify(fields)
	return self


# Delete Rows
func delete() -> SupabaseQuery:
	request = REQUESTS.DELETE
	return self


## [MODIFIERS] -----------------------------------------------------------------

func range_query(_from : int, _to : int) -> SupabaseQuery:
	header = PackedStringArray(["Range: " + str(_from) + "-" + str(_to)])
	return self
	
	
func order(column : String, direction : int = DIRECTIONS.ASCENDING, nullsorder : int = NULLSORDER.FIRST) -> SupabaseQuery:
	var direction_str : String
	match direction:
		DIRECTIONS.ASCENDING: direction_str = "asc"
		DIRECTIONS.DESCENDING: direction_str = "desc"
	var nullsorder_str : String
	match nullsorder:
		NULLSORDER.FIRST: nullsorder_str = "nullsfirst"
		NULLSORDER.LAST: nullsorder_str = "nullslast"
	query_struct.order += PackedStringArray([("%s.%s.%s" % [column, direction_str, nullsorder_str])])
	return self


## [FILTERS] -------------------------------------------------------------------- 

func filter(column : String, _filter : int, value : String, _props : Dictionary = {}) -> SupabaseQuery:
	var filter_str : String = match_filter(_filter)
	var array : PackedStringArray = query_struct[filter_str] as PackedStringArray
	var struct_filter : String = filter_str
	if _props.has("config"):
		struct_filter += "({config})".format(_props)
	if _props.has("negate"):
		struct_filter = ("not." + struct_filter) if _props.get("negate") else struct_filter
	# Apply custom logic or continue with default logic
	match filter_str:
		"Or":
			if _props.has("queries"):
				for _query in _props.get("queries"):
					array.append(_query.build_query().replace("=", ".") if (not _query is String) else _query)
		_:
			array.append("%s=%s.%s" % [column, struct_filter.to_lower(), value])
	query_struct[filter_str] = array
	return self


func match_filter(_filter : int) -> String:
	var filter_str : String
	match _filter:
		FILTERS.EQUAL:
			filter_str = "eq"
		FILTERS.FTS:
			filter_str = "fts"
		FILTERS.ILIKE:
			filter_str = "ilike"
		FILTERS.IN:
			filter_str = "In"
		FILTERS.IS:
			filter_str = "Is"
		FILTERS.GREATER_THAN:
			filter_str = "gt"
		FILTERS.GREATER_THAN_OR_EQUAL:
			filter_str = "gte"
		FILTERS.LIKE:
			filter_str = "like"
		FILTERS.LESS_THAN:
			filter_str = "lt"
		FILTERS.LESS_THAN_OR_EQUAL:
			filter_str = "lte"
		FILTERS.NOT_EQUAL:
			filter_str = "neq"
		FILTERS.OR:
			filter_str = "Or"
		FILTERS.PLFTS:
			filter_str = "plfts"
		FILTERS.PHFTS:
			filter_str = "phfts"
		FILTERS.WFTS:
			filter_str = "wfts"
	return filter_str


# Finds all rows whose value on the stated columns match the specified values.
func match(query_dict : Dictionary) -> SupabaseQuery:
	for key in query_dict.keys():
		eq(key, query_dict[key])
	return self


# Finds all rows whose value on the stated column match the specified value.
func eq(column : String, value : String) -> SupabaseQuery:
	filter(column, FILTERS.EQUAL, value)
	return self


# Finds all rows whose value on the stated column doesn't match the specified value.
func neq(column : String, value : String) -> SupabaseQuery:
	filter(column, FILTERS.NOT_EQUAL, value)
	return self


# Finds all rows whose value on the stated column is greater than the specified value
func gt(column : String, value : String) -> SupabaseQuery:
	filter(column, FILTERS.GREATER_THAN, value)
	return self


# Finds all rows whose value on the stated column is less than the specified value
func lt(column : String, value : String) -> SupabaseQuery:
	filter(column, FILTERS.LESS_THAN, value)
	return self


# Finds all rows whose value on the stated column is greater than or equal to the specified value
func gte(column : String, value : String) -> SupabaseQuery:
	filter(column, FILTERS.GREATER_THAN_OR_EQUAL, value)
	return self


# Finds all rows whose value on the stated column is less than or equal to the specified value
func lte(column : String, value : String) -> SupabaseQuery:
	filter(column, FILTERS.LESS_THAN_OR_EQUAL, value)
	return self


# Finds all rows whose value in the stated column matches the supplied pattern (case sensitive).
func like(column : String, value : String) -> SupabaseQuery:
	filter(column, FILTERS.LIKE, "*%s*" % value)
	return self

# Finds all rows whose value in the stated column matches the supplied pattern (case insensitive).
func ilike(column : String, value : String) -> SupabaseQuery:
	filter(column, FILTERS.ILIKE, value)
	return self


# A check for exact equality (null, true, false), finds all rows whose value on the stated column exactly match the specified value.
func Is(column : String, value, negate := false) -> SupabaseQuery:
	filter(column, FILTERS.IS, str(value), {negate = negate})
	return self


# Finds all rows whose value on the stated column is found on the specified values.
func In(column : String, array : PackedStringArray) -> SupabaseQuery:
	filter(column, FILTERS.IN, "(" + ",".join(array) + ")")
	return self


func Or(queries : Array) -> SupabaseQuery:
	filter("", FILTERS.OR, "", {queries = queries})
	return self


# Text Search
func text_search(column : String, _query : String, type := "", config := "") -> SupabaseQuery:
	var _filter : int
	match type:
		"plain":
			_filter = FILTERS.PLFTS
		"phrase":
			_filter = FILTERS.PHFTS
		"websearch":
			_filter = FILTERS.WFTS
		_:
			_filter = FILTERS.FTS
	_query = _query.replacen(" ", "%20")
	filter(column, _filter, _query, {config = config} if config != "" else {})
	return self


func clean() -> void:
	query = ""
	body = ""
	header = []
	request = 0
	
	query_struct.table = ""
	query_struct.select = PackedStringArray([])
	query_struct.order = PackedStringArray([])
	query_struct.eq = PackedStringArray([])
	query_struct.neq = PackedStringArray([])
	query_struct.gt = PackedStringArray([])
	query_struct.lt = PackedStringArray([])
	query_struct.gte = PackedStringArray([])
	query_struct.lte = PackedStringArray([])
	query_struct.like = PackedStringArray([])
	query_struct.ilike = PackedStringArray([])
	query_struct.IS = PackedStringArray([])
	query_struct.In = PackedStringArray([])
	query_struct.fts = PackedStringArray([])
	query_struct.plfts = PackedStringArray([])
	query_struct.phfts = PackedStringArray([])
	query_struct.wfts = PackedStringArray([])


func _to_string() -> String:
	return build_query()
