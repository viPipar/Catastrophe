extends ParallaxLayer


@export var speed: float = -200.0  # pixels per second

func _process(delta: float) -> void:
	motion_offset.y += speed * delta
