# Social state for the unified BendJogos process.
#
# This is deliberately an in-memory LAN demo. Passwords are never stored as
# clear text, but the compact U32 digest is not a production password KDF;
# put this behind TLS and replace digest_password before using real accounts.
#
# Ported to Bend 2.0.40. Hub interface (`import ./social.bend as Social`):
# `Social.State`, `Social.empty()`, and
# `Social.route(req, state, now) -> IO(State & HTTP.Response)` for
#   GET  /api/state/<token>
#   POST /api/{register,login,chat,invite,friend_request,friend_accept,
#              friend_remove,presence}   (body: newline-separated fields)
# `now` is the hub's monotonic millisecond clock (presence expires after
# 12 s without a request).
import Base
import ../HTTP.bend as HTTP
import ../Compat.bend as Compat

type User is Data:
  User{id: U32, name: String, password: U32, token: U32, seen: U32, game: String}

type Message is Data:
  Message{id: U32, sender: String, recipient: String, text: String, at: U32}

type Invite is Data:
  Invite{id: U32, sender: String, recipient: String, game: String, status: U32, at: U32}

# status: 0 pending, 1 accepted. `left` sent the request to `right`.
type Friend is Data:
  Friend{left: String, right: String, status: U32}

type State is Data:
  State{users: List<&2, User>, messages: List<&2, Message>, invites: List<&2, Invite>, friends: List<&2, Friend>, next_id: U32}

type Found is Data:
  Found{name: String, token: U32, seen: U32}
  Missing{}

def digest_go(s: String, +acc: U32) -> U32:
  match s:
    case SNil{}:
      acc
    case SCon{c, t}:
      digest_go(t, (acc * 16777619 + Char.to_u32(c) : U32))

def digest_password(name: String, password: String) -> U32:
  digest_go(name ++ password, 2166136261)

def num(s: String) -> U32:
  Compat.to_u32(s)

def len(s: String) -> U32:
  U32.from_nat(String.length(s))

def part(xs: List<&2, String>, n: Nat) -> String:
  Maybe.default(&2, String, List.get(&2, String, xs, n), "")

def bit(b: Bool) -> String:
  U32.show(Bool.to_u32(b))

def done(s: State, r: HTTP.Response) -> IO(State & HTTP.Response):
  IO.pure(State & HTTP.Response, (s, r))

# JSON
# ----

def user_json(user: User, now: U32) -> String:
  User{id, name, password, token, seen, game} = user
  String.concat(["{\"id\":", U32.show(id), ",\"name\":", HTTP.quoted(name), ",\"online\":", bit(((now - seen : U32) < 12000 : U32)), ",\"game\":", HTTP.quoted(game), "}"])

def users_json(xs: List<&2, User>, +now: U32) -> List<&2, String>:
  match xs:
    case Nil{}:
      Nil{}
    case h <> t:
      user_json(h, now) <> users_json(t, now)

def message_json(message: Message) -> String:
  Message{id, sender, recipient, text, at} = message
  String.concat(["{\"id\":", U32.show(id), ",\"from\":", HTTP.quoted(sender), ",\"to\":", HTTP.quoted(recipient), ",\"text\":", HTTP.quoted(text), ",\"at\":", U32.show(at), "}"])

def involves(+sender: String, +recipient: String, who: String) -> Bool:
  +w = who
  String.eq(sender, w) || String.eq(recipient, w)

def keep(hit: Bool, item: String, rest: List<&2, String>) -> List<&2, String>:
  match hit:
    case True{}:
      item <> rest
    case False{}:
      rest

def messages_json(xs: List<&2, Message>, +who: String) -> List<&2, String>:
  match xs:
    case Nil{}:
      Nil{}
    case +h <> t:
      Message{id, +sender, +recipient, text, at} = h
      keep(involves(sender, recipient, who), message_json(h), messages_json(t, who))

def invite_json(invite: Invite) -> String:
  Invite{id, sender, recipient, game, status, at} = invite
  String.concat(["{\"id\":", U32.show(id), ",\"from\":", HTTP.quoted(sender), ",\"to\":", HTTP.quoted(recipient), ",\"game\":", HTTP.quoted(game), ",\"status\":", U32.show(status), "}"])

def invite_sides(+invite: Invite, who: String) -> Bool:
  Invite{id, +sender, +recipient, game, status, at} = invite
  involves(sender, recipient, who)

def invites_json(xs: List<&2, Invite>, +who: String) -> List<&2, String>:
  match xs:
    case Nil{}:
      Nil{}
    case +h <> t:
      keep(invite_sides(h, who), invite_json(h), invites_json(t, who))

def friend_other(+left: String, right: String, who: String) -> String:
  Bool.pick(String, String.eq(left, who), right, left)

def friend_json(friend: Friend, who: String) -> String:
  Friend{+left, right, status} = friend
  "{\"name\":" ++ HTTP.quoted(friend_other(left, right, who)) ++ "}"

def friend_has(+friend: Friend, +status: U32, who: String) -> Bool:
  Friend{+left, +right, stored} = friend
  U32.is_eq(stored, status) && involves(left, right, who)

def friends_json(xs: List<&2, Friend>, +who: String) -> List<&2, String>:
  match xs:
    case Nil{}:
      Nil{}
    case +h <> t:
      keep(friend_has(h, 1, who), friend_json(h, who), friends_json(t, who))

def request_json(friend: Friend, +who: String) -> String:
  Friend{+left, +right, status} = friend
  String.concat(["{\"name\":", HTTP.quoted(friend_other(left, right, who)), ",\"incoming\":", bit(String.eq(right, who)), "}"])

def requests_json(xs: List<&2, Friend>, +who: String) -> List<&2, String>:
  match xs:
    case Nil{}:
      Nil{}
    case +h <> t:
      keep(friend_has(h, 0, who), request_json(h, who), requests_json(t, who))

def array(xs: List<&2, String>) -> String:
  "[" ++ String.join(xs, ",") ++ "]"

def state_json(state: State, +who: String, token: U32, +now: U32, ok: Bool, note: String) -> String:
  State{users, messages, invites, +friends, next_id} = state
  String.concat(["{\"ok\":", bit(ok), ",\"note\":", HTTP.quoted(note), ",\"token\":", U32.show(token), ",\"me\":", HTTP.quoted(who),
    ",\"users\":", array(users_json(users, now)), ",\"messages\":", array(messages_json(messages, who)),
    ",\"invites\":", array(invites_json(invites, who)), ",\"friends\":", array(friends_json(friends, who)),
    ",\"requests\":", array(requests_json(friends, who)), "}"])

def social_reply(+state: State, who: String, token: U32, now: U32, ok: Bool, note: String) -> IO(State & HTTP.Response):
  done(state, HTTP.json(state_json(state, who, token, now, ok, note)))

def empty() -> State:
  State{Nil{}, Nil{}, Nil{}, Nil{}, 1}

# Lookups
# -------

def token_hit(+token: U32, +stored: U32) -> Bool:
  (token > 0 : U32) && U32.is_eq(stored, token)

def find_token.pick(hit: Bool, here: Found, rest: Found) -> Found:
  match hit:
    case True{}:
      here
    case False{}:
      rest

def find_token(users: List<&2, User>, +token: U32) -> Found:
  match users:
    case Nil{}:
      Missing{}
    case h <> t:
      User{id, name, password, +stored, seen, game} = h
      find_token.pick(token_hit(token, stored), Found{name, stored, seen}, find_token(t, token))

def token_name.of(f: Found) -> String:
  match f:
    case Found{name, token, seen}:
      name
    case Missing{}:
      ""

def token_name(users: List<&2, User>, token: U32) -> String:
  token_name.of(find_token(users, token))

def user_name(u: User) -> String:
  User{id, name, password, token, seen, game} = u
  name

def find_name(users: List<&2, User>, +name: String) -> Bool:
  match users:
    case Nil{}:
      False{}
    case h <> t:
      String.eq(user_name(h), name) || find_name(t, name)

def same_pair(+left: String, +right: String, +one: String, +two: String) -> Bool:
  (String.eq(left, one) && String.eq(right, two)) || (String.eq(left, two) && String.eq(right, one))

# 0 = no relationship, 1 = pending request, 2 = accepted friendship.
def friends_kind(friends: List<&2, Friend>, +one: String, +two: String) -> U32:
  match friends:
    case Nil{}:
      0
    case h <> t:
      Friend{left, right, +status} = h
      Bool.pick(U32, same_pair(left, right, one, two), (status + 1 : U32), friends_kind(t, one, two))

def pending_from(+friend: Friend, +sender: String, +recipient: String) -> Bool:
  Friend{left, right, status} = friend
  U32.is_zero(status) && String.eq(left, sender) && String.eq(right, recipient)

def friends_accept(friends: List<&2, Friend>, +sender: String, +recipient: String) -> List<&2, Friend>:
  match friends:
    case Nil{}:
      Nil{}
    case +h <> +t:
      Friend{left, right, status} = h
      Bool.pick(List<&2, Friend>, pending_from(h, sender, recipient), Friend{left, right, 1} <> t, h <> friends_accept(t, sender, recipient))

def friends_incoming(friends: List<&2, Friend>, +sender: String, +recipient: String) -> Bool:
  match friends:
    case Nil{}:
      False{}
    case h <> t:
      pending_from(h, sender, recipient) || friends_incoming(t, sender, recipient)

def friends_remove(friends: List<&2, Friend>, +one: String, +two: String) -> List<&2, Friend>:
  match friends:
    case Nil{}:
      Nil{}
    case +h <> +t:
      Friend{left, right, status} = h
      Bool.pick(List<&2, Friend>, same_pair(left, right, one, two), t, h <> friends_remove(t, one, two))

# Marks the token's user as seen now and, with Some{game}, playing it.
def users_seen(users: List<&2, User>, +token: U32, +now: U32, +game: Maybe<&2, String>) -> List<&2, User>:
  match users:
    case Nil{}:
      Nil{}
    case +h <> +t:
      User{id, name, password, +stored, seen, old_game} = h
      Bool.pick(List<&2, User>, token_hit(token, stored),
        User{id, name, password, stored, now, Maybe.default(&2, String, game, old_game)} <> t,
        h <> users_seen(t, token, now, game))

def touch_users(users: List<&2, User>, token: U32, now: U32) -> List<&2, User>:
  users_seen(users, token, now, None{})

def password_for(users: List<&2, User>, +name: String) -> U32:
  match users:
    case Nil{}:
      0
    case h <> t:
      User{id, stored, password, token, seen, game} = h
      Bool.pick(U32, String.eq(stored, name), password, password_for(t, name))

def login_users(users: List<&2, User>, +name: String, +token: U32, +now: U32) -> List<&2, User>:
  match users:
    case Nil{}:
      Nil{}
    case +h <> +t:
      User{id, +stored, password, old_token, seen, game} = h
      Bool.pick(List<&2, User>, String.eq(stored, name), User{id, stored, password, token, now, game} <> t, h <> login_users(t, name, token, now))

# Actions
# -------

def register.go(bad: Bool, +state: State, +name: String, +password: String, +now: U32) -> IO(State & HTTP.Response):
  match bad:
    case True{}:
      social_reply(state, "", 0, now, False{}, "choose a unique name and a password of at least four characters")
    case False{}:
      State{users, messages, invites, friends, +next_id} = state
      do IO<State & HTTP.Response>:
        word : U32 <- IO.try(U32, IO.random_u32())
        +token : U32 = (word + 1 : U32)
        social_reply(State{User{next_id, name, digest_password(name, password), token, now, ""} <> users, messages, invites, friends, (next_id + 1 : U32)}, name, token, now, True{}, "account created")

def register(+state: State, +parts: List<&2, String>, +now: U32) -> IO(State & HTTP.Response):
  State{users, messages, invites, friends, next_id} = state
  +name = part(parts, 0n)
  +password = part(parts, 1n)
  register.go((len(name) < 2 : U32) || (len(password) < 4 : U32) || find_name(users, name), state, name, password, now)

def login.go(ok: Bool, +state: State, +name: String, +now: U32) -> IO(State & HTTP.Response):
  match ok:
    case False{}:
      social_reply(state, "", 0, now, False{}, "invalid username or password")
    case True{}:
      State{users, messages, invites, friends, next_id} = state
      do IO<State & HTTP.Response>:
        word : U32 <- IO.try(U32, IO.random_u32())
        +token : U32 = (word + 1 : U32)
        social_reply(State{login_users(users, name, token, now), messages, invites, friends, next_id}, name, token, now, True{}, "welcome back")

def login(+state: State, +parts: List<&2, String>, +now: U32) -> IO(State & HTTP.Response):
  State{users, messages, invites, friends, next_id} = state
  +name = part(parts, 0n)
  +stored = password_for(users, name)
  login.go((stored > 0 : U32) && U32.is_eq(stored, digest_password(name, part(parts, 1n))), state, name, now)

# The common shape of a signed-in action: on `ok` the new state, else the
# old one (with the caller seen now), and the matching note.
def answer(ok: Bool, +old: State, +new: State, +who: String, +token: U32, +now: U32, yes: String, no: String) -> IO(State & HTTP.Response):
  match ok:
    case True{}:
      social_reply(new, who, token, now, True{}, yes)
    case False{}:
      social_reply(old, who, token, now, False{}, no)

def chat(+state: State, +parts: List<&2, String>, +now: U32) -> IO(State & HTTP.Response):
  State{users, messages, invites, +friends, +next_id} = state
  +token = num(part(parts, 0n))
  +who = token_name(users, token)
  +recipient = part(parts, 1n)
  +text = part(parts, 2n)
  +seen = touch_users(users, token, now)
  answer((len(who) > 0 : U32) && U32.is_eq(friends_kind(friends, who, recipient), 2) && (len(text) > 0 : U32),
    State{seen, messages, invites, friends, next_id},
    State{seen, Message{next_id, who, recipient, text, now} <> messages, invites, friends, (next_id + 1 : U32)},
    who, token, now, "message sent", "messages can only be sent to accepted friends")

def invite(+state: State, +parts: List<&2, String>, +now: U32) -> IO(State & HTTP.Response):
  State{users, messages, invites, +friends, +next_id} = state
  +token = num(part(parts, 0n))
  +who = token_name(users, token)
  +recipient = part(parts, 1n)
  +game = part(parts, 2n)
  +seen = touch_users(users, token, now)
  answer((len(who) > 0 : U32) && U32.is_eq(friends_kind(friends, who, recipient), 2),
    State{seen, messages, invites, friends, next_id},
    State{seen, messages, Invite{next_id, who, recipient, game, 0, now} <> invites, friends, (next_id + 1 : U32)},
    who, token, now, "invitation sent", "game invitations can only be sent to accepted friends")

def friend_request(+state: State, +parts: List<&2, String>, +now: U32) -> IO(State & HTTP.Response):
  State{+users, messages, invites, +friends, next_id} = state
  +token = num(part(parts, 0n))
  +who = token_name(users, token)
  +other = part(parts, 1n)
  +seen = touch_users(users, token, now)
  answer((len(who) > 0 : U32) && find_name(users, other) && Bool.not(String.eq(who, other)) && U32.is_zero(friends_kind(friends, who, other)),
    State{seen, messages, invites, friends, next_id},
    State{seen, messages, invites, Friend{who, other, 0} <> friends, next_id},
    who, token, now, "friend request sent", "choose a user who is not already a friend or pending")

def friend_accept(+state: State, +parts: List<&2, String>, +now: U32) -> IO(State & HTTP.Response):
  State{users, messages, invites, +friends, next_id} = state
  +token = num(part(parts, 0n))
  +who = token_name(users, token)
  +sender = part(parts, 1n)
  +seen = touch_users(users, token, now)
  answer((len(who) > 0 : U32) && friends_incoming(friends, sender, who),
    State{seen, messages, invites, friends, next_id},
    State{seen, messages, invites, friends_accept(friends, sender, who), next_id},
    who, token, now, "friend request accepted", "no incoming request from that user")

def friend_remove(+state: State, +parts: List<&2, String>, +now: U32) -> IO(State & HTTP.Response):
  State{users, messages, invites, +friends, next_id} = state
  +token = num(part(parts, 0n))
  +who = token_name(users, token)
  +other = part(parts, 1n)
  +seen = touch_users(users, token, now)
  answer((len(who) > 0 : U32) && (friends_kind(friends, who, other) > 0 : U32),
    State{seen, messages, invites, friends, next_id},
    State{seen, messages, invites, friends_remove(friends, who, other), next_id},
    who, token, now, "relationship removed", "friendship or request not found")

def presence.go(ok: Bool, +state: State, +who: String, +token: U32, +game: String, +now: U32) -> IO(State & HTTP.Response):
  match ok:
    case False{}:
      social_reply(state, "", 0, now, False{}, "sign in to publish presence")
    case True{}:
      State{users, messages, invites, friends, next_id} = state
      social_reply(State{users_seen(users, token, now, Some{game}), messages, invites, friends, next_id}, who, token, now, True{}, "")

def presence(+state: State, +parts: List<&2, String>, +now: U32) -> IO(State & HTTP.Response):
  State{users, messages, invites, friends, next_id} = state
  +token = num(part(parts, 0n))
  +who = token_name(users, token)
  presence.go((len(who) > 0 : U32), state, who, token, part(parts, 1n), now)

def state_get.found(f: Found, +state: State, +token: U32, +now: U32) -> IO(State & HTTP.Response):
  match f:
    case Found{who, stored, seen}:
      State{users, messages, invites, friends, next_id} = state
      social_reply(State{touch_users(users, token, now), messages, invites, friends, next_id}, who, token, now, True{}, "")
    case Missing{}:
      social_reply(state, "", 0, now, False{}, "sign in to join the social space")

def state_get(+state: State, token_text: String, +now: U32) -> IO(State & HTTP.Response):
  State{users, messages, invites, friends, next_id} = state
  +token = num(token_text)
  state_get.found(find_token(users, token), state, token, now)

def action_code(+name: String) -> U32:
  Bool.pick(U32, String.eq(name, "register"), 1,
  Bool.pick(U32, String.eq(name, "login"), 2,
  Bool.pick(U32, String.eq(name, "chat"), 3,
  Bool.pick(U32, String.eq(name, "invite"), 4,
  Bool.pick(U32, String.eq(name, "friend_request"), 5,
  Bool.pick(U32, String.eq(name, "friend_accept"), 6,
  Bool.pick(U32, String.eq(name, "friend_remove"), 7,
  Bool.pick(U32, String.eq(name, "presence"), 8, 0))))))))

def action_route(code: U32, +body: String, +state: State, +now: U32) -> IO(State & HTTP.Response):
  match code:
    case 1:
      register(state, HTTP.body_lines(body), now)
    case 2:
      login(state, HTTP.body_lines(body), now)
    case 3:
      chat(state, HTTP.body_lines(body), now)
    case 4:
      invite(state, HTTP.body_lines(body), now)
    case 5:
      friend_request(state, HTTP.body_lines(body), now)
    case 6:
      friend_accept(state, HTTP.body_lines(body), now)
    case 7:
      friend_remove(state, HTTP.body_lines(body), now)
    case 8:
      presence(state, HTTP.body_lines(body), now)
    case other:
      social_reply(state, "", 0, now, False{}, "unknown social route")

# POST /api/<action>; GET /api/state/<token>. Anything else answers a JSON
# note, as the old module did.
def route.segs(post: Bool, segs: List<&2, String>, +body: String, +state: State, +now: U32) -> IO(State & HTTP.Response):
  match post segs:
    case False{} "api" <> "state" <> token <> rest:
      state_get(state, token, now)
    case False{} _:
      social_reply(state, "", 0, now, False{}, "use POST for social actions")
    case True{} "api" <> name <> Nil{}:
      action_route(action_code(name), body, state, now)
    case True{} "api" <> name <> token <> rest:
      state_get(state, token, now)
    case True{} _:
      social_reply(state, "", 0, now, False{}, "use the social API")

def route(req: HTTP.Request, state: State, now: U32) -> IO(State & HTTP.Response):
  HTTP.Request{method, target, headers, body} = req
  route.segs(String.eq(method, "POST"), HTTP.segments(target), body, state, now)
