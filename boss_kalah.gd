
extends Node2D
@onready var jatuh: AnimationPlayer = $jatuh

func _ready() -> void:
	await jatuh.animation_finished   # menunggu anim apa pun selesai
	get_tree().change_scene_to_file("res://scene/main menu.tscn")
