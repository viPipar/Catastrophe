extends CharacterBody2D

@onready var target = $"../main_character"
@export var gravity = 900
@export var speed = 150

var dead = false
var health = 10
var is_hit = false

func _ready() -> void:
	pass

func _physics_process(delta: float) -> void:
	# kasih gravitasi
	if not is_on_floor():
		velocity.y += gravity * delta

	if dead:
		return  # sudah mati

	if is_hit:
		move_and_slide() # tetap update supaya jatuh kalau di udara
		return

	# cari arah gerakan
	var direction = (target.position - position).normalized()
	velocity.x = direction.x * speed   # hanya X yang dikontrol musuh
	look_at(target.position)

	# animasi: jalan atau idle
	if abs(velocity.x) > 5:
		$AnimatedSprite2D.play("on_walk")
	else:
		$AnimatedSprite2D.play("on_idle")

	move_and_slide()

func _on_enemy_area_entered(area: Area2D) -> void:
	if dead:
		return

	if area.is_in_group("sword"):
		is_hit = true
		health -= 1
		$AnimatedSprite2D.play("on_hit")

		if health <= 0:
			dead = true
			$AnimatedSprite2D.play("on_destroy")
			await $AnimatedSprite2D.animation_finished
			queue_free()
		else:
			await $AnimatedSprite2D.animation_finished
			is_hit = false
