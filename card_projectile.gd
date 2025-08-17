extends Area2D

@export var speed: float = 400.0
var direction: int = 1

@onready var sprite: AnimatedSprite2D = $AnimatedSprite2D

func _ready() -> void:
	# set arah sprite
	sprite.flip_h = (direction < 0)
	sprite.play("default")  # pastikan animasi selalu jalan

func _physics_process(delta: float) -> void:
	position.x += speed * direction * delta
