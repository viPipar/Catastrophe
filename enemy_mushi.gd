extends CharacterBody2D

@export var speed: float = 150.0
@export var gravity: float = 900.0
@export var detection_range: float = 300.0
@export var idle_time: float = 1.0
@export var patrol_distance: float = 300.0
@export var arrive_threshold: float = 4.0
@export var chase_speed_mult: float = 1.2
@export var raycast_ahead: float = 16.0
@export var chase_stop_distance: float = 20.0
@export var attack_range: float = 64.0

@export var max_health: int = 24
@export var knockback_force: float = 200.0
@export var hitstun_time: float = 0.4
@export var knockback_decel: float = 1200.0

@export var attack_hard_timeout: float = 3.5
@export var parry_enable_frame: int = 5    # parry aktif duluan
@export var parry_disable_frame: int = 12
@export var hit_enable_frame: int = 13
@export var hit_disable_frame: int = 15
@export var hitarea_offset: float = 20.0

var health: int
var state: String = "patrol_move"
var idle_timer: float = 0.0
var facing_dir: int = 1

var hitstun_timer: float = 0.0
var invulnerable: bool = false

var patrol_center_x: float
var patrol_left_x: float
var patrol_right_x: float
var current_target_x: float

var _attack_timer: float = -1.0
var _attack_lock: bool = false

@onready var anim: AnimatedSprite2D = $AnimatedSprite2D
@onready var floor_check: RayCast2D = $RayCast2D
@onready var player: Node2D = get_parent().get_node("main_character")
@onready var hurtbox: Area2D = $Hurtbox
@onready var hit_area: Area2D = $HitArea
@onready var hit_shape: CollisionShape2D = $HitArea/CollisionShape2D
@onready var parry_area: Area2D = $ParryAttack
@onready var parry_shape: CollisionShape2D = $ParryAttack/CollisionShape2D

@onready var hurtsfx = $Audio/Hurt
@onready var walksfx = $Audio/Walk
@onready var attacksfx = $Audio/Attack
@onready var deathsfx = $Audio/Death

# posisi dasar untuk mirror
var _hitarea_base_pos: Vector2 = Vector2.ZERO
var _hitshape_base_pos: Vector2 = Vector2.ZERO
var _hitarea_base_pos_set: bool = false

var _parry_base_pos: Vector2 = Vector2.ZERO
var _parry_base_pos_set: bool = false

# ==================== READY ====================
func _ready() -> void:
	health = max_health
	patrol_center_x = global_position.x
	patrol_left_x = patrol_center_x - patrol_distance
	patrol_right_x = patrol_center_x + patrol_distance
	current_target_x = patrol_right_x
	walksfx.stream.loop = true

	hurtbox.area_entered.connect(_on_hurtbox_area_entered)
	anim.animation_finished.connect(_on_animation_finished)
	anim.frame_changed.connect(_on_animation_frame_changed)

	# pastikan collider mati di awal
	hit_shape.disabled = true
	parry_shape.disabled = true

	# rekam posisi dasar HitArea & ParryAttack
	_hitarea_base_pos = hit_area.position
	_hitshape_base_pos = hit_shape.position
	_hitarea_base_pos_set = true

	_parry_base_pos = parry_area.position
	_parry_base_pos_set = true

	_update_hitarea_transform()
	_update_parry_transform()

# ==================== PHYSICS PROCESS ====================
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
		"attack":
			_state_attack(delta)
		"onhit":
			velocity.x = move_toward(velocity.x, 0, knockback_decel * delta)
			hitstun_timer -= delta
			if hitstun_timer <= 0.0 and abs(velocity.x) < 10.0:
				invulnerable = false
				if _can_see_player():
					_set_state("chase")
				else:
					_set_state("patrol_move")

	_update_anim()
	_update_hitarea_transform()
	_update_parry_transform()
	move_and_slide()

# ==================== STATES ====================
func _state_patrol_move(_delta: float) -> void:
	var dir: int = sign(current_target_x - global_position.x)
	if dir == 0:
		dir = 1
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
		_set_state("chase")

func _state_idle(delta: float) -> void:
	velocity.x = 0
	idle_timer -= delta
	if _can_see_player():
		_set_state("chase")
		return
	if idle_timer <= 0.0:
		_set_state("patrol_move")

func _state_chase(_delta: float) -> void:
	if not _can_see_player():
		_set_state("patrol_move")
		return

	var dx: float = player.global_position.x - global_position.x - 60
	var dist_abs: float = abs(dx)
	var dir: int = sign(dx)

	if dist_abs <= attack_range:
		velocity.x = 0
		_set_state("attack")
		return

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

func _state_attack(delta: float) -> void:
	velocity.x = 0
	if _attack_timer >= 0.0:
		_attack_timer += delta
		if _attack_timer > attack_hard_timeout:
			_finish_attack()

# ==================== UTILS ====================
func _swap_target_and_idle() -> void:
	if is_equal_approx(current_target_x, patrol_right_x):
		current_target_x = patrol_left_x
	else:
		current_target_x = patrol_right_x
	idle_timer = idle_time
	_set_state("idle")

func _can_see_player() -> bool:
	if player == null:
		return false
	return global_position.distance_to(player.global_position) <= detection_range

func _update_anim() -> void:
	match state:
		"idle":
			if anim.animation != "idle":
				anim.play("idle")
			if walksfx.playing:
				walksfx.stop()

		"death":
			if anim.animation != "death":
				anim.play("death")
			if walksfx.playing:
				walksfx.stop()

		"onhit":
			if anim.animation != "onhit":
				anim.play("onhit")
			if walksfx.playing:
				walksfx.stop()

		"attack":
			if anim.animation != "attack":
				anim.play("attack")
			if walksfx.playing:
				walksfx.stop()

		_:
			# default dianggap "walk / chase"
			if anim.animation != "walk":
				anim.play("walk")

			# play sfx hanya kalau benar2 bergerak
			if abs(velocity.x) > 5.0:
				if not walksfx.playing:
					walksfx.play()
			else:
				if walksfx.playing:
					walksfx.stop()

	# flip sprite sesuai arah gerak
	if velocity.x != 0:
		anim.flip_h = velocity.x < 0
	else:
		anim.flip_h = facing_dir < 0


	if velocity.x != 0:
		anim.flip_h = velocity.x < 0
	else:
		anim.flip_h = facing_dir < 0

func _set_state(new_state: String, force: bool = false) -> void:
	if state == new_state:
		return
	if _attack_lock and not force:
		return

	if new_state == "attack":
		state = "attack"
		_attack_lock = true
		_attack_timer = 0.0
		# pastikan semua collider off saat mulai attack — akan di-enable per frame
		hit_shape.disabled = true
		parry_shape.disabled = true
		if anim.animation != "attack":
			attacksfx.play()
			anim.play("attack")
		return

	if new_state == "onhit" or new_state == "death":
		_attack_lock = false
		_attack_timer = -1.0

	state = new_state

# ==================== DAMAGE ====================
func _on_hurtbox_area_entered(area: Area2D) -> void:
	if invulnerable or state == "death":
		return
	# hanya abaikan hitarea sendiri
	if area == hit_area or area == parry_area:
		return

	var dmg: int = 0
	if area.name == "AttackArea":
		dmg = 2
	elif area.name in ["CardProjectile", "ParryStun"]:
		dmg = 1
	else:
		return

	_take_damage(dmg, area)


func _take_damage(amount: int, area: Area2D) -> void:
	if state == "death":
		return
	health -= amount
	if health > 0:
		invulnerable = true
		hitstun_timer = hitstun_time
		var dir: int = sign(global_position.x - area.global_position.x)
		if dir == 0:
			dir = 1
		velocity.x = dir * knockback_force
		hurtsfx.play()
		_set_state("onhit", true)
	else:
		_set_state("death", true)
		invulnerable = true
		velocity = Vector2.ZERO
		if anim.animation != "death":
			deathsfx.play()
			anim.play("death")

# ==================== ANIMATION EVENTS ====================
func _on_animation_finished() -> void:
	if anim.animation == "death":
		queue_free()
	elif anim.animation == "attack":
		_finish_attack()

func _on_animation_frame_changed() -> void:
	if anim.animation != "attack":
		return

	# anim berjalan → reset fallback timer
	if _attack_timer < 0.0:
		_attack_timer = 0.0
	_attack_timer = 0.0

	# parry window (bisa diparry oleh player) aktif lebih dahulu
	if anim.frame == parry_enable_frame:
		parry_shape.disabled = false
	elif anim.frame == parry_disable_frame:
		parry_shape.disabled = true

	# kemudian non-parry hit window (tidak bisa diparry)
	if anim.frame == hit_enable_frame:
		hit_shape.disabled = false
	elif anim.frame == hit_disable_frame:
		hit_shape.disabled = true

func _finish_attack() -> void:
	hit_shape.disabled = true
	parry_shape.disabled = true
	_attack_timer = -1.0
	_attack_lock = false

	if _can_see_player():
		_set_state("chase")
	else:
		_set_state("patrol_move")

# ==================== HITAREA & PARRY TRANSFORM ====================
func _update_hitarea_transform() -> void:
	if _hitarea_base_pos_set:
		hit_area.position = Vector2(abs(_hitarea_base_pos.x) * facing_dir, _hitarea_base_pos.y)
	else:
		hit_area.position.x = hitarea_offset * facing_dir

	hit_area.scale.x = 1 if facing_dir >= 0 else -1
	hit_shape.position = _hitshape_base_pos

func _update_parry_transform() -> void:
	if _parry_base_pos_set:
		parry_area.position = Vector2(abs(_parry_base_pos.x) * facing_dir, _parry_base_pos.y)
	else:
		parry_area.position.x = hitarea_offset * facing_dir

	parry_area.scale.x = 1 if facing_dir >= 0 else -1
	# kembalikan posisi lokal collisionshape seperti di editor (jika kamu menyimpan pos dasar, gantikan sesuai)
	parry_shape.position = parry_shape.position
	
