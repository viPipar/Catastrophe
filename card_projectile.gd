extends Area2D

@export var speed: float = 900.0
@export var max_lifetime: float = 3.0  # detik sebelum hilang otomatis
var direction: int = 1

var lifetime_timer: float = 0.0  # internal timer


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
		# hitung lifetime
	lifetime_timer += delta
	if lifetime_timer >= max_lifetime:
		queue_free()
