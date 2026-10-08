extends Button
## Shares a portrait-only alpha mask between unit clicks, card targeting, and target outlines.
class_name PortraitHitButton

static var _texture_masks: Dictionary = {}
var _alpha_mask: BitMap


## Caches the body's opaque bounds and fits the button to the actual displayed texture.
func setup_texture(texture: Texture2D, draw_rect: Rect2) -> void:
	if texture == null or draw_rect.size.x <= 0.0 or draw_rect.size.y <= 0.0:
		_alpha_mask = null
		size = Vector2.ZERO
		return
	if not _texture_masks.has(texture):
		var image: Image = texture.get_image()
		if image == null or image.is_empty():
			_alpha_mask = null
			return
		if image.is_compressed():
			image.decompress()
		var bounds: Rect2i = image.get_used_rect()
		if bounds.size.x <= 0 or bounds.size.y <= 0:
			_alpha_mask = null
			size = Vector2.ZERO
			return
		var mask: BitMap = BitMap.new()
		mask.create_from_image_alpha(image.get_region(bounds))
		_texture_masks[texture] = {"bounds": bounds, "mask": mask, "image_size": image.get_size()}
	var cached: Dictionary = _texture_masks[texture]
	var opaque_bounds: Rect2i = cached["bounds"]
	var image_size: Vector2i = cached["image_size"]
	_alpha_mask = cached["mask"] as BitMap
	var pixel_scale: Vector2 = draw_rect.size / Vector2(image_size)
	position = draw_rect.position + Vector2(opaque_bounds.position) * pixel_scale
	size = Vector2(opaque_bounds.size) * pixel_scale


## Rejects transparent pixels as well as everything outside the body-sized button.
func _has_point(point: Vector2) -> bool:
	if _alpha_mask == null or size.x <= 0.0 or size.y <= 0.0 or not Rect2(Vector2.ZERO, size).has_point(point):
		return false
	var pixel: Vector2i = Vector2i(point / size * Vector2(_alpha_mask.get_size()))
	return _alpha_mask.get_bitv(pixel)


## Uses the same mask for dragged cards and native button selection, including visual movement.
func contains_global_point(mouse_global_position: Vector2) -> bool:
	if disabled or not is_visible_in_tree():
		return false
	var local_point: Vector2 = get_global_transform_with_canvas().affine_inverse() * mouse_global_position
	return _has_point(local_point)
