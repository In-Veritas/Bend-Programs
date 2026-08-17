# Social state for the unified BendJogos process.
#
# This is deliberately an in-memory LAN demo. Passwords are never stored as
# clear text, but the compact U32 digest is not a production password KDF;
# put this behind TLS and replace digest_password before using real accounts.

import ../../bend-base/Base
import ../Compat
import ../../bend-base/IO/HTTP
import ../../bend-base/JSON

type User:
  User{id: U32, name: String, password: U32, token: U32, seen: U32, game: String}

type Message:
  Message{id: U32, sender: String, recipient: String, text: String, at: U32}

type Invite:
  Invite{id: U32, sender: String, recipient: String, game: String, status: U32, at: U32}

type Friend:
  # status: 0 pending, 1 accepted. `left` sent the request to `right`.
  Friend{left: String, right: String, status: U32}

type State:
  State{users: List(User), messages: List(Message), invites: List(Invite), friends: List(Friend), next_id: U32}

type Routed:
  Routed{state: State, response: HTTP.Response}

def digest_go(s: String, acc: U32) -> U32:
  match s:
    case List.Cons{c, t}:
      digest_go(t, (acc * 16777619) + Char.code(c))
    case List.Nil{}:
      acc

def digest_password(name: String, password: String) -> U32:
  digest_go(String.concat(name, password), 2166136261)

def user_json(user: User, now: U32) -> String:
  match user:
    case User.User{id, name, password, token, seen, game}:
      String.flatten(["{\"id\":", String.from_u32(id), ",\"name\":", JSON.quoted(name, ""), ",\"online\":", String.from_u32((now - seen) < 12000), ",\"game\":", JSON.quoted(game, ""), "}"])

def users_json(xs: List(User), now: U32) -> String:
  match xs:
    case List.Cons{h, List.Nil{}}:
      String.concat(user_json(h, now), "]")
    case List.Cons{h, t}:
      String.concat(user_json(h, now), String.concat(",", users_json(t, now)))
    case List.Nil{}:
      "]"

def message_json(message: Message) -> String:
  match message:
    case Message.Message{id, sender, recipient, text, at}:
      String.flatten(["{\"id\":", String.from_u32(id), ",\"from\":", JSON.quoted(sender, ""), ",\"to\":", JSON.quoted(recipient, ""), ",\"text\":", JSON.quoted(text, ""), ",\"at\":", String.from_u32(at), "}"])

def messages_json_go(xs: List(Message), who: String, first: U32) -> String:
  match xs:
    case List.Cons{h, t}:
      match h:
        case Message.Message{id, sender, recipient, text, at}:
          match String.eq_u32(sender, who) || String.eq_u32(recipient, who):
            case 0:
              messages_json_go(t, who, first)
            case k:
              match first:
                case 0:
                  String.concat(",", String.concat(message_json(Message.Message{id, sender, recipient, text, at}), messages_json_go(t, who, 0)))
                case j:
                  String.concat(message_json(Message.Message{id, sender, recipient, text, at}), messages_json_go(t, who, 0))
    case List.Nil{}:
      "]"

def messages_json(xs: List(Message), who: String) -> String:
  messages_json_go(xs, who, 1)

def invite_json(invite: Invite) -> String:
  match invite:
    case Invite.Invite{id, sender, recipient, game, status, at}:
      String.flatten(["{\"id\":", String.from_u32(id), ",\"from\":", JSON.quoted(sender, ""), ",\"to\":", JSON.quoted(recipient, ""), ",\"game\":", JSON.quoted(game, ""), ",\"status\":", String.from_u32(status), "}"])

def invites_json_go(xs: List(Invite), who: String, first: U32) -> String:
  match xs:
    case List.Cons{h, t}:
      match h:
        case Invite.Invite{id, sender, recipient, game, status, at}:
          match String.eq_u32(sender, who) || String.eq_u32(recipient, who):
            case 0:
              invites_json_go(t, who, first)
            case k:
              match first:
                case 0:
                  String.concat(",", String.concat(invite_json(Invite.Invite{id, sender, recipient, game, status, at}), invites_json_go(t, who, 0)))
                case j:
                  String.concat(invite_json(Invite.Invite{id, sender, recipient, game, status, at}), invites_json_go(t, who, 0))
    case List.Nil{}:
      "]"

def invites_json(xs: List(Invite), who: String) -> String:
  invites_json_go(xs, who, 1)

def friend_other(left: String, right: String, who: String) -> String:
  match String.eq_u32(left, who):
    case 0:
      left
    case k:
      right

def friend_json(friend: Friend, who: String) -> String:
  match friend:
    case Friend.Friend{left, right, status}:
      other = friend_other(left, right, who)
      String.flatten(["{\"name\":", JSON.quoted(other, ""), "}"])

def friends_json_go(xs: List(Friend), who: String, first: U32) -> String:
  match xs:
    case List.Cons{h, t}:
      match h:
        case Friend.Friend{left, right, status}:
          match (status == 1) && (String.eq_u32(left, who) || String.eq_u32(right, who)):
            case 0:
              friends_json_go(t, who, first)
            case k:
              match first:
                case 0:
                  String.concat(",", String.concat(friend_json(Friend.Friend{left, right, status}, who), friends_json_go(t, who, 0)))
                case j:
                  String.concat(friend_json(Friend.Friend{left, right, status}, who), friends_json_go(t, who, 0))
    case List.Nil{}:
      "]"

def friends_json(xs: List(Friend), who: String) -> String:
  friends_json_go(xs, who, 1)

def request_json(friend: Friend, who: String) -> String:
  match friend:
    case Friend.Friend{left, right, status}:
      other = friend_other(left, right, who)
      String.flatten(["{\"name\":", JSON.quoted(other, ""), ",\"incoming\":", String.from_u32(String.eq_u32(right, who)), "}"])

def requests_json_go(xs: List(Friend), who: String, first: U32) -> String:
  match xs:
    case List.Cons{h, t}:
      match h:
        case Friend.Friend{left, right, status}:
          match (status == 0) && (String.eq_u32(left, who) || String.eq_u32(right, who)):
            case 0:
              requests_json_go(t, who, first)
            case k:
              match first:
                case 0:
                  String.concat(",", String.concat(request_json(Friend.Friend{left, right, status}, who), requests_json_go(t, who, 0)))
                case j:
                  String.concat(request_json(Friend.Friend{left, right, status}, who), requests_json_go(t, who, 0))
    case List.Nil{}:
      "]"

def requests_json(xs: List(Friend), who: String) -> String:
  requests_json_go(xs, who, 1)

def state_json(state: State, who: String, token: U32, now: U32, ok: U32, note: String) -> String:
  match state:
    case State.State{users, messages, invites, friends, next_id}:
      String.flatten(["{\"ok\":", String.from_u32(ok), ",\"note\":", JSON.quoted(note, ""), ",\"token\":", String.from_u32(token), ",\"me\":", JSON.quoted(who, ""), ",\"users\":[", users_json(users, now), ",\"messages\":[", messages_json(messages, who), ",\"invites\":[", invites_json(invites, who), ",\"friends\":[", friends_json(friends, who), ",\"requests\":[", requests_json(friends, who), "}"])

def social_reply(state: State, who: String, token: U32, now: U32, ok: U32, note: String) -> Routed:
  Routed.Routed{state, HTTP.reply(200, "application/json; charset=utf-8", state_json(state, who, token, now, ok, note))}

def empty() -> State:
  State.State{List.Nil{}, List.Nil{}, List.Nil{}, List.Nil{}, 1}

type Found:
  Found{name: String, token: U32, seen: U32}
  Missing{}

def find_token(users: List(User), token: U32) -> Found:
  match users:
    case List.Cons{h, t}:
      match h:
        case User.User{id, name, password, stored, seen, game}:
          match (token > 0) && (stored == token):
            case 0:
              find_token(t, token)
            case k:
              Found.Found{name, stored, seen}
    case List.Nil{}:
      Found.Missing{}

def token_name(users: List(User), token: U32) -> String:
  match find_token(users, token):
    case Found.Found{name, token, seen}:
      name
    case Found.Missing{}:
      ""

def find_name(users: List(User), name: String) -> U32:
  match users:
    case List.Cons{h, t}:
      match h:
        case User.User{id, stored, password, token, seen, game}:
          match String.eq_u32(stored, name):
            case 0:
              find_name(t, name)
            case k:
              1
    case List.Nil{}:
      0

# 0 = no relationship, 1 = pending request, 2 = accepted friendship.
def friends_kind(friends: List(Friend), one: String, two: String) -> U32:
  match friends:
    case List.Cons{h, t}:
      match h:
        case Friend.Friend{left, right, status}:
          same = (String.eq_u32(left, one) && String.eq_u32(right, two)) || (String.eq_u32(left, two) && String.eq_u32(right, one))
          match same:
            case 0:
              friends_kind(t, one, two)
            case k:
              status + 1
    case List.Nil{}:
      0

def friends_accept(friends: List(Friend), sender: String, recipient: String) -> List(Friend):
  match friends:
    case List.Cons{h, t}:
      match h:
        case Friend.Friend{left, right, status}:
          match (status == 0) && (String.eq_u32(left, sender) && String.eq_u32(right, recipient)):
            case 0:
              List.Cons{Friend.Friend{left, right, status}, friends_accept(t, sender, recipient)}
            case k:
              List.Cons{Friend.Friend{left, right, 1}, t}
    case List.Nil{}:
      List.Nil{}

def friends_incoming(friends: List(Friend), sender: String, recipient: String) -> U32:
  match friends:
    case List.Cons{h, t}:
      match h:
        case Friend.Friend{left, right, status}:
          match (status == 0) && (String.eq_u32(left, sender) && String.eq_u32(right, recipient)):
            case 0:
              friends_incoming(t, sender, recipient)
            case k:
              1
    case List.Nil{}:
      0

def friends_remove(friends: List(Friend), one: String, two: String) -> List(Friend):
  match friends:
    case List.Cons{h, t}:
      match h:
        case Friend.Friend{left, right, status}:
          same = (String.eq_u32(left, one) && String.eq_u32(right, two)) || (String.eq_u32(left, two) && String.eq_u32(right, one))
          match same:
            case 0:
              List.Cons{Friend.Friend{left, right, status}, friends_remove(t, one, two)}
            case k:
              t
    case List.Nil{}:
      List.Nil{}

def touch_users(users: List(User), token: U32, now: U32) -> List(User):
  match users:
    case List.Cons{h, t}:
      match h:
        case User.User{id, name, password, stored, seen, game}:
          match (token > 0) && (stored == token):
            case 0:
              List.Cons{User.User{id, name, password, stored, seen, game}, touch_users(t, token, now)}
            case k:
              List.Cons{User.User{id, name, password, stored, now, game}, t}
    case List.Nil{}:
      List.Nil{}

def body_parts(body: Bytes) -> List(String):
  String.split(Char.Char{10}, Bytes.to_string(body))

def part(xs: List(String), n: U32) -> String:
  List.head(String, "", List.drop(String, n, xs))

def register(state: State, parts: List(String), now: U32) -> IO(Routed):
  match state:
    case State.State{users, messages, invites, friends, next_id}:
      name = part(parts, 0)
      password = part(parts, 1)
      match (String.length(name) < 2) || ((String.length(password) < 4) || (find_name(users, name) > 0)):
        case 0:
          do IO(Routed):
            token <- IO.rand_word()
            return social_reply(State.State{List.Cons{User.User{next_id, name, digest_password(name, password), token + 1, now, ""}, users}, messages, invites, friends, next_id + 1}, name, token + 1, now, 1, "account created")
        case k:
          IO.pure(Routed, social_reply(State.State{users, messages, invites, friends, next_id}, "", 0, now, 0, "choose a unique name and a password of at least four characters"))

def password_for(users: List(User), name: String) -> U32:
  match users:
    case List.Cons{h, t}:
      match h:
        case User.User{id, stored, password, token, seen, game}:
          match String.eq_u32(stored, name):
            case 0:
              password_for(t, name)
            case k:
              password
    case List.Nil{}:
      0

def login_users(users: List(User), name: String, token: U32, now: U32) -> List(User):
  match users:
    case List.Cons{h, t}:
      match h:
        case User.User{id, stored, password, old_token, seen, game}:
          match String.eq_u32(stored, name):
            case 0:
              List.Cons{User.User{id, stored, password, old_token, seen, game}, login_users(t, name, token, now)}
            case k:
              List.Cons{User.User{id, stored, password, token, now, game}, t}
    case List.Nil{}:
      List.Nil{}

def login(state: State, parts: List(String), now: U32) -> IO(Routed):
  match state:
    case State.State{users, messages, invites, friends, next_id}:
      name = part(parts, 0)
      password = part(parts, 1)
      match (password_for(users, name) > 0) && (password_for(users, name) == digest_password(name, password)):
        case 0:
          IO.pure(Routed, social_reply(State.State{users, messages, invites, friends, next_id}, "", 0, now, 0, "invalid username or password"))
        case k:
          do IO(Routed):
            token <- IO.rand_word()
            return social_reply(State.State{login_users(users, name, token + 1, now), messages, invites, friends, next_id}, name, token + 1, now, 1, "welcome back")

def chat(state: State, parts: List(String), now: U32) -> Routed:
  match state:
    case State.State{users, messages, invites, friends, next_id}:
      token = String.to_u32(part(parts, 0))
      who = token_name(users, token)
      recipient = part(parts, 1)
      text = part(parts, 2)
      match (String.length(who) > 0) && ((friends_kind(friends, who, recipient) == 2) && (String.length(text) > 0)):
        case 0:
          social_reply(State.State{touch_users(users, token, now), messages, invites, friends, next_id}, who, token, now, 0, "messages can only be sent to accepted friends")
        case k:
          social_reply(State.State{touch_users(users, token, now), List.Cons{Message.Message{next_id, who, recipient, text, now}, messages}, invites, friends, next_id + 1}, who, token, now, 1, "message sent")

def invite(state: State, parts: List(String), now: U32) -> Routed:
  match state:
    case State.State{users, messages, invites, friends, next_id}:
      token = String.to_u32(part(parts, 0))
      who = token_name(users, token)
      recipient = part(parts, 1)
      game = part(parts, 2)
      match (String.length(who) > 0) && (friends_kind(friends, who, recipient) == 2):
        case 0:
          social_reply(State.State{touch_users(users, token, now), messages, invites, friends, next_id}, who, token, now, 0, "game invitations can only be sent to accepted friends")
        case k:
          social_reply(State.State{touch_users(users, token, now), messages, List.Cons{Invite.Invite{next_id, who, recipient, game, 0, now}, invites}, friends, next_id + 1}, who, token, now, 1, "invitation sent")

def friend_request(state: State, parts: List(String), now: U32) -> Routed:
  match state:
    case State.State{users, messages, invites, friends, next_id}:
      token = String.to_u32(part(parts, 0))
      who = token_name(users, token)
      other = part(parts, 1)
      match (String.length(who) > 0) && ((find_name(users, other) > 0) && ((String.eq_u32(who, other) == 0) && (friends_kind(friends, who, other) == 0))):
        case 0:
          social_reply(State.State{touch_users(users, token, now), messages, invites, friends, next_id}, who, token, now, 0, "choose a user who is not already a friend or pending")
        case k:
          social_reply(State.State{touch_users(users, token, now), messages, invites, List.Cons{Friend.Friend{who, other, 0}, friends}, next_id}, who, token, now, 1, "friend request sent")

def friend_accept(state: State, parts: List(String), now: U32) -> Routed:
  match state:
    case State.State{users, messages, invites, friends, next_id}:
      token = String.to_u32(part(parts, 0))
      who = token_name(users, token)
      sender = part(parts, 1)
      match (String.length(who) > 0) && (friends_incoming(friends, sender, who) > 0):
        case 0:
          social_reply(State.State{touch_users(users, token, now), messages, invites, friends, next_id}, who, token, now, 0, "no incoming request from that user")
        case k:
          social_reply(State.State{touch_users(users, token, now), messages, invites, friends_accept(friends, sender, who), next_id}, who, token, now, 1, "friend request accepted")

def friend_remove(state: State, parts: List(String), now: U32) -> Routed:
  match state:
    case State.State{users, messages, invites, friends, next_id}:
      token = String.to_u32(part(parts, 0))
      who = token_name(users, token)
      other = part(parts, 1)
      match (String.length(who) > 0) && (friends_kind(friends, who, other) > 0):
        case 0:
          social_reply(State.State{touch_users(users, token, now), messages, invites, friends, next_id}, who, token, now, 0, "friendship or request not found")
        case k:
          social_reply(State.State{touch_users(users, token, now), messages, invites, friends_remove(friends, who, other), next_id}, who, token, now, 1, "relationship removed")

def users_presence(users: List(User), token: U32, now: U32, game: String) -> List(User):
  match users:
    case List.Cons{h, t}:
      match h:
        case User.User{id, name, password, stored, seen, old_game}:
          match (token > 0) && (stored == token):
            case 0:
              List.Cons{User.User{id, name, password, stored, seen, old_game}, users_presence(t, token, now, game)}
            case k:
              List.Cons{User.User{id, name, password, stored, now, game}, t}
    case List.Nil{}:
      List.Nil{}

def presence(state: State, parts: List(String), now: U32) -> Routed:
  match state:
    case State.State{users, messages, invites, friends, next_id}:
      token = String.to_u32(part(parts, 0))
      who = token_name(users, token)
      game = part(parts, 1)
      match String.length(who) > 0:
        case 0:
          social_reply(State.State{users, messages, invites, friends, next_id}, "", 0, now, 0, "sign in to publish presence")
        case k:
          social_reply(State.State{users_presence(users, token, now, game), messages, invites, friends, next_id}, who, token, now, 1, "")

def state_get(state: State, token_text: String, now: U32) -> Routed:
  State.State{users, messages, invites, friends, next_id} = state
  token = String.to_u32(token_text)
  match find_token(users, token):
    case Found.Found{who, stored, seen}:
      social_reply(State.State{touch_users(users, token, now), messages, invites, friends, next_id}, who, token, now, 1, "")
    case Found.Missing{}:
      social_reply(State.State{users, messages, invites, friends, next_id}, "", 0, now, 0, "sign in to join the social space")

def action_route(name: String, request: HTTP.Request, state: State, now: U32) -> IO(Routed):
  match String.eq_u32(name, "register"):
    case 0:
      match String.eq_u32(name, "login"):
        case 0:
          match String.eq_u32(name, "chat"):
            case 0:
              match String.eq_u32(name, "invite"):
                case 0:
                  match String.eq_u32(name, "friend_request"):
                    case 0:
                      match String.eq_u32(name, "friend_accept"):
                        case 0:
                          match String.eq_u32(name, "friend_remove"):
                            case 0:
                              match String.eq_u32(name, "presence"):
                                case 0:
                                  IO.pure(Routed, social_reply(state, "", 0, now, 0, "unknown social route"))
                                case k7:
                                  IO.pure(Routed, presence(state, body_parts(request_body(request)), now))
                            case k6:
                              IO.pure(Routed, friend_remove(state, body_parts(request_body(request)), now))
                        case k5:
                          IO.pure(Routed, friend_accept(state, body_parts(request_body(request)), now))
                    case k4:
                      IO.pure(Routed, friend_request(state, body_parts(request_body(request)), now))
                case k3:
                  IO.pure(Routed, invite(state, body_parts(request_body(request)), now))
            case k2:
              IO.pure(Routed, chat(state, body_parts(request_body(request)), now))
        case k2:
          login(state, body_parts(request_body(request)), now)
    case k2:
      register(state, body_parts(request_body(request)), now)

def string_route(name: String, args: List(String), request: HTTP.Request, state: State, now: U32) -> IO(Routed):
  match args:
    case List.Cons{token, rest}:
      IO.pure(Routed, state_get(state, token, now))
    case List.Nil{}:
      action_route(name, request, state, now)

def request_body(request: HTTP.Request) -> Bytes:
  match request:
    case HTTP.Request.Request{method, path, headers, body}:
      body

def request_route(request: HTTP.Request, state: State, now: U32) -> IO(Routed):
  match request:
    case HTTP.Request.Request{method, path, headers, body}:
      match String.eq_u32(method, "POST"):
        case 0:
          match String.split('/', path):
            case List.Cons{root, List.Cons{"api", List.Cons{"state", List.Cons{token, rest}}}}:
              IO.pure(Routed, state_get(state, token, now))
            case other:
              IO.pure(Routed, social_reply(state, "", 0, now, 0, "use POST for social actions"))
        case k:
          match String.split('/', path):
            case List.Cons{root, List.Cons{"api", List.Cons{name, args}}}:
              string_route(name, args, HTTP.Request.Request{method, path, headers, body}, state, now)
            case other:
              IO.pure(Routed, social_reply(state, "", 0, now, 0, "use the social API"))
