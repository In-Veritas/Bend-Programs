import Base
import ./model3d.bend as Model3D
import ./light.bend as Light

# Types
# =====

type PositiveDistance:
  NoDistance{}
  HasDistance{distance: U32}

type Hit:
  Miss{}
  Hit{distance: U32, opacity: U32}

type Sphere:
  Sphere{center: Model3D.Vec3, radius: U32, opacity: U32}

type PlaneY:
  PlaneY{height: Model3D.Scalar, opacity: U32}

type Triangle:
  Triangle{a: Model3D.Vec3, b: Model3D.Vec3, c: Model3D.Vec3, opacity: U32}

type Primitive:
  SpherePrimitive{sphere: Sphere}
  PlanePrimitive{plane: PlaneY}
  TrianglePrimitive{triangle: Triangle}

type Scene:
  Scene{primitives: List<Primitive>}

type TraceSample:
  TraceSample{visibility: Light.Visibility, distance: U32}

# Constants
# =========

# No hidden scene is installed. A caller supplies every traced primitive.

# Functions
# =========

assert raytrace_u32_func:
  forall value: Nat
  U32

def raytrace_u32_func(value):
  U32.from_nat(value)

assert raytrace_u32_pair_func:
  forall value: U32
  U32 & U32

def raytrace_u32_pair_func(value):
  ((left, left_exact), (right, right_exact)) = U32.copy(value)
  (left, right)

assert raytrace_u32_triple_func:
  forall value: U32
  U32 & (U32 & U32)

def raytrace_u32_triple_func(value):
  (first, rest) = raytrace_u32_pair_func(value)
  (second, third) = raytrace_u32_pair_func(rest)
  (first, (second, third))

# Sixteen trial bits cover the square root of every U32. The structural Nat
# fuel makes termination structurally evident to the checker.
assert raytrace_u32_sqrt_bits_func:
  forall fuel: Nat
  forall value: U32
  forall root: U32
  forall bit: U32
  U32

def raytrace_u32_sqrt_bits_func(fuel, value, root, bit):
  match fuel:
    case 0n:
      root
    case 1n+pred:
      (value_test, value_next) = raytrace_u32_pair_func(value)
      (root_candidate, root_keep) = raytrace_u32_pair_func(root)
      (bit_candidate, bit_next) = raytrace_u32_pair_func(bit)
      (candidate_left, (candidate_right, candidate_keep)) = raytrace_u32_triple_func(
        U32.or(root_candidate, bit_candidate)
      )
      match U32.is_le(U32.mul(candidate_left, candidate_right), value_test):
        case True{}:
          raytrace_u32_sqrt_bits_func(
            pred,
            value_next,
            candidate_keep,
            U32.shr(bit_next)
          )
        case False{}:
          raytrace_u32_sqrt_bits_func(
            pred,
            value_next,
            root_keep,
            U32.shr(bit_next)
          )

assert raytrace_u32_sqrt_func:
  forall value: U32
  U32

def raytrace_u32_sqrt_func(value):
  raytrace_u32_sqrt_bits_func(
    16n,
    value,
    0,
    U32.shln(15n, 1)
  )

assert raytrace_scalar_copy_func:
  forall value: Model3D.Scalar
  Model3D.Scalar & Model3D.Scalar

def raytrace_scalar_copy_func(value):
  Model3D.model3d_scalar_copy_func(value)

assert raytrace_scalar_triple_func:
  forall value: Model3D.Scalar
  Model3D.Scalar & (Model3D.Scalar & Model3D.Scalar)

def raytrace_scalar_triple_func(value):
  (first, rest) = raytrace_scalar_copy_func(value)
  (second, third) = raytrace_scalar_copy_func(rest)
  (first, (second, third))

assert raytrace_scalar_negative_func:
  forall magnitude: U32
  Model3D.Scalar

def raytrace_scalar_negative_func(magnitude):
  (test, keep) = raytrace_u32_pair_func(magnitude)
  match U32.is_zero(test):
    case True{}:
      Model3D.ScalarPos{0}
    case False{}:
      Model3D.ScalarNeg{keep}

assert raytrace_scalar_div_func:
  forall left: Model3D.Scalar
  forall right: Model3D.Scalar
  Model3D.Scalar

def raytrace_scalar_div_func(left, right):
  match left right:
    case Model3D.ScalarNeg{a} Model3D.ScalarNeg{b}:
      Model3D.ScalarPos{U32.div(U32.shln(8n, a), b)}
    case Model3D.ScalarNeg{a} Model3D.ScalarPos{b}:
      raytrace_scalar_negative_func(U32.div(U32.shln(8n, a), b))
    case Model3D.ScalarPos{a} Model3D.ScalarNeg{b}:
      raytrace_scalar_negative_func(U32.div(U32.shln(8n, a), b))
    case Model3D.ScalarPos{a} Model3D.ScalarPos{b}:
      Model3D.ScalarPos{U32.div(U32.shln(8n, a), b)}

assert raytrace_scalar_square_func:
  forall value: Model3D.Scalar
  Model3D.Scalar

def raytrace_scalar_square_func(value):
  (left, right) = raytrace_scalar_copy_func(value)
  Model3D.model3d_scalar_mul_func(left, right)

assert raytrace_scalar_sqrt_func:
  forall value: Model3D.Scalar
  Model3D.Scalar

def raytrace_scalar_sqrt_func(value):
  match value:
    case Model3D.ScalarNeg{magnitude}:
      Model3D.ScalarPos{0}
    case Model3D.ScalarPos{magnitude}:
      Model3D.ScalarPos{raytrace_u32_sqrt_func(U32.shln(8n, magnitude))}

assert raytrace_positive_distance_func:
  forall value: Model3D.Scalar
  PositiveDistance

def raytrace_positive_distance_func(value):
  match value:
    case Model3D.ScalarNeg{magnitude}:
      NoDistance{}
    case Model3D.ScalarPos{magnitude}:
      (test, keep) = raytrace_u32_pair_func(magnitude)
      match U32.is_zero(test):
        case True{}:
          NoDistance{}
        case False{}:
          HasDistance{keep}

assert raytrace_vec3_triple_func:
  forall value: Model3D.Vec3
  Model3D.Vec3 & (Model3D.Vec3 & Model3D.Vec3)

def raytrace_vec3_triple_func(value):
  (first, rest) = Model3D.model3d_vec3_copy_func(value)
  (second, third) = Model3D.model3d_vec3_copy_func(rest)
  (first, (second, third))

assert raytrace_vec3_cross_func:
  forall left: Model3D.Vec3
  forall right: Model3D.Vec3
  Model3D.Vec3

def raytrace_vec3_cross_func(left, right):
  match left right:
    case Model3D.Vec3{lx, ly, lz} Model3D.Vec3{rx, ry, rz}:
      (lx_first, lx_second) = raytrace_scalar_copy_func(lx)
      (ly_first, ly_second) = raytrace_scalar_copy_func(ly)
      (lz_first, lz_second) = raytrace_scalar_copy_func(lz)
      (rx_first, rx_second) = raytrace_scalar_copy_func(rx)
      (ry_first, ry_second) = raytrace_scalar_copy_func(ry)
      (rz_first, rz_second) = raytrace_scalar_copy_func(rz)
      Model3D.Vec3{
        Model3D.model3d_scalar_sub_func(
          Model3D.model3d_scalar_mul_func(ly_first, rz_first),
          Model3D.model3d_scalar_mul_func(lz_first, ry_first)
        ),
        Model3D.model3d_scalar_sub_func(
          Model3D.model3d_scalar_mul_func(lz_second, rx_first),
          Model3D.model3d_scalar_mul_func(lx_first, rz_second)
        ),
        Model3D.model3d_scalar_sub_func(
          Model3D.model3d_scalar_mul_func(lx_second, ry_second),
          Model3D.model3d_scalar_mul_func(ly_second, rx_second)
        )
      }

assert raytrace_scalar_in_unit_interval_func:
  forall value: Model3D.Scalar
  Bool

def raytrace_scalar_in_unit_interval_func(value):
  match value:
    case Model3D.ScalarNeg{magnitude}:
      False{}
    case Model3D.ScalarPos{magnitude}:
      U32.is_le(magnitude, raytrace_u32_func(256n))

assert raytrace_query_copy_func:
  forall query: Light.RayQuery
  Light.RayQuery & Light.RayQuery

def raytrace_query_copy_func(query):
  match query:
    case Light.RayQuery{origin, direction, min_distance, max_distance}:
      (origin_left, origin_right) = Model3D.model3d_vec3_copy_func(origin)
      (direction_left, direction_right) = Model3D.model3d_vec3_copy_func(direction)
      (min_left, min_right) = raytrace_u32_pair_func(min_distance)
      (max_left, max_right) = raytrace_u32_pair_func(max_distance)
      (
        Light.RayQuery{origin_left, direction_left, min_left, max_left},
        Light.RayQuery{origin_right, direction_right, min_right, max_right}
      )

assert raytrace_hit_nearest_func:
  forall left: Hit
  forall right: Hit
  Hit

def raytrace_hit_nearest_func(left, right):
  match left right:
    case Miss{} Miss{}:
      Miss{}
    case Miss{} Hit{distance, opacity}:
      Hit{distance, opacity}
    case Hit{distance, opacity} Miss{}:
      Hit{distance, opacity}
    case Hit{left_distance, left_opacity} Hit{right_distance, right_opacity}:
      (left_test, left_keep) = raytrace_u32_pair_func(left_distance)
      (right_test, right_keep) = raytrace_u32_pair_func(right_distance)
      match U32.is_le(left_test, right_test):
        case True{}:
          Hit{left_keep, left_opacity}
        case False{}:
          Hit{right_keep, right_opacity}

assert raytrace_nearest_positive_func:
  forall near: Model3D.Scalar
  forall far: Model3D.Scalar
  forall opacity: U32
  Hit

def raytrace_nearest_positive_func(near, far, opacity):
  match raytrace_positive_distance_func(near) raytrace_positive_distance_func(far):
    case NoDistance{} NoDistance{}:
      Miss{}
    case NoDistance{} HasDistance{distance}:
      Hit{distance, opacity}
    case HasDistance{distance} NoDistance{}:
      Hit{distance, opacity}
    case HasDistance{left} HasDistance{right}:
      (left_test, left_keep) = raytrace_u32_pair_func(left)
      (right_test, right_keep) = raytrace_u32_pair_func(right)
      match U32.is_le(left_test, right_test):
        case True{}:
          Hit{left_keep, opacity}
        case False{}:
          Hit{right_keep, opacity}

assert raytrace_range_filter_func:
  forall hit: Hit
  forall min_distance: U32
  forall max_distance: U32
  Hit

def raytrace_range_filter_func(hit, min_distance, max_distance):
  match hit:
    case Miss{}:
      Miss{}
    case Hit{distance, opacity}:
      match
        raytrace_u32_triple_func(distance)
        raytrace_u32_pair_func(min_distance)
        raytrace_u32_pair_func(max_distance):
        case
          (distance_min, (distance_max, distance_keep))
          (min_test, min_keep)
          (max_test, max_keep):
          match U32.is_le(min_test, distance_min):
            case False{}:
              Miss{}
            case True{}:
              match U32.is_le(distance_max, max_test):
                case False{}:
                  Miss{}
                case True{}:
                  Hit{distance_keep, opacity}

assert raytrace_sphere_roots_func:
  forall origin: Model3D.Vec3
  forall direction: Model3D.Vec3
  forall center: Model3D.Vec3
  forall radius: U32
  forall opacity: U32
  Hit

def raytrace_sphere_roots_func(origin, direction, center, radius, opacity):
  match
    raytrace_vec3_triple_func(Model3D.model3d_vec3_sub_func(origin, center))
    raytrace_vec3_triple_func(direction):
    case
      (offset_half, (offset_len_left, offset_len_right))
      (direction_half, (direction_len_left, direction_len_right)):
      match
        raytrace_scalar_copy_func(Model3D.model3d_vec3_dot_func(offset_half, direction_half))
        raytrace_scalar_copy_func(
          Model3D.model3d_vec3_dot_func(direction_len_left, direction_len_right)
        ):
        case (half_b_square, half_b_roots) (a_discriminant, a_roots):
          match Model3D.model3d_scalar_sub_func(
            raytrace_scalar_square_func(half_b_square),
            Model3D.model3d_scalar_mul_func(
              a_discriminant,
              Model3D.model3d_scalar_sub_func(
                Model3D.model3d_vec3_dot_func(offset_len_left, offset_len_right),
                raytrace_scalar_square_func(Model3D.ScalarPos{radius})
              )
            )
          ):
            case Model3D.ScalarNeg{magnitude}:
              Miss{}
            case Model3D.ScalarPos{magnitude}:
              match
                raytrace_scalar_copy_func(half_b_roots)
                raytrace_scalar_copy_func(a_roots)
                raytrace_scalar_copy_func(
                  raytrace_scalar_sqrt_func(Model3D.ScalarPos{magnitude})
                ):
                case
                  (half_b_near, half_b_far)
                  (a_near, a_far)
                  (root_near, root_far):
                  raytrace_nearest_positive_func(
                    raytrace_scalar_div_func(
                      Model3D.model3d_scalar_sub_func(
                        Model3D.model3d_scalar_negate_func(half_b_near),
                        root_near
                      ),
                      a_near
                    ),
                    raytrace_scalar_div_func(
                      Model3D.model3d_scalar_add_func(
                        Model3D.model3d_scalar_negate_func(half_b_far),
                        root_far
                      ),
                      a_far
                    ),
                    opacity
                  )

assert raytrace_sphere_hit_func:
  forall query: Light.RayQuery
  forall sphere: Sphere
  Hit

def raytrace_sphere_hit_func(query, sphere):
  match query sphere:
    case Light.RayQuery{origin, direction, min_distance, max_distance} Sphere{center, radius, opacity}:
      raytrace_range_filter_func(
        raytrace_sphere_roots_func(origin, direction, center, radius, opacity),
        min_distance,
        max_distance
      )

assert raytrace_plane_core_func:
  forall origin: Model3D.Vec3
  forall direction: Model3D.Vec3
  forall height: Model3D.Scalar
  forall opacity: U32
  Hit

def raytrace_plane_core_func(origin, direction, height, opacity):
  match origin direction:
    case Model3D.Vec3{origin_x, origin_y, origin_z} Model3D.Vec3{direction_x, direction_y, direction_z}:
      match raytrace_positive_distance_func(
        raytrace_scalar_div_func(
          Model3D.model3d_scalar_sub_func(height, origin_y),
          direction_y
        )
      ):
        case NoDistance{}:
          Miss{}
        case HasDistance{distance}:
          Hit{distance, opacity}

assert raytrace_plane_hit_func:
  forall query: Light.RayQuery
  forall plane: PlaneY
  Hit

def raytrace_plane_hit_func(query, plane):
  match query plane:
    case Light.RayQuery{origin, direction, min_distance, max_distance} PlaneY{height, opacity}:
      raytrace_range_filter_func(
        raytrace_plane_core_func(origin, direction, height, opacity),
        min_distance,
        max_distance
      )

assert raytrace_triangle_from_vertices_func:
  forall first: Model3D.Vertex
  forall second: Model3D.Vertex
  forall third: Model3D.Vertex
  forall opacity: U32
  Triangle

def raytrace_triangle_from_vertices_func(first, second, third, opacity):
  match first second third:
    case
      Model3D.Vertex{a, first_normal, first_uv}
      Model3D.Vertex{b, second_normal, second_uv}
      Model3D.Vertex{c, third_normal, third_uv}:
      Triangle{a, b, c, opacity}

assert raytrace_triangle_distance_func:
  forall distance: Model3D.Scalar
  forall min_distance: U32
  forall max_distance: U32
  forall opacity: U32
  Hit

def raytrace_triangle_distance_func(distance, min_distance, max_distance, opacity):
  match raytrace_positive_distance_func(distance):
    case NoDistance{}:
      Miss{}
    case HasDistance{positive}:
      raytrace_range_filter_func(
        Hit{positive, opacity},
        min_distance,
        max_distance
      )

assert raytrace_triangle_barycentric_func:
  forall u: Model3D.Scalar
  forall v: Model3D.Scalar
  forall distance: Model3D.Scalar
  forall min_distance: U32
  forall max_distance: U32
  forall opacity: U32
  Hit

def raytrace_triangle_barycentric_func(u, v, distance, min_distance, max_distance, opacity):
  match raytrace_scalar_copy_func(u) raytrace_scalar_copy_func(v):
    case (u_check, u_sum) (v_check, v_sum):
      match Bool.and(
        raytrace_scalar_in_unit_interval_func(u_check),
        raytrace_scalar_in_unit_interval_func(v_check)
      ):
        case False{}:
          Miss{}
        case True{}:
          match raytrace_scalar_in_unit_interval_func(
            Model3D.model3d_scalar_add_func(u_sum, v_sum)
          ):
            case False{}:
              Miss{}
            case True{}:
              raytrace_triangle_distance_func(
                distance,
                min_distance,
                max_distance,
                opacity
              )

assert raytrace_triangle_nonzero_determinant_func:
  forall direction: Model3D.Vec3
  forall edge_one: Model3D.Vec3
  forall edge_two: Model3D.Vec3
  forall offset_for_u: Model3D.Vec3
  forall offset_for_q: Model3D.Vec3
  forall h_for_u: Model3D.Vec3
  forall determinant: Model3D.Scalar
  forall min_distance: U32
  forall max_distance: U32
  forall opacity: U32
  Hit

def raytrace_triangle_nonzero_determinant_func(direction, edge_one, edge_two, offset_for_u, offset_for_q, h_for_u, determinant, min_distance, max_distance, opacity):
  match
    raytrace_scalar_triple_func(
      raytrace_scalar_div_func(Model3D.ScalarPos{raytrace_u32_func(256n)}, determinant)
    )
    Model3D.model3d_vec3_copy_func(raytrace_vec3_cross_func(offset_for_q, edge_one)):
    case
      (inverse_u, (inverse_v, inverse_distance))
      (q_for_v, q_for_distance):
      raytrace_triangle_barycentric_func(
        Model3D.model3d_scalar_mul_func(
          inverse_u,
          Model3D.model3d_vec3_dot_func(offset_for_u, h_for_u)
        ),
        Model3D.model3d_scalar_mul_func(
          inverse_v,
          Model3D.model3d_vec3_dot_func(direction, q_for_v)
        ),
        Model3D.model3d_scalar_mul_func(
          inverse_distance,
          Model3D.model3d_vec3_dot_func(edge_two, q_for_distance)
        ),
        min_distance,
        max_distance,
        opacity
      )

assert raytrace_triangle_determinant_test_func:
  forall determinant_test: Model3D.Scalar
  forall determinant_keep: Model3D.Scalar
  forall direction: Model3D.Vec3
  forall edge_one_for_q: Model3D.Vec3
  forall edge_two: Model3D.Vec3
  forall offset_for_u: Model3D.Vec3
  forall offset_for_q: Model3D.Vec3
  forall h_for_u: Model3D.Vec3
  forall min_distance: U32
  forall max_distance: U32
  forall opacity: U32
  Hit

def raytrace_triangle_determinant_test_func(determinant_test, determinant_keep, direction, edge_one_for_q, edge_two, offset_for_u, offset_for_q, h_for_u, min_distance, max_distance, opacity):
  match determinant_test:
    case Model3D.ScalarNeg{magnitude}:
      match U32.is_zero(magnitude):
        case True{}:
          Miss{}
        case False{}:
          raytrace_triangle_nonzero_determinant_func(
            direction,
            edge_one_for_q,
            edge_two,
            offset_for_u,
            offset_for_q,
            h_for_u,
            determinant_keep,
            min_distance,
            max_distance,
            opacity
          )
    case Model3D.ScalarPos{magnitude}:
      match U32.is_zero(magnitude):
        case True{}:
          Miss{}
        case False{}:
          raytrace_triangle_nonzero_determinant_func(
            direction,
            edge_one_for_q,
            edge_two,
            offset_for_u,
            offset_for_q,
            h_for_u,
            determinant_keep,
            min_distance,
            max_distance,
            opacity
          )

assert raytrace_triangle_determinant_func:
  forall direction: Model3D.Vec3
  forall edge_one_for_q: Model3D.Vec3
  forall edge_two: Model3D.Vec3
  forall offset_for_u: Model3D.Vec3
  forall offset_for_q: Model3D.Vec3
  forall h_for_u: Model3D.Vec3
  forall determinant: Model3D.Scalar
  forall min_distance: U32
  forall max_distance: U32
  forall opacity: U32
  Hit

def raytrace_triangle_determinant_func(direction, edge_one_for_q, edge_two, offset_for_u, offset_for_q, h_for_u, determinant, min_distance, max_distance, opacity):
  match raytrace_scalar_copy_func(determinant):
    case (determinant_test, determinant_keep):
      raytrace_triangle_determinant_test_func(
        determinant_test,
        determinant_keep,
        direction,
        edge_one_for_q,
        edge_two,
        offset_for_u,
        offset_for_q,
        h_for_u,
        min_distance,
        max_distance,
        opacity
      )

assert raytrace_triangle_h_func:
  forall direction: Model3D.Vec3
  forall edge_one_for_det: Model3D.Vec3
  forall edge_one_for_q: Model3D.Vec3
  forall edge_two: Model3D.Vec3
  forall offset_for_u: Model3D.Vec3
  forall offset_for_q: Model3D.Vec3
  forall h: Model3D.Vec3
  forall min_distance: U32
  forall max_distance: U32
  forall opacity: U32
  Hit

def raytrace_triangle_h_func(direction, edge_one_for_det, edge_one_for_q, edge_two, offset_for_u, offset_for_q, h, min_distance, max_distance, opacity):
  match Model3D.model3d_vec3_copy_func(h):
    case (h_for_det, h_for_u):
      raytrace_triangle_determinant_func(
        direction,
        edge_one_for_q,
        edge_two,
        offset_for_u,
        offset_for_q,
        h_for_u,
        Model3D.model3d_vec3_dot_func(edge_one_for_det, h_for_det),
        min_distance,
        max_distance,
        opacity
      )

assert raytrace_triangle_edges_func:
  forall origin: Model3D.Vec3
  forall direction_for_h: Model3D.Vec3
  forall direction_for_v: Model3D.Vec3
  forall edge_one: Model3D.Vec3
  forall edge_two: Model3D.Vec3
  forall a_for_offset: Model3D.Vec3
  forall min_distance: U32
  forall max_distance: U32
  forall opacity: U32
  Hit

def raytrace_triangle_edges_func(origin, direction_for_h, direction_for_v, edge_one, edge_two, a_for_offset, min_distance, max_distance, opacity):
  match
    Model3D.model3d_vec3_copy_func(edge_one)
    Model3D.model3d_vec3_copy_func(edge_two)
    Model3D.model3d_vec3_copy_func(Model3D.model3d_vec3_sub_func(origin, a_for_offset)):
    case
      (edge_one_for_det, edge_one_for_q)
      (edge_two_for_h, edge_two_for_distance)
      (offset_for_u, offset_for_q):
      raytrace_triangle_h_func(
        direction_for_v,
        edge_one_for_det,
        edge_one_for_q,
        edge_two_for_distance,
        offset_for_u,
        offset_for_q,
        raytrace_vec3_cross_func(direction_for_h, edge_two_for_h),
        min_distance,
        max_distance,
        opacity
      )

assert raytrace_triangle_core_func:
  forall origin: Model3D.Vec3
  forall direction: Model3D.Vec3
  forall a: Model3D.Vec3
  forall b: Model3D.Vec3
  forall c: Model3D.Vec3
  forall min_distance: U32
  forall max_distance: U32
  forall opacity: U32
  Hit

def raytrace_triangle_core_func(origin, direction, a, b, c, min_distance, max_distance, opacity):
  match
    raytrace_vec3_triple_func(a)
    Model3D.model3d_vec3_copy_func(direction):
    case
      (a_for_edge_one, (a_for_edge_two, a_for_offset))
      (direction_for_h, direction_for_v):
      raytrace_triangle_edges_func(
        origin,
        direction_for_h,
        direction_for_v,
        Model3D.model3d_vec3_sub_func(b, a_for_edge_one),
        Model3D.model3d_vec3_sub_func(c, a_for_edge_two),
        a_for_offset,
        min_distance,
        max_distance,
        opacity
      )

assert raytrace_triangle_hit_func:
  forall query: Light.RayQuery
  forall triangle: Triangle
  Hit

def raytrace_triangle_hit_func(query, triangle):
  match query triangle:
    case
      Light.RayQuery{origin, direction, min_distance, max_distance}
      Triangle{a, b, c, opacity}:
      raytrace_triangle_core_func(
        origin,
        direction,
        a,
        b,
        c,
        min_distance,
        max_distance,
        opacity
      )

assert raytrace_primitive_hit_func:
  forall query: Light.RayQuery
  forall primitive: Primitive
  Hit

def raytrace_primitive_hit_func(query, primitive):
  match primitive:
    case SpherePrimitive{sphere}:
      raytrace_sphere_hit_func(query, sphere)
    case PlanePrimitive{plane}:
      raytrace_plane_hit_func(query, plane)
    case TrianglePrimitive{triangle}:
      raytrace_triangle_hit_func(query, triangle)

assert raytrace_scene_hit_func:
  forall primitives: List<Primitive>
  forall query: Light.RayQuery
  Hit

def raytrace_scene_hit_func(primitives, query):
  match primitives:
    case Nil{}:
      Miss{}
    case Con{primitive, tail}:
      match raytrace_query_copy_func(query):
        case (query_here, query_tail):
          raytrace_hit_nearest_func(
            raytrace_primitive_hit_func(query_here, primitive),
            raytrace_scene_hit_func(tail, query_tail)
          )

assert raytrace_scene_visibility_func:
  forall query: Light.RayQuery
  forall primitives: List<Primitive>
  Light.Visibility

def raytrace_scene_visibility_func(query, primitives):
  match raytrace_scene_hit_func(primitives, query):
    case Miss{}:
      Light.ClearVisibility{}
    case Hit{distance, opacity}:
      Light.OccludedVisibility{opacity}

assert raytrace_scene_sample_func:
  forall query: Light.RayQuery
  forall primitives: List<Primitive>
  TraceSample

def raytrace_scene_sample_func(query, primitives):
  match raytrace_scene_hit_func(primitives, query):
    case Miss{}:
      TraceSample{Light.ClearVisibility{}, 0}
    case Hit{distance, opacity}:
      TraceSample{Light.OccludedVisibility{opacity}, distance}

# Universal theorem over every ray origin, direction, and distance interval:
# tracing an empty scene can never manufacture an occluder.
assert raytrace_empty_scene_clear_theorem_func:
  forall query: Light.RayQuery
  { raytrace_scene_visibility_func(query, Nil{}) == Light.ClearVisibility{} : Light.Visibility }

def raytrace_empty_scene_clear_theorem_func(query):
  {==}

# Universal algebraic theorem: a miss is the identity of nearest-hit choice.
assert raytrace_miss_left_identity_theorem_func:
  forall hit: Hit
  { raytrace_hit_nearest_func(Miss{}, hit) == hit : Hit }

def raytrace_miss_left_identity_theorem_func(hit):
  match hit:
    case Miss{}:
      {==}
    case Hit{distance, opacity}:
      {==}

# Closed front-sphere reference certificate. It is a regression fixture, not
# a claim about every sphere or every floating/fixed-point ray configuration.
assert raytrace_front_sphere_certificate_func:
  { raytrace_sphere_hit_func( Light.RayQuery{ Model3D.Vec3{ Model3D.ScalarPos{0}, Model3D.ScalarPos{0}, Model3D.ScalarPos{0} }, Model3D.Vec3{ Model3D.ScalarPos{raytrace_u32_func(256n)}, Model3D.ScalarPos{0}, Model3D.ScalarPos{0} }, raytrace_u32_func(1n), raytrace_u32_func(2048n) }, Sphere{ Model3D.Vec3{ Model3D.ScalarPos{raytrace_u32_func(512n)}, Model3D.ScalarPos{0}, Model3D.ScalarPos{0} }, raytrace_u32_func(256n), raytrace_u32_func(220n) } ) == Hit{raytrace_u32_func(256n), raytrace_u32_func(220n)} : Hit }

def raytrace_front_sphere_certificate_func():
  {==}

assert raytrace_reference_triangle_query_func:
  forall forward: Bool
  Light.RayQuery

def raytrace_reference_triangle_query_func(forward):
  match forward:
    case False{}:
      Light.RayQuery{
        Model3D.Vec3{
          Model3D.ScalarPos{0},
          Model3D.ScalarPos{0},
          Model3D.ScalarPos{0}
        },
        Model3D.Vec3{
          Model3D.ScalarNeg{raytrace_u32_func(256n)},
          Model3D.ScalarPos{0},
          Model3D.ScalarPos{0}
        },
        raytrace_u32_func(1n),
        raytrace_u32_func(2048n)
      }
    case True{}:
      Light.RayQuery{
        Model3D.Vec3{
          Model3D.ScalarPos{0},
          Model3D.ScalarPos{0},
          Model3D.ScalarPos{0}
        },
        Model3D.Vec3{
          Model3D.ScalarPos{raytrace_u32_func(256n)},
          Model3D.ScalarPos{0},
          Model3D.ScalarPos{0}
        },
        raytrace_u32_func(1n),
        raytrace_u32_func(2048n)
      }

assert raytrace_reference_triangle_func:
  forall marker: U32
  Triangle

def raytrace_reference_triangle_func(marker):
  Triangle{
    Model3D.Vec3{
      Model3D.ScalarPos{raytrace_u32_func(512n)},
      Model3D.ScalarNeg{raytrace_u32_func(256n)},
      Model3D.ScalarNeg{raytrace_u32_func(256n)}
    },
    Model3D.Vec3{
      Model3D.ScalarPos{raytrace_u32_func(512n)},
      Model3D.ScalarPos{raytrace_u32_func(256n)},
      Model3D.ScalarNeg{raytrace_u32_func(256n)}
    },
    Model3D.Vec3{
      Model3D.ScalarPos{raytrace_u32_func(512n)},
      Model3D.ScalarPos{0},
      Model3D.ScalarPos{raytrace_u32_func(256n)}
    },
    raytrace_u32_func(180n)
  }

assert raytrace_triangle_hit_certificate_func:
  { raytrace_triangle_hit_func( raytrace_reference_triangle_query_func(True{}), raytrace_reference_triangle_func(0) ) == Hit{raytrace_u32_func(512n), raytrace_u32_func(180n)} : Hit }

def raytrace_triangle_hit_certificate_func():
  {==}

assert raytrace_triangle_miss_certificate_func:
  { raytrace_triangle_hit_func( raytrace_reference_triangle_query_func(False{}), raytrace_reference_triangle_func(0) ) == Miss{} : Hit }

def raytrace_triangle_miss_certificate_func():
  {==}

# Universal theorem over every magnitude: the tracer's forward-distance gate
# rejects negative parameters before any scene-specific range decision.
assert raytrace_negative_distance_rejected_theorem_func:
  forall magnitude: U32
  { raytrace_positive_distance_func(Model3D.ScalarNeg{magnitude}) == NoDistance{} : PositiveDistance }

def raytrace_negative_distance_rejected_theorem_func(magnitude):
  {==}

assert raytrace_verification_consume_func:
  forall -empty_clear: @query: Light.RayQuery -> { raytrace_scene_visibility_func(query, Nil{}) == Light.ClearVisibility{} : Light.Visibility }
  forall -miss_identity: @hit: Hit -> { raytrace_hit_nearest_func(Miss{}, hit) == hit : Hit }
  forall -negative_distance: @magnitude: U32 -> { raytrace_positive_distance_func(Model3D.ScalarNeg{magnitude}) == NoDistance{} : PositiveDistance }
  forall -front_sphere: { raytrace_sphere_hit_func( Light.RayQuery{ Model3D.Vec3{ Model3D.ScalarPos{0}, Model3D.ScalarPos{0}, Model3D.ScalarPos{0} }, Model3D.Vec3{ Model3D.ScalarPos{raytrace_u32_func(256n)}, Model3D.ScalarPos{0}, Model3D.ScalarPos{0} }, raytrace_u32_func(1n), raytrace_u32_func(2048n) }, Sphere{ Model3D.Vec3{ Model3D.ScalarPos{raytrace_u32_func(512n)}, Model3D.ScalarPos{0}, Model3D.ScalarPos{0} }, raytrace_u32_func(256n), raytrace_u32_func(220n) } ) == Hit{raytrace_u32_func(256n), raytrace_u32_func(220n)} : Hit }
  forall -triangle_hit: { raytrace_triangle_hit_func( raytrace_reference_triangle_query_func(True{}), raytrace_reference_triangle_func(0) ) == Hit{raytrace_u32_func(512n), raytrace_u32_func(180n)} : Hit }
  forall -triangle_miss: { raytrace_triangle_hit_func( raytrace_reference_triangle_query_func(False{}), raytrace_reference_triangle_func(0) ) == Miss{} : Hit }
  Bool

def raytrace_verification_consume_func(empty_clear, miss_identity, negative_distance, front_sphere, triangle_hit, triangle_miss):
  True{}

assert raytrace_verification_func:
  Bool

def raytrace_verification_func():
  raytrace_verification_consume_func(
    raytrace_empty_scene_clear_theorem_func,
    raytrace_miss_left_identity_theorem_func,
    raytrace_negative_distance_rejected_theorem_func,
    raytrace_front_sphere_certificate_func(),
    raytrace_triangle_hit_certificate_func(),
    raytrace_triangle_miss_certificate_func()
  )
