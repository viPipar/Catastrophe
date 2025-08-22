extends CharacterBody2D

# Movement settings
@export var speed: float = 220.0
@export var jump_velocity: float = -450.0
@export var gravity: float = 900.0
@export var dash_speed: float = 300.0
@export var dash_duration: float = 0.25
var dash_timer: float = 0.0

# Double jump settings
@export var max_jumps: int = 2
var jump_count: int = 0

# State flags
var is_attacking = false
var is_dashing = false
var is_parrying = false
var is_jumping = false
var is_shooting = false
var facing_dir: int = 1

# Attack settings
var combo_step = 0
var max_combo = 3

# Attack lunge
@export var lunge_force: float = 10.0
@export var lunge_duration: float = 0.1
var lunge_timer: float = 0.0

# Projectile settings
@export var projectile_scene: PackedScene
@onready var spawn_point: Node2D = $SpawnPoint
var projectile_spawned: bool = false

# Timers
@onready var attack_timer: Timer = $StateMachine/AttackTimer
@onready var attack_cooldown_timer: Timer = $StateMachine/AttackCooldownTimer
@onready var attack_combo_timer: Timer = $StateMachine/AttackComboTimer

# Sprite reference
@onready var sprite: AnimatedSprite2D = $AnimatedSprite2D

# Attack hitbox frames (sesuaikan index frame dengan spritesheet-mu)
var attack_hitbox_frames = {
	"attack_1": {"on": 3, "off": 5},
	"attack_2": {"on": 1, "off": 5},
	"attack_3": {"on": 3, "off": 8}
}

func _ready():
	sprite.frame_changed.connect(_on_sprite_frame_changed)
	sprite.animation_finished.connect(_on_animation_finished)
	attack_timer.timeout.connect(_on_attack_timer_timeout)
	attack_cooldown_timer.timeout.connect(_on_attack_cooldown_timeout)
	attack_combo_timer.timeout.connect(_on_attack_combo_timeout)

func _physics_process(delta: float) -> void:
	# Parry locks input (gravity still applies)
	if is_parrying:
		if not is_on_floor():
			velocity.y += gravity * delta
		else:
			velocity.y = 0
		velocity.x = 0
		move_and_slide()
		return

	# When shooting: lock movement so animation can finish uninterrupted
	if is_shooting:
		if not is_on_floor():
			velocity.y += gravity * delta
		else:
			velocity.y = 0
		velocity.x = 0
		move_and_slide()
		return

	# Dash state
	if is_dashing:
		dash_timer -= delta
		velocity.y = 0
		velocity.x = facing_dir * dash_speed
		if sprite.animation != "dash":
			sprite.play("dash")
		if dash_timer <= 0:
			is_dashing = false
		move_and_slide()
		return

	# Gravity
	if not is_on_floor():
		velocity.y += gravity * delta
		if velocity.y < 0:
			if jump_count == 1 and sprite.animation != "jump":
				sprite.play("jump")
			elif jump_count == 2 and sprite.animation != "doublejump":
				sprite.play("doublejump")
		else:
			if sprite.animation != "fall":
				sprite.play("fall")
	else:
		if is_jumping:
			is_jumping = false
		jump_count = 0

	# Jump
	if Input.is_action_just_pressed("jump") and not is_parrying:
		if jump_count < max_jumps:
			velocity.y = jump_velocity
			jump_count += 1
			is_jumping = true
			if jump_count == 1:
				sprite.play("jump")
			else:
				sprite.play("doublejump")

	# Parry input
	if Input.is_action_just_pressed("parry") and not is_dashing and not is_attacking and not is_parrying and is_on_floor():
		is_parrying = true
		velocity.x = 0
		sprite.play("parry")

	# Attack input
	if Input.is_action_just_pressed("attack") and not is_dashing and not is_parrying and not is_shooting:
		try_attack()

	# Projectile input
	if Input.is_action_just_pressed("projectile") and not is_dashing and not is_parrying and not is_attacking and not is_shooting:
		is_shooting = true
		projectile_spawned = false
		sprite.play("projectile")

	# Movement input
	var dir := 0.0
	if Input.is_action_pressed("move_right"):
		dir += 1.0
	if Input.is_action_pressed("move_left"):
		dir -= 1.0

	# Update facing direction and flip related nodes
	if dir != 0:
		facing_dir = 1 if dir > 0 else -1

	# Dash input (requires a direction)
	if Input.is_action_just_pressed("dash") and not is_dashing and not is_parrying and dir != 0:
		is_dashing = true
		dash_timer = dash_duration
		velocity.x = dir * dash_speed
		velocity.y = 0
		sprite.play("dash")
		return

	# Attack lunge handling
	elif is_attacking:
		if lunge_timer > 0:
			lunge_timer -= delta
			velocity.x = facing_dir * lunge_force
		else:
			velocity.x = 0
	else:
		velocity.x = dir * speed
		if is_on_floor() and not is_attacking and not is_parrying and not is_shooting:
			if dir != 0:
				if sprite.animation != "walk":
					sprite.play("walk")
			else:
				if velocity.x == 0 and sprite.animation != "idle":
					sprite.play("idle")

	# flip visuals & flip attack area + spawnpoint horizontally
	if dir != 0:
		sprite.flip_h = dir < 0
		var attack_x = abs($AttackArea/CollisionShape2D.position.x)
		$AttackArea/CollisionShape2D.position.x = attack_x * facing_dir
		spawn_point.position.x = abs(spawn_point.position.x) * facing_dir

	move_and_slide()

func try_attack():
	if attack_cooldown_timer.is_stopped():
		if attack_combo_timer.is_stopped():
			combo_step = 0
		combo_step += 1
		if combo_step > max_combo:
			combo_step = 1
		is_attacking = true
		lunge_timer = lunge_duration
		sprite.play("attack_%d" % combo_step)
		attack_timer.start()
		attack_cooldown_timer.start()
		attack_combo_timer.start()

func spawn_projectile():
	if projectile_scene:
		var bullet = projectile_scene.instantiate()
		get_parent().add_child(bullet)  # spawn sebagai sibling di scene
		bullet.global_position = spawn_point.global_position
		
		# kasih arah sesuai player
		bullet.direction = facing_dir

		# flip sprite di projectile langsung (biar ngikut arah)
		if bullet.has_node("AnimatedSprite2D"):
			var spr: AnimatedSprite2D = bullet.get_node("AnimatedSprite2D")
			spr.flip_h = (facing_dir < 0)
			spr.play("default")  # pastikan animasi projectile jalan

func _on_sprite_frame_changed():
	var anim_name = sprite.animation
	# attack hitbox activation
	if anim_name in attack_hitbox_frames:
		var frame_data = attack_hitbox_frames[anim_name]
		if sprite.frame == frame_data["on"]:
			$AttackArea/CollisionShape2D.disabled = false
		elif sprite.frame == frame_data["off"]:
			$AttackArea/CollisionShape2D.disabled = true

	# spawn projectile only once per animation (sesuaikan frame index)
	if anim_name == "projectile" and sprite.frame == 4 and not projectile_spawned:
		spawn_projectile()
		projectile_spawned = true

func _on_animation_finished():
	if sprite.animation == "parry":
		is_parrying = false
	elif sprite.animation == "projectile":
		# sekarang animasi benar-benar selesai → reset shooting
		is_shooting = false
		projectile_spawned = false

func _on_attack_timer_timeout():
	$AttackArea/CollisionShape2D.disabled = true
	is_attacking = false

func _on_attack_cooldown_timeout():
	pass

func _on_attack_combo_timeout():
	combo_step = 0
