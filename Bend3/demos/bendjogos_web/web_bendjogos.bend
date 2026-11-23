# BendJogos unified LAN server: one process, one TCP port, all state shared.
#
# Namespaces (each game is its standalone demo source, imported directly):
#   /tic /snake /cells /minecraft /cubeworld2 /poker /belote /club-corvid
#   /duck-hunt /obfuscator /bar /elements /farmhands
#   /social (page) and /api/{register,login,state,chat,invite,...} (social.bend)
#   /games/balloon-defense /games/helicopter   static single-player games
#   /core/...                                  Bend2 Core pages and data (sync_core.mjs)
#   /clustering                                virome clustering analysis page
#
# Ported to Bend 2.0.40: an import alias is now a real namespace, so the hub
# imports every standalone `*_web` demo as a module (`Tic.Game`,
# `Tic.route`, ...) instead of the old generated `modules/*.bend` copies.
# Each demo documents its "Hub interface" in its README.
#
# build: bend Bend3/demos/bendjogos_web/web_bendjogos.bend -o Bend3/demos/bendjogos_web/build/web_bendjogos
# run:   ./Bend3/demos/bendjogos_web/build/web_bendjogos   (from the repository root)
# open:  http://<server-lan-ip>:8090
import Base
import ../HTTP.bend as HTTP
import ../Clock.bend as Clock
import ../tictactoe_web/web_tictactoe.bend as Tic
import ../slither_web/web_slither.bend as Snake
import ../agar_web/web_agar.bend as Cells
import ../minecraft_web/web_minecraft.bend as Mine
import ../cubeworld2_web/web_cubeworld2.bend as Cube
import ../poker_web/web_poker.bend as Poker
import ../belote_web/web_belote.bend as Belote
import ../club_corvid_web/web_club_corvid.bend as Corvid
import ../duck_hunt_web/web_duck_hunt.bend as Duck
import ../bend_obfuscator_web/web_obfuscator.bend as Obf
import ../bar_bench_web/web_bar.bend as Bar
import ../elements_web/web_elements.bend as Elements
import ../farmhands_web/web_farmhands.bend as Farm
import ./social.bend as Social

# A game's state behind one pointer. The native backend flattens a Data
# value into machine words; whole game states side by side (as `put.*` and
# the continuations below hold them) would pass the backend's 247-word
# limit for one segment ("an arity over 247"). A datatype that can hold
# itself is always boxed, so `Held` keeps every field of Platform one word.
type Held<-A: Data> is Data:
  Hold{value: A}
  Again{inner: Held<A>}

def unhold(-A: Data, h: Held<A>) -> A:
  match h:
    case Hold{value}:
      value
    case Again{inner}:
      unhold(A, inner)

type Platform is Data:
  Platform{tic: Held<Tic.Game>, snake: Held<Snake.Game>, cells: Held<Cells.Game>, mine: Held<Mine.Game>, cube: Held<Cube.Game>, poker: Held<Poker.Game>, belote: Held<Belote.Game>, corvid: Held<Corvid.Game>, duck: Held<Duck.Game>, obf: Held<Obf.Game>, bar: Held<Bar.Bar>, elements: Held<Elements.Elements>, farm: Held<Farm.Game>, social: Held<Social.State>}


def done(p: Platform, r: HTTP.Response) -> IO(Platform & HTTP.Response):
  IO.pure(Platform & HTTP.Response, (p, r))

def put.tic(r: Tic.Game & HTTP.Response, snake: Held<Snake.Game>, cells: Held<Cells.Game>, mine: Held<Mine.Game>, cube: Held<Cube.Game>, poker: Held<Poker.Game>, belote: Held<Belote.Game>, corvid: Held<Corvid.Game>, duck: Held<Duck.Game>, obf: Held<Obf.Game>, bar: Held<Bar.Bar>, elements: Held<Elements.Elements>, farm: Held<Farm.Game>, social: Held<Social.State>) -> Platform & HTTP.Response:
  (g, resp) = r
  (Platform{Hold{g}, snake, cells, mine, cube, poker, belote, corvid, duck, obf, bar, elements, farm, social}, resp)

def go.tic(req: HTTP.Request, p: Platform, now: U32) -> IO(Platform & HTTP.Response):
  Platform{g, snake, cells, mine, cube, poker, belote, corvid, duck, obf, bar, elements, farm, social} = p
  IO.bind(Tic.Game & HTTP.Response, Platform & HTTP.Response, Tic.route(req, unhold(Tic.Game, g)),
    r => IO.pure(Platform & HTTP.Response, put.tic(r, snake, cells, mine, cube, poker, belote, corvid, duck, obf, bar, elements, farm, social)))

def put.snake(r: Snake.Game & HTTP.Response, tic: Held<Tic.Game>, cells: Held<Cells.Game>, mine: Held<Mine.Game>, cube: Held<Cube.Game>, poker: Held<Poker.Game>, belote: Held<Belote.Game>, corvid: Held<Corvid.Game>, duck: Held<Duck.Game>, obf: Held<Obf.Game>, bar: Held<Bar.Bar>, elements: Held<Elements.Elements>, farm: Held<Farm.Game>, social: Held<Social.State>) -> Platform & HTTP.Response:
  (g, resp) = r
  (Platform{tic, Hold{g}, cells, mine, cube, poker, belote, corvid, duck, obf, bar, elements, farm, social}, resp)

def go.snake(req: HTTP.Request, p: Platform, now: U32) -> IO(Platform & HTTP.Response):
  Platform{tic, g, cells, mine, cube, poker, belote, corvid, duck, obf, bar, elements, farm, social} = p
  IO.bind(Snake.Game & HTTP.Response, Platform & HTTP.Response, Snake.route_now(req, unhold(Snake.Game, g), now),
    r => IO.pure(Platform & HTTP.Response, put.snake(r, tic, cells, mine, cube, poker, belote, corvid, duck, obf, bar, elements, farm, social)))

def put.cells(r: Cells.Game & HTTP.Response, tic: Held<Tic.Game>, snake: Held<Snake.Game>, mine: Held<Mine.Game>, cube: Held<Cube.Game>, poker: Held<Poker.Game>, belote: Held<Belote.Game>, corvid: Held<Corvid.Game>, duck: Held<Duck.Game>, obf: Held<Obf.Game>, bar: Held<Bar.Bar>, elements: Held<Elements.Elements>, farm: Held<Farm.Game>, social: Held<Social.State>) -> Platform & HTTP.Response:
  (g, resp) = r
  (Platform{tic, snake, Hold{g}, mine, cube, poker, belote, corvid, duck, obf, bar, elements, farm, social}, resp)

def go.cells(req: HTTP.Request, p: Platform, now: U32) -> IO(Platform & HTTP.Response):
  Platform{tic, snake, g, mine, cube, poker, belote, corvid, duck, obf, bar, elements, farm, social} = p
  IO.bind(Cells.Game & HTTP.Response, Platform & HTTP.Response, Cells.route_now(req, unhold(Cells.Game, g), now),
    r => IO.pure(Platform & HTTP.Response, put.cells(r, tic, snake, mine, cube, poker, belote, corvid, duck, obf, bar, elements, farm, social)))

def put.mine(r: Mine.Game & HTTP.Response, tic: Held<Tic.Game>, snake: Held<Snake.Game>, cells: Held<Cells.Game>, cube: Held<Cube.Game>, poker: Held<Poker.Game>, belote: Held<Belote.Game>, corvid: Held<Corvid.Game>, duck: Held<Duck.Game>, obf: Held<Obf.Game>, bar: Held<Bar.Bar>, elements: Held<Elements.Elements>, farm: Held<Farm.Game>, social: Held<Social.State>) -> Platform & HTTP.Response:
  (g, resp) = r
  (Platform{tic, snake, cells, Hold{g}, cube, poker, belote, corvid, duck, obf, bar, elements, farm, social}, resp)

def go.mine(req: HTTP.Request, p: Platform, now: U32) -> IO(Platform & HTTP.Response):
  Platform{tic, snake, cells, g, cube, poker, belote, corvid, duck, obf, bar, elements, farm, social} = p
  IO.bind(Mine.Game & HTTP.Response, Platform & HTTP.Response, Mine.route_at(req, unhold(Mine.Game, g), now),
    r => IO.pure(Platform & HTTP.Response, put.mine(r, tic, snake, cells, cube, poker, belote, corvid, duck, obf, bar, elements, farm, social)))

def put.cube(r: Cube.Game & HTTP.Response, tic: Held<Tic.Game>, snake: Held<Snake.Game>, cells: Held<Cells.Game>, mine: Held<Mine.Game>, poker: Held<Poker.Game>, belote: Held<Belote.Game>, corvid: Held<Corvid.Game>, duck: Held<Duck.Game>, obf: Held<Obf.Game>, bar: Held<Bar.Bar>, elements: Held<Elements.Elements>, farm: Held<Farm.Game>, social: Held<Social.State>) -> Platform & HTTP.Response:
  (g, resp) = r
  (Platform{tic, snake, cells, mine, Hold{g}, poker, belote, corvid, duck, obf, bar, elements, farm, social}, resp)

def go.cube(req: HTTP.Request, p: Platform, now: U32) -> IO(Platform & HTTP.Response):
  Platform{tic, snake, cells, mine, g, poker, belote, corvid, duck, obf, bar, elements, farm, social} = p
  IO.bind(Cube.Game & HTTP.Response, Platform & HTTP.Response, Cube.route_at(req, unhold(Cube.Game, g), now),
    r => IO.pure(Platform & HTTP.Response, put.cube(r, tic, snake, cells, mine, poker, belote, corvid, duck, obf, bar, elements, farm, social)))

def put.poker(r: Poker.Game & HTTP.Response, tic: Held<Tic.Game>, snake: Held<Snake.Game>, cells: Held<Cells.Game>, mine: Held<Mine.Game>, cube: Held<Cube.Game>, belote: Held<Belote.Game>, corvid: Held<Corvid.Game>, duck: Held<Duck.Game>, obf: Held<Obf.Game>, bar: Held<Bar.Bar>, elements: Held<Elements.Elements>, farm: Held<Farm.Game>, social: Held<Social.State>) -> Platform & HTTP.Response:
  (g, resp) = r
  (Platform{tic, snake, cells, mine, cube, Hold{g}, belote, corvid, duck, obf, bar, elements, farm, social}, resp)

def go.poker(req: HTTP.Request, p: Platform, now: U32) -> IO(Platform & HTTP.Response):
  Platform{tic, snake, cells, mine, cube, g, belote, corvid, duck, obf, bar, elements, farm, social} = p
  IO.bind(Poker.Game & HTTP.Response, Platform & HTTP.Response, Poker.route_at("/poker", req, unhold(Poker.Game, g)),
    r => IO.pure(Platform & HTTP.Response, put.poker(r, tic, snake, cells, mine, cube, belote, corvid, duck, obf, bar, elements, farm, social)))

def put.belote(r: Belote.Game & HTTP.Response, tic: Held<Tic.Game>, snake: Held<Snake.Game>, cells: Held<Cells.Game>, mine: Held<Mine.Game>, cube: Held<Cube.Game>, poker: Held<Poker.Game>, corvid: Held<Corvid.Game>, duck: Held<Duck.Game>, obf: Held<Obf.Game>, bar: Held<Bar.Bar>, elements: Held<Elements.Elements>, farm: Held<Farm.Game>, social: Held<Social.State>) -> Platform & HTTP.Response:
  (g, resp) = r
  (Platform{tic, snake, cells, mine, cube, poker, Hold{g}, corvid, duck, obf, bar, elements, farm, social}, resp)

def go.belote(req: HTTP.Request, p: Platform, now: U32) -> IO(Platform & HTTP.Response):
  Platform{tic, snake, cells, mine, cube, poker, g, corvid, duck, obf, bar, elements, farm, social} = p
  IO.bind(Belote.Game & HTTP.Response, Platform & HTTP.Response, Belote.route_at("/belote", req, unhold(Belote.Game, g)),
    r => IO.pure(Platform & HTTP.Response, put.belote(r, tic, snake, cells, mine, cube, poker, corvid, duck, obf, bar, elements, farm, social)))

def put.corvid(r: Corvid.Game & HTTP.Response, tic: Held<Tic.Game>, snake: Held<Snake.Game>, cells: Held<Cells.Game>, mine: Held<Mine.Game>, cube: Held<Cube.Game>, poker: Held<Poker.Game>, belote: Held<Belote.Game>, duck: Held<Duck.Game>, obf: Held<Obf.Game>, bar: Held<Bar.Bar>, elements: Held<Elements.Elements>, farm: Held<Farm.Game>, social: Held<Social.State>) -> Platform & HTTP.Response:
  (g, resp) = r
  (Platform{tic, snake, cells, mine, cube, poker, belote, Hold{g}, duck, obf, bar, elements, farm, social}, resp)

def go.corvid(req: HTTP.Request, p: Platform, now: U32) -> IO(Platform & HTTP.Response):
  Platform{tic, snake, cells, mine, cube, poker, belote, g, duck, obf, bar, elements, farm, social} = p
  IO.bind(Corvid.Game & HTTP.Response, Platform & HTTP.Response, Corvid.route_at(req, unhold(Corvid.Game, g), now),
    r => IO.pure(Platform & HTTP.Response, put.corvid(r, tic, snake, cells, mine, cube, poker, belote, duck, obf, bar, elements, farm, social)))

def put.duck(r: Duck.Game & HTTP.Response, tic: Held<Tic.Game>, snake: Held<Snake.Game>, cells: Held<Cells.Game>, mine: Held<Mine.Game>, cube: Held<Cube.Game>, poker: Held<Poker.Game>, belote: Held<Belote.Game>, corvid: Held<Corvid.Game>, obf: Held<Obf.Game>, bar: Held<Bar.Bar>, elements: Held<Elements.Elements>, farm: Held<Farm.Game>, social: Held<Social.State>) -> Platform & HTTP.Response:
  (g, resp) = r
  (Platform{tic, snake, cells, mine, cube, poker, belote, corvid, Hold{g}, obf, bar, elements, farm, social}, resp)

def go.duck(req: HTTP.Request, p: Platform, now: U32) -> IO(Platform & HTTP.Response):
  Platform{tic, snake, cells, mine, cube, poker, belote, corvid, g, obf, bar, elements, farm, social} = p
  IO.bind(Duck.Game & HTTP.Response, Platform & HTTP.Response, Duck.route(req, unhold(Duck.Game, g)),
    r => IO.pure(Platform & HTTP.Response, put.duck(r, tic, snake, cells, mine, cube, poker, belote, corvid, obf, bar, elements, farm, social)))

def put.obf(r: Obf.Game & HTTP.Response, tic: Held<Tic.Game>, snake: Held<Snake.Game>, cells: Held<Cells.Game>, mine: Held<Mine.Game>, cube: Held<Cube.Game>, poker: Held<Poker.Game>, belote: Held<Belote.Game>, corvid: Held<Corvid.Game>, duck: Held<Duck.Game>, bar: Held<Bar.Bar>, elements: Held<Elements.Elements>, farm: Held<Farm.Game>, social: Held<Social.State>) -> Platform & HTTP.Response:
  (g, resp) = r
  (Platform{tic, snake, cells, mine, cube, poker, belote, corvid, duck, Hold{g}, bar, elements, farm, social}, resp)

def go.obf(req: HTTP.Request, p: Platform, now: U32) -> IO(Platform & HTTP.Response):
  Platform{tic, snake, cells, mine, cube, poker, belote, corvid, duck, g, bar, elements, farm, social} = p
  IO.bind(Obf.Game & HTTP.Response, Platform & HTTP.Response, Obf.route(req, unhold(Obf.Game, g)),
    r => IO.pure(Platform & HTTP.Response, put.obf(r, tic, snake, cells, mine, cube, poker, belote, corvid, duck, bar, elements, farm, social)))

def put.bar(r: Bar.Bar & HTTP.Response, tic: Held<Tic.Game>, snake: Held<Snake.Game>, cells: Held<Cells.Game>, mine: Held<Mine.Game>, cube: Held<Cube.Game>, poker: Held<Poker.Game>, belote: Held<Belote.Game>, corvid: Held<Corvid.Game>, duck: Held<Duck.Game>, obf: Held<Obf.Game>, elements: Held<Elements.Elements>, farm: Held<Farm.Game>, social: Held<Social.State>) -> Platform & HTTP.Response:
  (g, resp) = r
  (Platform{tic, snake, cells, mine, cube, poker, belote, corvid, duck, obf, Hold{g}, elements, farm, social}, resp)

def go.bar(req: HTTP.Request, p: Platform, now: U32) -> IO(Platform & HTTP.Response):
  Platform{tic, snake, cells, mine, cube, poker, belote, corvid, duck, obf, g, elements, farm, social} = p
  IO.bind(Bar.Bar & HTTP.Response, Platform & HTTP.Response, Bar.route(req, unhold(Bar.Bar, g)),
    r => IO.pure(Platform & HTTP.Response, put.bar(r, tic, snake, cells, mine, cube, poker, belote, corvid, duck, obf, elements, farm, social)))

def put.elements(r: Elements.Elements & HTTP.Response, tic: Held<Tic.Game>, snake: Held<Snake.Game>, cells: Held<Cells.Game>, mine: Held<Mine.Game>, cube: Held<Cube.Game>, poker: Held<Poker.Game>, belote: Held<Belote.Game>, corvid: Held<Corvid.Game>, duck: Held<Duck.Game>, obf: Held<Obf.Game>, bar: Held<Bar.Bar>, farm: Held<Farm.Game>, social: Held<Social.State>) -> Platform & HTTP.Response:
  (g, resp) = r
  (Platform{tic, snake, cells, mine, cube, poker, belote, corvid, duck, obf, bar, Hold{g}, farm, social}, resp)

def go.elements(req: HTTP.Request, p: Platform, now: U32) -> IO(Platform & HTTP.Response):
  Platform{tic, snake, cells, mine, cube, poker, belote, corvid, duck, obf, bar, g, farm, social} = p
  IO.bind(Elements.Elements & HTTP.Response, Platform & HTTP.Response, Elements.route(req, unhold(Elements.Elements, g)),
    r => IO.pure(Platform & HTTP.Response, put.elements(r, tic, snake, cells, mine, cube, poker, belote, corvid, duck, obf, bar, farm, social)))

def put.farm(r: Farm.Game & HTTP.Response, tic: Held<Tic.Game>, snake: Held<Snake.Game>, cells: Held<Cells.Game>, mine: Held<Mine.Game>, cube: Held<Cube.Game>, poker: Held<Poker.Game>, belote: Held<Belote.Game>, corvid: Held<Corvid.Game>, duck: Held<Duck.Game>, obf: Held<Obf.Game>, bar: Held<Bar.Bar>, elements: Held<Elements.Elements>, social: Held<Social.State>) -> Platform & HTTP.Response:
  (g, resp) = r
  (Platform{tic, snake, cells, mine, cube, poker, belote, corvid, duck, obf, bar, elements, Hold{g}, social}, resp)

def go.farm(req: HTTP.Request, p: Platform, now: U32) -> IO(Platform & HTTP.Response):
  Platform{tic, snake, cells, mine, cube, poker, belote, corvid, duck, obf, bar, elements, g, social} = p
  IO.bind(Farm.Game & HTTP.Response, Platform & HTTP.Response, Farm.route(req, unhold(Farm.Game, g)),
    r => IO.pure(Platform & HTTP.Response, put.farm(r, tic, snake, cells, mine, cube, poker, belote, corvid, duck, obf, bar, elements, social)))

def put.social(r: Social.State & HTTP.Response, tic: Held<Tic.Game>, snake: Held<Snake.Game>, cells: Held<Cells.Game>, mine: Held<Mine.Game>, cube: Held<Cube.Game>, poker: Held<Poker.Game>, belote: Held<Belote.Game>, corvid: Held<Corvid.Game>, duck: Held<Duck.Game>, obf: Held<Obf.Game>, bar: Held<Bar.Bar>, elements: Held<Elements.Elements>, farm: Held<Farm.Game>) -> Platform & HTTP.Response:
  (g, resp) = r
  (Platform{tic, snake, cells, mine, cube, poker, belote, corvid, duck, obf, bar, elements, farm, Hold{g}}, resp)

def go.social(req: HTTP.Request, p: Platform, now: U32) -> IO(Platform & HTTP.Response):
  Platform{tic, snake, cells, mine, cube, poker, belote, corvid, duck, obf, bar, elements, farm, g} = p
  IO.bind(Social.State & HTTP.Response, Platform & HTTP.Response, Social.route(req, unhold(Social.State, g), now),
    r => IO.pure(Platform & HTTP.Response, put.social(r, tic, snake, cells, mine, cube, poker, belote, corvid, duck, obf, bar, elements, farm)))

# The game mounted at a first path segment, 0 for none.
def mount(+name: String) -> U32:
  Bool.pick(U32, String.eq(name, "tic"), 1,
  Bool.pick(U32, String.eq(name, "snake"), 2,
  Bool.pick(U32, String.eq(name, "cells"), 3,
  Bool.pick(U32, String.eq(name, "minecraft"), 4,
  Bool.pick(U32, String.eq(name, "cubeworld2"), 5,
  Bool.pick(U32, String.eq(name, "poker"), 6,
  Bool.pick(U32, String.eq(name, "belote"), 7,
  Bool.pick(U32, String.eq(name, "club-corvid"), 8,
  Bool.pick(U32, String.eq(name, "duck-hunt"), 9,
  Bool.pick(U32, String.eq(name, "obfuscator"), 10,
  Bool.pick(U32, String.eq(name, "bar"), 11,
  Bool.pick(U32, String.eq(name, "elements"), 12,
  Bool.pick(U32, String.eq(name, "farmhands"), 13,
  0)))))))))))))

def game_route(code: U32, req: HTTP.Request, p: Platform, now: U32) -> IO(Platform & HTTP.Response):
  match code:
    case 1:
      go.tic(req, p, now)
    case 2:
      go.snake(req, p, now)
    case 3:
      go.cells(req, p, now)
    case 4:
      go.mine(req, p, now)
    case 5:
      go.cube(req, p, now)
    case 6:
      go.poker(req, p, now)
    case 7:
      go.belote(req, p, now)
    case 8:
      go.corvid(req, p, now)
    case 9:
      go.duck(req, p, now)
    case 10:
      go.obf(req, p, now)
    case 11:
      go.bar(req, p, now)
    case 12:
      go.elements(req, p, now)
    case 13:
      go.farm(req, p, now)
    case other:
      done(p, HTTP.not_found())


# A page or script of this folder, relative to the repository root.
def asset(p: Platform, name: String) -> IO(Platform & HTTP.Response):
  do IO<Platform & HTTP.Response>:
    r : HTTP.Response <- HTTP.file("Bend3/demos/bendjogos_web/" ++ name)
    return (p, r)

# Core pages (slug -> page) and generated scripts, as copied by sync_core.mjs.
def core_file(+name: String) -> String:
  Bool.pick(String, String.eq(name, "poker"), "poker.html",
  Bool.pick(String, String.eq(name, "belote"), "belote.html",
  Bool.pick(String, String.eq(name, "bend-a-beet"), "bend-a-beet.html",
  Bool.pick(String, String.eq(name, "bendio-3d-land"), "bendio-3d-land.html",
  Bool.pick(String, String.eq(name, "bendy-birds"), "bendy-birds.html",
  Bool.pick(String, String.eq(name, "bend-fishing"), "bend-fishing.html",
  Bool.pick(String, String.eq(name, "bend-aquarium"), "bend-aquarium.html",
  Bool.pick(String, String.eq(name, "bend-landscape"), "bend-landscape.html",
  Bool.pick(String, String.eq(name, "poker_data.js"), name,
  Bool.pick(String, String.eq(name, "belote_data.js"), name,
  Bool.pick(String, String.eq(name, "bend_a_beet_data.js"), name,
  Bool.pick(String, String.eq(name, "bend_a_beet_camera.js"), name,
  Bool.pick(String, String.eq(name, "bendio_data.js"), name,
  Bool.pick(String, String.eq(name, "bendy_birds_data.js"), name,
  Bool.pick(String, String.eq(name, "bendy_birds_result.js"), name,
  Bool.pick(String, String.eq(name, "bend_fishing_data.js"), name,
  Bool.pick(String, String.eq(name, "bend_aquarium_data.js"), name,
  Bool.pick(String, String.eq(name, "landscape_data.js"), name, ""))))))))))))))))))

def core_found.pick(missing: Bool, file: String, p: Platform) -> IO(Platform & HTTP.Response):
  match missing:
    case True{}:
      done(p, HTTP.not_found())
    case False{}:
      asset(p, "core/" ++ file)

def core_found(+file: String, p: Platform) -> IO(Platform & HTTP.Response):
  core_found.pick(String.is_empty(file), file, p)

def core_route(args: List<&2, String>, p: Platform) -> IO(Platform & HTTP.Response):
  match args:
    case Nil{}:
      asset(p, "core/index.html")
    case name <> Nil{}:
      core_found(core_file(name), p)
    case other:
      done(p, HTTP.not_found())

# Exactly one page (`/name` or `/name/`), else 404.
def page_only(args: List<&2, String>, file: String, p: Platform) -> IO(Platform & HTTP.Response):
  match args:
    case Nil{}:
      asset(p, file)
    case other:
      done(p, HTTP.not_found())

def games_route(args: List<&2, String>, p: Platform) -> IO(Platform & HTTP.Response):
  match args:
    case "balloon-defense" <> Nil{}:
      asset(p, "games/balloon_defense.html")
    case "helicopter" <> Nil{}:
      asset(p, "games/helicopter.html")
    case other:
      done(p, HTTP.not_found())

def route.segs(segs: List<&2, String>, req: HTTP.Request, p: Platform, +now: U32) -> IO(Platform & HTTP.Response):
  match segs:
    case Nil{}:
      asset(p, "index.html")
    case "social" <> Nil{}:
      asset(p, "social.html")
    case "social" <> rest:
      go.social(req, p, now)
    case "api" <> rest:
      go.social(req, p, now)
    case "clustering" <> rest:
      page_only(rest, "clustering.html", p)
    case "core" <> rest:
      core_route(rest, p)
    case "games" <> rest:
      games_route(rest, p)
    case +name <> rest:
      game_route(mount(name), req, p, now)

def route(req: HTTP.Request, p: Platform) -> IO(Platform & HTTP.Response):
  HTTP.Request{method, +target, headers, body} = req
  do IO<Platform & HTTP.Response>:
    now : U32 <- Clock.now_ms()
    route.segs(HTTP.segments(target), HTTP.Request{method, target, headers, body}, p, now)

def main.listen(r: Result<&1, &1, U32 & String, Listener>, p: Platform) -> IO(Unit):
  match r:
    case Fail{(code, error)}:
      IO.print_err("listen failed: " ++ error)
    case Done{l}:
      do IO<Unit>:
        IO.print("BendJogos unified server listening on 0.0.0.0:8090\nopen http://<server-lan-ip>:8090 (run from the repository root)")
        HTTP.serve_on(~Platform, ~route, l, p)

def main() -> IO(Unit):
  do IO<Unit>:
    snake : Snake.Game <- Snake.init()
    cells : Cells.Game <- Cells.init()
    poker : Poker.Game <- Poker.init()
    belote : Belote.Game <- Belote.init()
    farm : Farm.Game <- Farm.init()
    r : Result<&1, &1, U32 & String, Listener> <- TCP.listen("0.0.0.0", 8090)
    main.listen(r, Platform{Hold{Tic.init()}, Hold{snake}, Hold{cells}, Hold{Mine.init()}, Hold{Cube.init()}, Hold{poker}, Hold{belote}, Hold{Corvid.init()}, Hold{Duck.init()}, Hold{Obf.init()}, Hold{Bar.init()}, Hold{Elements.init()}, Hold{farm}, Hold{Social.empty()}})
