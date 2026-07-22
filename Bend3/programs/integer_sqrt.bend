# integer square root as a binary search over the answer's bits: the root of
# a U32 fits in 16 bits, so exactly 16 probes settle it, most significant bit
# first. Each step proposes candidate = best-so-far + 2^(i-1) and keeps it iff
# candidate^2 still fits under n. The bit counter i is the halt measure.
#
# $ bend integer_sqrt.bend

List(t: Data) : Data {
  Cons{head: t, tail: List(t)}
  Nil{}
}

isqrt_go : U32 -> U32 -> +U32 +> U32
| 0 b n = b
| i b n = ! +ii +bb = &i &b;
  ! c = (+ *bb (<< 1 (- *ii 1)));
  ! +cc = &c;
  match (* *cc *cc) <= *n:
    case 0:
      isqrt_go((- *ii 1), *bb, n)
    case k:
      isqrt_go((- *ii 1), *cc, n)

isqrt : U32 -> U32
= λn. ! +nn = &n; isqrt_go(16, 0, nn)

main : List(U32) =
  [isqrt(0), isqrt(1), isqrt(99), isqrt(100), isqrt(1000000), isqrt(4294967295)]
