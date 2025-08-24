extends Area2D

@export var speed: float = 80.0
@export var detection_range: float = 500.0
@export var max_health: int = 60

var health: int
var velocity: Vector2 = Vector2.ZERO

@onready var player: Node2D = get_parent().get_node_or_null("main_character")
@onready var anim: AnimatedSprite2D = $AnimatedSprite2D
@onready var hurtsfx = $Audio/Hurt

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

# ===== Helpers jenis serangan =====
func _is_melee(area: Area2D) -> bool:
	return area.name == "AttackArea" \
		or (area.get_parent() != null and str(area.get_parent().name) == "AttackArea")

func _is_parry(area: Area2D) -> bool:
	return area.name == "ParryStun"

func _is_projectile(area: Area2D) -> bool:
	if area.name == "CardProjectile":
		return true
	if area.get_parent() != null and str(area.get_parent().name) == "CardProjectile":
		return true
	return area.is_in_group("projectile")  # kalau kamu pakai group

func _projectile_root(area: Area2D) -> Node:
	# balikin node pelurunya (bukan child Area-nya) supaya gampang dihapus
	if area.name == "CardProjectile":
		return area
	if area.get_parent() != null and str(area.get_parent().name) == "CardProjectile":
		return area.get_parent()
	# kalau pakai group, asumsi area itu child dari node peluru
	if area.is_in_group("projectile") and area.get_parent() != null:
		return area.get_parent()
	return null

func _damage_from_area(area: Area2D) -> int:
	# Prioritas: kalau area bawa meta "damage", pakai itu
	if area.has_meta("damage"):
		return int(area.get_meta("damage"))

	# Kalau tidak, ambil dari GameState per jenis
	if _is_melee(area):
		return GameState.damage_for("melee")
	elif _is_projectile(area):
		return GameState.damage_for("projectile")
	elif _is_parry(area):
		return GameState.damage_for("parry")
	return 0

func _on_hurtbox_area_entered(area: Area2D) -> void:
	if area == null or invulnerable:
		return

	# cegah self-hit tanpa menyebut hit_area/parry_area
	if area.get_parent() == self or area.owner == self:
		return

	# terima hanya melee / projectile / parry
	if not (_is_melee(area) or _is_projectile(area) or _is_parry(area)):
		return

	var dmg: int = _damage_from_area(area)
	if dmg <= 0:
		return

	# sumber untuk arah knockback (pakai root projectile kalau peluru)
	var source_node: Node = _projectile_root(area) if _is_projectile(area) \
		else (area.get_parent() if area.get_parent() != null else area)

	health = max(health - dmg, 0)

	if anim and anim.sprite_frames.has_animation("onhit"):
		hurtsfx.play()
		anim.play("onhit")

	var kb_dir := 1
	if source_node is Node2D:
		kb_dir = sign(global_position.x - (source_node as Node2D).global_position.x - 60)
		if kb_dir == 0: kb_dir = 1
	else:
		kb_dir = -sign(velocity.x) if velocity.x != 0 else 1

	knockback_velocity = Vector2(kb_dir * knockback_force, knockback_up)
	knockback_timer = knockback_duration
	invulnerable = true
	_clear_invulnerability_after(invuln_time)

	# hapus / trigger peluru
	if _is_projectile(area):
		var proj := _projectile_root(area)
		if proj:
			if proj.has_method("on_hit"): proj.call("on_hit")
			else: proj.queue_free()

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

func _player_damage() -> int:
	# Ambil damage pemain dari GameState (autoload)
	# fallback ke 10 kalau belum ada
	return int(GameState.damage_for("melee"))
