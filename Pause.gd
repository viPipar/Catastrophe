extends Control


# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	visible = false	
	
func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		_toggle_pause()
		
func _toggle_pause() -> void:
	if get_tree().paused:
		_resume_game()
	else:
		_pause_game()

func _pause_game() -> void:
	get_tree().paused = true
	visible = true
	process_mode = Node.PROCESS_MODE_ALWAYS

func _resume_game() -> void:
	get_tree().paused = false
	visible = false

# Called every frame. 'delta' is the elapsed time since the previous frame.	

func _on_resume_button_pressed() -> void:
	if get_tree().paused:
		_resume_game()


func _on_exit_pressed() -> void:
	if get_tree().paused:
		_resume_game()

func _on_how_to_play_button_pressed() -> void:
	$"Hidden Labels".visible = true


func _on_main_menu_button_pressed() -> void:
	get_tree().paused = false
	Engine.time_scale = 1.0
	GameState.reset_all()  # bersihin state run + overwrite save
	get_tree().change_scene_to_file("res://scene/main menu.tscn")


func _on_exit_how_to_play_pressed() -> void:
	$"Hidden Labels".visible = false
