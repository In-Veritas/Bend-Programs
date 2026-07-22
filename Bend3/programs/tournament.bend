# tournament maximum: seed a single-elimination bracket of 2^d players with
# scrambled numbers, then crown the champion. Every Match resolves its two
# halves with a fork/join let (! a b = f g;), so the whole bracket plays out
# in parallel on the compiled runtime -- finding a maximum in log(n) rounds.
# winner is branchless: the two comparison bits pick exactly one operand.
#
# $ bend tournament.bend

Bracket : Data {
  Player{seed: U32}
  Match{lft: Bracket, rgt: Bracket}
}

# a little LCG scramble so the bracket looks like a real draw
scramble : U32 -> U32
= λs. ! +ss = &(* s 1664525); (^ (+ *ss 1013904223) (>> *ss 7))

seed : U32 -> U32 -> Bracket
| 0 s = Player{(% s 1000)}
| d s = ! +dd +ss = &d &s;
  ! l r = seed((- *dd 1), scramble((* *ss 2))) seed((- *dd 1), scramble((+ (* *ss 2) 1)));
  Match{l, r}

winner : U32 -> U32 -> U32
| a b = ! +aa +bb = &a &b;
  (+ (* (>= *aa *bb) *aa) (* (< *aa *bb) *bb))

champion : Bracket -> U32
| Player{s}   = s
| Match{l, r} = ! a b = champion(l) champion(r); winner(a, b)

# 64 scrambled players enter, one number leaves
# (the interpreter is fine up to here; compiled, crank d way up)
main : U32 = champion(seed(6, 42))
