class_name ViewMath
extends RefCounted
## Painted stone base per art (measured on rift-structures.png alpha; both teams agree within 0.02): x = half-width
## of the base as a share of art_rect width; y = height of the base's widest row, its ground centre, above the bottom
## of the art as a share of art_rect height. The sim position is that ground centre, so range rings, shadows, hits and
## collision all sit under the middle of the building.
const STRUCTURE_FOOTPRINT := {
	"turret": Vector2(0.41, 0.17), "nexus_turret": Vector2(0.41, 0.17),
	"inhibitor": Vector2(0.43, 0.24), "nexus": Vector2(0.46, 0.20),
}
const CRYSTAL_ROW := 0.746 # crystal height above the bottom of the art, as a share of art_rect height
## Sim (x, y) px  <->  3D (x*S, h, y*S) metres. Sim +y (south, toward the camera) is 3D +Z.
## "Art px" are 2D screen-up offsets authored against 56 px heroes; they become metres along the camera's
## card-up vector U (camera basis Y), scaled by UNIT_SCALE (or STRUCTURE_SCALE / FX_SCALE).

static func to3(v: Vector2, h_m: float = 0.0) -> Vector3:
	return Vector3(v.x * ViewConfig.S, h_m, v.y * ViewConfig.S)

static func to2(p: Vector3) -> Vector2:
	return Vector2(p.x, p.z) / ViewConfig.S

static func art_m(art_px: float, scale: float = ViewConfig.UNIT_SCALE) -> float:
	return art_px * ViewConfig.S * scale

static func card_up(cam: Camera3D) -> Vector3:
	return cam.global_basis.y.normalized()

static func lifted(feet: Vector2, art_px: float, up: Vector3, scale: float = ViewConfig.UNIT_SCALE) -> Vector3:
	return to3(feet) + up * art_m(art_px, scale)

static func ground_hit(cam: Camera3D, screen: Vector2) -> Variant:
	return Plane(Vector3.UP, 0.0).intersects_ray(cam.project_ray_origin(screen), cam.project_ray_normal(screen))

static func screen_angle(cam: Camera3D, at: Vector3, dir: Vector2) -> float:
	# On-screen angle (radians, screen y down) of a sim-plane direction starting at a 3D point.
	var a := cam.unproject_position(at)
	var b := cam.unproject_position(at + Vector3(dir.x, 0.0, dir.y).normalized() * 0.5)
	return (b - a).angle()

static func card_basis(cam: Camera3D, screen_rot: float) -> Basis:
	# Camera-facing card rotated in the image plane: local +X points along screen angle screen_rot.
	var b := cam.global_basis
	var x := b.x * cos(screen_rot) - b.y * sin(screen_rot)
	var y := b.x * sin(screen_rot) + b.y * cos(screen_rot)
	return Basis(x, y, b.z)


## Height of a structure's crystal above its sim point in art px.
static func crystal_lift_px(rect: Rect2) -> float:
	return rect.size.y * CRYSTAL_ROW - rect.end.y
