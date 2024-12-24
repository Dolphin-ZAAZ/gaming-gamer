extends Node

class_name DataHelperClass

func save_to_file(file_name: String, data: Array) -> bool:
	var file_path = "res://data/" + file_name + ".dat"
	var file = FileAccess.open(file_path, FileAccess.WRITE)
	if file:
		file.store_var(data)
		file.close()
		return true
	else:
		return false

func load_from_file(file_name: String) -> Object:
	var file_path = "res://data/" + file_name + ".dat"
	var file = null
	var data = []
	if FileAccess.file_exists(file_path):
		file = FileAccess.open(file_path, FileAccess.READ)
		return file
	else:
		push_error(file_path + " - file not found")
	return data
