@tool
class_name ClearUndoRedoHistory
extends EditorScript

func _run() -> void:
	EditorInterface.get_editor_undo_redo().clear_history(EditorUndoRedoManager.INVALID_HISTORY)
