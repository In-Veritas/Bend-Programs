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
# [0, pi], mirrored), good to ~0.2%. (The original Bend3 had no trig
# primitive; Bend 2.0.40 has F32.sin, which the headless probe uses to
# measure the approximation, but the scene keeps Bhaskara on purpose.)
# The pure side computes every frame and emits the demos' flat draw
# commands; ../CommandGFX.bend turns them into an Image for App.run and
# the window's clicks back into the old packed panel clicks.
#
# build:  bend Bend3/demos/elements/elements.bend -o /tmp/elements
# run:    /tmp/elements            (q or closing the window quits)
# demo:   /tmp/elements --demo     (~10 s, then exits)
# probe:  /tmp/elements --probe    (headless: no window; checks frames
#                                   and scripted clicks)
import Base
import ../Clock.bend as Clock
import ../CommandGFX.bend as GFX

# ---------------------------------------------------------------- math

def pickf(c: Bool, a: F32, b: F32) -> F32:
  match c:
    case True{}:
      a
    case False{}:
      b

def pick(c: Bool, a: U32, b: U32) -> U32:
  match c:
    case True{}:
      a
    case False{}:
      b

def clamp0(+x: F32) -> F32:
  pickf(F32.is_lt(x, 0.0), 0.0, x)

# sine for any |x| < ~6400: floor-based range reduction mod 2pi (the
# +1024 shift makes truncation act as floor), Bhaskara I on each half
def fsin_h(+t: F32) -> F32:
  +p = (t * (3.14159265 - t) : F32)
  (16.0 * p / (49.3480220 - 4.0 * p) : F32)

def fsin(+x: F32) -> F32:
  +q = (U32.to_f32(F32.to_u32((x / 6.28318531 + 1024.0 : F32))) - 1024.0 : F32)
  +r = (x - q * 6.28318531 : F32)
  pickf(F32.is_gt(r, 3.14159265), (0.0 - fsin_h((r - 3.14159265 : F32)) : F32), fsin_h(r))

def fcos(+x: F32) -> F32:
  fsin((x + 1.57079633 : F32))

def f32_abs(+x: F32) -> F32:
  pickf(F32.is_lt(x, 0.0), (0.0 - x : F32), x)

def f32_cap(+x: F32, +top: F32) -> F32:
  pickf(F32.is_gt(x, top), top, x)

def f32_falloff(+delta: F32, +radius: F32) -> F32:
  (radius / (radius + f32_abs(delta)) : F32)

def u32_cap(+x: U32, +top: U32) -> U32:
  pick(U32.is_gt(x, top), top, x)

# A reaction packs a six-bit countdown and the 300x152 local click point:
#   time + x*64 + y*(64*300)
def u32_reaction_make(+time: U32, +x: U32, +y: U32) -> U32:
  (u32_cap(time, 63) + (x % 300) * 64 + (y % 152) * 19200 : U32)

def u32_reaction_time(+x: U32) -> U32:
  (x % 64 : U32)

def u32_reaction_x(+x: U32) -> U32:
  (x / 64 % 300 : U32)

def u32_reaction_y(+x: U32) -> U32:
  (x / 19200 % 152 : U32)

def f32_of(+x: U32) -> F32:
  U32.to_f32(x)

def u32_reaction_amp(+x: U32, +top: U32) -> F32:
  (f32_of(u32_cap(u32_reaction_time(x), top)) / f32_of(top) : F32)

def u32_reaction_age(+x: U32, +top: U32) -> F32:
  +k = u32_reaction_time(x)
  pickf(U32.is_eq(k, 0), 0.0, f32_of((top - u32_cap(k, top) : U32)))

def u32_cool(+x: U32) -> U32:
  pick(U32.is_gt(u32_reaction_time(x), 1), (x - 1 : U32), 0)

def u32_active_rgb(+x: U32, +idle: U32, +active: U32) -> U32:
  pick(U32.is_eq(u32_reaction_time(x), 0), idle, active)

# ---------------------------------------------------------------- draw commands

# a rect placed inside a panel: px,py panel origin, fx,fy F32 local coords
def prect(+px: U32, +py: U32, +fx: F32, +fy: F32, w: U32, h: U32, rgb: U32, t: List<&2, U32>) -> List<&2, U32>:
  GFX.cmd_rect((px + F32.to_u32((clamp0(fx) + 0.5 : F32)) : U32),
    (1000 + py + F32.to_u32((clamp0(fy) + 0.5 : F32)) : U32), w, h, rgb, t)

def h_of(+x: F32) -> U32:
  F32.to_u32((x + 0.5 : F32))

# ---------------------------------------------------------------- earth (12,76)
# a click strikes a local epicenter: the ground pulse decays with distance,
# and each boulder is launched up and away from the point of impact

def earth_pillars(+k: Nat, +t: F32, +hit: U32, acc: List<&2, U32>) -> List<&2, U32>:
  match k:
    case 0n:
      acc
    case 1n+n:
      +p = f32_of(U32.from_nat(n))
      +x = (10.0 + p * 28.0 : F32)
      +amp = u32_reaction_amp(hit, 48)
      +age = u32_reaction_age(hit, 48)
      +cx = f32_of(u32_reaction_x(hit))
      +power = (0.55 + f32_of(u32_reaction_y(hit)) / 160.0 : F32)
      +near = f32_falloff((x - cx : F32), 44.0)
      +base = (26.0 + 18.0 * fsin((p * 0.9 - t * 2.1 : F32)) : F32)
      +pulse = (24.0 * amp * power * near * fcos((f32_abs((x - cx : F32)) * 0.065 - age * 0.34 : F32)) : F32)
      +ph = clamp0((base + pulse : F32))
      +y = (138.0 - ph : F32)
      earth_pillars(n, t, hit,
        prect(12, 76, x, y, 24, h_of(ph), 9073493,
          prect(12, 76, x, y, 24, 4, 7035458, acc)))

def earth_rocks(+k: Nat, +hit: U32, acc: List<&2, U32>) -> List<&2, U32>:
  match k:
    case 0n:
      acc
    case 1n+n:
      +i = f32_of(U32.from_nat(n))
      +phase = (u32_reaction_age(hit, 48) / 48.0 : F32)
      +launch = (4.0 * phase * (1.0 - phase) : F32)
      +base = (20.0 + i * 120.0 : F32)
      +cx = f32_of(u32_reaction_x(hit))
      +delta = (base + 10.0 - cx : F32)
      +near = f32_falloff(delta, 92.0)
      +away = (delta / (18.0 + f32_abs(delta)) : F32)
      +power = (0.55 + f32_of(u32_reaction_y(hit)) / 160.0 : F32)
      +x = (base + 96.0 * power * near * away * launch : F32)
      +y = (124.0 - (52.0 + 68.0 * power * near) * launch : F32)
      earth_rocks(n, hit,
        prect(12, 76, x, y, 20, 14, 10125410,
          prect(12, 76, (x + 4.0 : F32), (y - 4.0 : F32), 12, 5, 9073493, acc)))

def earth(+t: F32, +hit: U32, acc: List<&2, U32>) -> List<&2, U32>:
  GFX.cmd_rect(12, 1214, 300, 14, 4864810,
    earth_pillars(10n, t, hit, earth_rocks(3n, hit, acc)))

# ---------------------------------------------------------------- water (328,76)
# the click is a pull point: it raises a local traveling ripple and draws
# the lifted ribbon toward that part of the pool

def water_cols(+k: Nat, +t: F32, +hit: U32, acc: List<&2, U32>) -> List<&2, U32>:
  match k:
    case 0n:
      acc
    case 1n+n:
      +c = f32_of(U32.from_nat(n))
      +x = (c * 12.0 : F32)
      +amp = u32_reaction_amp(hit, 60)
      +age = u32_reaction_age(hit, 60)
      +cx = f32_of(u32_reaction_x(hit))
      +lift = (0.45 + (151.0 - f32_of(u32_reaction_y(hit))) / 170.0 : F32)
      +near = f32_falloff((x - cx : F32), (38.0 + age : F32))
      +base = (70.0 + 12.0 * fsin((c * 0.55 - t * 2.2 : F32)) + 5.0 * fsin((c * 1.3 + t * 3.1 : F32)) : F32)
      +pull = (28.0 * amp * lift * near * fcos((f32_abs((x - cx : F32)) * 0.075 - age * 0.31 : F32)) : F32)
      +ys = (base - pull : F32)
      water_cols(n, t, hit,
        prect(328, 76, x, ys, 12, h_of(clamp0((152.0 - ys : F32))), 2977500,
          prect(328, 76, x, (ys - 3.0 : F32), 12, 4, 8370416, acc)))

def water_whirl(+k: Nat, +t: F32, +hit: U32, acc: List<&2, U32>) -> List<&2, U32>:
  match k:
    case 0n:
      acc
    case 1n+n:
      +i = f32_of(U32.from_nat(n))
      +amp = u32_reaction_amp(hit, 60)
      +cx = f32_of(u32_reaction_x(hit))
      +cy = f32_of(u32_reaction_y(hit))
      +lift = (0.45 + (151.0 - cy) / 170.0 : F32)
      +pull = (amp * 0.72 : F32)
      +a = (t * 1.8 + i * 0.5 + u32_reaction_age(hit, 60) * 0.24 + cx / 300.0 * amp : F32)
      +mx = (144.0 + (cx - 144.0) * pull : F32)
      +my = (32.0 + (cy - 32.0) * pull * 0.48 : F32)
      +x = (mx + (26.0 + 24.0 * amp * lift) * fcos(a) : F32)
      +y = (my + (18.0 + 12.0 * amp * lift) * fsin(a) : F32)
      water_whirl(n, t, hit,
        prect(328, 76, x, y, 9, 7, 5232869, acc))

def water(+t: F32, +hit: U32, acc: List<&2, U32>) -> List<&2, U32>:
  water_cols(25n, t, hit, water_whirl(6n, t, hit, acc))

# ---------------------------------------------------------------- fire (12,240)
# a click feeds heat into a local point: nearby columns flare most, while
# sparks are pulled toward the hotspot before rising from it

def fire_cols(+k: Nat, +t: F32, +hit: U32, acc: List<&2, U32>) -> List<&2, U32>:
  match k:
    case 0n:
      acc
    case 1n+n:
      +c = f32_of(U32.from_nat(n))
      +x = (7.0 + c * 13.0 : F32)
      +s1 = (0.5 + 0.5 * fsin((c * 1.9 + t * 5.3 : F32)) : F32)
      +s2 = (0.6 + 0.4 * fsin((c * 0.8 - t * 3.1 : F32)) : F32)
      +amp = u32_reaction_amp(hit, 45)
      +cx = f32_of(u32_reaction_x(hit))
      +heat = (0.55 + f32_of(u32_reaction_y(hit)) / 160.0 : F32)
      +near = f32_falloff((x - cx : F32), 34.0)
      +ho = f32_cap((20.0 + 60.0 * (s1 * s2) + 72.0 * amp * heat * near : F32), 145.0)
      +hm = (ho * 0.62 : F32)
      +hc = (ho * 0.30 : F32)
      fire_cols(n, t, hit,
        prect(12, 240, x, (148.0 - ho : F32), 13, h_of(ho), 13646360,
          prect(12, 240, (x + 2.0 : F32), (148.0 - hm : F32), 9, h_of(hm), 15759384,
            prect(12, 240, (x + 4.0 : F32), (148.0 - hc : F32), 5, h_of(hc), 16308296, acc))))

def fire_sparks(+k: Nat, +t: F32, +hit: U32, acc: List<&2, U32>) -> List<&2, U32>:
  match k:
    case 0n:
      acc
    case 1n+n:
      +i = f32_of(U32.from_nat(n))
      +amp = u32_reaction_amp(hit, 45)
      +cx = f32_of(u32_reaction_x(hit))
      +heat = (0.55 + f32_of(u32_reaction_y(hit)) / 160.0 : F32)
      +base = (34.0 + i * 72.0 : F32)
      +near = f32_falloff((base - cx : F32), 70.0)
      +v = (t * 55.0 + i * 40.0 + u32_reaction_age(hit, 45) * 9.0 * heat * near : F32)
      +m = (v - f32_of(F32.to_u32((v / 130.0 : F32))) * 130.0 : F32)
      +x = (base + (cx - base) * amp * near * 0.62 + 6.0 * fsin((t * 3.0 + i : F32)) : F32)
      fire_sparks(n, t, hit,
        prect(12, 240, x, (140.0 - m : F32), 4, 4, 16308296, acc))

def fire(+t: F32, +hit: U32, acc: List<&2, U32>) -> List<&2, U32>:
  fire_cols(22n, t, hit, fire_sparks(4n, t, hit, acc))

# ---------------------------------------------------------------- air (328,240)
# the click supplies a directional gust from the panel center: its angle
# moves the vortex, while its distance controls expansion and spin

def air_parts(+k: Nat, +t: F32, +hit: U32, acc: List<&2, U32>) -> List<&2, U32>:
  match k:
    case 0n:
      acc
    case 1n+n:
      +p = U32.from_nat(n)
      +arm = f32_of((p / 10 : U32))
      +j = f32_of((p % 10 : U32))
      +amp = u32_reaction_amp(hit, 60)
      +dx = ((f32_of(u32_reaction_x(hit)) - 150.0) / 150.0 : F32)
      +dy = ((f32_of(u32_reaction_y(hit)) - 76.0) / 76.0 : F32)
      +force = (0.55 + (f32_abs(dx) + f32_abs(dy)) * 0.38 : F32)
      +age = u32_reaction_age(hit, 60)
      +a = (t * 2.2 + arm * 2.0944 + j * 0.30 + age * (0.20 + dx * 0.12) : F32)
      +r = (13.0 + j * 6.3 + 32.0 * amp * force : F32)
      +x = (144.0 + dx * 55.0 * amp + r * fcos(a) : F32)
      +y = (72.0 + dy * 38.0 * amp + r * fsin(a) : F32)
      +sz = (7 - p % 10 / 2 + u32_reaction_time(hit) / 30 : U32)
      air_parts(n, t, hit,
        prect(328, 240, x, y, sz, sz, 13358056, acc))

def air(+t: F32, +hit: U32, acc: List<&2, U32>) -> List<&2, U32>:
  air_parts(30n, t, hit, acc)

# ---------------------------------------------------------------- scene

# glyphs: B=10 E=11 N=12 D=13 !=14, scale 8 -> 24x40 each
def title(acc: List<&2, U32>) -> List<&2, U32>:
  GFX.cmd_glyph(240, 1014, 8, 10, 15790072,
    GFX.cmd_glyph(272, 1014, 8, 11, 15790072,
      GFX.cmd_glyph(304, 1014, 8, 12, 15790072,
        GFX.cmd_glyph(336, 1014, 8, 13, 15790072,
          GFX.cmd_glyph(368, 1014, 8, 14, 15790072, acc)))))

def panels(+e: U32, +w: U32, +f: U32, +a: U32, acc: List<&2, U32>) -> List<&2, U32>:
  GFX.cmd_rect(12, 1076, 300, 152, u32_active_rgb(e, 1709839, 2634274),
    GFX.cmd_rect(328, 1076, 300, 152, u32_active_rgb(w, 923168, 1323088),
      GFX.cmd_rect(12, 1240, 300, 152, u32_active_rgb(f, 1708044, 2695198),
        GFX.cmd_rect(328, 1240, 300, 152, u32_active_rgb(a, 1316378, 2177379), acc))))

def scene(+t: F32, +e: U32, +w: U32, +f: U32, +a: U32) -> List<&2, U32>:
  GFX.cmd_clear(921622,
    title(
      panels(e, w, f, a,
        earth(t, e, water(t, w, fire(t, f, air(t, a, Nil{})))))))

# ---------------------------------------------------------------- app state

# t: scene clock (s); e w f a: the four packed reactions; left: frames
# until the app quits by itself (--demo: 300); paced: advance one frame
# per 33 ms of wall clock (off in the headless probe); last: the clock
# of the last advanced frame.
type El is Data:
  El{t: F32, e: U32, w: U32, f: U32, a: U32, left: U32, paced: Bool, last: U32}

def view(s: El) -> El & Image:
  El{+t, +e, +w, +f, +a, left, paced, last} = s
  (El{t, e, w, f, a, left, paced, last}, GFX.image(10n, scene(t, e, w, f, a)))

# the clock wraps at 1000*2pi so phases stay inside fsin's range forever
def twrap(+t: F32) -> F32:
  pickf(F32.is_gt(t, 6283.18531), (t - 6283.18531 : F32), t)

# A packed panel click (256 + 4 * (y * 300 + x) + panel) starts that
# panel's reaction at the clicked local point.
def react.panel(panel: U32, +x: U32, +y: U32, s: El) -> El:
  match panel:
    case 0:
      El{t, e, w, f, a, left, paced, last} = s
      El{t, u32_reaction_make(48, x, y), w, f, a, left, paced, last}
    case 1:
      El{t, e, w, f, a, left, paced, last} = s
      El{t, e, u32_reaction_make(60, x, y), f, a, left, paced, last}
    case 2:
      El{t, e, w, f, a, left, paced, last} = s
      El{t, e, w, u32_reaction_make(45, x, y), a, left, paced, last}
    case _:
      El{t, e, w, f, a, left, paced, last} = s
      El{t, e, w, f, u32_reaction_make(60, x, y), left, paced, last}

def react.go(click: Bool, +k: U32, s: El) -> El:
  match click:
    case True{}:
      +payload = (k - 256 : U32)
      +cell = (payload / 4 : U32)
      react.panel((payload % 4 : U32), (cell % 300 : U32), (cell / 300 : U32), s)
    case False{}:
      s

def react(+k: U32, s: El) -> El:
  react.go(U32.is_gt(k, 255), k, s)

# One 33 ms frame: the clock moves and every reaction cools.
def advance(s: El, +now: U32) -> El:
  El{+t, +e, +w, +f, +a, +left, paced, last} = s
  El{twrap((t + 0.033 : F32)), u32_cool(e), u32_cool(w), u32_cool(f), u32_cool(a), (left - 1 : U32), paced, now}

def advance.at(due: Bool, s: El, +now: U32) -> El:
  match due:
    case True{}:
      advance(s, now)
    case False{}:
      s

def tick.paced(over: Bool, paced: Bool, s: El, +last: U32) -> IO(Maybe<El>):
  match over paced:
    case True{} _:
      IO.pure(Maybe<El>, None{})
    case False{} True{}:
      do IO<Maybe<El>>:
        +now : U32 <- Clock.now_ms()
        return Some{advance.at(U32.is_ge((now - last : U32), 33), s, now)}
    case False{} False{}:
      IO.pure(Maybe<El>, Some{advance(s, 0)})

def tick.run(s: El) -> IO(Maybe<El>):
  El{t, e, w, f, a, +left, +paced, +last} = s
  tick.paced(U32.is_eq(left, 0), paced, El{t, e, w, f, a, left, paced, last}, last)

def tick.key(quit: Bool, +k: U32, s: El) -> IO(Maybe<El>):
  match quit:
    case True{}:
      IO.pure(Maybe<El>, None{})
    case False{}:
      tick.run(react(k, s))

# A click reacts at once; time advances once per 33 ms; q or closing
# the window quits.
def tick(events: List<Event>, s: El) -> IO(Maybe<El>):
  +k = GFX.panel_event(events)
  tick.key(U32.is_eq(k, 113) || U32.is_eq(k, 81), k, s)

# ---------------------------------------------------------------- headless probe

def check(name: String, +got: U32, +want: U32) -> IO(Unit):
  IO.print(Bool.pick(String, U32.is_eq(got, want), "ok   ", "FAIL ") ++ name ++ ": "
    ++ U32.show(got) ++ " (want " ++ U32.show(want) ++ ")")

# The largest |fsin(x) - F32.sin(x)| over n samples from x0 by dx.
def sin_err(n: Nat, +x: F32, +dx: F32, +worst: F32) -> F32:
  match n:
    case 0n:
      worst
    case 1n+k:
      sin_err(k, (x + dx : F32), dx, F32.max(worst, f32_abs((fsin(x) - F32.sin(x) : F32))))

def replicate(n: Nat) -> List<List<Event>>:
  match n:
    case 0n:
      Nil{}
    case 1n+k:
      Nil{} <> replicate(k)

def click(+x: F32, +y: F32) -> List<Event>:
  [Press{0, Tool.Mouse{}, x, y, 0, 0, True{}}, Press{0, Tool.Mouse{}, x, y, 0, 0, False{}}]

def probe.state(+name: String, r: Maybe<El>, +want_e: U32, +want_w: U32, +want_f: U32, +want_a: U32) -> IO(Unit):
  match r:
    case None{}:
      IO.print("FAIL " ++ name ++ ": the app quit")
    case Some{El{t, +e, +w, +f, +a, left, paced, last}}:
      do IO<Unit>:
        check(name ++ " earth", e, want_e)
        check(name ++ " water", w, want_w)
        check(name ++ " fire", f, want_f)
        check(name ++ " air", a, want_a)

def probe.quit(r: Maybe<El>) -> IO(Unit):
  match r:
    case None{}:
      IO.print("ok   q quits")
    case Some{s}:
      IO.print("FAIL q did not quit")

def probe() -> IO(Unit):
  +calm = GFX.image(10n, scene(0.0, 0, 0, 0, 0))
  +hit = GFX.image(10n, scene(1.0, u32_reaction_make(48, 150, 70), u32_reaction_make(60, 150, 70),
    u32_reaction_make(45, 150, 70), u32_reaction_make(60, 150, 70)))
  +s0 = {El{0.0, 0, 0, 0, 0, 4294967295, False{}, 0} : El}
  do IO<Unit>:
    IO.print("elements probe (no window)")
    IO.print("Bhaskara sine vs F32.sin, max error over [-20, 20]: "
      ++ F32.show(sin_err(4000n, (0.0 - 20.0 : F32), 0.01, 0.0)))
    check("background (5,5)", GFX.pixel(10n, calm, 5, 5), 921622)
    check("title B glyph cell (242,16)", GFX.pixel(10n, calm, 242, 16), 15790072)
    check("title gap between letters (266,16)", GFX.pixel(10n, calm, 266, 16), 921622)
    check("earth panel, idle (20,80)", GFX.pixel(10n, calm, 20, 80), 1709839)
    check("earth ground strip (100,220)", GFX.pixel(10n, calm, 100, 220), 4864810)
    check("water panel, idle sky (620,80)", GFX.pixel(10n, calm, 620, 80), 923168)
    check("water pool bottom (500,225)", GFX.pixel(10n, calm, 500, 225), 2977500)
    check("fire panel, idle top (300,244)", GFX.pixel(10n, calm, 300, 244), 1708044)
    check("air panel, idle corner (620,388)", GFX.pixel(10n, calm, 620, 388), 1316378)
    check("earth panel, struck (20,80)", GFX.pixel(10n, hit, 20, 80), 2634274)
    check("water panel, pulled (620,80)", GFX.pixel(10n, hit, 620, 80), 1323088)
    check("fire panel, fed (300,244)", GFX.pixel(10n, hit, 300, 244), 2695198)
    check("air panel, gusting (620,388)", GFX.pixel(10n, hit, 620, 388), 2177379)
    IO.print("calm frame: " ++ U32.show(GFX.leaves(calm)) ++ " leaves (vs 409600 pixels)")
    r1 : Maybe<El> <- App.play(~El, ~App{view, tick},
      [click(100.0, 150.0), click(400.0, 100.0), click(30.0, 300.0), click(600.0, 380.0)], s0)
    probe.state("4 clicks, 4 frames:", r1,
      u32_reaction_make(44, 88, 74), u32_reaction_make(57, 72, 24),
      u32_reaction_make(43, 18, 60), u32_reaction_make(59, 272, 140))
    r2 : Maybe<El> <- App.play(~El, ~App{view, tick}, click(100.0, 150.0) <> replicate(60n), s0)
    probe.state("a click, then 60 frames, cooled:", r2, 0, 0, 0, 0)
    r3 : Maybe<El> <- App.play(~El, ~App{view, tick}, [click(5.0, 5.0), [Key{113, True{}}]], s0)
    probe.quit(r3)

# ---------------------------------------------------------------- main

def run(r: Result<&1, &1, U32 & String, Window>, s: El) -> IO(Unit):
  match r:
    case Fail{e}:
      IO.print("could not open a window")
    case Done{w}:
      App.loop(~El, ~App{view, tick}, 4294967295n, w, s)

def open(s: El) -> IO(Unit):
  do IO<Unit>:
    r : Result<&1, &1, U32 & String, Window> <- Window.open("Bend!", 640, 400)
    run(r, s)

def go(+now: U32, args: List<String>) -> IO(Unit):
  match args:
    case prog <> "--probe" <> rest:
      probe()
    case prog <> a <> rest:
      open(El{0.0, 0, 0, 0, 0, 300, True{}, now})
    case _:
      open(El{0.0, 0, 0, 0, 0, 4294967295, True{}, now})

def main() -> IO(Unit):
  do IO<Unit>:
    args : List<String> <- IO.args()
    +now : U32 <- Clock.now_ms()
    go(now, args)
