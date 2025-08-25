extends Node2D


# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	pass

# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	pass


func _on_check_area_body_entered(body: Node2D) -> void:
	if body.is_in_group("player"):
		$animasi_jatuh.play("jatuh")
		await $animasi_jatuh.animation_finished
		$animasi_jatuh.play("fade_in")
		await $animasi_jatuh.animation_finished
		get_tree().change_scene_to_file("res://boss_room/scene/boss_room.tscn")
	else :
		pass
