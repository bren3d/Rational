@tool
class_name PrintUndoRedo
extends EditorScript

func _run() -> void:
	var ur: UndoRedo = EditorInterface.get_editor_undo_redo().get_history_undo_redo(EditorUndoRedoManager.GLOBAL_HISTORY)
	
	print("\n- - Global UndoRedo - -\n\tVersion: %d | Count: %d" % [ur.get_version(), ur.get_history_count()])
	print("\tIs Commiting: %s" % ur.is_committing_action())
	print("\tHas Undo: %s" % ur.has_undo())
	print("\tHas Redo: %s" % ur.has_redo())
	print("\tCurrent Action ID: %d" % ur.get_current_action())
	print("\tCurrent Action Name: %s" % ur.get_current_action_name())
	print("\n- - FULL ACTION LIST- -")
	for id: int in ur.get_history_count():
		print("\t#%d: %s" % [id, ur.get_action_name(id)])
	print("- - - - - - - - - -\n")
	
