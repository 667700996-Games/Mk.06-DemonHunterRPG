class_name RiftProjectile
extends Node2D

var active := false
var enemy_owned := false
var velocity := Vector2.ZERO
var damage := 1.0
var radius := 7.0
var remaining := 1.0
var penetration := 1
var element := "physical"
var critical := false
var context: Dictionary = {}
var hit_ids: Dictionary = {}
var trail: Array[Vector2] = []
var initial_life := 1.0
var boomeranged := false

func activate(origin: Vector2, direction: Vector2, spec: Dictionary, from_enemy := false) -> void:
	global_position = origin
	enemy_owned = from_enemy
	damage = float(spec.get("damage", 10.0))
	radius = float(spec.get("radius", 7.0))
	remaining = float(spec.get("life", 1.5))
	initial_life = remaining
	penetration = int(spec.get("penetration", 1))
	element = spec.get("element", "physical")
	critical = bool(spec.get("critical", false))
	velocity = direction.normalized() * float(spec.get("speed", 700.0))
	context = spec.duplicate(true)
	context["direction"] = direction.normalized()
	boomeranged = false
	hit_ids.clear()
	trail.clear()
	active = true
	visible = true
	queue_redraw()

func deactivate() -> void:
	active = false
	visible = false
	hit_ids.clear()
	trail.clear()

func simulate(delta: float) -> bool:
	if not active: return false
	remaining -= delta
	if context.get("effects", {}).has("boomerang") and not boomeranged and remaining < initial_life * 0.48:
		boomeranged = true
		velocity = -velocity
		hit_ids.clear()
	trail.push_front(global_position)
	if trail.size() > 5: trail.pop_back()
	global_position += velocity * delta
	rotation = velocity.angle()
	queue_redraw()
	return remaining > 0.0 and global_position.length() < 3600.0

func register_hit(instance_id: int) -> bool:
	if hit_ids.has(instance_id): return false
	hit_ids[instance_id] = true
	penetration -= 1
	if penetration <= 0: deactivate()
	return true

func _draw() -> void:
	if not active: return
	var color: Color = RiftEnemy.ELEMENT_COLORS.get(element, Color.WHITE)
	if enemy_owned: color = color.lerp(Color("#ff335f"), 0.45)
	# Crisp spearhead plus bloom, rotated by node transform.
	draw_circle(Vector2.ZERO, radius * 1.8, Color(color, 0.12))
	draw_colored_polygon(PackedVector2Array([Vector2(radius * 1.9, 0), Vector2(-radius, -radius * 0.72), Vector2(-radius * 0.5, 0), Vector2(-radius, radius * 0.72)]), color)
	draw_rect(Rect2(-radius * 0.3, -2, radius * 1.4, 4), Color.WHITE if critical else color.lightened(0.35))
