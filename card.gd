extends CharacterBody2D

@export var target: Node2D = null
@export var follow_distance := 40
@export var max_distance := 500
@export var stop_threshold := 5.0
@export var speed = 170
@export var acceleration := 8.0
@export var friction := 10.0

# offset untuk posisi relatif (misalnya ke kiri target)
@export var offset := Vector2(-40, 0)  # 40 pixel ke kiri

func _physics_process(delta):
	if target:
		follow_target(delta)
	move_and_slide()

func follow_target(delta):
	# posisi ideal di kiri target
	var desired_position = target.global_position + offset
	var to_target = desired_position - global_position
	var distance = to_target.length()

	if distance <= follow_distance + stop_threshold:
		velocity = velocity.lerp(Vector2.ZERO, friction * delta)
		return

	var speed_multiplier = 1.0 + clamp(distance / max_distance, 0.0, 1.0)
	var effective_speed = speed * speed_multiplier

	# Tentukan arah 4-way
	var dir = Vector2.ZERO
	if abs(to_target.x) > abs(to_target.y):
		dir.x = sign(to_target.x)
	else:
		dir.y = sign(to_target.y)

	var target_velocity = dir * effective_speed

	velocity = velocity.lerp(target_velocity, acceleration * delta)
