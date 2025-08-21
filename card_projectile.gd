extends Area2D

@export var speed: float = 500.0
var direction: int = 1

func _ready() -> void:
	# pastikan animasi jalan
	if has_node("AnimatedSprite2D"):
		var spr: AnimatedSprite2D = $AnimatedSprite2D
		if spr.sprite_frames.has_animation("default"):
			spr.play("default")

	# connect sinyal tabrakan (kalau belum dihubungkan di editor)
	if has_signal("body_entered"):
		connect("body_entered", Callable(self, "_on_body_entered"))

func _process(delta: float) -> void:
	# gerak horizontal sesuai arah
	position.x += direction * speed * delta

	# auto hancur kalau terlalu jauh (biar gak numpuk di scene)
	if global_position.x < -3000 or global_position.x > 3000:
		queue_free()

func _on_body_entered(body: Node) -> void:
	# kalau kena enemy, kasih damage dan hancur
	if body.is_in_group("enemy"):
		if body.has_method("take_damage"):
			body.take_damage(5) # contoh damage 5
		queue_free()

	# kalau kena tembok atau tilemap → hancur juga
	if body.is_in_group("wall") or body.is_in_group("obstacle"):
		queue_free()
