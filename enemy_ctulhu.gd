extends CharacterBody2D

# === PARAMETER UMUM ===
@export var speed: float = 150.0
@export var gravity: float = 900.0
@export var detection_range: float = 500.0
@export var idle_time: float = 1.0
@export var patrol_distance: float = 300.0
@export var arrive_threshold: float = 4.0
@export var chase_speed_mult: float = 1.2
@export var raycast_ahead: float = 16.0
@export var chase_stop_distance: float = 20.0
@export var attack_range: float = 220.0

# === STAT & DAMAGE ===
@export var max_health: int = 500
@export var hitstun_time: float = 0.3

# === ATTACK HANDLING ===
@export var attack_hard_timeout: float = 3.5
@export var hit_frames: Array[Vector2i] = [
	Vector2i(3, 8)  # contoh: aktif di frame 6–12
]
@export var parry_frames: Vector2i = Vector2i(1, 3) # parry aktif frame 3–7
@export var hitarea_offset: float = 20.0

# === STATE VAR ===
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

# Attack state helper
var _attack_timer: float = -1.0
var _attack_lock: bool = false

# === NODE REFS ===
@onready var anim: AnimatedSprite2D = $AnimatedSprite2D
@onready var floor_check: RayCast2D = $RayCast2D
@onready var player: Node2D = get_parent().get_node_or_null("main_character")
@onready var hurtbox: Area2D = $Hurtbox
@onready var hit_area: Area2D = $HitArea
@onready var hit_shape: CollisionShape2D = $HitArea/CollisionShape2D
@onready var parry_area: Area2D = $ParryAttack
@onready var parry_shape: CollisionShape2D = $ParryAttack/CollisionShape2D

@onready var hurtsfx = $Audio/Hurt
@onready var walksfx = $Audio/Walk
@onready var deathsfx = $Audio/Death
@onready var attacksfx = $Audio/Attack
@onready var screamsfx = $Audio/Scream

# backup posisi awal hitarea & parry agar mirror konsisten
var _hitarea_base_pos: Vector2 = Vector2.ZERO
var _hitshape_base_pos: Vector2 = Vector2.ZERO
var _parry_base_pos: Vector2 = Vector2.ZERO
var _parryshape_base_pos: Vector2 = Vector2.ZERO

func _ready() -> void:
	# initialize health & patrol bounds
	health = max_health
	patrol_center_x = global_position.x
	patrol_left_x = patrol_center_x - patrol_distance
	patrol_right_x = patrol_center_x + patrol_distance
	current_target_x = patrol_right_x
	walksfx.stream.loop = true

	# signals
	if hurtbox:
		hurtbox.area_entered.connect(_on_hurtbox_area_entered)
	anim.animation_finished.connect(_on_animation_finished)
	anim.frame_changed.connect(_on_animation_frame_changed)

	# pastikan collider mati di awal
	if hit_shape:
		hit_shape.disabled = true
	if parry_shape:
		parry_shape.disabled = true

	# record base positions for mirroring
	if hit_area:
		_hitarea_base_pos = hit_area.position
	if hit_shape:
		_hitshape_base_pos = hit_shape.position
	if parry_area:
		_parry_base_pos = parry_area.position
	if parry_shape:
		_parryshape_base_pos = parry_shape.position

	_update_hitarea_transform()
	_update_parry_transform()

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

# ================== STATE FUNCTIONS ==================
func _state_patrol_move(_delta: float) -> void:
	var dir = sign(current_target_x - global_position.x)
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
	elif idle_timer <= 0.0:
		_set_state("patrol_move")

func _state_chase(_delta: float) -> void:
	if not _can_see_player():
		_set_state("patrol_move")
		return

	var dx = player.global_position.x - global_position.x - 60
	var dist_abs = abs(dx)
	var dir = sign(dx)

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

# ================== STATE UTILS ==================
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
			anim.play("idle")
			if walksfx.playing:
				walksfx.stop()

		"death":
			anim.play("death")
			if walksfx.playing:
				walksfx.stop()

		"onhit":
			anim.play("onhit")
			if walksfx.playing:
				walksfx.stop()

		"attack":
			anim.play("attack")
			if walksfx.playing:
				walksfx.stop()

		_:
			if anim.animation != "walk":
				anim.play("walk")
			if not walksfx.playing:
				walksfx.play()


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
		if hit_shape:
			hit_shape.disabled = true
		if parry_shape:
			parry_shape.disabled = true
		attacksfx.play()
		anim.play("attack")
		return
	if new_state == "onhit" or new_state == "death":
		_attack_lock = false
		_attack_timer = -1.0
	state = new_state

func _damage_from_area(area: Area2D) -> int:
	# Kalau area sudah membawa angka damage sendiri, pakai itu
	if area.has_meta("damage"):
		return int(area.get_meta("damage"))

	# Kalau tidak, ambil dari GameState per jenis serangan
	match area.name:
		"AttackArea":
			return GameState.damage_for("melee")
		"CardProjectile":
			return GameState.damage_for("projectile")
		"ParryStun":
			return GameState.damage_for("parry")
		_:
			return 0

# ================== DAMAGE ==================
func _on_hurtbox_area_entered(area: Area2D) -> void:
	if invulnerable or state == "death":
		return
	if area == hit_area or area == parry_area or area.get_parent() == self or area.owner == self:
		return

	var dmg := _damage_from_area(area)
	if dmg <= 0:
		return
	_take_damage(dmg, area)

func _take_damage(amount: int, area: Area2D) -> void:
	if state == "death":
		return
	health -= amount
	if health < 0:
		health = 0
	if health > 0:
		invulnerable = true
		hitstun_timer = hitstun_time
		var dir = sign(global_position.x - area.global_position.x)
		if dir == 0:
			dir = 1
		velocity.x = 0
		hurtsfx.play()
		_set_state("onhit", true)
	else:
		_set_state("death", true)
		invulnerable = true
		deathsfx.play()
		screamsfx.play()
		anim.play("death")

# ================== ANIM EVENTS ==================
func _on_animation_finished() -> void:
	if anim.animation == "death":
		queue_free()
	elif anim.animation == "attack":
		_finish_attack()

func _on_animation_frame_changed() -> void:
	if anim.animation != "attack":
		return
	_attack_timer = 0.0
	var frame_now = anim.frame

	# parry window 3–7
	if frame_now >= parry_frames.x and frame_now <= parry_frames.y:
		parry_shape.disabled = false
	else:
		parry_shape.disabled = true

	# hit window (pakai array hit_frames)
	var enable = false
	for range in hit_frames:
		if frame_now >= range.x and frame_now <= range.y:
			enable = true
			break
	hit_shape.disabled = not enable

func _finish_attack() -> void:
	hit_shape.disabled = true
	parry_shape.disabled = true
	_attack_timer = -1.0
	_attack_lock = false
	if _can_see_player():
		_set_state("chase")
	else:
		_set_state("patrol_move")

# ================== HITAREA & PARRY TRANSFORM ==================
func _update_hitarea_transform() -> void:
	if _hitarea_base_pos == Vector2.ZERO:
		hit_area.position = Vector2(hitarea_offset * facing_dir, 0)
	else:
		hit_area.position = Vector2(abs(_hitarea_base_pos.x) * facing_dir, _hitarea_base_pos.y)
	hit_shape.position = _hitshape_base_pos
	hit_area.scale.x = 1 if facing_dir >= 0 else -1

func _update_parry_transform() -> void:
	if _parry_base_pos == Vector2.ZERO:
		parry_area.position = Vector2(hitarea_offset * facing_dir, 0)
	else:
		parry_area.position = Vector2(abs(_parry_base_pos.x) * facing_dir, _parry_base_pos.y)
	parry_shape.position = _parryshape_base_pos
	parry_area.scale.x = 1 if facing_dir >= 0 else -1
