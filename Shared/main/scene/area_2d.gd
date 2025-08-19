extends Area2D

@onready var fader: AnimationPlayer = $"../main_character/Camera2D2/Faderlayer/AnimationPlayer"
@export var next_scene_path: String = "res://Shared/main/scene/Castle.tscn"
var _used := false  # biar gak ke-trigger berkali-kali

func _on_body_entered(body: Node2D) -> void:
	if _used: return
	if body.is_in_group("player"):
		_used = true
		if fader:
			fader.play("fade_in")
			await fader.animation_finished
			get_tree().change_scene_to_file(next_scene_path)
