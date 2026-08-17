# elements: the four bending arts, each working its element in its own
# clickable panel. "BEND!" up top, of course.
#
#   earth (top-left)    impact waves and rocks pushed away from the click
#   water (top-right)   local ripples and a stream pulled to the click
#   fire  (bottom-left) a hotspot that locally feeds flames and sparks
#   air   (bottom-right) a vortex pushed in the click's direction
#
# All motion is sums of traveling sines; sin comes from Bhaskara I's
# 7th-century approximation (16 t (pi - t) / (5 pi^2 - 4 t (pi - t)) on
# [0, pi], mirrored), good to ~0.2% -- Bend has no trig primitives.
# The pure fragment computes every frame and emits flat draw commands;
# effs/window.c (the same Cocoa effect as bar_bench, font extended with
# B E N D !) rasterizes and presents them.
#
# build:  bun bend-ts/src/bend.ts gabriel_demos/elements/elements.bend --no-halt -o gabriel_demos/elements/elements
# run:    ./gabriel_demos/elements/elements            (q or closing the window quits)
# demo:   ./gabriel_demos/elements/elements --demo     (~10 s, then exits)
#
# no-halt
# skip-native

import ../../bend-base/Base
import ../Compat
import ../CommandGFX

def win_open(w: U32, h: U32, title: String) -> IO(U32):
  CommandGFX.open(title, w, h)

def win_frame(cmds: List(U32)) -> IO(U32):
  CommandGFX.frame_panel(cmds)

def win_close() -> IO(U32):
  CommandGFX.close()

# ---------------------------------------------------------------- math

def clamp0(x: F32) -> F32:
  match x < 0.0:
    case 0:
      x
    case k:
      0.0

# sine for any |x| < ~6400: floor-based range reduction mod 2pi (the
# +1024 shift makes truncation act as floor), Bhaskara I on each half
def fsin_h(t: F32) -> F32:
  p = t * (3.14159265 - t)
  (16.0 * p) / (49.3480220 - (4.0 * p))

def fsin(x: F32) -> F32:
  q = U32.to_f32(F32.to_u32((x / 6.28318531) + 1024.0)) - 1024.0
  r = x - (q * 6.28318531)
  match r > 3.14159265:
    case 0:
      fsin_h(r)
    case k:
      0.0 - fsin_h(r - 3.14159265)

def fcos(x: F32) -> F32:
  fsin(x + 1.57079633)

def f32_abs(x: F32) -> F32:
  match x < 0.0:
    case 0:
      x
    case k:
      0.0 - x

def f32_cap(x: F32, top: F32) -> F32:
  match x > top:
    case 0:
      x
    case k:
      top

def f32_falloff(delta: F32, radius: F32) -> F32:
  radius / (radius + f32_abs(delta))

def u32_cap(x: U32, top: U32) -> U32:
  match x > top:
    case 0:
      x
    case k:
      top

# A reaction packs a six-bit countdown and the 300x152 local click point:
#   time + x*64 + y*(64*300)
def u32_reaction_make(time: U32, x: U32, y: U32) -> U32:
  (u32_cap(time, 63) + ((x % 300) * 64)) + ((y % 152) * 19200)

def u32_reaction_time(x: U32) -> U32:
  x % 64

def u32_reaction_x(x: U32) -> U32:
  (x / 64) % 300

def u32_reaction_y(x: U32) -> U32:
  (x / 19200) % 152

def u32_reaction_amp(x: U32, top: U32) -> F32:
  U32.to_f32(u32_cap(u32_reaction_time(x), top)) / U32.to_f32(top)

def u32_reaction_age(x: U32, top: U32) -> F32:
  match u32_reaction_time(x):
    case 0:
      0.0
    case k:
      U32.to_f32(top - u32_cap(k, top))

def u32_cool(x: U32) -> U32:
  match u32_reaction_time(x):
    case 0:
      0
    case k:
      match k > 1:
        case 0:
          0
        case more:
          x - 1

def u32_active_rgb(x: U32, idle: U32, active: U32) -> U32:
  match u32_reaction_time(x):
    case 0:
      idle
    case k:
      active

# ---------------------------------------------------------------- draw commands

def cmd_clear(rgb: U32, t: List(U32)) -> List(U32):
  List.Cons{0, List.Cons{rgb, t}}

def cmd_rect(x: U32, yb: U32, w: U32, h: U32, rgb: U32, t: List(U32)) -> List(U32):
  List.Cons{1, List.Cons{x, List.Cons{yb, List.Cons{w, List.Cons{h, List.Cons{rgb, t}}}}}}

def cmd_glyph(x: U32, yb: U32, s: U32, g: U32, rgb: U32, t: List(U32)) -> List(U32):
  List.Cons{2, List.Cons{x, List.Cons{yb, List.Cons{s, List.Cons{g, List.Cons{rgb, t}}}}}}

# a rect placed inside a panel: px,py panel origin, fx,fy F32 local coords
def prect(px: U32, py: U32, fx: F32, fy: F32, w: U32, h: U32, rgb: U32, t: List(U32)) -> List(U32):
  cmd_rect(px + F32.to_u32(clamp0(fx) + 0.5), (1000 + py) + F32.to_u32(clamp0(fy) + 0.5), w, h, rgb, t)

# ---------------------------------------------------------------- earth (12,76)
# a click strikes a local epicenter: the ground pulse decays with distance,
# and each boulder is launched up and away from the point of impact

def earth_pillars(k: U32, t: F32, hit: U32, acc: List(U32)) -> List(U32):
  match k:
    case 0:
      acc
    case n:
      p = U32.to_f32(n - 1)
      x = 10.0 + (p * 28.0)
      amp = u32_reaction_amp(hit, 48)
      age = u32_reaction_age(hit, 48)
      cx = U32.to_f32(u32_reaction_x(hit))
      power = 0.55 + (U32.to_f32(u32_reaction_y(hit)) / 160.0)
      near = f32_falloff(x - cx, 44.0)
      base = 26.0 + (18.0 * fsin((p * 0.9) - (t * 2.1)))
      pulse = (((24.0 * amp) * power) * near) * fcos((f32_abs(x - cx) * 0.065) - (age * 0.34))
      ph = clamp0(base + pulse)
      y = (138.0 - ph)
      hh = F32.to_u32(ph + 0.5)
      earth_pillars(n - 1, t, hit,
        prect(12, 76, x, y, 24, hh, 9073493,
          prect(12, 76, x, y, 24, 4, 7035458, acc)))

def earth_rocks(k: U32, hit: U32, acc: List(U32)) -> List(U32):
  match k:
    case 0:
      acc
    case n:
      j = n - 1
      i = U32.to_f32(j)
      phase = u32_reaction_age(hit, 48) / 48.0
      launch = (4.0 * phase) * (1.0 - phase)
      base = 20.0 + (i * 120.0)
      cx = U32.to_f32(u32_reaction_x(hit))
      delta = (base + 10.0) - cx
      near = f32_falloff(delta, 92.0)
      away = delta / (18.0 + f32_abs(delta))
      power = 0.55 + (U32.to_f32(u32_reaction_y(hit)) / 160.0)
      x = base + ((((96.0 * power) * near) * away) * launch)
      y = 124.0 - (((52.0 + ((68.0 * power) * near)) * launch))
      earth_rocks(n - 1, hit,
        prect(12, 76, x, y, 20, 14, 10125410,
          prect(12, 76, x + 4.0, y - 4.0, 12, 5, 9073493, acc)))

def earth(t: F32, hit: U32, acc: List(U32)) -> List(U32):
  cmd_rect(12, 1214, 300, 14, 4864810,
    earth_pillars(10, t, hit, earth_rocks(3, hit, acc)))

# ---------------------------------------------------------------- water (328,76)
# the click is a pull point: it raises a local traveling ripple and draws
# the lifted ribbon toward that part of the pool

def water_cols(k: U32, t: F32, hit: U32, acc: List(U32)) -> List(U32):
  match k:
    case 0:
      acc
    case n:
      c = U32.to_f32(n - 1)
      x = c * 12.0
      amp = u32_reaction_amp(hit, 60)
      age = u32_reaction_age(hit, 60)
      cx = U32.to_f32(u32_reaction_x(hit))
      lift = 0.45 + ((151.0 - U32.to_f32(u32_reaction_y(hit))) / 170.0)
      near = f32_falloff(x - cx, 38.0 + age)
      base = (70.0 + (12.0 * fsin((c * 0.55) - (t * 2.2)))) + (5.0 * fsin((c * 1.3) + (t * 3.1)))
      pull = ((((28.0 * amp) * lift) * near) * fcos((f32_abs(x - cx) * 0.075) - (age * 0.31)))
      ys = base - pull
      hh = F32.to_u32(clamp0(152.0 - ys) + 0.5)
      water_cols(n - 1, t, hit,
        prect(328, 76, x, ys, 12, hh, 2977500,
          prect(328, 76, x, ys - 3.0, 12, 4, 8370416, acc)))

def water_whirl(k: U32, t: F32, hit: U32, acc: List(U32)) -> List(U32):
  match k:
    case 0:
      acc
    case n:
      i = U32.to_f32(n - 1)
      amp = u32_reaction_amp(hit, 60)
      cx = U32.to_f32(u32_reaction_x(hit))
      cy = U32.to_f32(u32_reaction_y(hit))
      lift = 0.45 + ((151.0 - cy) / 170.0)
      pull = amp * 0.72
      a = (((t * 1.8) + (i * 0.5)) + (u32_reaction_age(hit, 60) * 0.24)) + ((cx / 300.0) * amp)
      mx = 144.0 + (((cx - 144.0) * pull))
      my = 32.0 + (((cy - 32.0) * pull) * 0.48)
      x = mx + ((26.0 + ((24.0 * amp) * lift)) * fcos(a))
      y = my + ((18.0 + ((12.0 * amp) * lift)) * fsin(a))
      water_whirl(n - 1, t, hit,
        prect(328, 76, x, y, 9, 7, 5232869, acc))

def water(t: F32, hit: U32, acc: List(U32)) -> List(U32):
  water_cols(25, t, hit, water_whirl(6, t, hit, acc))

# ---------------------------------------------------------------- fire (12,240)
# a click feeds heat into a local point: nearby columns flare most, while
# sparks are pulled toward the hotspot before rising from it

def fire_cols(k: U32, t: F32, hit: U32, acc: List(U32)) -> List(U32):
  match k:
    case 0:
      acc
    case n:
      c = U32.to_f32(n - 1)
      x = 7.0 + (c * 13.0)
      s1 = 0.5 + (0.5 * fsin((c * 1.9) + (t * 5.3)))
      s2 = 0.6 + (0.4 * fsin((c * 0.8) - (t * 3.1)))
      amp = u32_reaction_amp(hit, 45)
      cx = U32.to_f32(u32_reaction_x(hit))
      heat = 0.55 + (U32.to_f32(u32_reaction_y(hit)) / 160.0)
      near = f32_falloff(x - cx, 34.0)
      ho = f32_cap((20.0 + (60.0 * (s1 * s2))) + (((72.0 * amp) * heat) * near), 145.0)
      hm = ho * 0.62
      hc = ho * 0.30
      fire_cols(n - 1, t, hit,
        prect(12, 240, x, 148.0 - ho, 13, F32.to_u32(ho + 0.5), 13646360,
          prect(12, 240, x + 2.0, 148.0 - hm, 9, F32.to_u32(hm + 0.5), 15759384,
            prect(12, 240, x + 4.0, 148.0 - hc, 5, F32.to_u32(hc + 0.5), 16308296, acc))))

def fire_sparks(k: U32, t: F32, hit: U32, acc: List(U32)) -> List(U32):
  match k:
    case 0:
      acc
    case n:
      i = U32.to_f32(n - 1)
      amp = u32_reaction_amp(hit, 45)
      cx = U32.to_f32(u32_reaction_x(hit))
      heat = 0.55 + (U32.to_f32(u32_reaction_y(hit)) / 160.0)
      base = 34.0 + (i * 72.0)
      near = f32_falloff(base - cx, 70.0)
      v = ((t * 55.0) + (i * 40.0)) + (((u32_reaction_age(hit, 45) * 9.0) * heat) * near)
      m = v - (U32.to_f32(F32.to_u32(v / 130.0)) * 130.0)
      x = (base + ((((cx - base) * amp) * near) * 0.62)) + (6.0 * fsin((t * 3.0) + i))
      fire_sparks(n - 1, t, hit,
        prect(12, 240, x, 140.0 - m, 4, 4, 16308296, acc))

def fire(t: F32, hit: U32, acc: List(U32)) -> List(U32):
  fire_cols(22, t, hit, fire_sparks(4, t, hit, acc))

# ---------------------------------------------------------------- air (328,240)
# the click supplies a directional gust from the panel center: its angle
# moves the vortex, while its distance controls expansion and spin

def air_parts(k: U32, t: F32, hit: U32, acc: List(U32)) -> List(U32):
  match k:
    case 0:
      acc
    case n:
      arm = U32.to_f32((n - 1) / 10)
      j = U32.to_f32((n - 1) % 10)
      amp = u32_reaction_amp(hit, 60)
      dx = (U32.to_f32(u32_reaction_x(hit)) - 150.0) / 150.0
      dy = (U32.to_f32(u32_reaction_y(hit)) - 76.0) / 76.0
      force = 0.55 + ((f32_abs(dx) + f32_abs(dy)) * 0.38)
      age = u32_reaction_age(hit, 60)
      a = (((t * 2.2) + (arm * 2.0944)) + (j * 0.30)) + (age * (0.20 + (dx * 0.12)))
      r = (13.0 + (j * 6.3)) + ((32.0 * amp) * force)
      x = (144.0 + ((dx * 55.0) * amp)) + (r * fcos(a))
      y = (72.0 + ((dy * 38.0) * amp)) + (r * fsin(a))
      sz = (7 - (((n - 1) % 10) / 2)) + (u32_reaction_time(hit) / 30)
      air_parts(n - 1, t, hit,
        prect(328, 240, x, y, sz, sz, 13358056, acc))

def air(t: F32, hit: U32, acc: List(U32)) -> List(U32):
  air_parts(30, t, hit, acc)

# ---------------------------------------------------------------- scene

# glyphs: B=10 E=11 N=12 D=13 !=14, scale 8 -> 24x40 each
def title(acc: List(U32)) -> List(U32):
  cmd_glyph(240, 1014, 8, 10, 15790072,
    cmd_glyph(272, 1014, 8, 11, 15790072,
      cmd_glyph(304, 1014, 8, 12, 15790072,
        cmd_glyph(336, 1014, 8, 13, 15790072,
          cmd_glyph(368, 1014, 8, 14, 15790072, acc)))))

def panels(e: U32, w: U32, f: U32, a: U32, acc: List(U32)) -> List(U32):
  cmd_rect(12, 1076, 300, 152, u32_active_rgb(e, 1709839, 2634274),
    cmd_rect(328, 1076, 300, 152, u32_active_rgb(w, 923168, 1323088),
      cmd_rect(12, 1240, 300, 152, u32_active_rgb(f, 1708044, 2695198),
        cmd_rect(328, 1240, 300, 152, u32_active_rgb(a, 1316378, 2177379), acc))))

def scene(t: F32, e: U32, w: U32, f: U32, a: U32) -> List(U32):
  cmd_clear(921622,
    title(
      panels(e, w, f, a,
        earth(t, e, water(t, w, fire(t, f, air(t, a, List.Nil{})))))))

# ---------------------------------------------------------------- loop

def quit() -> IO(U32):
  do IO(U32):
    _ <- win_close()
    return 0

def twrap(t: F32) -> F32:
  match t > 6283.18531:
    case 0:
      t
    case k:
      t - 6283.18531

def react(n: U32, t: F32, k: U32, e: U32, w: U32, f: U32, a: U32) -> IO(U32):
  match k > 255:
    case 0:
      run(n, t, e, w, f, a)
    case click:
      payload = k - 256
      panel = payload % 4
      cell = payload / 4
      x = cell % 300
      y = cell / 300
      match panel:
        case 0:
          run(n, t, u32_reaction_make(48, x, y), w, f, a)
        case 1:
          run(n, t, e, u32_reaction_make(60, x, y), f, a)
        case 2:
          run(n, t, e, w, u32_reaction_make(45, x, y), a)
        case p:
          run(n, t, e, w, f, u32_reaction_make(60, x, y))

def step(n: U32, t: F32, k: U32, e: U32, w: U32, f: U32, a: U32) -> IO(U32):
  match (k == 113) || (k == 81):
    case 0:
      react(n, twrap(t + 0.033), k, u32_cool(e), u32_cool(w), u32_cool(f), u32_cool(a))
    case q:
      quit()

def run(n: U32, t: F32, e: U32, w: U32, f: U32, a: U32) -> IO(U32):
  match n:
    case 0:
      quit()
    case m:
      do IO(U32):
        k <- win_frame(scene(t, e, w, f, a))
        _ <- IO.sleep(33)
        step(m - 1, t, k, e, w, f, a)

def frames_of(a: List(String)) -> U32:
  match a:
    case List.Nil{}:
      4294967295
    case List.Cons{h, r}:
      300

def go(ok: U32, n: U32) -> IO(U32):
  match ok:
    case 0:
      do IO(U32):
        _ <- IO.write("could not open a window\n")
        return 1
    case k:
      run(n, 0.0, 0, 0, 0, 0)

def main() -> IO(U32):
  do IO(U32):
    a <- IO.args()
    ok <- win_open(640, 400, "Bend!")
    go(ok, frames_of(a))
