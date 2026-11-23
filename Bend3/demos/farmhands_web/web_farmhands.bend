# Farmhands: a persistent multiplayer LAN farm inspired by the social visiting
# loop of Colheita Feliz. Bend owns authentication decisions, crop time,
# inventory, unlocks, harvesting, theft limits, CSV parsing/serialization, and
# every state transition. The browser renders server snapshots.
#
# Routes (each also answers under the hub prefix /farmhands, which the page
# picks up from its own location):
#   GET  /                         page
#   GET  /api/state/<token>/<farm> authenticated snapshot
#   POST /api/register             username\npassword
#   POST /api/login                username\npassword
#   POST /api/plant                token\nplot\ncrop
#   POST /api/harvest              token\nplot
#   POST /api/steal                token\nowner\nplot
#   POST /api/unlock               token
#
# Hub interface: `Game`, `init() -> IO(Game)` (loads the CSVs) and
# `route(req, game)`; `route` accepts paths with or without `/farmhands`.
#
# build: bend Bend3/demos/farmhands_web/web_farmhands.bend -o Bend3/demos/farmhands_web/build/web_farmhands
# run:   ./Bend3/demos/farmhands_web/build/web_farmhands   (from the repository root)
# env:   FARMHANDS_PORT (default 8093), FARMHANDS_DATA_DIR (default
#        Bend3/demos/farmhands_web/data)
import Base
import ../HTTP.bend as HTTP
import ../Compat.bend as Compat
import ../Clock.bend as Clock
import ./farmhands_logic.bend as L
import ./pbkdf2.bend as Hash

type Credential is Data:
  Credential{name: String, salt: U32, password_hash: String}

type Session is Data:
  Session{token: U32, name: String}

type Paths is Data:
  Paths{credentials: String, farm: String}

# The whole server state (the old `App`).
type Game is Data:
  Game{credentials: List<&2, Credential>, sessions: List<&2, Session>, farm: L.Farm, paths: Paths, clock: WallClock}

# Wall-clock seconds: Base's IO.now is monotonic, which would not survive a
# reboot of the machine holding farm_state.csv, so init reads the Unix time
# once (`date +%s`) and every request adds the monotonic time elapsed since.
type WallClock is Data:
  WallClock{wall0: U32, mono0: U32}

def done(g: Game, r: HTTP.Response) -> IO(Game & HTTP.Response):
  IO.pure(Game & HTTP.Response, (g, r))

def part(values: List<&2, String>, index: Nat) -> String:
  Maybe.default(&2, String, List.get(&2, String, values, index), "")

def num(s: String) -> U32:
  Compat.to_u32(s)

def len(s: String) -> U32:
  U32.from_nat(String.length(s))

def username_char_valid(c: Char) -> Bool:
  +code = Char.to_u32(c)
  ((code >= 48 : U32) && (code <= 57 : U32)) || ((code >= 65 : U32) && (code <= 90 : U32)) ||
  ((code >= 97 : U32) && (code <= 122 : U32)) || U32.is_eq(code, 45) || U32.is_eq(code, 95)

def username_chars_valid(name: String) -> Bool:
  match name:
    case SNil{}:
      True{}
    case SCon{head, tail}:
      username_char_valid(head) && username_chars_valid(tail)

def username_valid(+name: String) -> Bool:
  +n = len(name)
  (n >= 2 : U32) && (n <= 20 : U32) && username_chars_valid(name)

def password_valid(+password: String) -> Bool:
  +n = len(password)
  (n >= 4 : U32) && (n <= 128 : U32)

def credential_find.pick(hit: Bool, +head: Credential, rest: Maybe<&2, Credential>) -> Maybe<&2, Credential>:
  match hit:
    case True{}:
      Some{head}
    case False{}:
      rest

def credential_name(c: Credential) -> String:
  Credential{name, salt, hash} = c
  name

def credential_find(credentials: List<&2, Credential>, +name: String) -> Maybe<&2, Credential>:
  match credentials:
    case Nil{}:
      None{}
    case +head <> tail:
      credential_find.pick(String.eq(credential_name(head), name), head, credential_find(tail, name))

def credential_exists(credentials: List<&2, Credential>, name: String) -> Bool:
  Maybe.is_some(&2, Credential, credential_find(credentials, name))

def session_name.pick(hit: Bool, name: String, rest: String) -> String:
  match hit:
    case True{}:
      name
    case False{}:
      rest

def session_name(sessions: List<&2, Session>, +token: U32) -> String:
  match sessions:
    case Nil{}:
      ""
    case head <> tail:
      Session{stored, name} = head
      session_name.pick((token > 0 : U32) && U32.is_eq(stored, token), name, session_name(tail, token))

def sessions_without_name.pick(hit: Bool, head: Session, rest: List<&2, Session>) -> List<&2, Session>:
  match hit:
    case True{}:
      rest
    case False{}:
      head <> rest

def session_holder(s: Session) -> String:
  Session{token, name} = s
  name

def sessions_without_name(sessions: List<&2, Session>, +name: String) -> List<&2, Session>:
  match sessions:
    case Nil{}:
      Nil{}
    case +head <> tail:
      sessions_without_name.pick(String.eq(session_holder(head), name), head, sessions_without_name(tail, name))

def sessions_login(sessions: List<&2, Session>, token: U32, +name: String) -> List<&2, Session>:
  Session{token, name} <> sessions_without_name(sessions, name)

# CSV credentials
# ===============

def credential_csv_line(credential: Credential) -> String:
  Credential{name, salt, hash} = credential
  String.concat(["C,", name, ",", U32.show(salt), ",", hash, "\n"])

def credentials_csv_rows(credentials: List<&2, Credential>) -> String:
  match credentials:
    case Nil{}:
      ""
    case head <> tail:
      credential_csv_line(head) ++ credentials_csv_rows(tail)

def credentials_csv(credentials: List<&2, Credential>) -> String:
  "kind,username,salt,password_hash\n" ++ credentials_csv_rows(credentials)

def credentials_parse.pick(ok: Bool, +fields: List<&2, String>, rest: List<&2, Credential>) -> List<&2, Credential>:
  match ok:
    case False{}:
      rest
    case True{}:
      Credential{part(fields, 1n), num(part(fields, 2n)), part(fields, 3n)} <> rest

def credentials_parse(lines: List<&2, String>) -> List<&2, Credential>:
  match lines:
    case Nil{}:
      Nil{}
    case line <> tail:
      +fields = String.split(line, ',')
      credentials_parse.pick(String.eq(part(fields, 0n), "C") && U32.is_eq(len(part(fields, 3n)), 64), fields, credentials_parse(tail))

def credentials_from_result(result: Result<&1, &1, U32 & String, String>) -> List<&2, Credential>:
  match result:
    case Done{text}:
      credentials_parse(String.split(text, '\n'))
    case Fail{e}:
      Nil{}

# CSV farm state
# ==============

def player_csv_line(player: L.Player) -> String:
  L.Player{name, coins, unlocked, turnip, carrot, radish, tomato} = player
  String.concat(["P,", name, ",", U32.show(coins), ",", U32.show(unlocked), ",", U32.show(turnip), ",", U32.show(carrot), ",", U32.show(radish), ",", U32.show(tomato), "\n"])

def plot_csv_line(plot: L.Plot) -> String:
  L.Plot{owner, index, crop, planted_at, steals, thieves} = plot
  String.concat(["L,", owner, ",", U32.show(index), ",", U32.show(crop), ",", U32.show(planted_at), ",", U32.show(steals), ",", String.join(thieves, ";"), "\n"])

def theft_csv_line(theft: L.Theft) -> String:
  L.Theft{thief, owner, day, plot, planted_at} = theft
  String.concat(["T,", thief, ",", owner, ",", U32.show(day), ",", U32.show(plot), ",", U32.show(planted_at), "\n"])

def players_csv_rows(players: List<&2, L.Player>) -> String:
  match players:
    case Nil{}:
      ""
    case head <> tail:
      player_csv_line(head) ++ players_csv_rows(tail)

def plots_csv_rows(plots: List<&2, L.Plot>) -> String:
  match plots:
    case Nil{}:
      ""
    case head <> tail:
      plot_csv_line(head) ++ plots_csv_rows(tail)

def thefts_csv_rows(thefts: List<&2, L.Theft>) -> String:
  match thefts:
    case Nil{}:
      ""
    case head <> tail:
      theft_csv_line(head) ++ thefts_csv_rows(tail)

def farm_csv(farm: L.Farm) -> String:
  L.Farm{players, plots, thefts} = farm
  String.concat(["kind,name_or_thief,value1,value2,value3,value4,value5\n", players_csv_rows(players), plots_csv_rows(plots), thefts_csv_rows(thefts)])

def nonempty_strings(values: List<&2, String>) -> List<&2, String>:
  match values:
    case Nil{}:
      Nil{}
    case +head <> tail:
      +rest = nonempty_strings(tail)
      Bool.pick(List<&2, String>, String.is_empty(head), rest, head <> rest)

def farm_parse_line.kind(+kind: String, +fields: List<&2, String>, farm: L.Farm) -> L.Farm:
  L.Farm{+players, +plots, +thefts} = farm
  Bool.pick(L.Farm, String.eq(kind, "P"),
    L.Farm{L.Player{part(fields, 1n), num(part(fields, 2n)), num(part(fields, 3n)), num(part(fields, 4n)), num(part(fields, 5n)), num(part(fields, 6n)), num(part(fields, 7n))} <> players, plots, thefts},
  Bool.pick(L.Farm, String.eq(kind, "L"),
    L.Farm{players, L.Plot{part(fields, 1n), num(part(fields, 2n)), num(part(fields, 3n)), num(part(fields, 4n)), num(part(fields, 5n)), nonempty_strings(String.split(part(fields, 6n), ';'))} <> plots, thefts},
  Bool.pick(L.Farm, String.eq(kind, "T"),
    L.Farm{players, plots, L.Theft{part(fields, 1n), part(fields, 2n), num(part(fields, 3n)), num(part(fields, 4n)), num(part(fields, 5n))} <> thefts},
    L.Farm{players, plots, thefts})))

def farm_parse_line(+fields: List<&2, String>, farm: L.Farm) -> L.Farm:
  farm_parse_line.kind(part(fields, 0n), fields, farm)

def farm_parse(lines: List<&2, String>) -> L.Farm:
  match lines:
    case Nil{}:
      L.farm_new()
    case line <> tail:
      farm_parse_line(String.split(line, ','), farm_parse(tail))

def farm_from_result(result: Result<&1, &1, U32 & String, String>) -> L.Farm:
  match result:
    case Done{text}:
      farm_parse(String.split(text, '\n'))
    case Fail{e}:
      L.farm_new()

def farm_ensure_credentials(credentials: List<&2, Credential>, farm: L.Farm) -> L.Farm:
  match credentials:
    case Nil{}:
      farm
    case head <> tail:
      L.farm_add_player(farm_ensure_credentials(tail, farm), credential_name(head))

# JSON snapshots
# ==============

def player_json(player: L.Player) -> String:
  L.Player{name, coins, unlocked, turnip, carrot, radish, tomato} = player
  String.concat([
    "{\"name\":", HTTP.quoted(name), ",\"coins\":", U32.show(coins), ",\"unlocked\":", U32.show(unlocked),
    ",\"inventory\":{\"turnip\":", U32.show(turnip), ",\"carrot\":", U32.show(carrot), ",\"radish\":", U32.show(radish), ",\"tomato\":", U32.show(tomato), "}}"])

def crop_remaining_ms(ready: Bool, +duration: U32, +elapsed: U32) -> U32:
  match ready:
    case True{}:
      0
    case False{}:
      ((duration - elapsed : U32) * 1000 : U32)

def users_list(players: List<&2, L.Player>) -> List<&2, String>:
  match players:
    case Nil{}:
      Nil{}
    case head <> tail:
      HTTP.quoted(L.player_name(head)) <> users_list(tail)

def owner_name(players: List<&2, L.Player>, +requested: String, fallback: String) -> String:
  Bool.pick(String, L.player_exists(players, requested), requested, fallback)

def empty_plot_json(index: U32, locked: Bool) -> String:
  String.concat(["{\"index\":", U32.show(index), ",\"locked\":", U32.show(Bool.to_u32(locked)), ",\"crop\":0,\"stage\":0}"])

def planted_plot_json(+plot: L.Plot, +viewer: String, thefts: List<&2, L.Theft>, +now: U32) -> String:
  L.Plot{+owner, index, +crop, +planted_at, +steals, thieves} = plot
  +ready = L.crop_ready(plot, now)
  +elapsed = (now - planted_at : U32)
  +remaining = crop_remaining_ms(ready, L.crop_duration(crop), elapsed)
  +daily = L.theft_count(thefts, viewer, owner, L.current_day(now))
  +mine = String.eq(viewer, owner)
  +can_steal = ready && Bool.not(mine) && L.steal_slot_open(steals) && Bool.not(L.string_member(thieves, viewer)) && L.daily_slot_open(daily)
  String.concat([
    "{\"index\":", U32.show(index), ",\"locked\":0,\"crop\":", U32.show(crop), ",\"cropName\":", HTTP.quoted(L.crop_name(crop)),
    ",\"stage\":", U32.show(L.crop_stage(plot, now)), ",\"ready\":", U32.show(Bool.to_u32(ready)),
    ",\"remainingMs\":", U32.show(remaining), ",\"steals\":", U32.show(steals), ",\"yield\":", U32.show(L.yield_remaining(steals)),
    ",\"canSteal\":", U32.show(Bool.to_u32(can_steal)), ",\"canHarvest\":", U32.show(Bool.to_u32(ready && mine)), "}"])

def plot_slot_found(found: Maybe<&2, L.Plot>, +index: U32, viewer: String, thefts: List<&2, L.Theft>, now: U32) -> String:
  match found:
    case None{}:
      empty_plot_json(index, False{})
    case Some{plot}:
      planted_plot_json(plot, viewer, thefts, now)

def plot_slot_json(locked: Bool, plots: List<&2, L.Plot>, thefts: List<&2, L.Theft>, +owner: String, viewer: String, +index: U32, now: U32) -> String:
  match locked:
    case True{}:
      empty_plot_json(index, True{})
    case False{}:
      plot_slot_found(L.plot_find(plots, owner, index), index, viewer, thefts, now)

# The 12 plot slots, index counting up while the Nat fuel counts down.
def plot_slots(fuel: Nat, +plots: List<&2, L.Plot>, +thefts: List<&2, L.Theft>, +owner: String, +viewer: String, +unlocked: U32, +index: U32, +now: U32) -> List<&2, String>:
  match fuel:
    case 0n:
      Nil{}
    case 1n+f:
      plot_slot_json((index >= unlocked : U32), plots, thefts, owner, viewer, index, now) <> plot_slots(f, plots, thefts, owner, viewer, unlocked, (index + 1 : U32), now)

def state_json.players(viewer_found: Maybe<&2, L.Player>, owner_found: Maybe<&2, L.Player>, +farm: L.Farm, +viewer: String, +token: U32, +now: U32, +ok: Bool, +note: String, +amount: U32) -> String:
  match viewer_found:
    case None{}:
      "{\"ok\":0,\"note\":\"Session expired. Sign in again.\"}"
    case Some{viewer_player}:
      match owner_found:
        case None{}:
          "{\"ok\":0,\"note\":\"Farm not found.\"}"
        case Some{owner_player}:
          L.Player{+owner_value, owner_coins, +unlocked, turnip, carrot, radish, tomato} = owner_player
          L.Farm{players, plots, thefts} = farm
          String.concat([
            "{\"ok\":", U32.show(Bool.to_u32(ok)), ",\"note\":", HTTP.quoted(note), ",\"amount\":", U32.show(amount), ",\"token\":", U32.show(token),
            ",\"now\":", U32.show(now), ",\"me\":", player_json(viewer_player), ",\"owner\":", HTTP.quoted(owner_value),
            ",\"users\":[", String.join(users_list(players), ","), "]",
            ",\"plots\":[", String.join(plot_slots(12n, plots, thefts, owner_value, viewer, unlocked, 0, now), ","), "]}"])

def state_json(+farm: L.Farm, +viewer: String, +token: U32, requested_owner: String, +now: U32, +ok: Bool, +note: String, +amount: U32) -> String:
  L.Farm{+players, plots, thefts} = farm
  +selected = owner_name(players, requested_owner, viewer)
  state_json.players(L.player_find(players, viewer), L.player_find(players, selected), farm, viewer, token, now, ok, note, amount)

def app_reply(+g: Game, viewer: String, token: U32, owner: String, now: U32, ok: Bool, note: String, amount: U32) -> IO(Game & HTTP.Response):
  Game{credentials, sessions, farm, paths, clock} = g
  done(g, HTTP.json(state_json(farm, viewer, token, owner, now, ok, note, amount)))

def auth_reply(g: Game, note: String) -> IO(Game & HTTP.Response):
  done(g, HTTP.json("{\"ok\":0,\"note\":" ++ HTTP.quoted(note) ++ "}"))

# Persistence and authentication
# ==============================

def write_text.wrote(m: File & Result<&1, &1, U32 & String, Unit>) -> IO(Bool):
  (f, r) = m
  do IO<Bool>:
    File.close(f)
    return Result.is_done(&1, &1, U32 & String, Unit, r)

def write_text.opened(r: Result<&1, &1, U32 & String, File>, text: String) -> IO(Bool):
  match r:
    case Fail{e}:
      IO.pure(Bool, False{})
    case Done{f}:
      IO.bind(File & Result<&1, &1, U32 & String, Unit>, Bool, File.write(f, text), write_text.wrote)

# Replaces a file's whole content; True once it is written.
def write_text(path: String, text: String) -> IO(Bool):
  IO.bind(Result<&1, &1, U32 & String, File>, Bool, File.open(path, "w"), r => write_text.opened(r, text))

def default_data_dir() -> String:
  "Bend3/demos/farmhands_web/data"

def paths_in(directory: String) -> Paths:
  +d = directory
  Paths{d ++ "/credentials.csv", d ++ "/farm_state.csv"}

def paths_from_env(result: Result<&1, &1, U32 & String, String>) -> Paths:
  match result:
    case Done{+directory}:
      paths_in(Bool.pick(String, String.is_empty(directory), default_data_dir(), directory))
    case Fail{e}:
      paths_in(default_data_dir())

def app_from_loaded(clock: WallClock, paths: Paths, credential_result: Result<&1, &1, U32 & String, String>, farm_result: Result<&1, &1, U32 & String, String>) -> Game:
  +credentials = credentials_from_result(credential_result)
  Game{credentials, Nil{}, farm_ensure_credentials(credentials, farm_from_result(farm_result)), paths, clock}

def load_app(clock: WallClock, +paths: Paths) -> IO(Game):
  Paths{credential_path, farm_path} = paths
  do IO<Game>:
    credential_result : Result<&1, &1, U32 & String, String> <- HTTP.read_text(credential_path)
    farm_result : Result<&1, &1, U32 & String, String> <- HTTP.read_text(farm_path)
    return app_from_loaded(clock, paths, credential_result, farm_result)

def save_farm_result(saved: Bool, +old_app: Game, +new_app: Game, viewer: String, token: U32, owner: String, now: U32, note: String, amount: U32) -> IO(Game & HTTP.Response):
  match saved:
    case True{}:
      app_reply(new_app, viewer, token, owner, now, True{}, note, amount)
    case False{}:
      app_reply(old_app, viewer, token, owner, now, False{}, "The action was rejected because farm_state.csv could not be saved.", 0)

def save_action(+old_app: Game, +new_app: Game, +viewer: String, +token: U32, +owner: String, +now: U32, +note: String, +amount: U32) -> IO(Game & HTTP.Response):
  Game{credentials, sessions, farm, Paths{credential_path, farm_path}, clock} = new_app
  do IO<Game & HTTP.Response>:
    saved : Bool <- write_text(farm_path, farm_csv(farm))
    save_farm_result(saved, old_app, new_app, viewer, token, owner, now, note, amount)

def apply_action.ok(ok: Bool, +g: Game, new_farm: L.Farm, +viewer: String, +token: U32, +owner: String, +now: U32, +note: String, +amount: U32) -> IO(Game & HTTP.Response):
  match ok:
    case False{}:
      app_reply(g, viewer, token, owner, now, False{}, note, 0)
    case True{}:
      Game{credentials, sessions, old_farm, paths, clock} = g
      save_action(g, Game{credentials, sessions, new_farm, paths, clock}, viewer, token, owner, now, note, amount)

def apply_action(+g: Game, action: L.FarmAction, +viewer: String, +token: U32, +owner: String, +now: U32) -> IO(Game & HTTP.Response):
  L.FarmAction{new_farm, ok, note, amount} = action
  apply_action.ok(ok, g, new_farm, viewer, token, owner, now, note, amount)

def register_saved(credentials_ok: Bool, farm_ok: Bool, +old_app: Game, +new_app: Game, +name: String, +token: U32, +now: U32) -> IO(Game & HTTP.Response):
  match credentials_ok:
    case False{}:
      auth_reply(old_app, "Account not created: credentials.csv could not be saved.")
    case True{}:
      match farm_ok:
        case False{}:
          auth_reply(old_app, "Account not created: farm_state.csv could not be saved.")
        case True{}:
          app_reply(new_app, name, token, name, now, True{}, "Account created.", 0)

def register_hashed(+g: Game, +name: String, +salt: U32, +hash: String, +token: U32, +now: U32) -> IO(Game & HTTP.Response):
  Game{credentials, sessions, farm, +paths, clock} = g
  Paths{credential_path, farm_path} = paths
  +new_credentials = {Credential{name, salt, hash} <> credentials : List<&2, Credential>}
  +new_farm = L.farm_add_player(farm, name)
  +new_app = {Game{new_credentials, sessions_login(sessions, token, name), new_farm, paths, clock} : Game}
  do IO<Game & HTTP.Response>:
    credentials_ok : Bool <- write_text(credential_path, credentials_csv(new_credentials))
    farm_ok : Bool <- write_text(farm_path, farm_csv(new_farm))
    register_saved(credentials_ok, farm_ok, g, new_app, name, token, now)

def register.go(ok: Bool, +g: Game, +name: String, +password: String, +now: U32) -> IO(Game & HTTP.Response):
  match ok:
    case False{}:
      auth_reply(g, "Use a unique 2–20 character name containing letters, digits, - or _, and a 4–128 character password.")
    case True{}:
      do IO<Game & HTTP.Response>:
        +salt : U32 <- IO.try(U32, IO.random_u32())
        +hash : String = Hash.password_hash(password, salt)
        word : U32 <- IO.try(U32, IO.random_u32())
        register_hashed(g, name, salt, hash, (word + 1 : U32), now)

def register(+g: Game, +parts: List<&2, String>, +now: U32) -> IO(Game & HTTP.Response):
  Game{credentials, sessions, farm, paths, clock} = g
  +name = part(parts, 0n)
  +password = part(parts, 1n)
  register.go(username_valid(name) && password_valid(password) && Bool.not(credential_exists(credentials, name)), g, name, password, now)

def login_checked(same: Bool, +g: Game, +stored: String, +now: U32) -> IO(Game & HTTP.Response):
  match same:
    case False{}:
      auth_reply(g, "Invalid username or password.")
    case True{}:
      Game{credentials, sessions, farm, paths, clock} = g
      do IO<Game & HTTP.Response>:
        word : U32 <- IO.try(U32, IO.random_u32())
        +token : U32 = (word + 1 : U32)
        app_reply(Game{credentials, sessions_login(sessions, token, stored), farm, paths, clock}, stored, token, stored, now, True{}, "Welcome back.", 0)

def login_hash(+g: Game, credential: Credential, password: String, +now: U32) -> IO(Game & HTTP.Response):
  Credential{+stored, salt, +expected} = credential
  login_checked(String.eq(Hash.password_hash(password, salt), expected), g, stored, now)

def login.found(found: Maybe<&2, Credential>, +g: Game, +password: String, +now: U32) -> IO(Game & HTTP.Response):
  match found:
    case None{}:
      auth_reply(g, "Invalid username or password.")
    case Some{credential}:
      login_hash(g, credential, password, now)

def login(+g: Game, +parts: List<&2, String>, +now: U32) -> IO(Game & HTTP.Response):
  Game{credentials, sessions, farm, paths, clock} = g
  login.found(credential_find(credentials, part(parts, 0n)), g, part(parts, 1n), now)

# HTTP actions and routing
# ========================

def actor_of(+g: Game, +token: U32) -> String:
  Game{credentials, sessions, farm, paths, clock} = g
  session_name(sessions, token)

def state_get(+g: Game, +token: U32, +requested: String, +now: U32) -> IO(Game & HTTP.Response):
  +viewer = actor_of(g, token)
  Bool.pick(IO(Game & HTTP.Response), String.is_empty(viewer),
    auth_reply(g, "Session expired. Sign in again."),
    app_reply(g, viewer, token, requested, now, True{}, "", 0))

# What a signed-in action does: 1 plant, 2 harvest, 3 steal, 4 unlock.
def act(code: U32, +g: Game, +actor: String, +token: U32, +parts: List<&2, String>, +now: U32) -> IO(Game & HTTP.Response):
  match code:
    case 1:
      Game{credentials, sessions, farm, paths, clock} = g
      apply_action(g, L.farm_plant(farm, actor, num(part(parts, 1n)), num(part(parts, 2n)), now), actor, token, actor, now)
    case 2:
      Game{credentials, sessions, farm, paths, clock} = g
      apply_action(g, L.farm_harvest(farm, actor, num(part(parts, 1n)), now), actor, token, actor, now)
    case 3:
      Game{credentials, sessions, farm, paths, clock} = g
      +owner = part(parts, 1n)
      apply_action(g, L.farm_steal(farm, actor, owner, num(part(parts, 2n)), now), actor, token, owner, now)
    case other:
      Game{credentials, sessions, farm, paths, clock} = g
      apply_action(g, L.farm_unlock(farm, actor), actor, token, actor, now)

def act_note(code: U32) -> String:
  match code:
    case 1:
      "Sign in before planting."
    case 2:
      "Sign in before harvesting."
    case 3:
      "Sign in before visiting farms."
    case other:
      "Sign in before unlocking land."

def signed_in(+code: U32, +g: Game, +parts: List<&2, String>, +now: U32) -> IO(Game & HTTP.Response):
  +token = num(part(parts, 0n))
  +actor = actor_of(g, token)
  Bool.pick(IO(Game & HTTP.Response), String.is_empty(actor),
    auth_reply(g, act_note(code)),
    act(code, g, actor, token, parts, now))

def post_code(+name: String) -> U32:
  Bool.pick(U32, String.eq(name, "register"), 1,
  Bool.pick(U32, String.eq(name, "login"), 2,
  Bool.pick(U32, String.eq(name, "plant"), 3,
  Bool.pick(U32, String.eq(name, "harvest"), 4,
  Bool.pick(U32, String.eq(name, "steal"), 5,
  Bool.pick(U32, String.eq(name, "unlock"), 6, 0))))))

def api_post(code: U32, +body: String, +g: Game, +now: U32) -> IO(Game & HTTP.Response):
  match code:
    case 1:
      register(g, HTTP.body_lines(body), now)
    case 2:
      login(g, HTTP.body_lines(body), now)
    case 3:
      signed_in(1, g, HTTP.body_lines(body), now)
    case 4:
      signed_in(2, g, HTTP.body_lines(body), now)
    case 5:
      signed_in(3, g, HTTP.body_lines(body), now)
    case 6:
      signed_in(4, g, HTTP.body_lines(body), now)
    case other:
      done(g, HTTP.not_found())

# 1 GET state, 2 POST action, 0 anything else (405).
def api_kind(+method: String, +name: String) -> U32:
  Bool.pick(U32, String.eq(name, "state") && String.eq(method, "GET"), 1,
  Bool.pick(U32, String.eq(method, "POST"), 2, 0))

def api_route(kind: U32, +name: String, +args: List<&2, String>, +body: String, +g: Game, +now: U32) -> IO(Game & HTTP.Response):
  match kind:
    case 1:
      state_get(g, num(part(args, 0n)), HTTP.url_decode(part(args, 1n)), now)
    case 2:
      api_post(post_code(name), body, g, now)
    case other:
      done(g, HTTP.method_not_allowed())

def index_page(g: Game) -> IO(Game & HTTP.Response):
  do IO<Game & HTTP.Response>:
    r : HTTP.Response <- HTTP.file("Bend3/demos/farmhands_web/index.html")
    return (g, r)

def unprefix(segs: List<&2, String>) -> List<&2, String>:
  match segs:
    case Nil{}:
      Nil{}
    case +h <> +t:
      Bool.pick(List<&2, String>, String.eq(h, "farmhands"), t, h <> t)

def route.segs(segs: List<&2, String>, +method: String, +body: String, +g: Game, +now: U32) -> IO(Game & HTTP.Response):
  match segs:
    case Nil{}:
      index_page(g)
    case "api" <> +name <> args:
      api_route(api_kind(method, name), name, args, body, g, now)
    case other:
      done(g, HTTP.not_found())

# `now` is wall-clock seconds.
def route_at(req: HTTP.Request, g: Game, now: U32) -> IO(Game & HTTP.Response):
  HTTP.Request{method, target, headers, body} = req
  route.segs(unprefix(HTTP.segments(target)), method, body, g, now)

def wall_now(clock: WallClock, mono: U32) -> U32:
  WallClock{wall0, mono0} = clock
  (wall0 + (mono - mono0 : U32) / 1000 : U32)

def game_clock(+g: Game) -> WallClock:
  Game{credentials, sessions, farm, paths, clock} = g
  clock

def route.clocked(req: HTTP.Request, +g: Game) -> IO(Game & HTTP.Response):
  do IO<Game & HTTP.Response>:
    mono : U32 <- Clock.now_ms()
    route_at(req, g, wall_now(game_clock(g), mono))

def route(req: HTTP.Request, g: Game) -> IO(Game & HTTP.Response):
  route.clocked(req, g)

# Pure routing classifier used by the regression suite: 1 page, 2 API, 3
# anything else (also under /farmhands).
def route_path_class.go(segs: List<&2, String>) -> U32:
  match segs:
    case Nil{}:
      1
    case "api" <> name <> args:
      2
    case other:
      3

def route_path_class(target: String) -> U32:
  route_path_class.go(unprefix(HTTP.segments(target)))

# Startup
# =======

# Loads both CSVs (FARMHANDS_DATA_DIR or the default directory) and writes
# them back normalized, as the old server did before listening.
def init.save(+g: Game) -> IO(Game):
  Game{credentials, sessions, farm, Paths{credential_path, farm_path}, clock} = g
  do IO<Game>:
    a : Bool <- write_text(credential_path, credentials_csv(credentials))
    b : Bool <- write_text(farm_path, farm_csv(farm))
    return g

def unix_seconds(r: Result<&1, &1, U32 & String, U32 & (String & String)>) -> U32:
  match r:
    case Done{(status, (out, err))}:
      Compat.to_u32(String.trim(out))
    case Fail{e}:
      0

def init() -> IO(Game):
  do IO<Game>:
    mono0 : U32 <- Clock.now_ms()
    date : Result<&1, &1, U32 & String, U32 & (String & String)> <- Process.run("date", ["+%s"], "", 64, 5000)
    dir : Result<&1, &1, U32 & String, String> <- IO.get_env("FARMHANDS_DATA_DIR")
    g : Game <- load_app(WallClock{unix_seconds(date), mono0}, paths_from_env(dir))
    init.save(g)

def port_from_env(result: Result<&1, &1, U32 & String, String>) -> U32:
  match result:
    case Done{text}:
      +parsed = num(text)
      Bool.pick(U32, U32.is_zero(parsed), 8093, parsed)
    case Fail{e}:
      8093

def main.listen(r: Result<&1, &1, U32 & String, Listener>, +port: U32, g: Game) -> IO(Unit):
  match r:
    case Fail{e}:
      IO.print_err("Farmhands could not listen on the selected port.")
    case Done{l}:
      do IO<Unit>:
        IO.print("Farmhands listening on 0.0.0.0:" ++ U32.show(port) ++ "\nopen http://<server-lan-ip>:" ++ U32.show(port))
        HTTP.serve_on(~Game, ~route, l, g)

def main() -> IO(Unit):
  do IO<Unit>:
    port_text : Result<&1, &1, U32 & String, String> <- IO.get_env("FARMHANDS_PORT")
    +port : U32 = port_from_env(port_text)
    g : Game <- init()
    r : Result<&1, &1, U32 & String, Listener> <- TCP.listen("0.0.0.0", port)
    main.listen(r, port, g)
