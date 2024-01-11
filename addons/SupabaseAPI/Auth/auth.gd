@tool
extends Node
class_name SupabaseAuth


class Providers:
	const APPLE := "apple"
	const BITBUCKET := "bitbucket"
	const DISCORD := "discord"
	const FACEBOOK := "facebook"
	const GITHUB := "github"
	const GITLAB := "gitlab"
	const GOOGLE := "google"
	const TWITTER := "twitter"

signal signed_up(signed_user)
signal signed_up_phone(signed_user)
signal signed_in(signed_user)
signal signed_in_otp(signed_user)
signal otp_verified()
signal signed_in_anonymous()
signal signed_out()
signal got_user()
signal user_updated(updated_user)
signal magic_link_sent()
signal reset_email_sent()
signal token_refreshed(refreshed_user)
signal user_invited()
signal error(supabase_error)

const _auth_endpoint := "/auth/v1"
const _provider_endpoint := _auth_endpoint + "/authorize"
const _signin_endpoint := _auth_endpoint + "/token?grant_type=password"
const _signin_otp_endpoint := _auth_endpoint + "/otp"
const _verify_otp_endpoint := _auth_endpoint + "/verify"
const _signup_endpoint := _auth_endpoint + "/signup"
const _refresh_token_endpoint := _auth_endpoint + "/token?grant_type=refresh_token"
const _logout_endpoint := _auth_endpoint + "/logout"
const _user_endpoint := _auth_endpoint + "/user"
const _magiclink_endpoint := _auth_endpoint + "/magiclink"
const _invite_endpoint := _auth_endpoint + "/invite"
const _reset_password_endpoint := _auth_endpoint + "/recover"

var tcp_server := TCPServer.new()
var tcp_timer := Timer.new()

var bearer : PackedStringArray = ["Authorization: Bearer %s"]

var user : Dictionary


func is_logged() -> bool:
	if "access_token" in user:
		return true
	return false


func get_task(task_code : int, endpoint : String, payload := {}) -> AuthTask:
	var auth_task : AuthTask
	if task_code in [AuthTask.METHODS.LOGOUT, AuthTask.METHODS.USER, AuthTask.METHODS.UPDATE, AuthTask.METHODS.REFRESH]:
		auth_task = AuthTask.new(task_code, Supabase.config.supabaseUrl + endpoint, Supabase.header + bearer, payload)
	elif task_code == AuthTask.METHODS.SIGNINANONYM:
		var _bearer = bearer
		_bearer[0] = bearer[0] % Supabase.config.supabaseKey
		auth_task = AuthTask.new(task_code, Supabase.config.supabaseUrl + endpoint, Supabase.header + _bearer, payload)
		return auth_task
	else:
		auth_task = AuthTask.new(task_code, Supabase.config.supabaseUrl + endpoint, Supabase.header, payload)
	_process_task(auth_task)
	return auth_task


# Allow your users to sign up and create a new account.
func sign_up(email : String, password : String, data: Dictionary = {}) -> AuthTask:
	return get_task(AuthTask.METHODS.SIGNUP ,_signup_endpoint ,{"email" : email, "password" : password, "data" : data})


# Allow your users to sign up and create a new account using phone/password combination.
# NOTE: the OTP sent to the user must be verified.
func sign_up_phone(phone : String, password : String, data: Dictionary = {}) -> AuthTask:
	return get_task(AuthTask.METHODS.SIGNUPPHONEPASSWORD, _signup_endpoint, {"phone" : phone, "password" : password, "data" : data})


# If an account is created, users can login to your app.
func sign_in(email : String, password := "") -> AuthTask:
	return get_task(AuthTask.METHODS.SIGNIN, _signin_endpoint, {"email" : email, "password" : password})


# If an account is created, users can login to your app using phone/password combination.
# NOTE: this requires sign_up_phone() and verify_otp() to work
func sign_in_phone(phone : String, password := "") -> AuthTask:
	return get_task(AuthTask.METHODS.SIGNIN, _signin_endpoint, {"phone" : phone, "password" : password})


# Sign in using OTP - the user won't need to use a password but the token must be validated.
# This method always requires to use OTP verification, unlike sign_in_phone()
func sign_in_otp(phone : String) -> AuthTask:
	return get_task(AuthTask.METHODS.SIGNINOTP, _signin_otp_endpoint, {"phone" : phone})


# Verify the OTP token sent to a user as an SMS
func verify_otp(phone : String, token : String) -> AuthTask:
	return get_task(AuthTask.METHODS.VERIFYOTP, _verify_otp_endpoint, {phone = phone, token = token, type = "sms"})


# Sign in as an anonymous user
func sign_in_anonymous() -> AuthTask:
	return get_task(AuthTask.METHODS.SIGNINANONYM, _signin_endpoint)


# If a user is logged in, this will log it out
func sign_out() -> AuthTask:
	return get_task(AuthTask.METHODS.LOGOUT, _logout_endpoint)


# If an account is created, users can login to your app with a magic link sent via email.
# NOTE: this method currently won't work unless the fragment (#) is *MANUALLY* replaced with a query (?) and the browser is reloaded
# [https://github.com/supabase/supabase/issues/1698]
func send_magic_link(email : String) -> AuthTask:
	return get_task(AuthTask.METHODS.MAGICLINK, _magiclink_endpoint, {"email" : email})


# Get the JSON object for the logged in user.
func get_user_as_json(user_access_token : String = user.access_token) -> AuthTask:
	return get_task(AuthTask.METHODS.USER, _user_endpoint)


# Update credentials of the authenticated user, together with optional metadata
func update(email : String, password : String = "", data : Dictionary = {}) -> AuthTask:
	return get_task(AuthTask.METHODS.UPDATE, _user_endpoint, {"email" : email, "password" : password, "data" : data})


# Request a reset password mail to the specified email
func reset_password_for_email(email : String) -> AuthTask:
	return get_task(AuthTask.METHODS.RECOVER, _reset_password_endpoint, {"email" : email})


# Invite another user by their email
func invite_user_by_email(email : String) -> AuthTask:
	return get_task(AuthTask.METHODS.INVITE, _invite_endpoint, {"email" : email})


# Refresh the access_token of the authenticated user using the refresh_token
# No need to call this manually except specific needs, since the process will be handled automatically
func refresh_token(refresh_token : String = user.refresh_token, expires_in : float = user.expires_in) -> AuthTask:
	await get_tree().create_timer(expires_in - 10).timeout
	return get_task(AuthTask.METHODS.REFRESH, _invite_endpoint, {refresh_token = refresh_token})



# Retrieve the response from the server
func _get_link_response(delta : float):
	await get_tree().create_timer(delta).timeout
	var peer := tcp_server.take_connection()
	if peer != null:
		var raw_result := peer.get_utf8_string(peer.get_available_bytes())
		return raw_result
	else:
		_get_link_response(delta)


# Process a specific task
func _process_task(task : AuthTask) -> void:
	task.completed.connect(_on_task_completed)
	var httprequest := HTTPRequest.new()
	httprequest.process_mode = Node.PROCESS_MODE_ALWAYS
	add_child(httprequest)
	task.push_request(httprequest)


func _on_task_completed(task : AuthTask) -> void:
	if task.handler != null:
		task.handler.queue_free()
	if task.data != null and !task.data.is_empty():
		if "access_token" in task.data:
			user = task.data
			bearer = ["Authorization: Bearer %s"]
			bearer[0] = bearer[0] % task.data.access_token
			match task.code:
				AuthTask.METHODS.SIGNUP:
					signed_up.emit(user)
				AuthTask.METHODS.SIGNUPPHONEPASSWORD:
					signed_up_phone.emit(user)
				AuthTask.METHODS.SIGNIN:
					signed_in.emit(user)
				AuthTask.METHODS.SIGNINOTP:
					signed_in_otp.emit(user)
				AuthTask.METHODS.UPDATE: 
					user_updated.emit(user)
				AuthTask.METHODS.REFRESH:
					token_refreshed.emit(user)
				AuthTask.METHODS.VERIFYOTP:
					otp_verified.emit()
				AuthTask.METHODS.SIGNINANONYM:
					signed_in_anonymous.emit()
			refresh_token()
		else:
			match task.code:
				AuthTask.METHODS.MAGICLINK:
					magic_link_sent.emit()
				AuthTask.METHODS.RECOVER:
					reset_email_sent.emit()
				AuthTask.METHODS.INVITE:
					user_invited.emit()
				AuthTask.METHODS.LOGOUT:
					signed_out.emit()
					user = {}
					bearer = ["Authorization: Bearer %s"]
	elif task.error != {}:
		error.emit(task.error)
