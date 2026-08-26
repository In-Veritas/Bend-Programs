import Base
import ../../compat/list.bend as List

# Types
# =====

# Signed Q24.8 scalar. Magnitudes are raw fixed-point units.
type Scalar:
  ScalarPos{magnitude: U32}
  ScalarNeg{magnitude: U32}

type Vec2:
  Vec2{x: Scalar, y: Scalar}

type Vec3:
  Vec3{x: Scalar, y: Scalar, z: Scalar}

type Color:
  Color{red: U32, green: U32, blue: U32}

# Textures remain pure values. Sampling is deterministic and backend-neutral.
type Texture:
  SolidTexture{color: Color}
  CheckerTexture{first: Color, second: Color, scale: U32}
  FacetTexture{low: Color, high: Color, stride: U32}
  NoiseTexture{low: Color, high: Color, seed: U32, grain: U32}

# Every optical/fiber channel is 0..255 by convention. The library preserves
# the authored channel values; consumers choose whether and how to clamp them.
type Material:
  Material{
    texture: Texture,
    roughness: U32,
    metallic: U32,
    reflection: U32,
    fuzz: U32,
    fur_length: U32,
    fur_density: U32
  }

type Vertex:
  Vertex{position: Vec3, normal: Vec3, uv: Vec2}

# Counter-clockwise indexed triangle. material_slot permits mixed meshes.
type Facet:
  Facet{a: U32, b: U32, c: U32, material_slot: U32}

type Quad:
  Quad{
    a: U32,
    b_first: U32,
    b_second: U32,
    c_first: U32,
    c_second: U32,
    d: U32,
    material_slot: U32
  }

# A strand is anchored to an actual vertex and carries independent length,
# curl, and tint. A renderer can expand it into camera-facing ribbons/tubes.
type FurStrand:
  FurStrand{root_vertex: U32, length: U32, curl: U32, tint: Color}

type Mesh:
  Mesh{
    vertices: List<Vertex>,
    facets: List<Facet>,
    fur: List<FurStrand>,
    material: Material
  }

type MeshStats:
  MeshStats{vertices: Nat, facets: Nat, strands: Nat}

# Constants
# =========

# There are no closed runtime globals. Callers choose seeds and model inputs.

# Functions
# =========

assert model3d_u32_func:
  forall value: Nat
  U32

def model3d_u32_func(value):
  U32.from_nat(value)

assert model3d_u32_pair_func:
  forall value: U32
  U32 & U32

def model3d_u32_pair_func(value):
  ((left, left_exact), (right, right_exact)) = U32.copy(value)
  (left, right)

assert model3d_u32_triple_func:
  forall value: U32
  U32 & (U32 & U32)

def model3d_u32_triple_func(value):
  (first, rest) = model3d_u32_pair_func(value)
  (second, third) = model3d_u32_pair_func(rest)
  (first, (second, third))

assert model3d_u32_four_func:
  forall value: U32
  U32 & (U32 & (U32 & U32))

def model3d_u32_four_func(value):
  (first, rest) = model3d_u32_pair_func(value)
  (second, tail) = model3d_u32_pair_func(rest)
  (third, fourth) = model3d_u32_pair_func(tail)
  (first, (second, (third, fourth)))

assert model3d_scalar_zero_func:
  Scalar

def model3d_scalar_zero_func():
  ScalarPos{0}

assert model3d_scalar_copy_func:
  forall value: Scalar
  Scalar & Scalar

def model3d_scalar_copy_func(value):
  match value:
    case ScalarPos{magnitude}:
      (left, right) = model3d_u32_pair_func(magnitude)
      (ScalarPos{left}, ScalarPos{right})
    case ScalarNeg{magnitude}:
      (left, right) = model3d_u32_pair_func(magnitude)
      (ScalarNeg{left}, ScalarNeg{right})

assert model3d_scalar_negate_func:
  forall value: Scalar
  Scalar

def model3d_scalar_negate_func(value):
  match value:
    case ScalarPos{magnitude}:
      ScalarNeg{magnitude}
    case ScalarNeg{magnitude}:
      ScalarPos{magnitude}

assert model3d_scalar_difference_func:
  forall positive: U32
  forall negative: U32
  Scalar

def model3d_scalar_difference_func(positive, negative):
  (test_positive, keep_positive) = model3d_u32_pair_func(positive)
  (test_negative, keep_negative) = model3d_u32_pair_func(negative)
  match U32.is_ge(test_positive, test_negative):
    case True{}:
      ScalarPos{U32.sub(keep_positive, keep_negative)}
    case False{}:
      ScalarNeg{U32.sub(keep_negative, keep_positive)}

assert model3d_scalar_add_func:
  forall left: Scalar
  forall right: Scalar
  Scalar

def model3d_scalar_add_func(left, right):
  match left right:
    case ScalarPos{a} ScalarPos{b}:
      ScalarPos{U32.add(a, b)}
    case ScalarPos{a} ScalarNeg{b}:
      model3d_scalar_difference_func(a, b)
    case ScalarNeg{a} ScalarPos{b}:
      model3d_scalar_difference_func(b, a)
    case ScalarNeg{a} ScalarNeg{b}:
      ScalarNeg{U32.add(a, b)}

assert model3d_scalar_sub_func:
  forall left: Scalar
  forall right: Scalar
  Scalar

def model3d_scalar_sub_func(left, right):
  model3d_scalar_add_func(left, model3d_scalar_negate_func(right))

assert model3d_scalar_mul_func:
  forall left: Scalar
  forall right: Scalar
  Scalar

def model3d_scalar_mul_func(left, right):
  match left right:
    case ScalarPos{a} ScalarPos{b}:
      ScalarPos{U32.shrn(8n, U32.mul(a, b))}
    case ScalarPos{a} ScalarNeg{b}:
      ScalarNeg{U32.shrn(8n, U32.mul(a, b))}
    case ScalarNeg{a} ScalarPos{b}:
      ScalarNeg{U32.shrn(8n, U32.mul(a, b))}
    case ScalarNeg{a} ScalarNeg{b}:
      ScalarPos{U32.shrn(8n, U32.mul(a, b))}

assert model3d_scalar_scale_raw_func:
  forall value: Scalar
  forall scale: U32
  Scalar

def model3d_scalar_scale_raw_func(value, scale):
  match value:
    case ScalarPos{magnitude}:
      ScalarPos{U32.shrn(8n, U32.mul(magnitude, scale))}
    case ScalarNeg{magnitude}:
      ScalarNeg{U32.shrn(8n, U32.mul(magnitude, scale))}

assert model3d_vec2_copy_func:
  forall value: Vec2
  Vec2 & Vec2

def model3d_vec2_copy_func(value):
  match value:
    case Vec2{x, y}:
      (x1, x2) = model3d_scalar_copy_func(x)
      (y1, y2) = model3d_scalar_copy_func(y)
      (Vec2{x1, y1}, Vec2{x2, y2})

assert model3d_vec3_copy_func:
  forall value: Vec3
  Vec3 & Vec3

def model3d_vec3_copy_func(value):
  match value:
    case Vec3{x, y, z}:
      (x1, x2) = model3d_scalar_copy_func(x)
      (y1, y2) = model3d_scalar_copy_func(y)
      (z1, z2) = model3d_scalar_copy_func(z)
      (Vec3{x1, y1, z1}, Vec3{x2, y2, z2})

assert model3d_vec3_add_func:
  forall left: Vec3
  forall right: Vec3
  Vec3

def model3d_vec3_add_func(left, right):
  match left right:
    case Vec3{lx, ly, lz} Vec3{rx, ry, rz}:
      Vec3{
        model3d_scalar_add_func(lx, rx),
        model3d_scalar_add_func(ly, ry),
        model3d_scalar_add_func(lz, rz)
      }

assert model3d_vec3_sub_func:
  forall left: Vec3
  forall right: Vec3
  Vec3

def model3d_vec3_sub_func(left, right):
  match left right:
    case Vec3{lx, ly, lz} Vec3{rx, ry, rz}:
      Vec3{
        model3d_scalar_sub_func(lx, rx),
        model3d_scalar_sub_func(ly, ry),
        model3d_scalar_sub_func(lz, rz)
      }

assert model3d_vec3_scale_func:
  forall value: Vec3
  forall scale: Scalar
  Vec3

def model3d_vec3_scale_func(value, scale):
  match value:
    case Vec3{x, y, z}:
      (first, rest) = model3d_scalar_copy_func(scale)
      (second, third) = model3d_scalar_copy_func(rest)
      Vec3{
        model3d_scalar_mul_func(x, first),
        model3d_scalar_mul_func(y, second),
        model3d_scalar_mul_func(z, third)
      }

assert model3d_vec3_dot_func:
  forall left: Vec3
  forall right: Vec3
  Scalar

def model3d_vec3_dot_func(left, right):
  match left right:
    case Vec3{lx, ly, lz} Vec3{rx, ry, rz}:
      model3d_scalar_add_func(
        model3d_scalar_mul_func(lx, rx),
        model3d_scalar_add_func(
          model3d_scalar_mul_func(ly, ry),
          model3d_scalar_mul_func(lz, rz)
        )
      )

assert model3d_vec3_reflect_finish_func:
  forall incident: Vec3
  forall normal: Vec3
  forall dot: Scalar
  Vec3

def model3d_vec3_reflect_finish_func(incident, normal, dot):
  (dot_left, dot_right) = model3d_scalar_copy_func(dot)
  model3d_vec3_sub_func(
    incident,
    model3d_vec3_scale_func(
      normal,
      model3d_scalar_add_func(dot_left, dot_right)
    )
  )

assert model3d_vec3_reflect_func:
  forall incident: Vec3
  forall normal: Vec3
  Vec3

def model3d_vec3_reflect_func(incident, normal):
  (normal_for_dot, normal_for_scale) = model3d_vec3_copy_func(normal)
  (incident_for_dot, incident_for_sub) = model3d_vec3_copy_func(incident)
  model3d_vec3_reflect_finish_func(
    incident_for_sub,
    normal_for_scale,
    model3d_vec3_dot_func(incident_for_dot, normal_for_dot)
  )

assert model3d_vec3_reflect_axis_x_func:
  forall value: Vec3
  Vec3

def model3d_vec3_reflect_axis_x_func(value):
  match value:
    case Vec3{x, y, z}:
      Vec3{model3d_scalar_negate_func(x), y, z}

assert model3d_color_copy_func:
  forall value: Color
  Color & Color

def model3d_color_copy_func(value):
  match value:
    case Color{red, green, blue}:
      (r1, r2) = model3d_u32_pair_func(red)
      (g1, g2) = model3d_u32_pair_func(green)
      (b1, b2) = model3d_u32_pair_func(blue)
      (Color{r1, g1, b1}, Color{r2, g2, b2})

assert model3d_color_scale_func:
  forall value: Color
  forall amount: U32
  Color

def model3d_color_scale_func(value, amount):
  match value:
    case Color{red, green, blue}:
      (a1, (a2, a3)) = model3d_u32_triple_func(amount)
      Color{
        U32.div(U32.mul(red, a1), model3d_u32_func(255n)),
        U32.div(U32.mul(green, a2), model3d_u32_func(255n)),
        U32.div(U32.mul(blue, a3), model3d_u32_func(255n))
      }

assert model3d_checker_uv_func:
  forall u: Scalar
  forall v: Scalar
  forall first: Color
  forall second: Color
  forall scale: U32
  Color

def model3d_checker_uv_func(u, v, first, second, scale):
  match u v:
    case ScalarNeg{um} ScalarNeg{vm}:
      match U32.to_nat(U32.mod(U32.add(U32.div(um, scale), U32.div(vm, model3d_u32_func(32n))), model3d_u32_func(2n))):
        case 0n: first
        case 1n+pred: second
    case ScalarNeg{um} ScalarPos{vm}:
      match U32.to_nat(U32.mod(U32.add(U32.div(um, scale), U32.div(vm, model3d_u32_func(32n))), model3d_u32_func(2n))):
        case 0n: first
        case 1n+pred: second
    case ScalarPos{um} ScalarNeg{vm}:
      match U32.to_nat(U32.mod(U32.add(U32.div(um, scale), U32.div(vm, model3d_u32_func(32n))), model3d_u32_func(2n))):
        case 0n: first
        case 1n+pred: second
    case ScalarPos{um} ScalarPos{vm}:
      match U32.to_nat(U32.mod(U32.add(U32.div(um, scale), U32.div(vm, model3d_u32_func(32n))), model3d_u32_func(2n))):
        case 0n: first
        case 1n+pred: second

assert model3d_noise_uv_func:
  forall u: Scalar
  forall v: Scalar
  forall low: Color
  forall high: Color
  forall seed: U32
  forall grain: U32
  Color

def model3d_noise_uv_func(u, v, low, high, seed, grain):
  match u v:
    case ScalarNeg{um} ScalarNeg{vm}:
      match U32.to_nat(U32.mod(U32.xor(seed, U32.add(U32.mul(um, model3d_u32_func(17n)), U32.mul(vm, grain))), model3d_u32_func(2n))):
        case 0n: low
        case 1n+pred: high
    case ScalarNeg{um} ScalarPos{vm}:
      match U32.to_nat(U32.mod(U32.xor(seed, U32.add(U32.mul(um, model3d_u32_func(17n)), U32.mul(vm, grain))), model3d_u32_func(2n))):
        case 0n: low
        case 1n+pred: high
    case ScalarPos{um} ScalarNeg{vm}:
      match U32.to_nat(U32.mod(U32.xor(seed, U32.add(U32.mul(um, model3d_u32_func(17n)), U32.mul(vm, grain))), model3d_u32_func(2n))):
        case 0n: low
        case 1n+pred: high
    case ScalarPos{um} ScalarPos{vm}:
      match U32.to_nat(U32.mod(U32.xor(seed, U32.add(U32.mul(um, model3d_u32_func(17n)), U32.mul(vm, grain))), model3d_u32_func(2n))):
        case 0n: low
        case 1n+pred: high

assert model3d_texture_sample_func:
  forall texture: Texture
  forall uv: Vec2
  forall facet_id: U32
  Color

def model3d_texture_sample_func(texture, uv, facet_id):
  match texture:
    case SolidTexture{color}:
      color
    case CheckerTexture{first, second, scale}:
      match uv:
        case Vec2{u, v}:
          model3d_checker_uv_func(u, v, first, second, scale)
    case FacetTexture{low, high, stride}:
      match U32.to_nat(U32.mod(U32.div(facet_id, stride), model3d_u32_func(2n))):
        case 0n: low
        case 1n+pred: high
    case NoiseTexture{low, high, seed, grain}:
      match uv:
        case Vec2{u, v}:
          model3d_noise_uv_func(u, v, low, high, seed, grain)

assert model3d_ring_radius_func:
  forall ring: U32
  U32

def model3d_ring_radius_func(ring):
  match U32.to_nat(U32.mod(ring, model3d_u32_func(13n))):
    case 0n: model3d_u32_func(40n)
    case 1n+rest1:
      match rest1:
        case 0n: model3d_u32_func(80n)
        case 1n+rest2:
          match rest2:
            case 0n: model3d_u32_func(128n)
            case 1n+rest3:
              match rest3:
                case 0n: model3d_u32_func(180n)
                case 1n+rest4:
                  match rest4:
                    case 0n: model3d_u32_func(220n)
                    case 1n+rest5:
                      match rest5:
                        case 0n: model3d_u32_func(245n)
                        case 1n+rest6:
                          match rest6:
                            case 0n: model3d_u32_func(256n)
                            case 1n+rest7:
                              match rest7:
                                case 0n: model3d_u32_func(245n)
                                case 1n+rest8:
                                  match rest8:
                                    case 0n: model3d_u32_func(220n)
                                    case 1n+rest9:
                                      match rest9:
                                        case 0n: model3d_u32_func(180n)
                                        case 1n+rest10:
                                          match rest10:
                                            case 0n: model3d_u32_func(128n)
                                            case 1n+rest11:
                                              match rest11:
                                                case 0n: model3d_u32_func(80n)
                                                case 1n+rest12: model3d_u32_func(40n)

assert model3d_direction_func:
  forall segment: U32
  Vec2

def model3d_direction_func(segment):
  match U32.to_nat(U32.mod(segment, model3d_u32_func(8n))):
    case 0n:
      Vec2{ScalarPos{model3d_u32_func(256n)}, ScalarPos{0}}
    case 1n+rest1:
      match rest1:
        case 0n:
          Vec2{ScalarPos{model3d_u32_func(181n)}, ScalarPos{model3d_u32_func(181n)}}
        case 1n+rest2:
          match rest2:
            case 0n:
              Vec2{ScalarPos{0}, ScalarPos{model3d_u32_func(256n)}}
            case 1n+rest3:
              match rest3:
                case 0n:
                  Vec2{ScalarNeg{model3d_u32_func(181n)}, ScalarPos{model3d_u32_func(181n)}}
                case 1n+rest4:
                  match rest4:
                    case 0n:
                      Vec2{ScalarNeg{model3d_u32_func(256n)}, ScalarPos{0}}
                    case 1n+rest5:
                      match rest5:
                        case 0n:
                          Vec2{ScalarNeg{model3d_u32_func(181n)}, ScalarNeg{model3d_u32_func(181n)}}
                        case 1n+rest6:
                          match rest6:
                            case 0n:
                              Vec2{ScalarPos{0}, ScalarNeg{model3d_u32_func(256n)}}
                            case 1n+rest7:
                              Vec2{ScalarPos{model3d_u32_func(181n)}, ScalarNeg{model3d_u32_func(181n)}}

assert model3d_ring_normal_y_func:
  forall ring: U32
  Scalar

def model3d_ring_normal_y_func(ring):
  (test, keep) = model3d_u32_pair_func(ring)
  match U32.is_le(test, model3d_u32_func(6n)):
    case True{}:
      ScalarNeg{U32.mul(U32.sub(model3d_u32_func(6n), keep), model3d_u32_func(32n))}
    case False{}:
      ScalarPos{U32.mul(U32.sub(keep, model3d_u32_func(6n)), model3d_u32_func(32n))}

assert model3d_ring_vertex_finish_func:
  forall segment_direction: U32
  forall ring_radius: U32
  forall ring_height: U32
  forall ring_normal: U32
  forall segment_uv: U32
  forall ring_uv: U32
  Vertex

def model3d_ring_vertex_finish_func(segment_direction, ring_radius, ring_height, ring_normal, segment_uv, ring_uv):
  match
    model3d_vec2_copy_func(model3d_direction_func(segment_direction))
    model3d_u32_pair_func(model3d_ring_radius_func(ring_radius)):
    case
      (Vec2{position_x, position_z}, Vec2{normal_x, normal_z})
      (radius_x, radius_z):
      Vertex{
        Vec3{
          model3d_scalar_scale_raw_func(position_x, radius_x),
          ScalarPos{U32.mul(ring_height, model3d_u32_func(48n))},
          model3d_scalar_scale_raw_func(position_z, radius_z)
        },
        Vec3{normal_x, model3d_ring_normal_y_func(ring_normal), normal_z},
        Vec2{
          ScalarPos{U32.mul(segment_uv, model3d_u32_func(32n))},
          ScalarPos{U32.mul(ring_uv, model3d_u32_func(20n))}
        }
      }

assert model3d_ring_vertex_func:
  forall index: U32
  Vertex

def model3d_ring_vertex_func(index):
  match model3d_u32_pair_func(index):
    case (for_ring, for_segment):
      match
        model3d_u32_four_func(U32.div(for_ring, model3d_u32_func(8n)))
        model3d_u32_pair_func(U32.mod(for_segment, model3d_u32_func(8n))):
        case
          (ring_radius, (ring_height, (ring_normal, ring_uv)))
          (segment_direction, segment_uv):
          model3d_ring_vertex_finish_func(
            segment_direction,
            ring_radius,
            ring_height,
            ring_normal,
            segment_uv,
            ring_uv
          )

assert model3d_indices_func:
  forall fuel: Nat
  forall index: U32
  List<U32>

def model3d_indices_func(fuel, index):
  match fuel:
    case 0n:
      Nil{}
    case 1n+pred:
      (current, next) = model3d_u32_pair_func(index)
      Con{current, model3d_indices_func(pred, U32.inc(next))}

assert model3d_vertices_from_indices_func:
  forall indices: List<U32>
  List<Vertex>

def model3d_vertices_from_indices_func(indices):
  match indices:
    case Nil{}:
      Nil{}
    case Con{index, tail}:
      Con{model3d_ring_vertex_func(index), model3d_vertices_from_indices_func(tail)}

assert model3d_facet_flip_func:
  forall facet: Facet
  Facet

def model3d_facet_flip_func(facet):
  match facet:
    case Facet{a, b, c, material_slot}:
      Facet{a, c, b, material_slot}

assert model3d_next_segment_func:
  forall segment: U32
  U32

def model3d_next_segment_func(segment):
  match U32.to_nat(U32.mod(U32.inc(segment), model3d_u32_func(8n))):
    case 0n:
      0
    case 1n+pred:
      U32.inc(U32.from_nat(pred))

assert model3d_quad_finish_func:
  forall a: U32
  forall b: U32
  forall c: U32
  forall d: U32
  Quad

def model3d_quad_finish_func(a, b, c, d):
  match model3d_u32_pair_func(b) model3d_u32_pair_func(c):
    case (b_first, b_second) (c_first, c_second):
      Quad{a, b_first, b_second, c_first, c_second, d, 0}

assert model3d_quad_func:
  forall base: U32
  forall segment: U32
  Quad

def model3d_quad_func(base, segment):
  (base_a, (base_b, (base_c, base_d))) = model3d_u32_four_func(base)
  (seg_a, (seg_c, seg_next)) = model3d_u32_triple_func(segment)
  match model3d_u32_pair_func(model3d_next_segment_func(seg_next)):
    case (next_b, next_d):
      model3d_quad_finish_func(
        U32.add(base_a, seg_a),
        U32.add(base_b, next_b),
        U32.add(U32.add(base_c, model3d_u32_func(8n)), seg_c),
        U32.add(U32.add(base_d, model3d_u32_func(8n)), next_d)
      )

assert model3d_ring_quads_func:
  forall fuel: Nat
  forall base: U32
  forall segment: U32
  List<Quad>

def model3d_ring_quads_func(fuel, base, segment):
  match fuel:
    case 0n:
      Nil{}
    case 1n+pred:
      (base_here, base_next) = model3d_u32_pair_func(base)
      (segment_here, segment_next) = model3d_u32_pair_func(segment)
      Con{
        model3d_quad_func(base_here, segment_here),
        model3d_ring_quads_func(pred, base_next, U32.inc(segment_next))
      }

assert model3d_facets_from_quads_func:
  forall quads: List<Quad>
  List<Facet>

def model3d_facets_from_quads_func(quads):
  match quads:
    case Nil{}:
      Nil{}
    case Con{Quad{a, b_first, b_second, c_first, c_second, d, material_slot}, tail}:
      Con{
        Facet{a, c_first, b_first, 0},
        Con{
          Facet{b_second, c_second, d, material_slot},
          model3d_facets_from_quads_func(tail)
        }
      }

assert model3d_ring_facets_func:
  forall fuel: Nat
  forall base: U32
  forall segment: U32
  List<Facet>

def model3d_ring_facets_func(fuel, base, segment):
  model3d_facets_from_quads_func(model3d_ring_quads_func(fuel, base, segment))

assert model3d_body_facets_func:
  forall fuel: Nat
  forall base: U32
  List<Facet>

def model3d_body_facets_func(fuel, base):
  match fuel:
    case 0n:
      Nil{}
    case 1n+pred:
      (base_here, base_next) = model3d_u32_pair_func(base)
      List.append(
        Facet,
        model3d_ring_facets_func(8n, base_here, 0),
        model3d_body_facets_func(pred, U32.add(base_next, model3d_u32_func(8n)))
      )

assert model3d_fur_root_func:
  forall strand: FurStrand
  U32

def model3d_fur_root_func(strand):
  match strand:
    case FurStrand{root_vertex, length, curl, tint}:
      root_vertex

# The generated strand is paired with mathematical evidence that its live root
# is exactly the caller-supplied vertex index. Strand shape remains explicit;
# material fuzz and fur controls add the per-surface variation at shading time.
assert model3d_fur_strand_certified_func:
  forall index: U32
  exists strand: FurStrand
  { model3d_fur_root_func(strand) == index : U32 }

def model3d_fur_strand_certified_func(index):
  (
    FurStrand{
      index,
      model3d_u32_func(32n),
      model3d_u32_func(13n),
      Color{model3d_u32_func(128n), model3d_u32_func(36n), model3d_u32_func(48n)}
    },
    {==}
  )

assert model3d_fur_strand_func:
  forall index: U32
  FurStrand

def model3d_fur_strand_func(index):
  (strand, root_exact) = model3d_fur_strand_certified_func(index)
  strand

assert model3d_fur_from_indices_func:
  forall indices: List<U32>
  List<FurStrand>

def model3d_fur_from_indices_func(indices):
  match indices:
    case Nil{}:
      Nil{}
    case Con{index, tail}:
      (strand, root_exact) = model3d_fur_strand_certified_func(index)
      Con{strand, model3d_fur_from_indices_func(tail)}

assert model3d_fur_root_indices_func:
  forall strands: List<FurStrand>
  List<U32>

def model3d_fur_root_indices_func(strands):
  match strands:
    case Nil{}:
      Nil{}
    case Con{strand, tail}:
      Con{model3d_fur_root_func(strand), model3d_fur_root_indices_func(tail)}

assert model3d_beet_mesh_func:
  forall seed: U32
  Mesh

def model3d_beet_mesh_func(seed):
  (texture_seed, sheen_seed) = model3d_u32_pair_func(seed)
  Mesh{
    model3d_vertices_from_indices_func(model3d_indices_func(104n, 0)),
    model3d_body_facets_func(12n, 0),
    model3d_fur_from_indices_func(model3d_indices_func(104n, 0)),
    Material{
      NoiseTexture{
        Color{model3d_u32_func(116n), model3d_u32_func(24n), model3d_u32_func(46n)},
        Color{model3d_u32_func(205n), model3d_u32_func(52n), model3d_u32_func(73n)},
        texture_seed,
        model3d_u32_func(29n)
      },
      model3d_u32_func(82n),
      model3d_u32_func(18n),
      U32.add(model3d_u32_func(80n), U32.mod(sheen_seed, model3d_u32_func(80n))),
      model3d_u32_func(35n),
      model3d_u32_func(40n),
      model3d_u32_func(104n)
    }
  }

assert model3d_mesh_stats_func:
  forall mesh: Mesh
  MeshStats

def model3d_mesh_stats_func(mesh):
  match mesh:
    case Mesh{vertices, facets, fur, material}:
      MeshStats{
        List.length(Vertex, vertices),
        List.length(Facet, facets),
        List.length(FurStrand, fur)
      }

# Mathematical theorem by constructor induction over every signed Q24.8 value.
assert model3d_scalar_negation_involution_theorem_func:
  forall value: Scalar
  { model3d_scalar_negate_func(model3d_scalar_negate_func(value)) == value : Scalar }

def model3d_scalar_negation_involution_theorem_func(value):
  match value:
    case ScalarPos{magnitude}:
      {==}
    case ScalarNeg{magnitude}:
      {==}

# Mathematical theorem over every indexed facet, independent of mesh size.
assert model3d_facet_flip_involution_theorem_func:
  forall facet: Facet
  { model3d_facet_flip_func(model3d_facet_flip_func(facet)) == facet : Facet }

def model3d_facet_flip_involution_theorem_func(facet):
  match facet:
    case Facet{a, b, c, material_slot}:
      {==}

# Structural induction: each arbitrary input index produces exactly one vertex.
assert model3d_vertices_cardinality_theorem_func:
  forall indices: List<U32>
  { List.length(Vertex, model3d_vertices_from_indices_func(indices)) == List.length(U32, indices) : Nat }

def model3d_vertices_cardinality_theorem_func(indices):
  match indices:
    case Nil{}:
      {==}
    case Con{index, tail}:
      %model3d_vertices_cardinality_theorem_func(tail) : {
        1n+List.length(Vertex, model3d_vertices_from_indices_func(tail)) == 1n+_
        : Nat
      }
      {==}

# Structural induction: every arbitrary fur anchor produces exactly one strand.
assert model3d_fur_cardinality_theorem_func:
  forall indices: List<U32>
  { List.length(FurStrand, model3d_fur_from_indices_func(indices)) == List.length(U32, indices) : Nat }

def model3d_fur_cardinality_theorem_func(indices):
  match indices:
    case Nil{}:
      {==}
    case Con{index, tail}:
      %model3d_fur_cardinality_theorem_func(tail) : {
        1n+List.length(FurStrand, model3d_fur_from_indices_func(tail)) == 1n+_
        : Nat
      }
      {==}

# Structural induction with the exact U32.copy witnesses from strand
# construction: generated fur preserves every caller-supplied anchor, in
# order, for an arbitrary index list.
assert model3d_fur_roots_preserved_theorem_func:
  forall indices: List<U32>
  { model3d_fur_root_indices_func(model3d_fur_from_indices_func(indices)) == indices : List<U32> }

def model3d_fur_roots_preserved_theorem_func(indices):
  match indices:
    case Nil{}:
      {==}
    case Con{index, tail}:
      Equal.cong(
        List<U32>,
        List<U32>,
        rest => Con{index, rest},
        model3d_fur_root_indices_func(model3d_fur_from_indices_func(tail)),
        tail,
        model3d_fur_roots_preserved_theorem_func(tail)
      )

# One induction establishes both generated-mesh facts together, so affine
# callers need not duplicate the arbitrary index list merely to combine laws.
assert model3d_generated_indices_well_formed_theorem_func:
  forall indices: List<U32>
  { List.length(Vertex, model3d_vertices_from_indices_func(indices)) == List.length(FurStrand, model3d_fur_from_indices_func(indices)) : Nat } & { model3d_fur_root_indices_func(model3d_fur_from_indices_func(indices)) == indices : List<U32> }

def model3d_generated_indices_well_formed_theorem_func(indices):
  match indices:
    case Nil{}:
      ({==}, {==})
    case Con{index, tail}:
      (tail_cardinality, tail_roots) = model3d_generated_indices_well_formed_theorem_func(tail)
      (
        Equal.cong(
          Nat,
          Nat,
          value => 1n+value,
          List.length(Vertex, model3d_vertices_from_indices_func(tail)),
          List.length(FurStrand, model3d_fur_from_indices_func(tail)),
          tail_cardinality
        ),
        Equal.cong(
          List<U32>,
          List<U32>,
          rest => Con{index, rest},
          model3d_fur_root_indices_func(model3d_fur_from_indices_func(tail)),
          tail,
          tail_roots
        )
      )

# Structural induction over arbitrary indexed quads. Every quad supplied to the
# actual mesh expansion function contributes exactly two triangle facets.
assert model3d_quad_expansion_cardinality_theorem_func:
  forall quads: List<Quad>
  { List.length(Facet, model3d_facets_from_quads_func(quads)) == Nat.double(List.length(Quad, quads)) : Nat }

def model3d_quad_expansion_cardinality_theorem_func(quads):
  match quads:
    case Nil{}:
      {==}
    case Con{Quad{a, b_first, b_second, c_first, c_second, d, material_slot}, tail}:
      %model3d_quad_expansion_cardinality_theorem_func(tail) : {
        2n+List.length(Facet, model3d_facets_from_quads_func(tail))
        == 2n+_ : Nat
      }
      {==}

# Closed reference normalization: useful as a regression certificate, not a
# mathematical theorem about all procedural textures.
assert model3d_checker_reference_certificate_func:
  { model3d_texture_sample_func( CheckerTexture{ Color{model3d_u32_func(12n), model3d_u32_func(34n), model3d_u32_func(56n)}, Color{model3d_u32_func(90n), model3d_u32_func(80n), model3d_u32_func(70n)}, model3d_u32_func(32n) }, Vec2{ScalarPos{model3d_u32_func(4n)}, ScalarPos{model3d_u32_func(8n)}}, 0 ) == Color{model3d_u32_func(12n), model3d_u32_func(34n), model3d_u32_func(56n)} : Color }

def model3d_checker_reference_certificate_func():
  {==}

assert model3d_verification_consume_func:
  forall -negation_involution: @value: Scalar -> { model3d_scalar_negate_func(model3d_scalar_negate_func(value)) == value : Scalar }
  forall -facet_flip_involution: @facet: Facet -> { model3d_facet_flip_func(model3d_facet_flip_func(facet)) == facet : Facet }
  forall -vertex_cardinality: @indices: List<U32> -> { List.length(Vertex, model3d_vertices_from_indices_func(indices)) == List.length(U32, indices) : Nat }
  forall -fur_cardinality: @indices: List<U32> -> { List.length(FurStrand, model3d_fur_from_indices_func(indices)) == List.length(U32, indices) : Nat }
  forall -fur_roots_preserved: @indices: List<U32> -> { model3d_fur_root_indices_func(model3d_fur_from_indices_func(indices)) == indices : List<U32> }
  forall -quad_expansion_cardinality: @quads: List<Quad> -> { List.length(Facet, model3d_facets_from_quads_func(quads)) == Nat.double(List.length(Quad, quads)) : Nat }
  forall -checker_reference: { model3d_texture_sample_func( CheckerTexture{ Color{model3d_u32_func(12n), model3d_u32_func(34n), model3d_u32_func(56n)}, Color{model3d_u32_func(90n), model3d_u32_func(80n), model3d_u32_func(70n)}, model3d_u32_func(32n) }, Vec2{ScalarPos{model3d_u32_func(4n)}, ScalarPos{model3d_u32_func(8n)}}, 0 ) == Color{model3d_u32_func(12n), model3d_u32_func(34n), model3d_u32_func(56n)} : Color }
  Bool

def model3d_verification_consume_func(negation_involution, facet_flip_involution, vertex_cardinality, fur_cardinality, fur_roots_preserved, quad_expansion_cardinality, checker_reference):
  True{}

assert model3d_verification_func:
  Bool

def model3d_verification_func():
  model3d_verification_consume_func(
    model3d_scalar_negation_involution_theorem_func,
    model3d_facet_flip_involution_theorem_func,
    model3d_vertices_cardinality_theorem_func,
    model3d_fur_cardinality_theorem_func,
    model3d_fur_roots_preserved_theorem_func,
    model3d_quad_expansion_cardinality_theorem_func,
    model3d_checker_reference_certificate_func()
  )
