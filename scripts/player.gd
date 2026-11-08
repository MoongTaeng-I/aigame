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
    var horizontal := int(Input.is_key_pressed(KEY_RIGHT)) - int(Input.is_key_pressed(KEY_LEFT))
    var vertical := int(Input.is_key_pressed(KEY_DOWN)) - int(Input.is_key_pressed(KEY_UP))
    var direction := Vector2(horizontal, vertical)
    if direction != Vector2.ZERO:
        direction = direction.normalized()
    # move_and_collide stops this whole input vector on collision, so corner pressure never slides along a wall.
    move_and_collide(direction * move_speed * delta)

func _draw() -> void:
    draw_circle(Vector2.ZERO, body_radius, PLAYER_COLOR)
    draw_arc(Vector2.ZERO, body_radius, 0.0, TAU, 48, Color("#eee6ff"), 2.0)
