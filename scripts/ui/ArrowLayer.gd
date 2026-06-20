extends Control
## 拖动卡牌时绘制从卡牌到鼠标位置的指向箭头，本身不接收输入。
class_name ArrowLayer

var active: bool = false
var start_position: Vector2 = Vector2.ZERO
var end_position: Vector2 = Vector2.ZERO


func begin_arrow(start_global: Vector2, end_global: Vector2) -> void:
	active = true
	start_position = start_global
	end_position = end_global
	queue_redraw()


func update_arrow(end_global: Vector2) -> void:
	end_position = end_global
	queue_redraw()


func end_arrow() -> void:
	active = false
	queue_redraw()


func _draw() -> void:
	if not active:
		return

	var inverse_transform := get_global_transform_with_canvas().affine_inverse()
	var local_start: Vector2 = inverse_transform * start_position
	var local_end: Vector2 = inverse_transform * end_position
	var control_lift: float = clampf(local_start.distance_to(local_end) * 0.22, 54.0, 140.0)
	var control: Vector2 = (local_start + local_end) * 0.5 + Vector2(0.0, -control_lift)

	var points := PackedVector2Array()
	var segments: int = 20
	for i in segments + 1:
		var t: float = float(i) / float(segments)
		var a: Vector2 = local_start.lerp(control, t)
		var b: Vector2 = control.lerp(local_end, t)
		points.append(a.lerp(b, t))

	draw_polyline(points, Color(0.18, 0.55, 0.95), 6.0, true)

	var head_t: float = 0.94
	var head_a: Vector2 = local_start.lerp(control, head_t)
	var head_b: Vector2 = control.lerp(local_end, head_t)
	var head_from: Vector2 = head_a.lerp(head_b, head_t)
	var direction := (local_end - head_from).normalized()
	if direction == Vector2.ZERO:
		return
	var side := Vector2(-direction.y, direction.x)
	var tip_a := local_end - direction * 24.0 + side * 12.0
	var tip_b := local_end - direction * 24.0 - side * 12.0
	draw_polygon(
		PackedVector2Array([local_end, tip_a, tip_b]),
		PackedColorArray([Color(0.18, 0.55, 0.95)])
	)
