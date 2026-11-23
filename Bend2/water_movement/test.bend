# Headless checks for main.bend: runs the pure step functions (no window)
# and prints a summary per engine/container plus PASS/FAIL lines.
#
#   bend test.bend -o /tmp/water_test && /tmp/water_test
import Base
import ./main.bend as M

# Summaries
# =========

type Sum is Data:
  Sum{total: F32, peak: F32, bad: U32}

def T.pick(c: Bool, a: F32, b: F32) -> F32:
  match c:
    case True{}:
      a
    case False{}:
      b

def T.picku(c: Bool, a: U32, b: U32) -> U32:
  match c:
    case True{}:
      a
    case False{}:
      b

def T.abs(+a: F32) -> F32:
  T.pick((a < 0.0 : F32), (0.0 - a : F32), a)

def T.finite(+v: F32) -> Bool:
  F32.is_eq(v, v) && (T.abs(v) < 1000000.0 : F32)

def T.sum_row(xs: List<&2, F32>, acc: Sum) -> Sum:
  match xs:
    case []:
      acc
    case Con{+v, rest}:
      Sum{t, +p, +b} = acc
      +a = T.abs(v)
      T.sum_row(rest, Sum{(t + v : F32), T.pick((p < a : F32), a, p),
        T.picku(T.finite(v), b, (b + 1 : U32))})

def T.sum_rows(g: List<&2, List<&2, F32>>, acc: Sum) -> Sum:
  match g:
    case []:
      acc
    case r <> rest:
      T.sum_rows(rest, T.sum_row(r, acc))

def T.sum(g: List<&2, List<&2, F32>>) -> Sum:
  T.sum_rows(g, Sum{0.0, 0.0, 0})

# Particles: count, mean y, and how many are outside the tank or not finite.
type PSum is Data:
  PSum{n: U32, ysum: F32, out: U32}

def T.out(+x: F32, +y: F32) -> Bool:
  Bool.not(T.finite(x) && T.finite(y) && (0.6 <= x : F32)
    && (x <= M.Wm.gwf() - 0.6 : F32) && (0.6 <= y : F32)
    && (y <= M.Wm.ghf() - 0.6 : F32))

def T.psum_go(ps: List<&2, M.Part>, acc: PSum) -> PSum:
  match ps:
    case []:
      acc
    case p <> rest:
      M.Part{+x, +y, vx, vy} = p
      PSum{n, s, +o} = acc
      T.psum_go(rest, PSum{(n + 1 : U32), (s + y : F32),
        T.picku(T.out(x, y), (o + 1 : U32), o)})

def T.psum(ps: List<&2, M.Part>) -> PSum:
  T.psum_go(ps, PSum{0, 0.0, 0})

def T.mean_y(p: PSum) -> F32:
  PSum{n, s, o} = p
  (s / U32.to_f32(U32.max(n, 1)) : F32)

# Runs a spec for n steps.
def T.run(spec: String, n: Nat) -> M.Sim:
  +c = M.Wm.parse_spec(spec)
  M.Wm.run_sim(n, c, M.Wm.init_sim(c))

def T.h_of(s: M.Sim) -> List<&2, List<&2, F32>>:
  M.Sim{h, v, ps, r, t} = s
  h

def T.ps_of(s: M.Sim) -> List<&2, M.Part>:
  M.Sim{h, v, ps, r, t} = s
  ps

def T.tick_of(s: M.Sim) -> U32:
  M.Sim{h, v, ps, r, t} = s
  t

def T.cell(g: List<&2, List<&2, F32>>, +x: Nat, y: Nat) -> F32:
  match g y:
    case [] _:
      0.0
    case r <> rest 0n:
      M.Wm.headf(List.drop(&2, F32, r, x), 0.0)
    case r <> rest 1n+j:
      T.cell(rest, x, j)

# Output
# ======

def T.check(name: String, ok: Bool) -> IO(Unit):
  match ok:
    case True{}:
      IO.print("PASS " ++ name)
    case False{}:
      IO.print("FAIL " ++ name)

def T.grid_line(spec: String, s: Sum) -> String:
  Sum{t, p, b} = s
  spec ++ ": total " ++ F32.show(t) ++ " peak " ++ F32.show(p) ++ " bad "
    ++ U32.show(b)

def T.part_line(spec: String, +p: PSum) -> String:
  PSum{n, s, o} = p
  spec ++ ": particles " ++ U32.show(n) ++ " mean_y " ++ F32.show(T.mean_y(p))
    ++ " outside " ++ U32.show(o)

def T.bad(s: Sum) -> U32:
  Sum{t, p, b} = s
  b

def T.total(s: Sum) -> F32:
  Sum{t, p, b} = s
  t

def T.pout(p: PSum) -> U32:
  PSum{n, s, o} = p
  o

def T.pn(p: PSum) -> U32:
  PSum{n, s, o} = p
  n

# Every algorithm x container with all three events, 120 steps: finite
# (grids) or inside the tank (particles).
def T.sweep(specs: List<&2, String>) -> IO(U32):
  match specs:
    case []:
      IO.pure(U32, 0)
    case Con{+spec, rest}:
      +s = T.run(spec, 120n)
      +g = T.sum(T.h_of(s))
      +p = T.psum(T.ps_of(s))
      do IO<U32>:
        IO.print(T.grid_line(spec, g))
        IO.print(T.part_line(spec, p))
        more : U32 <- T.sweep(rest)
        return (more + T.bad(g) + T.pout(p) : U32)

def T.specs() -> List<&2, String>:
  ["navier-stokes:still:rain,rock,fish", "shallow:stream:rain,rock,fish",
    "stable:sphere:rain,rock,fish", "lbm:still:rain,rock,fish",
    "lbm:sphere:rain,rock,fish", "ca:stream:rain,rock,fish",
    "ca:sphere:rain,rock,fish", "sph:still:rain,rock,fish",
    "sph:sphere:rain,rock,fish", "pbf:still:rain,rock,fish",
    "pbf:sphere:rain,rock,fish", "pic:stream:rain,rock,fish"]

def T.fish_x(f: M.Fish) -> U32:
  M.Fpos{x, y, r} = f
  x

def T.fish_r(f: M.Fish) -> Bool:
  M.Fpos{x, y, r} = f
  r

def T.vec_y(v: M.Vec) -> F32:
  M.Vec{x, y} = v
  y

def T.near(+a: F32, +b: F32, +eps: F32) -> Bool:
  (T.abs((a - b : F32)) < eps : F32)

def T.pans_tick(ps: List<&2, M.Pan>) -> U32:
  match ps:
    case []:
      0
    case p <> rest:
      M.Pan{c, s} = p
      T.tick_of(s)

def T.world_tick(w: M.World) -> U32:
  M.World{pans, wait, every, paused} = w
  T.pans_tick(pans)

def T.live(n: Nat, w: M.World) -> M.World:
  match n:
    case 0n:
      w
    case 1n+p:
      T.live(p, M.Wm.advance(w))

def T.img_nodes(i: Image) -> U32:
  match i:
    case Pix{c}:
      1
    case Qua{a, b, c, d}:
      (T.img_nodes(a) + T.img_nodes(b) + T.img_nodes(c) + T.img_nodes(d) + 1
        : U32)

def main() -> IO(Unit):
  # wave: the rock's central impulse spreads out as a ring
  +w0 = T.h_of(T.run("ns:still:rock", 0n))
  +w12 = T.h_of(T.run("ns:still:rock", 12n))
  # relax / CA conserve the water (still tank, rock impulse, no sources)
  +r0 = T.total(T.sum(T.h_of(T.run("lbm:still:rock", 0n))))
  +r80 = T.total(T.sum(T.h_of(T.run("lbm:still:rock", 80n))))
  +c0 = T.total(T.sum(T.h_of(T.run("ca:sphere:rock", 0n))))
  +c80 = T.total(T.sum(T.h_of(T.run("ca:sphere:rock", 80n))))
  # particles settle into the lower rows; the sphere's disk falls
  +pool = T.psum(T.ps_of(T.run("sph:still:", 150n)))
  +disk0 = T.psum(T.ps_of(T.run("pbf:sphere:", 0n)))
  +disk = T.psum(T.ps_of(T.run("pbf:sphere:", 150n)))
  # rain: grids get dimples near the top, particles one droplet per 3 steps
  +dry = T.total(T.sum(T.h_of(T.run("lbm:still:", 3n))))
  +wet = T.total(T.sum(T.h_of(T.run("lbm:still:rain", 3n))))
  +drops = T.pn(T.psum(T.ps_of(T.run("sph:still:rain", 30n))))
  # fish: the wake lowers the water (relax keeps the volume)
  +fishy = T.total(T.sum(T.h_of(T.run("lbm:still:fish", 30n))))
  # live loop: a panel restarts after LOOP_TICKS steps
  +wl = T.live(260n, M.World{M.Wm.init_pans(M.Wm.conts()), 0, 1, False{}})
  do IO<Unit>:
    IO.print("== sweep: 120 steps, all events ==")
    bad : U32 <- T.sweep(T.specs())
    T.check("all engines finite and particles inside the tank", U32.is_eq(bad, 0))
    IO.print("rock centre " ++ F32.show(T.cell(w0, 20n, 11n)) ++ " -> "
      ++ F32.show(T.cell(w12, 20n, 11n)) ++ "; 6 cells out "
      ++ F32.show(T.cell(w0, 26n, 11n)) ++ " -> " ++ F32.show(T.cell(w12, 26n, 11n)))
    T.check("wave: rock impulse spreads into ripples",
      (T.cell(w12, 20n, 11n) < T.cell(w0, 20n, 11n) : F32)
      && (0.01 < T.abs(T.cell(w12, 26n, 11n)) : F32)
      && T.near(T.cell(w0, 26n, 11n), 0.0, 0.000001))
    IO.print("lbm total " ++ F32.show(r0) ++ " -> " ++ F32.show(r80)
      ++ ", ca total " ++ F32.show(c0) ++ " -> " ++ F32.show(c80))
    T.check("relax conserves water", T.near(r0, r80, 0.01))
    T.check("CA conserves water", T.near(c0, c80, 0.01))
    IO.print(T.part_line("sph:still 150", pool))
    T.check("pool stays in the lower rows", (16.0 < T.mean_y(pool) : F32)
      && U32.is_eq(T.pout(pool), 0) && U32.is_eq(T.pn(pool), 360))
    IO.print("disk mean_y " ++ F32.show(T.mean_y(disk0)) ++ " -> "
      ++ F32.show(T.mean_y(disk)))
    T.check("sphere disk falls and settles", (T.mean_y(disk0) + 6.0
      < T.mean_y(disk) : F32))
    IO.print("rain total " ++ F32.show(dry) ++ " vs " ++ F32.show(wet)
      ++ "; sph rain particles " ++ U32.show(drops))
    T.check("rain adds impulses", (dry + 1.0 < wet : F32))
    T.check("rain adds a droplet every 3 steps", U32.is_eq(drops, 370))
    T.check("fish wake dimples the water", (fishy < 0.0 - 1.0 : F32))
    T.check("fish swims right then turns", U32.is_eq(T.fish_x(M.Wm.fish_for(False{}, 0)), 2)
      && U32.is_eq(T.fish_x(M.Wm.fish_for(False{}, 30)), 32)
      && T.fish_r(M.Wm.fish_for(False{}, 30))
      && U32.is_eq(T.fish_x(M.Wm.fish_for(False{}, 40)), 34)
      && Bool.not(T.fish_r(M.Wm.fish_for(False{}, 40))))
    T.check("rock falls then rests on the floor (particles)",
      T.near(T.vec_y(M.Wm.rock_pos(True{}, 5)), 6.0, 0.001)
      && T.near(T.vec_y(M.Wm.rock_pos(True{}, 100)), 20.0, 0.001))
    IO.print("live tick after 260 steps (loop 240): "
      ++ U32.show(T.world_tick(wl)))
    T.check("panels loop after LOOP_TICKS", U32.is_eq(T.world_tick(wl), 20))
    IO.print("window " ++ U32.show(M.Wm.win_w()) ++ " x " ++ U32.show(M.Wm.win_h())
      ++ ", frame nodes " ++ U32.show(T.img_nodes(M.Wm.draw(wl))))
    T.check("json frames", String.starts_with(M.Wm.frames_json(), "{\"w\":40,\"h\":22,\"cols\":3"))
