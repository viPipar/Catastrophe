extends Area2D

@export var speed: float = 80.0
@export var detection_range: float = 300.0
@export var max_health: int = 20

var health: int
var velocity: Vector2 = Vector2.ZERO

@onready var player: Node2D = get_parent().get_node_or_null("main_character")
@onready var anim: AnimatedSprite2D = $AnimatedSprite2D

# --- knockback / hitstun ---
@export var knockback_force: float = 160.0          # horizontal knockback magnitude
@export var knockback_up: float = -80.0             # vertical component (negative = up)
@export var knockback_duration: float = 0.20        # how long knockback actively moves the mob
@export var knockback_decel: float = 1200.0         # how fast knockback velocity decays
var knockback_timer: float = 0.0
var knockback_velocity: Vector2 = Vector2.ZERO

# invulnerability after hit
@export var invuln_time: float = 0.25
var invulnerable: bool = false

func _ready() -> void:
	health = max_health
	# connect self area_entered if not connected in editor (safe auto-connect)
	if not is_connected("area_entered", Callable(self, "_on_hurtbox_area_entered")):
		connect("area_entered", Callable(self, "_on_hurtbox_area_entered"))

func _process(delta: float) -> void:
	# if knockback active, override movement and decay knockback
	if knockback_timer > 0.0:
		knockback_timer -= delta
		# apply knockback movement (frame-rate independent)
		global_position += knockback_velocity * delta
		# decay knockback_velocity toward zero
		knockback_velocity = knockback_velocity.move_toward(Vector2.ZERO, knockback_decel * delta)
		# when finished, ensure timer zeroed
		if knockback_timer <= 0.0:
			knockback_timer = 0.0
		# play onhit anim while in knockback (ensure anim exists)
		if anim and anim.animation != "onhit":
			if anim.sprite_frames.has_animation("onhit"):
				anim.play("onhit")
		return

	# default behaviour: follow / fly toward player if in range
	if player and is_instance_valid(player):
		var dist = global_position.distance_to(player.global_position)
		if dist <= detection_range:
			velocity = (player.global_position - global_position).normalized() * speed
			global_position += velocity * delta
			if anim:
				if anim.animation != "fly":
					anim.play("fly")
		else:
			velocity = Vector2.ZERO
			if anim:
				if anim.animation != "fly":
					anim.play("fly")

		# arah animasi (flip)
		if velocity.x != 0 and anim:
			anim.flip_h = velocity.x < 0

# This handler is called when ANY Area2D overlaps this Area2D (including AttackArea)
# We will react only when the entering area is named "AttackArea" (or its parent).
func _on_hurtbox_area_entered(area: Area2D) -> void:
	# ignore self overlaps
	if area == null:
		return
	# ignore if currently invulnerable
	if invulnerable:
		return

	# Accept either the area itself named AttackArea or its parent named AttackArea
	var area_is_attack_area := false
	if area.name == "AttackArea":
		area_is_attack_area = true
	elif area.get_parent() != null and str(area.get_parent().name) == "AttackArea":
		area_is_attack_area = true

	if not area_is_attack_area:
		return

	# Source (closest meaningful node): prefer area's parent if available
	var source_node: Node = area.get_parent() if area.get_parent() != null else area

	# Apply damage = 3
	var dmg: int = 3
	health -= dmg
	if health < 0:
		health = 0

	# Play onhit animation if exists
	if anim:
		if anim.sprite_frames.has_animation("onhit"):
			anim.play("onhit")
		elif anim.sprite_frames.has_animation("hurt"):
			anim.play("hurt")

	# Start small knockback away from the source
	var kb_dir = 1
	if source_node is Node2D:
		kb_dir = sign(global_position.x - (source_node as Node2D).global_position.x)
		if kb_dir == 0:
			kb_dir = 1
	else:
		# fallback: push opposite of current movement
		kb_dir = -sign(velocity.x) if velocity.x != 0 else 1

	knockback_velocity = Vector2(kb_dir * knockback_force, knockback_up)
	knockback_timer = knockback_duration

	# set invulnerability for a short window to avoid multi-hit spam
	invulnerable = true
	# use a deferred timer to clear invulnerability (non-blocking)
	_clear_invulnerability_after(invuln_time)

	# If health is zero -> die
	if health <= 0:
		_die()

# helper to clear invulnerability (uses coroutine via timer)
func _clear_invulnerability_after(secs: float) -> void:
	# start a background timer (non-blocking)
	# we intentionally don't await here so this function returns immediately
	var t = get_tree().create_timer(secs)
	# when timer times out, set invulnerable false
	t.timeout.connect(func() -> void:
		invulnerable = false
	)

func _die() -> void:
	# play death animation if present then free
	if anim:
		if anim.sprite_frames.has_animation("death"):
			anim.play("death")
	# queue_free after a short delay to let animation play (if any)
	var t = get_tree().create_timer(0.12)
	t.timeout.connect(func() -> void:
		if is_inside_tree():
			queue_free()
	)

# (removed _take_damage() per request)
