extends CharacterBody2D

@export var speed: float = 100.0
@export var gravity: float = 900.0
@export var detection_range: float = 200.0
@export var idle_time: float = 1.0
@export var patrol_distance: float = 300.0
@export var arrive_threshold: float = 4.0
@export var chase_speed_mult: float = 1.2
@export var raycast_ahead: float = 16.0
@export var chase_stop_distance: float = 20.0   # jarak aman saat mengejar

@export var max_health: int = 24
@export var knockback_force: float = 200.0
@export var hitstun_time: float = 0.20          # lama stun setelah kena hit
@export var knockback_decel: float = 1200.0     # redaman knockback per detik

var health: int
var state: String = "patrol_move"   # patrol_move | idle | chase | onhit | death
var idle_timer: float = 0.0
var facing_dir: int = 1

# hit-stun & i-frames
var hitstun_timer: float = 0.0
var invulnerable: bool = false

var patrol_center_x: float
var patrol_left_x: float
var patrol_right_x: float
var current_target_x: float

@onready var anim: AnimatedSprite2D = $AnimatedSprite2D
@onready var floor_check: RayCast2D = $RayCast2D
@onready var player: Node2D = get_parent().get_node("main_character")
@onready var hurtbox: Area2D = $Hurtbox

func _ready() -> void:
	health = max_health
	patrol_center_x = global_position.x
	patrol_left_x = patrol_center_x - patrol_distance
	patrol_right_x = patrol_center_x + patrol_distance
	current_target_x = patrol_right_x

	# sambung sinyal sekali saja
	hurtbox.area_entered.connect(_on_hurtbox_area_entered)
	anim.animation_finished.connect(_on_animation_finished)

func _physics_process(delta: float) -> void:
	if state == "death":
		return

	if not is_on_floor():
		velocity.y += gravity * delta

	match state:
		"patrol_move":
			_state_patrol_move(delta)
		"idle":
			_state_idle(delta)
		"chase":
			_state_chase(delta)
		"onhit":
			# Redam knockback sampai berhenti + hitstun countdown
			velocity.x = move_toward(velocity.x, 0, knockback_decel * delta)
			hitstun_timer -= delta
			if hitstun_timer <= 0.0 and abs(velocity.x) < 10.0:
				invulnerable = false
				# balik ke chase kalau player masih dekat, kalau tidak patrol
				state = "chase" if _can_see_player() else "patrol_move"

	_update_anim()
	move_and_slide()

func _state_patrol_move(delta: float) -> void:
	var dir: int = sign(current_target_x - global_position.x)
	if dir == 0: dir = 1
	velocity.x = dir * speed
	facing_dir = dir

	floor_check.position.x = raycast_ahead * dir

	if not floor_check.is_colliding():
		velocity.x = 0
		_swap_target_and_idle()
		return

	if abs(current_target_x - global_position.x) <= arrive_threshold:
		velocity.x = 0
		_swap_target_and_idle()
		return

	if _can_see_player():
		state = "chase"

func _state_idle(delta: float) -> void:
	velocity.x = 0
	idle_timer -= delta
	if _can_see_player():
		state = "chase"
		return
	if idle_timer <= 0.0:
		state = "patrol_move"

func _state_chase(delta: float) -> void:
	if not _can_see_player():
		state = "patrol_move"
		return

	var dx: float = player.global_position.x - global_position.x
	var dist_abs: float = abs(dx)
	var dir: int = sign(dx)

	# Terlalu dekat → berhenti (tidak fallback ke arah lama)
	if dist_abs <= chase_stop_distance:
		velocity.x = 0
		if dir != 0:
			facing_dir = dir
		floor_check.position.x = raycast_ahead * (facing_dir if facing_dir != 0 else 1)
		return

	if dir == 0:
		dir = facing_dir
	floor_check.position.x = raycast_ahead * dir

	if floor_check.is_colliding():
		velocity.x = dir * speed * chase_speed_mult
		facing_dir = dir
	else:
		velocity.x = 0

func _swap_target_and_idle() -> void:
	if is_equal_approx(current_target_x, patrol_right_x):
		current_target_x = patrol_left_x
	else:
		current_target_x = patrol_right_x
	idle_timer = idle_time
	state = "idle"

func _can_see_player() -> bool:
	if player == null:
		return false
	return global_position.distance_to(player.global_position) <= detection_range

func _update_anim() -> void:
	match state:
		"idle":
			if anim.animation != "idle":
				anim.play("idle")
		"death":
			if anim.animation != "death":
				anim.play("death")
		"onhit":
			if anim.animation != "onhit":
				anim.play("onhit")   # pastikan anim onhit tidak loop di SpriteFrames
		_:
			if anim.animation != "walk":
				anim.play("walk")

	# arah tampilan
	if velocity.x != 0:
		anim.flip_h = velocity.x < 0
	else:
		anim.flip_h = facing_dir < 0

# ================= HEALTH & DAMAGE =================

func _on_hurtbox_area_entered(area: Area2D) -> void:
	# Saat hit-stun, abaikan hit agar tidak "terkunci" di onhit
	if invulnerable or state == "death":
		return
	if area.name == "AttackArea":
		_take_damage(2, area)

func _take_damage(amount: int, area: Area2D) -> void:
	if state == "death":
		return

	health -= amount
	if health > 0:
		# i-frames singkat + knockback + masuk onhit
		invulnerable = true
		hitstun_timer = hitstun_time

		var dir: int = sign(global_position.x - area.global_position.x)  # dorong menjauh dari sumber hit
		if dir == 0: dir = 1
		velocity.x = dir * knockback_force
		state = "onhit"
	else:
		state = "death"
		invulnerable = true
		velocity = Vector2.ZERO
		anim.play("death")

func _on_animation_finished() -> void:
	# Hapus node setelah animasi death selesai
	if anim.animation == "death":
		queue_free()
