# PBKDF2-HMAC-SHA-256 in pure Bend (the old effs/password_hash.c C effect,
# ported so the server needs no foreign code and still checks with ALL
# PROOFS CHECK). password_hash(password, salt) answers the same 64 lowercase
# hex digits as the old C: the salt is 4 big-endian bytes, one 32-byte block
# (INT(1)), 60,000 rounds, the password as its UTF-8 bytes.
#
# The rounds work on whole 32-bit words: HMAC's inner and outer pad states
# are compressed once, and every round is two compressions over a single
# pre-padded block, as optimized C implementations do. The loops are
# tail calls over U32 parameters, which the native backend turns into
# machine loops.
import Base

type S8 is Data:
  S8{a: U32, b: U32, c: U32, d: U32, e: U32, f: U32, g: U32, h: U32}

type W16 is Data:
  W16{w0: U32, w1: U32, w2: U32, w3: U32, w4: U32, w5: U32, w6: U32, w7: U32, w8: U32, w9: U32, w10: U32, w11: U32, w12: U32, w13: U32, w14: U32, w15: U32}

def k(i: U32) -> U32:
  match i:
    case 0:
      1116352408
    case 1:
      1899447441
    case 2:
      3049323471
    case 3:
      3921009573
    case 4:
      961987163
    case 5:
      1508970993
    case 6:
      2453635748
    case 7:
      2870763221
    case 8:
      3624381080
    case 9:
      310598401
    case 10:
      607225278
    case 11:
      1426881987
    case 12:
      1925078388
    case 13:
      2162078206
    case 14:
      2614888103
    case 15:
      3248222580
    case 16:
      3835390401
    case 17:
      4022224774
    case 18:
      264347078
    case 19:
      604807628
    case 20:
      770255983
    case 21:
      1249150122
    case 22:
      1555081692
    case 23:
      1996064986
    case 24:
      2554220882
    case 25:
      2821834349
    case 26:
      2952996808
    case 27:
      3210313671
    case 28:
      3336571891
    case 29:
      3584528711
    case 30:
      113926993
    case 31:
      338241895
    case 32:
      666307205
    case 33:
      773529912
    case 34:
      1294757372
    case 35:
      1396182291
    case 36:
      1695183700
    case 37:
      1986661051
    case 38:
      2177026350
    case 39:
      2456956037
    case 40:
      2730485921
    case 41:
      2820302411
    case 42:
      3259730800
    case 43:
      3345764771
    case 44:
      3516065817
    case 45:
      3600352804
    case 46:
      4094571909
    case 47:
      275423344
    case 48:
      430227734
    case 49:
      506948616
    case 50:
      659060556
    case 51:
      883997877
    case 52:
      958139571
    case 53:
      1322822218
    case 54:
      1537002063
    case 55:
      1747873779
    case 56:
      1955562222
    case 57:
      2024104815
    case 58:
      2227730452
    case 59:
      2361852424
    case 60:
      2428436474
    case 61:
      2756734187
    case 62:
      3204031479
    case other:
      3329325298

def iv() -> S8:
  S8{1779033703, 3144134277, 1013904242, 2773480762, 1359893119, 2600822924, 528734635, 1541459225}

def rotr(+x: U32, +n: Nat) -> U32:
  ((x >> n : U32) .|. (x << Nat.sub(32n, n) : U32) : U32)

def big_s0(+a: U32) -> U32:
  (rotr(a, 2n) .^. rotr(a, 13n) .^. rotr(a, 22n) : U32)

def big_s1(+e: U32) -> U32:
  (rotr(e, 6n) .^. rotr(e, 11n) .^. rotr(e, 25n) : U32)

def small_s0(+x: U32) -> U32:
  (rotr(x, 7n) .^. rotr(x, 18n) .^. (x >> 3n : U32) : U32)

def small_s1(+x: U32) -> U32:
  (rotr(x, 17n) .^. rotr(x, 19n) .^. (x >> 10n : U32) : U32)

def ch(+e: U32, f: U32, g: U32) -> U32:
  ((e .&. f : U32) .^. (U32.not(e) .&. g : U32) : U32)

def maj(+a: U32, +b: U32, +c: U32) -> U32:
  ((a .&. b : U32) .^. (a .&. c : U32) .^. (b .&. c : U32) : U32)

# The 64 rounds over a sliding 16-word message schedule.
def rounds(fuel: Nat, +i: U32,
  +a: U32, +b: U32, +c: U32, +d: U32, +e: U32, +f: U32, +g: U32, +h: U32,
  +w0: U32, +w1: U32, w2: U32, w3: U32, w4: U32, w5: U32, w6: U32, w7: U32,
  w8: U32, +w9: U32, w10: U32, w11: U32, w12: U32, w13: U32, +w14: U32, w15: U32) -> S8:
  match fuel:
    case 0n:
      S8{a, b, c, d, e, f, g, h}
    case 1n+p:
      +t1 = (h + big_s1(e) + ch(e, f, g) + k(i) + w0 : U32)
      +t2 = (big_s0(a) + maj(a, b, c) : U32)
      +next = (small_s1(w14) + w9 + small_s0(w1) + w0 : U32)
      rounds(p, (i + 1 : U32), (t1 + t2 : U32), a, b, c, (d + t1 : U32), e, f, g,
        w1, w2, w3, w4, w5, w6, w7, w8, w9, w10, w11, w12, w13, w14, w15, next)

def add8(s: S8, t: S8) -> S8:
  S8{a, b, c, d, e, f, g, h} = s
  S8{a2, b2, c2, d2, e2, f2, g2, h2} = t
  S8{(a + a2 : U32), (b + b2 : U32), (c + c2 : U32), (d + d2 : U32), (e + e2 : U32), (f + f2 : U32), (g + g2 : U32), (h + h2 : U32)}

def compress(+s: S8, blk: W16) -> S8:
  S8{a, b, c, d, e, f, g, h} = s
  W16{w0, w1, w2, w3, w4, w5, w6, w7, w8, w9, w10, w11, w12, w13, w14, w15} = blk
  add8(s, rounds(64n, 0, a, b, c, d, e, f, g, h, w0, w1, w2, w3, w4, w5, w6, w7, w8, w9, w10, w11, w12, w13, w14, w15))

# A 32-byte digest followed by SHA-256 padding for a message that is one
# 64-byte pad block plus these 32 bytes (768 bits).
def digest_block(s: S8) -> W16:
  S8{a, b, c, d, e, f, g, h} = s
  W16{a, b, c, d, e, f, g, h, 2147483648, 0, 0, 0, 0, 0, 0, 768}

def xor8(s: S8, t: S8) -> S8:
  S8{a, b, c, d, e, f, g, h} = s
  S8{a2, b2, c2, d2, e2, f2, g2, h2} = t
  S8{(a .^. a2 : U32), (b .^. b2 : U32), (c .^. c2 : U32), (d .^. d2 : U32), (e .^. e2 : U32), (f .^. f2 : U32), (g .^. g2 : U32), (h .^. h2 : U32)}

def xor16(blk: W16, +m: U32) -> W16:
  W16{w0, w1, w2, w3, w4, w5, w6, w7, w8, w9, w10, w11, w12, w13, w14, w15} = blk
  W16{(w0 .^. m : U32), (w1 .^. m : U32), (w2 .^. m : U32), (w3 .^. m : U32), (w4 .^. m : U32), (w5 .^. m : U32), (w6 .^. m : U32), (w7 .^. m : U32),
    (w8 .^. m : U32), (w9 .^. m : U32), (w10 .^. m : U32), (w11 .^. m : U32), (w12 .^. m : U32), (w13 .^. m : U32), (w14 .^. m : U32), (w15 .^. m : U32)}

# Bytes
# -----

def utf8(c: Char) -> List<&2, U32>:
  +n = Char.to_u32(c)
  Bool.pick(List<&2, U32>, (n < 128 : U32), [n],
  Bool.pick(List<&2, U32>, (n < 2048 : U32), [(192 .|. (n >> 6n : U32) : U32), (128 .|. (n .&. 63 : U32) : U32)],
  Bool.pick(List<&2, U32>, (n < 65536 : U32),
    [(224 .|. (n >> 12n : U32) : U32), (128 .|. ((n >> 6n : U32) .&. 63 : U32) : U32), (128 .|. (n .&. 63 : U32) : U32)],
    [(240 .|. (n >> 18n : U32) : U32), (128 .|. ((n >> 12n : U32) .&. 63 : U32) : U32), (128 .|. ((n >> 6n : U32) .&. 63 : U32) : U32), (128 .|. (n .&. 63 : U32) : U32)])))

def bytes(s: String) -> List<&2, U32>:
  match s:
    case SNil{}:
      Nil{}
    case SCon{h, t}:
      List.append(&2, U32, utf8(h), bytes(t))

def words(xs: List<&2, U32>) -> List<&2, U32>:
  match xs:
    case a <> b <> c <> d <> rest:
      ((a << 24n : U32) .|. (b << 16n : U32) .|. (c << 8n : U32) .|. d : U32) <> words(rest)
    case other:
      Nil{}

def blocks(xs: List<&2, U32>) -> List<&2, W16>:
  match xs:
    case w0 <> w1 <> w2 <> w3 <> w4 <> w5 <> w6 <> w7 <> w8 <> w9 <> w10 <> w11 <> w12 <> w13 <> w14 <> w15 <> rest:
      W16{w0, w1, w2, w3, w4, w5, w6, w7, w8, w9, w10, w11, w12, w13, w14, w15} <> blocks(rest)
    case other:
      Nil{}

def compress_all(xs: List<&2, W16>, +s: S8) -> S8:
  match xs:
    case Nil{}:
      s
    case b <> rest:
      compress_all(rest, compress(s, b))

def length32(xs: List<&2, U32>) -> U32:
  U32.from_nat(List.length(&2, U32, xs))

# SHA-256 of a byte list (messages under 512 MiB).
def sha256(+msg: List<&2, U32>) -> S8:
  +n = length32(msg)
  +zeros = ((119 - (n % 64 : U32) : U32) % 64 : U32)
  +bits = (n * 8 : U32)
  +tail = {128 <> List.replicate(U32, U32.to_nat(zeros), 0) : List<&2, U32>}
  +len = {[0, 0, 0, 0, (bits >> 24n : U32), ((bits >> 16n : U32) .&. 255 : U32), ((bits >> 8n : U32) .&. 255 : U32), (bits .&. 255 : U32)] : List<&2, U32>}
  compress_all(blocks(words(List.append(&2, U32, msg, List.append(&2, U32, tail, len)))), iv())

def s8_words(s: S8) -> List<&2, U32>:
  S8{a, b, c, d, e, f, g, h} = s
  [a, b, c, d, e, f, g, h]

# HMAC key: hashed when longer than a block, then zero-padded to 64 bytes.
def key_block(+key: List<&2, U32>) -> W16:
  +short = Bool.pick(List<&2, U32>, (length32(key) > 64 : U32), [], key)
  +ws = Bool.pick(List<&2, U32>, (length32(key) > 64 : U32), s8_words(sha256(key)), words(List.append(&2, U32, short, List.replicate(U32, U32.to_nat((64 - length32(short) : U32)), 0))))
  +padded = List.append(&2, U32, ws, List.replicate(U32, U32.to_nat((16 - length32(ws) : U32)), 0))
  Maybe.default(&2, W16, List.head(&2, W16, blocks(padded)), W16{0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0})

def hmac_rounds(fuel: Nat, +inner: S8, +outer: S8, +u: S8, +acc: S8) -> S8:
  match fuel:
    case 0n:
      acc
    case 1n+p:
      +next = compress(outer, digest_block(compress(inner, digest_block(u))))
      hmac_rounds(p, inner, outer, next, xor8(acc, next))

def hex_digit(+n: U32) -> Char:
  Char.from_u32(Bool.pick(U32, (n < 10 : U32), (n + 48 : U32), (n + 87 : U32)))

def hex_word(fuel: Nat, +w: U32) -> String:
  match fuel:
    case 0n:
      ""
    case 1n+p:
      +q = p
      SCon{hex_digit(((w >> Nat.mul(q, 4n) : U32) .&. 15 : U32)), hex_word(q, w)}

def hex(xs: List<&2, U32>) -> String:
  match xs:
    case Nil{}:
      ""
    case w <> rest:
      hex_word(8n, w) ++ hex(rest)

# PBKDF2-HMAC-SHA-256(password, salt as 4 big-endian bytes, rounds, 32
# bytes), rendered as 64 lowercase hex digits.
def pbkdf2(password: String, salt: U32, rounds: U32) -> String:
  +key = key_block(bytes(password))
  +inner = compress(iv(), xor16(key, 909522486))
  +outer = compress(iv(), xor16(key, 1549556828))
  # U1 = HMAC(P, salt || INT(1)): 8 message bytes after the 64-byte pad.
  +u1 = compress(outer, digest_block(compress(inner, W16{salt, 1, 2147483648, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 576})))
  hex(s8_words(hmac_rounds(U32.to_nat((rounds - 1 : U32)), inner, outer, u1, u1)))

def password_hash(password: String, salt: U32) -> String:
  pbkdf2(password, salt, 60000)
