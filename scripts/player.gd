extends CharacterBody2D

const PLAYER_COLOR := Color("#b18cff")
var move_speed: float = 0.0
var body_radius: float = 18.0
var push_weight: float = 1.0

func configure_body(radius: float, weight: float) -> void:
    body_radius = radius
    push_weight = weight
    var collision_shape := get_node("CollisionShape2D") as CollisionShape2D
    var circle := collision_shape.shape as CircleShape2D
    circle.radius = body_radius
    queue_redraw()

func _ready() -> void:
    queue_redraw()

func _physics_process(delta: float) -> void:
    var direction := Vector2(
        Input.get_axis("move_left", "move_right"),
        Input.get_axis("move_up", "move_down")
    )
    if direction != Vector2.ZERO:
        direction = direction.normalized()
    # Resolve each axis independently so a blocked component does not cancel motion along the wall.
    move_and_collide(Vector2(direction.x * move_speed * delta, 0.0))
    move_and_collide(Vector2(0.0, direction.y * move_speed * delta))

func _draw() -> void:
    draw_circle(Vector2.ZERO, body_radius, PLAYER_COLOR)
    draw_arc(Vector2.ZERO, body_radius, 0.0, TAU, 48, Color("#eee6ff"), 2.0)
