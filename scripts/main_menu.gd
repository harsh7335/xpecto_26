extends Control
@onready var button_click: AudioStreamPlayer = $ButtonClick
func _on_play_pressed() -> void:
	button_click.play()
	await get_tree().create_timer(1).timeout
	get_tree().change_scene_to_file("res://scenes/level_01.tscn")


func _on_quit_pressed() -> void:
	button_click.play()
	await get_tree().create_timer(1).timeout
	get_tree().quit()
