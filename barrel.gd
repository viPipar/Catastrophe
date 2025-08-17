extends Area2D

var dead = false;
var health = 10
var is_hit = false

func _ready() -> void:
	pass
	
func _process(delta: float) -> void:
	if dead == false :
		if is_hit == false :
			$AnimatedSprite2D.play("on_idle")
		


func _on_barrel_area_entered(area: Area2D) -> void:
	if area.is_in_group("sword") :
		$AnimatedSprite2D.play("on_hit")
		is_hit = true
		health -=1
		
	if health <= 0 :
		dead = true
		$AnimatedSprite2D.play("on_destroy") 
		

func _on_animated_sprite_2d_animation_finished() -> void:
	print("Animasi selesai: ", $AnimatedSprite2D.animation)
	if $AnimatedSprite2D.animation == "on_destroy":
		queue_free()
	
	if $AnimatedSprite2D.animation == "on_hit":
		is_hit = false
