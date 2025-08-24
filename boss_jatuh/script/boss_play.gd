extends Node2D
@onready var animasi_jatuh: AnimationPlayer = $animasi_jatuh


# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	pass

# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	pass


func _on_check_area_body_entered(body: Node2D) -> void:
	if body.is_in_group("player"):
		print("aku kaya")
		animasi_jatuh.play("jatuh")
		await get_tree().create_timer(5.5).timeout
		animasi_jatuh.play("fade_in")
		await get_tree().create_timer(1).timeout
		get_tree().change_scene_to_file("res://boss_room/scene/boss_room.tscn")
	else :
		pass
