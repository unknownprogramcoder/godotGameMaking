extends KinematicBody2D

const FLOOR = Vector2(0, -1)
export var SLOPE_STOP : float

export var H_WEIGHT_GROUND : float
export var H_WEIGHT_AIR : float
export var H_WEIGHT_CROUCH : float

var velocity = Vector2()

var move_direction = 0
var is_crouching = false
export var RUN_SPEED : float
export var CRAWL_SPEED : float

export var JUMP_HEIGHT : float
export var JUMP_TIME_TO_PEAK : float
export var JUMP_TIME_TO_DESCENT : float
onready var JUMP_VELOCITY : float=(2.0*JUMP_HEIGHT)/JUMP_TIME_TO_PEAK
onready var JUMP_GRAVITY : float=(-2.0*JUMP_HEIGHT)/(JUMP_TIME_TO_PEAK*JUMP_TIME_TO_PEAK)
onready var FALL_GRAVITY : float=(-2.0*JUMP_HEIGHT)/(JUMP_TIME_TO_DESCENT*JUMP_TIME_TO_DESCENT)

onready var standing_gesture = $Sprite_idle
onready var crouching_gesture = $Sprite_crouch
onready var standing_collision = $StandingShape
onready var crouching_collision = $CrouchingShape

#################################
var state = null setget set_state
var previous_state = null
var states = {}
#################################

#onready var raycasts = $Raycasts

func _handle_move_input():
	move_direction = -int(Input.is_action_pressed("ui_left")) + int(Input.is_action_pressed("ui_right"))
	if (state == states.crouch) or (state == states.crawl):
		velocity.x = lerp(velocity.x, CRAWL_SPEED * move_direction, _get_h_weight())
	else:
		velocity.x = lerp(velocity.x, RUN_SPEED * move_direction, _get_h_weight())
	#if move_direction != 0:
	#	$Body.scale.x = move_direction
	
	if Input.is_action_just_pressed("ui_up"):
		if (state == states.idle) or (state == states.run):
			jump()
	
	if Input.is_action_pressed("ui_down"):
		if (state == states.idle) or (state == states.run):
			crouch()
	elif (state == states.crouch) or (state == states.crawl):
		if can_stand():
			stand_up()

func _apply_shape_transformation():
	if (state == states.crouch) or (state == states.crawl):
		_on_crouch()
	else:
		_on_stand()

func _apply_gravity(delta):
	velocity.y -= get_gravity() * delta

func _apply_movement(delta):
	velocity = move_and_slide(velocity, FLOOR, SLOPE_STOP)

#func _check_on_ground():
#	for raycast in raycasts.get_children():
#		if raycast.is_colliding():
#			return true
#	return false

func _get_h_weight():
	if (state == states.crouch) or (state == states.crawl):
		return H_WEIGHT_CROUCH
	elif (state == states.idle) or (state == states.run):
		return H_WEIGHT_GROUND
	elif (state == states.jump) or (state == states.fall):
		return H_WEIGHT_AIR
		
func jump():
	velocity.y = -JUMP_VELOCITY
func crouch():
	is_crouching = true
func stand_up():
	is_crouching = false
func can_stand() -> bool:
	var space_state = get_world_2d().direct_space_state
	var query = Physics2DShapeQueryParameters.new()
	query.set_shape(standing_collision.shape)
	query.transform = standing_collision.global_transform
	query.collision_layer = collision_mask
	var results = space_state.intersect_shape(query)
	#print("BEFORE", results.size())
	for i in range(results.size() -1, -1, -1):
		var collider = results[i].collider
		var shape = results[i].shape
		if collider is CollisionObject2D && collider.is_shape_owner_one_way_collision_enabled(shape):
			results.remove(i)
		if collider is TileMap:
			var tile_id = collider.get_cellv(results[i].metadata)
			if collider.tile_set.tile_get_shape_one_way(tile_id, 0):
				results.remove(i)
	#print("AFTER", results.size())
	return results.size() == 1
	
func get_gravity() -> float:
	return JUMP_GRAVITY if velocity.y < 0.0 else FALL_GRAVITY
	
func _on_crouch():
	standing_gesture.visible = false
	crouching_gesture.visible = true
	standing_collision.disabled = true
	crouching_collision.disabled = false
func _on_stand():
	standing_gesture.visible = true
	crouching_gesture.visible = false
	standing_collision.disabled = false
	crouching_collision.disabled = true
	
func _physics_process(delta):
	if state != null:
		_state_logic(delta)
		var transition = _get_transition(delta)
		if transition != null:
			set_state(transition)

func _ready():
	add_state("idle")
	add_state("run")
	add_state("jump")
	add_state("fall")
	add_state("crouch")
	add_state("crawl")
	add_state("crouch-ing")
	add_state("stand-ing")
	call_deferred("set_state", states.idle)

func _state_logic(delta):
	_handle_move_input()
	_apply_shape_transformation()
	_apply_gravity(delta)
	_apply_movement(delta)
	
func _get_transition(delta):
	match state:
		states.idle:
			if !is_on_floor():
				if velocity.y < 0:
					return states.jump
				elif velocity.y > 0:
					return states.fall
			elif is_crouching:
				if velocity.x == 0:
					return states.crouch
				elif velocity.x != 0:
					return states.crawl
			elif velocity.x != 0:
				return states.run
		states.run:
			if !is_on_floor():
				if velocity.y < 0:
					return states.jump
				elif velocity.y > 0:
					return states.fall
			elif is_crouching:
				if velocity.x == 0:
					return states.crouch
				elif velocity.x != 0:
					return states.crawl
			elif velocity.x == 0:
				return states.idle
		states.jump:
			if is_on_floor():
				if velocity.x == 0:
					return states.idle
				elif velocity.x != 0:
					return states.run
			elif velocity.y >= 0:
				return states.fall
		states.fall:
			if is_on_floor():
				if velocity.x == 0:
					return states.idle
				elif velocity.x != 0:
					return states.run
			elif velocity.y >= 0:
				return states.jump
		states.crouch:
			if !is_crouching:
				if velocity.x == 0:
					return states.idle
				elif velocity.x != 0:
					return states.run
			elif velocity.x != 0:
				return states.crawl
		states.crawl:
			if !is_crouching:
				if velocity.x == 0:
					return states.idle
				elif velocity.x != 0:
					return states.run
			elif velocity.x == 0:
				return states.crouch
	return null
	
func _enter_state(new_state, old_state):
	pass
func _exit_state(old_state, new_state):
	pass
	
func set_state(new_state):
	previous_state = state
	state = new_state
	if previous_state != null:
		_exit_state(previous_state, new_state)
	if new_state != null:
		_enter_state(new_state, previous_state)

func add_state(state_name):
	states[state_name] = states.size()
