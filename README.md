# Supabase API for Godot 4
Adds Supabase connectivity in Godot 4.

Tested up to 4.4.1.stable

NOTE: It uses a custom JSON parser to preserve the distinction between ints and floats

<br>

### Some snippets

Initialize API and signup
```
const config := {
	"supabaseUrl" : "{yourprojectURL}",
	"supabaseKey" : "{yourprojectKEY}"
}

func _ready():
	Supabase.load_config(config)
	var signing_in = Supabase.Auth.sign_in("something@email.org", "password")
	var auth : AuthTask = await signing_in.completed # currently needs to be split this way due to a RC6 bug
```

<br>

Login, get user data from database and avatar from storage
```
func _ready():
	var auth : AuthTask = await Supabase.Auth.sign_in("something@email.org", "password").completed # without the bug workaround, see above for RC6 version
	var query := SupabaseQuery.new().from("yourTable").select().eq("uid", auth_task.data.user.id)
	var query_task = await Supabase.Database.query(query).completed
	var download_task = await Supabase.Storage.from("avatars").download("{userid}.png", "user://avatar.png").completed
```

<br>

Login anonymously and subscribe to a realtime database
```
func _ready():
	Supabase.Auth.sign_in_anonymous()
	var client : RealtimeClient = await Supabase.Realtime.connected_client()
	var channel := client.channel("public").subscribe()
	channel.insert.connect(_on_insert)
	channel.update.connect(_on_update)
	
func _on_insert(data : Dictionary):
	print(data)

func _on_update(data : Dictionary):
	print(data)
```

<br>

---

### Need some testing:
- SupabaseAuth.sign_up_phone()
- SupabaseAuth.sign_in_phone()
- SupabaseAuth.sign_in_otp()
- SupabaseAuth.verify_otp()
- SupabaseAuth.send_magic_link()
- SupabaseAuth.update()
- SupabaseAuth.reset_password_for_email()
- SupabaseAuth.invite_user_by_email()
- SupabaseDatabase.call_rpc()

Help is welcome!
