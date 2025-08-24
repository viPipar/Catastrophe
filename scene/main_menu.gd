extends Control


func _on_start_button_pressed() -> void:
	get_tree().change_scene_to_file("res://Shared/main/scene/Surface.tscn")


func _on_quit_button_pressed() -> void:
	get_tree().quit()


func _on_credit_button_pressed() -> void:
	print("credit kang")
	$"Hidden Labels2".visible = true

func _on_how_to_play_button_pressed() -> void:
	print("haw tu pley")
	$"Hidden Labels".visible = true


func _on_exit_pressed() -> void:
	$"Hidden Labels".visible = false
	$"Hidden Labels2".visible = false	
