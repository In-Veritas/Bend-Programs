# Farmhands: a persistent multiplayer LAN farm inspired by the social visiting
# loop of Colheita Feliz. Bend owns authentication decisions, crop time,
# inventory, unlocks, harvesting, theft limits, CSV parsing/serialization, and
# every state transition. The browser renders server snapshots.
#
# Routes:
#   GET  /                         page
#   GET  /api/state/<token>/<farm> authenticated snapshot
#   POST /api/register             username\npassword
#   POST /api/login                username\npassword
#   POST /api/plant                token\nplot\ncrop
#   POST /api/harvest              token\nplot
#   POST /api/steal                token\nowner\nplot
#   POST /api/unlock               token

import List
import String
import Char
import Result
import Pair
import Bytes
import Unit
import IO
import TCP
import HTTP
import JSON
import ./farmhands_logic

type Credential:
  Credential{name: String, salt: U32, password_hash: String}

type Session:
  Session{token: U32, name: String}

type Paths:
  Paths{credentials: String, farm: String}

type App:
  App{credentials: List<Credential>, sessions: List<Session>, farm: Farm, paths: Paths}

type Routed:
  Routed{app: App, response: Response}

type CredentialFound:
  CredentialHere{credential: Credential}
  CredentialMissing{}

def password_hash(password: String, salt: U32) -> IO<String>:
  import ./effs/password_hash.c

def credential_push(value: Credential, values: List<Credential>) -> List<Credential>:
  Cons{value, values}

def session_push(value: Session, values: List<Session>) -> List<Session>:
  Cons{value, values}

def credentials_empty() -> List<Credential>:
  Nil{}

def sessions_empty() -> List<Session>:
  Nil{}

def part(values: List<String>, index: U32) -> String:
  List::head<String>("", List::drop<String>(index, values))

def body_parts(body: Bytes) -> List<String>:
  String::split(Char{10}, Bytes::to_string(body))

def request_body(request: Request) -> Bytes:
  match request:
    case Request{method, path, headers, body}:
      body

def username_char_valid(char: Char) -> U32:
  code = Char::code(char)
  ((code >= 48) && (code <= 57)) || (((code >= 65) && (code <= 90)) || (((code >= 97) && (code <= 122)) || ((code == 45) || (code == 95))))

def username_chars_valid(name: String) -> U32:
  match name:
    case Cons{head, tail}:
      username_char_valid(head) && username_chars_valid(tail)
    case Nil{}:
      1

def username_valid(name: String) -> U32:
  (String::length(name) >= 2) && ((String::length(name) <= 20) && username_chars_valid(name))

def password_valid(password: String) -> U32:
  (String::length(password) >= 4) && (String::length(password) <= 128)

def credential_find(credentials: List<Credential>, name: String) -> CredentialFound:
  match credentials:
    case Cons{head, tail}:
      match head:
        case Credential{stored, salt, hash}:
          match String::eq(stored, name):
            case 0:
              credential_find(tail, name)
            case yes:
              CredentialHere{Credential{stored, salt, hash}}
    case Nil{}:
      CredentialMissing{}

def credential_exists(credentials: List<Credential>, name: String) -> U32:
  match credential_find(credentials, name):
    case CredentialHere{credential}:
      1
    case CredentialMissing{}:
      0

def session_name(sessions: List<Session>, token: U32) -> String:
  match sessions:
    case Cons{head, tail}:
      match head:
        case Session{stored, name}:
          match (token > 0) && (stored == token):
            case 0:
              session_name(tail, token)
            case yes:
              name
    case Nil{}:
      ""

def sessions_without_name(sessions: List<Session>, name: String) -> List<Session>:
  match sessions:
    case Cons{head, tail}:
      match head:
        case Session{token, stored}:
          match String::eq(stored, name):
            case 0:
              session_push(Session{token, stored}, sessions_without_name(tail, name))
            case yes:
              sessions_without_name(tail, name)
    case Nil{}:
      Nil{}

def sessions_login(sessions: List<Session>, token: U32, name: String) -> List<Session>:
  session_push(Session{token, name}, sessions_without_name(sessions, name))

# CSV credentials
# ===============

def credential_csv_line(credential: Credential) -> String:
  match credential:
    case Credential{name, salt, hash}:
      String::flatten(["C,", name, ",", String::from_u32(salt), ",", hash, "\n"])

def credentials_csv_rows(credentials: List<Credential>) -> String:
  match credentials:
    case Cons{head, tail}:
      String::concat(credential_csv_line(head), credentials_csv_rows(tail))
    case Nil{}:
      ""

def credentials_csv(credentials: List<Credential>) -> String:
  String::concat("kind,username,salt,password_hash\n", credentials_csv_rows(credentials))

def credentials_parse(lines: List<String>) -> List<Credential>:
  match lines:
    case Cons{line, tail}:
      fields = String::split(Char{44}, line)
      match String::eq(part(fields, 0), "C") && (String::length(part(fields, 3)) == 64):
        case 0:
          credentials_parse(tail)
        case yes:
          credential_push(
            Credential{part(fields, 1), String::to_u32(part(fields, 2)), part(fields, 3)},
            credentials_parse(tail)
          )
    case Nil{}:
      credentials_empty()

def credentials_from_result(result: Result<String>) -> List<Credential>:
  match result:
    case Done{text}:
      credentials_parse(String::split(Char{10}, text))
    case Fail{code, error}:
      credentials_empty()

# CSV farm state
# ==============

def player_csv_line(player: Player) -> String:
  match player:
    case Player{name, coins, unlocked, turnip, carrot, radish, tomato}:
      String::flatten(["P,",name,",",String::from_u32(coins),",",String::from_u32(unlocked),",",String::from_u32(turnip),",",String::from_u32(carrot),",",String::from_u32(radish),",",String::from_u32(tomato),"\n"])

def plot_csv_line(plot: Plot) -> String:
  match plot:
    case Plot{owner, index, crop, planted_at, steals, thieves}:
      String::flatten(["L,",owner,",",String::from_u32(index),",",String::from_u32(crop),",",String::from_u32(planted_at),",",String::from_u32(steals),",",String::join(";", thieves),"\n"])

def theft_csv_line(theft: Theft) -> String:
  match theft:
    case Theft{thief, owner, day, plot, planted_at}:
      String::flatten(["T,",thief,",",owner,",",String::from_u32(day),",",String::from_u32(plot),",",String::from_u32(planted_at),"\n"])

def players_csv_rows(players: List<Player>) -> String:
  match players:
    case Cons{head, tail}:
      String::concat(player_csv_line(head), players_csv_rows(tail))
    case Nil{}:
      ""

def plots_csv_rows(plots: List<Plot>) -> String:
  match plots:
    case Cons{head, tail}:
      String::concat(plot_csv_line(head), plots_csv_rows(tail))
    case Nil{}:
      ""

def thefts_csv_rows(thefts: List<Theft>) -> String:
  match thefts:
    case Cons{head, tail}:
      String::concat(theft_csv_line(head), thefts_csv_rows(tail))
    case Nil{}:
      ""

def farm_csv(farm: Farm) -> String:
  match farm:
    case Farm{players, plots, thefts}:
      String::flatten([
        "kind,name_or_thief,value1,value2,value3,value4,value5\n",
        players_csv_rows(players), plots_csv_rows(plots), thefts_csv_rows(thefts)
      ])

def nonempty_strings(values: List<String>) -> List<String>:
  match values:
    case Cons{head, tail}:
      match String::length(head) > 0:
        case 0:
          nonempty_strings(tail)
        case yes:
          string_push(head, nonempty_strings(tail))
    case Nil{}:
      Nil{}

def farm_parse_line(fields: List<String>, farm: Farm) -> Farm:
  match farm:
    case Farm{players, plots, thefts}:
      kind = part(fields, 0)
      match String::eq(kind, "P"):
        case 0:
          match String::eq(kind, "L"):
            case 0:
              match String::eq(kind, "T"):
                case 0:
                  Farm{players, plots, thefts}
                case yes:
                  Farm{
                    players, plots,
                    theft_push(Theft{part(fields,1),part(fields,2),String::to_u32(part(fields,3)),String::to_u32(part(fields,4)),String::to_u32(part(fields,5))}, thefts)
                  }
            case yes:
              Farm{
                players,
                plot_push(Plot{part(fields,1),String::to_u32(part(fields,2)),String::to_u32(part(fields,3)),String::to_u32(part(fields,4)),String::to_u32(part(fields,5)),nonempty_strings(String::split(Char{59},part(fields,6)))}, plots),
                thefts
              }
        case yes:
          Farm{
            player_push(Player{part(fields,1),String::to_u32(part(fields,2)),String::to_u32(part(fields,3)),String::to_u32(part(fields,4)),String::to_u32(part(fields,5)),String::to_u32(part(fields,6)),String::to_u32(part(fields,7))}, players),
            plots, thefts
          }

def farm_parse(lines: List<String>) -> Farm:
  match lines:
    case Cons{line, tail}:
      farm_parse_line(String::split(Char{44}, line), farm_parse(tail))
    case Nil{}:
      farm_new()

def farm_from_result(result: Result<String>) -> Farm:
  match result:
    case Done{text}:
      farm_parse(String::split(Char{10}, text))
    case Fail{code, error}:
      farm_new()

def farm_ensure_credentials(credentials: List<Credential>, farm: Farm) -> Farm:
  match credentials:
    case Cons{head, tail}:
      match head:
        case Credential{name, salt, hash}:
          farm_add_player(farm_ensure_credentials(tail, farm), name)
    case Nil{}:
      farm

# JSON snapshots
# ==============

def player_json(player: Player) -> String:
  match player:
    case Player{name, coins, unlocked, turnip, carrot, radish, tomato}:
      String::flatten([
        "{\"name\":",JSON::quoted(name,""),",\"coins\":",String::from_u32(coins),",\"unlocked\":",String::from_u32(unlocked),
        ",\"inventory\":{\"turnip\":",String::from_u32(turnip),",\"carrot\":",String::from_u32(carrot),",\"radish\":",String::from_u32(radish),",\"tomato\":",String::from_u32(tomato),"}}"
      ])

def comma_unless_first(first: U32) -> String:
  match first:
    case 0:
      ","
    case yes:
      ""

def comma_if_more(left: U32) -> String:
  match left:
    case 0:
      ""
    case more:
      ","

def crop_remaining_ms(ready: U32, duration: U32, elapsed: U32) -> U32:
  match ready:
    case 0:
      (duration - elapsed) * 1000
    case yes:
      0

def users_json(players: List<Player>, first: U32) -> String:
  match players:
    case Cons{head, tail}:
      prefix = comma_unless_first(first)
      String::flatten([prefix, JSON::quoted(player_name(head),""), users_json(tail, 0)])
    case Nil{}:
      "]"

def owner_name(players: List<Player>, requested: String, fallback: String) -> String:
  match player_exists(players, requested):
    case 0:
      fallback
    case yes:
      requested

def empty_plot_json(index: U32, locked: U32) -> String:
  String::flatten(["{\"index\":",String::from_u32(index),",\"locked\":",String::from_u32(locked),",\"crop\":0,\"stage\":0}"])

def planted_plot_json(plot: Plot, viewer: String, thefts: List<Theft>, now: U32) -> String:
  match plot:
    case Plot{owner, index, crop, planted_at, steals, thieves}:
      ready = crop_ready(Plot{owner,index,crop,planted_at,steals,thieves}, now)
      elapsed = now - planted_at
      duration = crop_duration(crop)
      remaining = crop_remaining_ms(ready,duration,elapsed)
      daily = theft_count(thefts, viewer, owner, current_day(now))
      can_steal = ready && ((String::eq(viewer, owner) == 0) && (steal_slot_open(steals) && ((string_member(thieves, viewer) == 0) && daily_slot_open(daily))))
      String::flatten([
        "{\"index\":",String::from_u32(index),",\"locked\":0,\"crop\":",String::from_u32(crop),",\"cropName\":",JSON::quoted(crop_name(crop),""),
        ",\"stage\":",String::from_u32(crop_stage(Plot{owner,index,crop,planted_at,steals,thieves},now)),",\"ready\":",String::from_u32(ready),
        ",\"remainingMs\":",String::from_u32(remaining),",\"steals\":",String::from_u32(steals),",\"yield\":",String::from_u32(yield_remaining(steals)),
        ",\"canSteal\":",String::from_u32(can_steal),",\"canHarvest\":",String::from_u32(ready && String::eq(viewer,owner)),"}"
      ])

def plot_slot_json(plots: List<Plot>, thefts: List<Theft>, owner: String, viewer: String, unlocked: U32, index: U32, now: U32) -> String:
  match index >= unlocked:
    case 0:
      match plot_find(plots, owner, index):
        case PlotMissing{}:
          empty_plot_json(index, 0)
        case PlotHere{plot}:
          planted_plot_json(plot, viewer, thefts, now)
    case yes:
      empty_plot_json(index, 1)

def plots_json_go(plots: List<Plot>, thefts: List<Theft>, owner: String, viewer: String, unlocked: U32, index: U32, left: U32, now: U32) -> String:
  match left:
    case 0:
      "]"
    case more:
      remaining = more - 1
      separator = comma_if_more(remaining)
      String::flatten([plot_slot_json(plots,thefts,owner,viewer,unlocked,index,now),separator,plots_json_go(plots,thefts,owner,viewer,unlocked,index+1,remaining,now)])

def state_json(app: App, viewer: String, token: U32, requested_owner: String, now: U32, ok: U32, note: String, amount: U32) -> String:
  match app:
    case App{credentials, sessions, farm, paths}:
      match farm:
        case Farm{players, plots, thefts}:
          selected = owner_name(players, requested_owner, viewer)
          state_json_players(App{credentials,sessions,Farm{players,plots,thefts},paths}, player_find(players, viewer), player_find(players, selected), viewer, token, selected, now, ok, note, amount)

def state_json_players(app: App, viewer_found: PlayerFound, owner_found: PlayerFound, viewer: String, token: U32, selected: String, now: U32, ok: U32, note: String, amount: U32) -> String:
  match app:
    case App{credentials, sessions, farm, paths}:
      match farm:
        case Farm{players, plots, thefts}:
          match viewer_found:
            case PlayerMissing{}:
              "{\"ok\":0,\"note\":\"Session expired. Sign in again.\"}"
            case PlayerHere{viewer_player}:
              match owner_found:
                case PlayerMissing{}:
                  "{\"ok\":0,\"note\":\"Farm not found.\"}"
                case PlayerHere{owner_player}:
                  match owner_player:
                    case Player{owner_name_value, owner_coins, unlocked, turnip, carrot, radish, tomato}:
                      String::flatten([
                        "{\"ok\":",String::from_u32(ok),",\"note\":",JSON::quoted(note,""),",\"amount\":",String::from_u32(amount),",\"token\":",String::from_u32(token),
                        ",\"now\":",String::from_u32(now),",\"me\":",player_json(viewer_player),",\"owner\":",JSON::quoted(owner_name_value,""),",\"users\":[",users_json(players,1),
                        ",\"plots\":[",plots_json_go(plots,thefts,owner_name_value,viewer,unlocked,0,12,now),"}"
                      ])

def json_response(body: String) -> Response:
  Response{
    200,
    [Header{"Content-Type","application/json; charset=utf-8"},Header{"Cache-Control","no-store, no-cache, must-revalidate"}],
    HTTP::body(body)
  }

def app_reply(app: App, viewer: String, token: U32, owner: String, now: U32, ok: U32, note: String, amount: U32) -> Routed:
  Routed{app, json_response(state_json(app,viewer,token,owner,now,ok,note,amount))}

def auth_reply(app: App, note: String) -> Routed:
  Routed{app, json_response(String::flatten(["{\"ok\":0,\"note\":",JSON::quoted(note,""),"}"]))}

# Persistence and authentication
# ==============================

def path_join(directory: String, file: String) -> String:
  String::flatten([directory,"/",file])

def paths_from_env(result: Result<String>) -> Paths:
  match result:
    case Done{directory}:
      Paths{path_join(directory,"credentials.csv"),path_join(directory,"farm_state.csv")}
    case Fail{code, error}:
      Paths{"gabriel_demos/farmhands_web/data/credentials.csv","gabriel_demos/farmhands_web/data/farm_state.csv"}

def app_from_loaded(paths: Paths, credential_result: Result<String>, farm_result: Result<String>) -> App:
  credentials = credentials_from_result(credential_result)
  farm = farm_ensure_credentials(credentials, farm_from_result(farm_result))
  App{credentials, sessions_empty(), farm, paths}

def load_app(paths: Paths) -> IO<App>:
  match paths:
    case Paths{credential_path, farm_path}:
      do IO<App>:
        credential_result : Result<String> <- IO::read_text(credential_path)
        farm_result : Result<String> <- IO::read_text(farm_path)
        return app_from_loaded(Paths{credential_path,farm_path}, credential_result, farm_result)

def save_farm_result(result: Result<U32>, old_app: App, new_app: App, viewer: String, token: U32, owner: String, now: U32, note: String, amount: U32) -> Routed:
  match result:
    case Done{unit}:
      app_reply(new_app,viewer,token,owner,now,1,note,amount)
    case Fail{code, error}:
      app_reply(old_app,viewer,token,owner,now,0,"The action was rejected because farm_state.csv could not be saved.",0)

def save_action(old_app: App, new_app: App, viewer: String, token: U32, owner: String, now: U32, note: String, amount: U32) -> IO<Routed>:
  match new_app:
    case App{credentials, sessions, farm, Paths{credential_path,farm_path}}:
      do IO<Routed>:
        result : Result<U32> <- IO::write_text(farm_path, farm_csv(farm))
        return save_farm_result(result,old_app,App{credentials,sessions,farm,Paths{credential_path,farm_path}},viewer,token,owner,now,note,amount)

def apply_action(app: App, action: FarmAction, viewer: String, token: U32, owner: String, now: U32) -> IO<Routed>:
  match app:
    case App{credentials, sessions, old_farm, paths}:
      match action:
        case FarmAction{new_farm, ok, note, amount}:
          match ok:
            case 0:
              IO::pure<Routed>( app_reply(App{credentials,sessions,old_farm,paths},viewer,token,owner,now,0,note,0))
            case yes:
              save_action(App{credentials,sessions,old_farm,paths},App{credentials,sessions,new_farm,paths},viewer,token,owner,now,note,amount)

def register_saved(credential_result: Result<U32>, farm_result: Result<U32>, old_app: App, new_app: App, name: String, token: U32, now: U32) -> Routed:
  match credential_result:
    case Fail{code, error}:
      auth_reply(old_app,"Account not created: credentials.csv could not be saved.")
    case Done{unit}:
      match farm_result:
        case Fail{code, error}:
          auth_reply(old_app,"Account not created: farm_state.csv could not be saved.")
        case Done{unit}:
          app_reply(new_app,name,token,name,now,1,"Account created.",0)

def register_hashed(credentials: List<Credential>, sessions: List<Session>, farm: Farm, paths: Paths, name: String, salt: U32, hash: String, token_word: U32, now: U32) -> IO<Routed>:
  token = token_word + 1
  new_credentials = credential_push(Credential{name,salt,hash},credentials)
  new_sessions = sessions_login(sessions,token,name)
  new_farm = farm_add_player(farm,name)
  match paths:
    case Paths{credential_path,farm_path}:
      do IO<Routed>:
        credential_result : Result<U32> <- IO::write_text(credential_path,credentials_csv(new_credentials))
        farm_result : Result<U32> <- IO::write_text(farm_path,farm_csv(new_farm))
        return register_saved(
          credential_result,farm_result,
          App{credentials,sessions,farm,Paths{credential_path,farm_path}},
          App{new_credentials,new_sessions,new_farm,Paths{credential_path,farm_path}},
          name,token,now
        )

def register(app: App, parts: List<String>, now: U32) -> IO<Routed>:
  match app:
    case App{credentials, sessions, farm, paths}:
      name = part(parts,0)
      password = part(parts,1)
      match username_valid(name) && (password_valid(password) && (credential_exists(credentials,name) == 0)):
        case 0:
          IO::pure<Routed>(auth_reply(App{credentials,sessions,farm,paths},"Use a unique 2–20 character name containing letters, digits, - or _, and a 4–128 character password."))
        case yes:
          do IO<Routed>:
            salt : U32 <- IO::rand()
            hash : String <- password_hash(password,salt)
            token_word : U32 <- IO::rand()
            register_hashed(credentials,sessions,farm,paths,name,salt,hash,token_word,now)

def login_hash(app: App, credential: Credential, name: String, password: String, now: U32) -> IO<Routed>:
  match app:
    case App{credentials,sessions,farm,paths}:
      match credential:
        case Credential{stored,salt,expected}:
          do IO<Routed>:
            actual : String <- password_hash(password,salt)
            match String::eq(actual,expected):
              case 0:
                IO::pure<Routed>(auth_reply(App{credentials,sessions,farm,paths},"Invalid username or password."))
              case yes:
                do IO<Routed>:
                  token_word : U32 <- IO::rand()
                  return app_reply(App{credentials,sessions_login(sessions,token_word + 1,stored),farm,paths},stored,token_word + 1,stored,now,1,"Welcome back.",0)

def login(app: App, parts: List<String>, now: U32) -> IO<Routed>:
  name = part(parts,0)
  password = part(parts,1)
  match app:
    case App{credentials,sessions,farm,paths}:
      match credential_find(credentials,name):
        case CredentialMissing{}:
          IO::pure<Routed>(auth_reply(App{credentials,sessions,farm,paths},"Invalid username or password."))
        case CredentialHere{credential}:
          login_hash(App{credentials,sessions,farm,paths},credential,name,password,now)

# HTTP actions and routing
# ========================

def state_get(app: App, token: U32, requested: String, now: U32) -> Routed:
  match app:
    case App{credentials,sessions,farm,paths}:
      viewer = session_name(sessions,token)
      match String::length(viewer) > 0:
        case 0:
          auth_reply(App{credentials,sessions,farm,paths},"Session expired. Sign in again.")
        case yes:
          app_reply(App{credentials,sessions,farm,paths},viewer,token,requested,now,1,"",0)

def plant(app: App, parts: List<String>, now: U32) -> IO<Routed>:
  token = String::to_u32(part(parts,0))
  index = String::to_u32(part(parts,1))
  crop = String::to_u32(part(parts,2))
  match app:
    case App{credentials,sessions,farm,paths}:
      actor = session_name(sessions,token)
      match String::length(actor) > 0:
        case 0:
          IO::pure<Routed>(auth_reply(App{credentials,sessions,farm,paths},"Sign in before planting."))
        case yes:
          apply_action(App{credentials,sessions,farm,paths},farm_plant(farm,actor,index,crop,now),actor,token,actor,now)

def harvest(app: App, parts: List<String>, now: U32) -> IO<Routed>:
  token = String::to_u32(part(parts,0))
  index = String::to_u32(part(parts,1))
  match app:
    case App{credentials,sessions,farm,paths}:
      actor = session_name(sessions,token)
      match String::length(actor) > 0:
        case 0:
          IO::pure<Routed>(auth_reply(App{credentials,sessions,farm,paths},"Sign in before harvesting."))
        case yes:
          apply_action(App{credentials,sessions,farm,paths},farm_harvest(farm,actor,index,now),actor,token,actor,now)

def steal(app: App, parts: List<String>, now: U32) -> IO<Routed>:
  token = String::to_u32(part(parts,0))
  owner = part(parts,1)
  index = String::to_u32(part(parts,2))
  match app:
    case App{credentials,sessions,farm,paths}:
      actor = session_name(sessions,token)
      match String::length(actor) > 0:
        case 0:
          IO::pure<Routed>(auth_reply(App{credentials,sessions,farm,paths},"Sign in before visiting farms."))
        case yes:
          apply_action(App{credentials,sessions,farm,paths},farm_steal(farm,actor,owner,index,now),actor,token,owner,now)

def unlock(app: App, parts: List<String>, now: U32) -> IO<Routed>:
  token = String::to_u32(part(parts,0))
  match app:
    case App{credentials,sessions,farm,paths}:
      actor = session_name(sessions,token)
      match String::length(actor) > 0:
        case 0:
          IO::pure<Routed>(auth_reply(App{credentials,sessions,farm,paths},"Sign in before unlocking land."))
        case yes:
          apply_action(App{credentials,sessions,farm,paths},farm_unlock(farm,actor),actor,token,actor,now)

def method_not_allowed(app: App) -> Routed:
  Routed{app,HTTP::reply(405,"text/plain; charset=utf-8","Method Not Allowed\n")}

def missing(app: App) -> Routed:
  Routed{app,HTTP::not_found()}

def index_result(result: Result<String>, app: App) -> Routed:
  match result:
    case Done{html}:
      Routed{app,HTTP::reply(200,"text/html; charset=utf-8",html)}
    case Fail{code, error}:
      Routed{app,HTTP::reply(500,"text/plain; charset=utf-8","index.html not found -- run from the repository root\n")}

def index_page(app: App) -> IO<Routed>:
  do IO<Routed>:
    result : Result<String> <- IO::read_text("gabriel_demos/farmhands_web/index.html")
    return index_result(result,app)

def api_post(name: String, request: Request, app: App, now: U32) -> IO<Routed>:
  parts = body_parts(request_body(request))
  match String::eq(name,"register"):
    case 0:
      match String::eq(name,"login"):
        case 0:
          match String::eq(name,"plant"):
            case 0:
              match String::eq(name,"harvest"):
                case 0:
                  match String::eq(name,"steal"):
                    case 0:
                      match String::eq(name,"unlock"):
                        case 0:
                          IO::pure<Routed>(missing(app))
                        case yes:
                          unlock(app,parts,now)
                    case yes:
                      steal(app,parts,now)
                case yes:
                  harvest(app,parts,now)
            case yes:
              plant(app,parts,now)
        case yes:
          login(app,parts,now)
    case yes:
      register(app,parts,now)

def api_route(method: String, name: String, args: List<String>, request: Request, app: App, now: U32) -> IO<Routed>:
  match String::eq(name,"state") && String::eq(method,"GET"):
    case 0:
      match String::eq(method,"POST"):
        case 0:
          IO::pure<Routed>(method_not_allowed(app))
        case yes:
          api_post(name,request,app,now)
    case yes:
      IO::pure<Routed>(state_get(app,String::to_u32(part(args,0)),part(args,1),now))

def route(request: Request, app: App, now: U32) -> IO<Routed>:
  match request:
    case Request{method,path,headers,body}:
      match String::eq(path,"/"):
        case 0:
          match String::split(Char{47},path):
            case Cons{root,Cons{"api",Cons{name,args}}}:
              api_route(method,name,args,Request{method,path,headers,body},app,now)
            case other:
              IO::pure<Routed>(missing(app))
        case yes:
          index_page(app)

# Pure routing classifier used by the regression suite. Keeping this separate
# catches accidental catch-all pattern reordering without performing IO.
def route_path_class(path: String) -> U32:
  match String::eq(path,"/"):
    case 0:
      match String::split(Char{47},path):
        case Cons{root,Cons{"api",Cons{name,args}}}:
          2
        case other:
          3
    case root:
      1

def route_path_test() -> U32:
  (route_path_class("/") == 1) && ((route_path_class("/api/register") == 2) && (route_path_class("/missing") == 3))

# Sequential stateful server
# ==========================

def serve(server: U32, app: App) -> IO<U32>:
  do IO<U32>:
    accepted : Result<U32> <- TCP::accept(server)
    accept_result(accepted,server,app)

def routed_send(routed: Routed, server: U32, conn: Conn) -> IO<U32>:
  match routed:
    case Routed{app,response}:
      do IO<U32>:
        sent : Result<U32> <- HTTP::send_response(conn,HTTP::with_connection(0,response))
        closed : U32 <- HTTP::conn_close(conn)
        serve(server,app)

def inbound_result(inbound: Inbound, server: U32, conn: Conn, app: App) -> IO<U32>:
  match inbound:
    case Got{http11,request,rest}:
      do IO<U32>:
        now : U32 <- IO::now()
        routed : Routed <- route(request,app,now)
        routed_send(routed,server,conn)
    case Closed{}:
      do IO<U32>:
        closed : U32 <- HTTP::conn_close(conn)
        serve(server,app)
    case Bad{code,error}:
      routed_send(Routed{app,HTTP::err_response(code,error)},server,conn)

def accept_result(result: Result<U32>, server: U32, app: App) -> IO<U32>:
  match result:
    case Done{fd}:
      do IO<U32>:
        inbound : Inbound <- HTTP::read_request(Plain{fd},Nil{})
        inbound_result(inbound,server,Plain{fd},app)
    case Fail{code, error}:
      do IO<U32>:
        printed : U32 <- IO::print_err("Farmhands accept failed.\n")
        return 1

def port_from_env(result: Result<String>) -> U32:
  match result:
    case Done{text}:
      parsed = String::to_u32(text)
      match parsed > 0:
        case 0:
          8093
        case yes:
          parsed
    case Fail{code, error}:
      8093

def listen_result(result: Result<U32>, app: App, port: U32) -> IO<U32>:
  match result:
    case Done{server}:
      do IO<U32>:
        printed : U32 <- IO::print(String::flatten(["Farmhands listening on 0.0.0.0:",String::from_u32(port),"\nopen http://<server-lan-ip>:",String::from_u32(port),"\n"]))
        serve(server,app)
    case Fail{code, error}:
      do IO<U32>:
        printed : U32 <- IO::print_err("Farmhands could not listen on the selected port.\n")
        return 1

def start_from_env(directory_result: Result<String>, port_result: Result<String>) -> IO<U32>:
  paths = paths_from_env(directory_result)
  port = port_from_env(port_result)
  do IO<U32>:
    app : App <- load_app(paths)
    match app:
      case App{credentials,sessions,farm,Paths{credential_path,farm_path}}:
        do IO<U32>:
          credential_saved : Result<U32> <- IO::write_text(credential_path,credentials_csv(credentials))
          farm_saved : Result<U32> <- IO::write_text(farm_path,farm_csv(farm))
          listened : Result<U32> <- TCP::listen(port)
          listen_result(listened,App{credentials,sessions,farm,Paths{credential_path,farm_path}},port)

def main() -> IO<U32>:
  do IO<U32>:
    directory_result : Result<String> <- IO::get_env("FARMHANDS_DATA_DIR")
    port_result : Result<String> <- IO::get_env("FARMHANDS_PORT")
    start_from_env(directory_result, port_result)
