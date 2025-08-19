extends Area2D

@export var speed: float = 80.0
@export var detection_range: float = 200.0
@export var max_health: int = 5

var health: int
var velocity: Vector2 = Vector2.ZERO

@onready var player: Node2D = get_parent().get_node("main_character")
@onready var anim: AnimatedSprite2D = $AnimatedSprite2D

func _ready() -> void:
	health = max_health

func _process(delta: float) -> void:
	if player and is_instance_valid(player):
		var dist = global_position.distance_to(player.global_position)
		if dist <= detection_range:
			# terbang ke arah player
			velocity = (player.global_position - global_position).normalized() * speed
			global_position += velocity * delta
			anim.play("fly")
		else:
			# idle kalau player jauh
			velocity = Vector2.ZERO
			anim.play("fly")

		# arah animasi (flip)
		if velocity.x != 0:
			anim.flip_h = velocity.x < 0

func _on_hurtbox_area_entered(area: Area2D) -> void:
	if area.name == "AttackArea":
		_take_damage(1)

func _take_damage(amount: int) -> void:
	health -= amount
	if health <= 0:
		queue_free()
