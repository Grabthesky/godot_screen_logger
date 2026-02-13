@tool
extends EditorPlugin

func _enter_tree() -> void:
	# Registra el autoload para que esté disponible en toda la escena
	add_autoload_singleton("ScreenLog", "res://addons/screen_logger/screen_log.gd")

func _exit_tree() -> void:
	remove_autoload_singleton("ScreenLog")
