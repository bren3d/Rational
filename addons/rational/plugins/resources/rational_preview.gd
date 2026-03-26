@tool
extends EditorResourcePreviewGenerator

var previews: Dictionary[String, Image]

func init_preview(main_editor: Node) -> void:
	main_editor.graph_edit

func _handles(type: String) -> bool:
	return type == &"Resource"

func _can_generate_small_preview() -> bool:
	return false

func _generate_from_path(path: String, size: Vector2i, metadata: Dictionary) -> Texture2D:
	return null

func _generate(resource: Resource, size: Vector2i, metadata: Dictionary) -> Texture2D:
	if not resource is RationalComponent:
		return null
	
	
	
	return null
