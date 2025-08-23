extends Control


func _on_start_button_pressed() -> void:
	get_tree().change_scene_to_file("res://scene/nyoba_scene.tscn")


func _on_quit_button_pressed() -> void:
	get_tree().quit()


func _on_settings_button_pressed() -> void:
	$"Label Setting".visible = true
	$"Animation Player".play("fade_out")
