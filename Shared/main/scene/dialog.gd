extends Area2D


@export var SURFACE = load("res://surface.dialogue")
var _used := false  # biar gak ke-trigger berkali-kali

func _on_body_entered(body: Node2D) -> void:
	if _used: return
	if body.is_in_group("player"):
		_used = true
		DialogueManager.show_dialogue_balloon(SURFACE, "start")
		if body.has_method("freeze"):
			body.freeze("freeze_zone")
	# 3) Tunggu sampai dialog yang SE-RESOURCE ini selesai
		while true:
			var res = await DialogueManager.dialogue_ended
			if res == SURFACE:
				break

		if is_instance_valid(body) and body.has_method("unfreeze"):
			body.unfreeze()


func _on_body_exited(body: Node2D) -> void:
	if body.is_in_group("Player"):
		if body.has_method("unfreeze"):
			body.unfreeze()
