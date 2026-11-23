# Headless tests for the aquarium's pure simulation (GUIDE.md section 12).
# They drive main.bend's own transition functions (do_eat, one_tick,
# run_ticks, Aq.press, ...) and print one PASS/FAIL line per check.
#
#   bend test.bend -o /tmp/aquarium_test && /tmp/aquarium_test
import Base
import ./main.bend as A

# A creature at rest: stage, position, size, timer, hunt clock, fed.
type Res is Data:
  Res{name: String, ok: Bool}

def mk(st: A.Stage, x: F32, y: F32, sz: F32, tm: U32, hu: U32, fd: U32) ->
  A.Ent:
  A.Ent{st, x, y, 0.0, 0.0, sz, tm, hu, fd, 1, True{}}

def play(es: +List<A.Ent>) -> A.Aq:
  A.Aq{es, 0, 777, A.Play{}, False{}, 0.0, 0.0, 0, False{}}

def ents_of(+s: A.Aq) -> +List<A.Ent>:
  A.Aq.ents(s)

def eat_es(r: A.EatRes) -> +List<A.Ent>:
  A.EatRes{es, _, _} = r
  es

def eaten(+es: +List<A.Ent>) -> +List<A.Ent>:
  eat_es(A.do_eat(es))

def n(+es: +List<A.Ent>, +sel: U32) -> U32:
  A.count_stage(es, sel)

def first(+es: +List<A.Ent>) -> A.Ent:
  match es:
    case []:
      mk(A.Egg{}, 0.0, 0.0, 0.0, 0, 0, 0)
    case h <> t:
      h

# Sum of sizes (to tell which fish grew).
def sizes(+es: +List<A.Ent>) -> F32:
  match es:
    case []:
      0.0
    case h <> t:
      (A.Ent.size(h) + sizes(t) : F32)

def near(+a: F32, +b: F32) -> Bool:
  (F32.abs((a - b : F32)) < 0.001 : F32)

# Every creature is a number and inside the tank (with a little slack).
def sane(+es: +List<A.Ent>) -> Bool:
  match es:
    case []:
      True{}
    case h <> t:
      +x = A.Ent.x(h)
      +y = A.Ent.y(h)
      F32.is_eq(x, x) && F32.is_eq(y, y) && (0.0 <= x : F32) && (x <= 560.0 : F32)
        && (0.0 <= y : F32) && (y <= 380.0 : F32) && sane(t)

def is_over(ph: A.Phase) -> Bool:
  match ph:
    case A.Over{_, _}:
      True{}
    case _:
      False{}

def over_score(ph: A.Phase) -> U32:
  match ph:
    case A.Over{s, _}:
      s
    case _:
      999

def presses(k: Nat, +s: A.Aq) -> A.Aq:
  match k:
    case 0n:
      s
    case 1n+p:
      presses(p, A.Aq.release(A.Aq.press(330.0, 30.0, s)))

# Feed one adult a fresh prey of stage `ps` k times, each time off its eat
# cooldown; returns the adult.
def feed(k: Nat, +ad: A.Ent, +ps: A.Stage, +psz: F32) -> A.Ent:
  match k:
    case 0n:
      ad
    case 1n+p:
      A.Ent{st, x, y, vx, vy, sz, _, hu, fd, rg, fc} = ad
      feed(p, first(eaten([A.Ent{st, x, y, vx, vy, sz, 22, hu, fd, rg, fc},
        mk(ps, x, y, psz, 0, 0, 0)])), ps, psz)

# Distance between the first two creatures.
def gap(+es: +List<A.Ent>) -> F32:
  match es:
    case []:
      0.0
    case a <> t:
      +b = first(t)
      F32.hypot((A.Ent.x(a) - A.Ent.x(b) : F32), (A.Ent.y(a) - A.Ent.y(b) : F32))

def line(name: String, ok: Bool) -> String:
  match ok:
    case True{}:
      "PASS  " ++ name
    case False{}:
      "FAIL  " ++ name

def tally(+rs: +List<Res>) -> U32:
  match rs:
    case []:
      0
    case r <> t:
      Res{_, ok} = r
      (Bool.to_u32(ok) + tally(t) : U32)

def show_all(+rs: +List<Res>) -> IO(Unit):
  match rs:
    case []:
      IO.pure(Unit, Unit{})
    case r <> t:
      Res{name, ok} = r
      do IO<Unit>:
        IO.print(line(name, ok))
        show_all(t)

def busy() -> A.Aq:
  # start, pour for 120 ticks, let it all live for 1500 more
  +s0 = A.Aq.press(330.0, 30.0, A.Aq.init())
  A.run_ticks(1500n, A.Aq.release(A.run_ticks(120n, s0)))

def tests() -> +List<Res>:
  +hatched = ents_of(A.one_tick(play([mk(A.Egg{}, 100.0, 200.0, 1.0, 149, 0, 0)])))
  +air = first(ents_of(A.one_tick(play([mk(A.Egg{}, 100.0, 20.0, 1.0, 0, 0, 0)]))))
  +sunk = first(ents_of(A.run_ticks(10n, play([mk(A.Egg{}, 100.0, 150.0, 1.0, 0, 0,
    0)]))))
  +fry_up = eaten([mk(A.Fry{}, 100.0, 200.0, 17.0, 22, 0, 11), mk(A.Egg{}, 100.0,
    200.0, 1.0, 0, 0, 0)])
  +juv_up = eaten([mk(A.Juv{}, 100.0, 200.0, 20.0, 22, 220, 4), mk(A.Fry{}, 100.0,
    200.0, 3.0, 0, 0, 0)])
  +brk = A.one_tick(play([mk(A.Adult{}, 100.0, 200.0, 130.0, 22, 220, 0),
    mk(A.Fry{}, 100.0, 200.0, 3.0, 0, 0, 0), mk(A.Adult{}, 400.0, 300.0, 50.0, 0,
    0, 0), mk(A.Fry{}, 450.0, 100.0, 3.0, 0, 0, 0)]))
  +fry_eat = eaten([mk(A.Fry{}, 100.0, 200.0, 3.0, 22, 0, 0), mk(A.Egg{}, 100.0,
    200.0, 1.0, 0, 0, 0)])
  +shared = eaten([mk(A.Fry{}, 100.0, 200.0, 3.0, 22, 0, 0), mk(A.Fry{}, 100.0,
    200.0, 3.0, 22, 0, 0), mk(A.Egg{}, 100.0, 200.0, 1.0, 0, 0, 0)])
  +hatch4 = ents_of(A.run_ticks(160n, play([mk(A.Egg{}, 100.0, 200.0, 1.0, 0, 0, 0),
    mk(A.Egg{}, 200.0, 200.0, 1.0, 0, 0, 0), mk(A.Egg{}, 300.0, 200.0, 1.0, 0, 0,
    0), mk(A.Egg{}, 400.0, 200.0, 1.0, 0, 0, 0)])))
  +b = busy()
  +forage = ents_of(A.run_ticks(30n, play([mk(A.Fry{}, 100.0, 200.0, 3.0, 22, 0, 0),
    mk(A.Egg{}, 100.0, 200.0, 1.0, 0, 0, 0), mk(A.Egg{}, 100.0, 200.0, 1.0, 0, 0,
    0), mk(A.Egg{}, 100.0, 200.0, 1.0, 0, 0, 0), mk(A.Egg{}, 100.0, 200.0, 1.0, 0,
    0, 0), mk(A.Egg{}, 100.0, 200.0, 1.0, 0, 0, 0)])))
  +wander = ents_of(A.run_ticks(2000n, play([mk(A.Fry{}, 100.0, 200.0, 3.0, 0, 0,
    0), mk(A.Fry{}, 300.0, 200.0, 5.0, 0, 0, 0), mk(A.Juv{}, 500.0, 300.0, 5.0,
    0, 0, 0)])))
  +ad_fry = first(eaten([mk(A.Adult{}, 100.0, 200.0, 40.0, 22, 220, 0),
    mk(A.Fry{}, 100.0, 200.0, 3.0, 0, 0, 0)]))
  +ad_juv = eaten([mk(A.Adult{}, 100.0, 200.0, 40.0, 22, 220, 0), mk(A.Juv{},
    100.0, 200.0, 15.0, 0, 0, 0)])
  +ad_egg = eaten([mk(A.Adult{}, 100.0, 200.0, 40.0, 22, 220, 0), mk(A.Egg{},
    100.0, 200.0, 1.0, 0, 0, 0)])
  +juv_fry = first(eaten([mk(A.Juv{}, 100.0, 200.0, 20.0, 22, 220, 0),
    mk(A.Fry{}, 100.0, 200.0, 3.0, 0, 0, 0)]))
  +juv_juv = eaten([mk(A.Juv{}, 100.0, 200.0, 20.0, 22, 220, 0), mk(A.Juv{},
    100.0, 200.0, 8.0, 0, 0, 0)])
  +juv_big_fry = eaten([mk(A.Juv{}, 100.0, 200.0, 5.0, 22, 220, 0), mk(A.Fry{},
    100.0, 200.0, 3.0, 0, 0, 0)])
  +cool = eaten([mk(A.Fry{}, 100.0, 200.0, 3.0, 5, 0, 0), mk(A.Egg{}, 100.0,
    200.0, 1.0, 0, 0, 0)])
  +fall = first(ents_of(A.run_ticks(60n, A.Aq{[mk(A.Adult{}, 100.0, 200.0, 40.0,
    0, 0, 0)], 0, 777, A.Over{1, 0}, False{}, 0.0, 0.0, 0, False{}})))
  +wet = A.Aq.press(130.0, 200.0, A.Aq.init())
  +dry = A.Aq.press(130.0, 30.0, A.Aq.init())
  +gate = eaten([mk(A.Adult{}, 100.0, 200.0, 40.0, 22, 100, 0), mk(A.Fry{}, 100.0,
    200.0, 3.0, 0, 0, 0)])
  +school = ents_of(A.one_tick(play([mk(A.Fry{}, 100.0, 200.0, 3.0, 0, 0, 0),
    mk(A.Fry{}, 140.0, 200.0, 3.0, 0, 0, 0)])))
  +bump = ents_of(A.one_tick(play([mk(A.Juv{}, 100.0, 200.0, 20.0, 0, 0, 0),
    mk(A.Juv{}, 102.0, 200.0, 20.0, 0, 0, 0)])))
  +flood = presses(50n, play([]))
  +pour = A.run_ticks(300n, A.Aq.press(330.0, 30.0, A.Aq.init()))
  +juv_egg = first(eaten([mk(A.Juv{}, 100.0, 200.0, 20.0, 22, 0, 0), mk(A.Egg{},
    100.0, 200.0, 1.0, 0, 0, 0)]))
  +ad_ad = eaten([mk(A.Adult{}, 100.0, 200.0, 40.0, 22, 220, 0), mk(A.Adult{},
    100.0, 200.0, 20.0, 0, 0, 0)])
  +ad4 = feed(4n, mk(A.Adult{}, 100.0, 200.0, 40.0, 22, 220, 0), A.Fry{}, 3.0)
  +ad5 = feed(5n, mk(A.Adult{}, 100.0, 200.0, 40.0, 22, 220, 0), A.Fry{}, 3.0)
  +aj1 = feed(1n, mk(A.Adult{}, 100.0, 200.0, 40.0, 22, 220, 0), A.Juv{}, 10.0)
  +aj2 = feed(2n, mk(A.Adult{}, 100.0, 200.0, 40.0, 22, 220, 0), A.Juv{}, 10.0)
  [Res{"T1  egg -> fry hatch (born size)", U32.is_eq(n(hatched, 1), 1)
      && near(A.Ent.size(first(hatched)), 3.0)},
    Res{"T2  egg falls in air", A.is_egg(air) && (A.Ent.y(air) > 20.0 : F32)},
    Res{"T3  egg sinks (stays egg)", A.is_egg(sunk) && (A.Ent.y(sunk) > 150.0 : F32)},
    Res{"T4  fry -> juvenile after 12 eggs", U32.is_eq(n(fry_up, 2), 1)
      && U32.is_eq(n(fry_up, 4), 0)},
    Res{"T5  juvenile -> adult after 5 fry", U32.is_eq(n(juv_up, 3), 1)
      && U32.is_eq(n(juv_up, 1), 0)},
    Res{"T6  adult grows -> break", is_over(A.Aq.phase(brk))},
    Res{"T7  fry eats egg", U32.is_eq(n(fry_eat, 4), 0)
      && near(A.Ent.size(first(fry_eat)), 4.3)},
    Res{"T8  shared egg -> 1 eater", U32.is_eq(n(shared, 4), 0)
      && near(sizes(shared), 7.3)},
    Res{"T9  break -> game over phase", is_over(A.Aq.phase(brk))
      && Bool.not(A.Aq.pouring(brk))},
    Res{"T10 eggs hatch over time", U32.is_eq(n(hatch4, 1), 4)},
    Res{"T11 busy world stable", sane(ents_of(b)) && (A.count_all(ents_of(b)) > 0 : U32)},
    Res{"T12 fry forages (1 egg / second)", U32.is_eq(n(forage, 4), 3)},
    Res{"T13 no-food wander stable", sane(wander) && U32.is_eq(A.count_all(wander), 3)},
    Res{"T14 juvenile grows from fry", near(A.Ent.size(juv_fry), 22.0)},
    Res{"T15 adult grows gradually (x1.10)", near(A.Ent.size(ad_fry), 44.0)},
    Res{"T16 more meals per stage", (A.FRY_MEALS() > A.JUV_MEALS() : U32)
      && U32.is_eq(n(eaten([mk(A.Fry{}, 100.0, 200.0, 3.0, 22, 0, 10), mk(A.Egg{},
        100.0, 200.0, 1.0, 0, 0, 0)]), 2), 0)},
    Res{"T17 adult eats juvenile", U32.is_eq(n(ad_juv, 2), 0)
      && U32.is_eq(A.Ent.fed(first(ad_juv)), 5)},
    Res{"T18 adult ignores egg", U32.is_eq(n(ad_egg, 4), 1)},
    Res{"T19 juvenile eats fry (hunt clock resets)", U32.is_eq(A.Ent.fed(juv_fry), 1)
      && U32.is_eq(A.Ent.hu(juv_fry), 0)},
    Res{"T20 tier + half-size sanity", U32.is_eq(n(juv_juv, 2), 2)
      && U32.is_eq(n(juv_big_fry, 1), 1) && U32.is_eq(n(ad_ad, 3), 1)},
    Res{"T21 score counts adults only", U32.is_eq(over_score(A.Aq.phase(brk)), 2)},
    Res{"T22 eat cooldown (1/sec)", U32.is_eq(n(cool, 4), 1)},
    Res{"T23 game-over fish fall", near(A.Ent.y(fall), A.FLOOR())},
    Res{"T24 pour only above water", U32.is_eq(n(ents_of(wet), 4), 0)
      && U32.is_eq(n(ents_of(dry), 4), 4)},
    Res{"T25 hunt gate (fish / 10s)", U32.is_eq(n(gate, 1), 1)},
    Res{"T26 hunt clock reset rules", (A.Ent.hu(ad_fry) >= 220 : U32)
      && U32.is_eq(A.Ent.hu(juv_fry), 0)},
    Res{"T27 fry swarm cohesion", (gap(school) < 40.0 : F32)},
    Res{"T28 fish collision push", (gap(bump) > 2.0 : F32)},
    Res{"T29 no entity cap (50 taps)", U32.is_eq(A.count_all(ents_of(flood)), 200)},
    Res{"T30 no entity cap (pour 300 ticks: " ++ U32.show(A.count_all(ents_of(pour)))
      ++ " creatures)", (A.count_all(ents_of(pour)) >= 300 : U32)},
    Res{"T31 juvenile eats egg, no growth", near(A.Ent.size(juv_egg), 20.0)
      && U32.is_eq(A.Ent.fed(juv_egg), 0)},
    Res{"T32 adult eats adult", U32.is_eq(n(ad_ad, 3), 1)
      && near(A.Ent.size(first(ad_ad)), 44.0)},
    Res{"T33 adult cycle: 5 fry", (A.Ent.hu(ad4) >= 220 : U32)
      && U32.is_eq(A.Ent.fed(ad4), 8) && U32.is_eq(A.Ent.hu(ad5), 0)
      && U32.is_eq(A.Ent.fed(ad5), 0)},
    Res{"T34 adult cycle: 2 juveniles", (A.Ent.hu(aj1) >= 220 : U32)
      && U32.is_eq(A.Ent.fed(aj1), 5) && U32.is_eq(A.Ent.hu(aj2), 0)}]

def main() -> IO(Unit):
  +rs = tests()
  do IO<Unit>:
    show_all(rs)
    IO.print(U32.show(tally(rs)) ++ "/34 passing")
