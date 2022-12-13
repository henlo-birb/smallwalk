# i used a ColorRect to hold my shader, cuz that made the most sense i guess
extends ColorRect


const SPEED := 5
const MOUSE_SPEED = .002;

const shader = preload("res://Main.shader")

# cam is actually a Spatial node. I used it even tho this is a 2d scene in order to be able to adjust its transform and stuff more easily 
onready var cam = $Cam
# for some reason it wouldn't work with an AudioStream3D and a Listener3D so i had to go 2d. i think it's because this is a 2d scene?
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
	
#	i used Dialogic for the dialogue since i didn't have the time to, and didn't really want to make a dialogue system myself
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
#		i had to manually hide the text bubble during the pauses, because i wanted most of it to be one Dialogic timeline :/
		"hide_bubble":
			find_node("TextBubble", true, false).visible = false
		"show_bubble":
			find_node("TextBubble", true, false).visible = true
		"main_ended":
			can_end = true
		"game_ended":
			can_close = true
		
func update_shader_params():
#	why is lookDir camel case and the rest of the uniforms all caps w/ underscores? ig i was real tired when writing this lmao
	material.set_shader_param("lookDir", cam.transform.basis.z)
	material.set_shader_param("TRANSFORM", cam.transform.origin)

#	make the friend float on your left side a bit ahead of you unless you're in the ending sequence. the lerps here are to make it feel more natural and not so jumpy
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
		
#	dont do anything if you havent started the game
	if not started:
		return
		
#	handle movement input
	var movement = Vector3.ZERO
	if Input.is_action_pressed("ui_left"):
		movement.x -= SPEED * delta
	if Input.is_action_pressed("ui_right"):
		movement.x += SPEED * delta
	if Input.is_action_pressed("ui_up"):
		movement.z += SPEED * delta
	if Input.is_action_pressed("ui_down"):
		movement.z -= SPEED * delta

# 	this commented-out flying stuff here is from noodleswoops
#	if Input.is_action_pressed("fly_up"):
#		cam.translate(Vector3(0, SPEED * delta, 0))
#	if Input.is_action_pressed("fly_down"):
#		cam.translate(Vector3(0, -SPEED * delta, 0))
	
#	if Input.is_action_just_pressed("toggle_floor"):
#		floor_present = !floor_present
#		material.set_shader_param("FLOOR", floor_present)

#	so's this bit that lets you control the mode
#	mode = (mode + int(Input.is_action_just_pressed("toggle_mode"))) % 3

#	change the mode if you're more than 200 ahead of the start position. i could've put this logic in the shader but i didnt wanna have to rewrite the mode stuff already there from noodleswoops (i ended up doing that partially anyway tho lmao)
	mode = 2 if cam.transform.origin.z > 200 else 0
	
#	more noodleswoops stuff
#	print(cam.transform.origin)
#	max_increases +=  int(Input.is_action_just_pressed("increase"))
#	max_increases -=  int(Input.is_action_just_pressed("decrease"))
	
	cam.global_translate(movement.rotated(Vector3.UP, cam.rotation.y))
	cam.transform.origin.z = clamp(cam.transform.origin.z, -10, 330)

#	i didn't originally have an x limit, but people playing at the con kept thinking you were supposed to follow the friend instead of the path, and walking off into the infinite distance so i added a limit
	cam.transform.origin.x = clamp(cam.transform.origin.x, -20, 20)
	
#	update the listener position so the storm sound fades in when you get close to the end
	listener.position.x = cam.transform.origin.x
	listener.position.y = cam.transform.origin.z
	
	
	
	update_shader_params()
	
#	heres the game ending logic, it runs when you walk past 320, finished the main dialogue, and the end hasn't been triggered yet
	if can_end and not tween and cam.transform.origin.z > 320:
#		start the ending dialogue
		if not can_close and not ending:
			if is_instance_valid(dialogic):
				dialogic.queue_free()
			dialogic = Dialogic.start("end")
			add_child(dialogic)
			dialogic.connect("dialogic_signal", self, "dialogic_signal")
			ending = true
#		when the ending dialogue is over, make the friend float off into the distance, fade out, and restart the scene
		elif can_close:
			tween = get_tree().create_tween()
			tween.tween_interval(2)
			tween.tween_property(self, "friend_pos:z", 380.0, 10).set_ease(Tween.EASE_IN).set_trans(Tween.TRANS_SINE)
			tween.parallel().tween_property($CanvasLayer/FadeOut, "color:a", 1.0, 5).set_ease(Tween.EASE_IN).set_trans(Tween.TRANS_SINE).set_delay(3)
			tween.tween_property($Wind, "volume_db", -100.0, 3).set_ease(Tween.EASE_IN).set_trans(Tween.TRANS_SINE)
			tween.tween_callback(get_tree(),"change_scene", ["res://Main.tscn"])

# this bit just handles mouse movement for looking around
func _input(event):
	if started and event is InputEventMouseMotion:
		var movement = event.relative * MOUSE_SPEED
		cam_rot += movement
		cam.transform.basis = Basis()
		cam.rotate_object_local(Vector3.UP, cam_rot.x)
		cam.rotate_object_local(Vector3.RIGHT, cam_rot.y)

