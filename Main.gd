extends ColorRect


const SPEED := 5
const MOUSE_SPEED = .002;

const shader = preload("res://Main.shader")

onready var cam = $Cam
onready var listener = $Listener2D
var cam_rot := Vector2()
var max_increases := 15
var mode := 0
var floor_present = false;
var dialogic
var started = false
var tween
var can_end = false
var can_close = false
var ending = false

onready var friend_pos = cam.transform.origin

func _ready():
	material = ShaderMaterial.new()
	material.shader = shader
	Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
	update_shader_params()

#	cam.translate(Vector3(0, 0, 320))

func start_game():
	started = true
	Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)
	dialogic = Dialogic.start("start")
	add_child_below_node(cam, dialogic)
	dialogic.connect("dialogic_signal", self, "dialogic_signal")
#	dialogic.scale = Vector2(0.5, 0.5)
#	dialogic.transform = Transform2D(Vector2(0.5, 0), Vector2(0,0.5), Vector2(80, 120))
	$GridContainer.queue_free()
	
func quit():
	get_tree().quit()
	

func dialogic_signal(arg):
	match arg:
		"hide_bubble":
			find_node("TextBubble", true, false).visible = false
		"show_bubble":
			find_node("TextBubble", true, false).visible = true
		"main_ended":
			can_end = true
		"game_ended":
			can_close = true
		
func update_shader_params():
	material.set_shader_param("lookDir", cam.transform.basis.z)
	material.set_shader_param("TRANSFORM", cam.transform.origin)
	if not can_close:
		friend_pos = lerp(friend_pos, cam.transform.origin, 0.1)
		friend_pos.z = lerp(friend_pos.z, clamp(friend_pos.z, cam.transform.origin.z, cam.transform.origin.z + 10), 0.1)
	material.set_shader_param("FRIEND_POS", friend_pos)
	material.set_shader_param("MAX_INCREASES", max_increases)
	material.set_shader_param("MODE", mode)

	
func _process(delta):
	if Input.is_action_pressed("ui_cancel"):
		get_tree().quit()
	if Input.is_action_just_pressed("fullscreen"):
		OS.window_fullscreen = !OS.window_fullscreen
		
	
	if not started:
		return
	var movement = Vector3.ZERO
	if Input.is_action_pressed("ui_left"):
		movement.x -= SPEED * delta
	if Input.is_action_pressed("ui_right"):
		movement.x += SPEED * delta
	if Input.is_action_pressed("ui_up"):
		movement.z += SPEED * delta
	if Input.is_action_pressed("ui_down"):
		movement.z -= SPEED * delta
#	if Input.is_action_pressed("fly_up"):
#		cam.translate(Vector3(0, SPEED * delta, 0))
#	if Input.is_action_pressed("fly_down"):
#		cam.translate(Vector3(0, -SPEED * delta, 0))
	
#	if Input.is_action_just_pressed("toggle_floor"):
#		floor_present = !floor_present
#		material.set_shader_param("FLOOR", floor_present)
	
#	mode = (mode + int(Input.is_action_just_pressed("toggle_mode"))) % 3
	mode = 2 if cam.transform.origin.z > 200 else 0
#	print(cam.transform.origin)
#	max_increases +=  int(Input.is_action_just_pressed("increase"))
#	max_increases -=  int(Input.is_action_just_pressed("decrease"))
	
#	cam.translate_object_local(movement)translate_object_local
	cam.global_translate(movement.rotated(Vector3.UP, cam.rotation.y))
	cam.transform.origin.z = clamp(cam.transform.origin.z, -10, 330)
	cam.transform.origin.x = clamp(cam.transform.origin.x, -20, 20)
	
	listener.position.x = cam.transform.origin.x
	listener.position.y = cam.transform.origin.z
	
	
	
	update_shader_params()
	
	if can_end and not tween and cam.transform.origin.z > 320:
		if not can_close and not ending:
			if is_instance_valid(dialogic):
				dialogic.queue_free()
			dialogic = Dialogic.start("end")
			add_child(dialogic)
			dialogic.connect("dialogic_signal", self, "dialogic_signal")
			ending = true
		elif can_close:
			tween = get_tree().create_tween()
			tween.tween_interval(2)
			tween.tween_property(self, "friend_pos:z", 380.0, 10).set_ease(Tween.EASE_IN).set_trans(Tween.TRANS_SINE)
			tween.parallel().tween_property($CanvasLayer/FadeOut, "color:a", 1.0, 5).set_ease(Tween.EASE_IN).set_trans(Tween.TRANS_SINE).set_delay(3)
			tween.tween_property($Wind, "volume_db", -100.0, 3).set_ease(Tween.EASE_IN).set_trans(Tween.TRANS_SINE)
			tween.tween_callback(get_tree(),"change_scene", ["res://Main.tscn"])

	
func _input(event):
	if started and event is InputEventMouseMotion:
		var movement = event.relative * MOUSE_SPEED
		cam_rot += movement
		cam.transform.basis = Basis()
		cam.rotate_object_local(Vector3.UP, cam_rot.x)
		cam.rotate_object_local(Vector3.RIGHT, cam_rot.y)

