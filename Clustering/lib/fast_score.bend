# Pure threshold-calibrated MinHash score. Kept independent of FASTA IO so
# BendTT's proven kernel can validate its laws with `--verdict`.
import Base

def choose(-A: Type, b: Bool, f: Bool -> A) -> A:
  f(b)

def minimum(+a: U32, +b: U32) -> U32:
  choose(U32, U32.is_lt(a, b), \{True: a; False: b})

law basis_power:
  for fuel: Nat
  for +value: U32
  for +accumulator: U32
  U32

def basis_power(fuel, value, accumulator):
  match fuel:
    case Zero{}:
      accumulator
    case Succ{rest}:
      basis_power(rest, value,
        U32.div(U32.mul(accumulator, value), 10000))

law score:
  for +common: U32
  for +populated: U32
  for +threshold: U32
  U32

def score(common, populated, threshold):
  choose(U32, U32.is_eq(common, 0), \{
    True: 0
    False: (
      +word_identity = {basis_power(15n, threshold, 10000) : U32}
      +jaccard = {U32.div(U32.mul(word_identity, 10000),
        U32.sub(20000, word_identity)) : U32}
      +expected = {U32.div(U32.mul(64, jaccard), 10000) : U32}
      +rounded = {U32.div(U32.add(U32.mul(expected, 2), 4), 5) : U32}
      +raw_required = {choose(U32, U32.is_gt(1, rounded), \{
        True: 1
        False: rounded
      }) : U32}
      +required = {minimum(raw_required, populated) : U32}
      choose(U32,
        U32.is_eq(populated, 0) || U32.is_lt(common, required), \{
          True: 0
          False: U32.add(threshold,
            U32.div(U32.mul(U32.sub(10000, threshold), common), populated))
        })
    )
  })

# The indexed traversal calls this wrapper after counting common postings.
# This universal law states that its decision is exactly the canonical score,
# rather than a second approximation added by the index.
law indexed_score:
  for +common: U32
  for +populated: U32
  for +threshold: U32
  U32

def indexed_score(common, populated, threshold):
  score(common, populated, threshold)

law indexed_score_agrees:
  for +common: U32
  for +populated: U32
  for +threshold: U32
  {indexed_score(common, populated, threshold)
    == score(common, populated, threshold) : U32}

def indexed_score_agrees(common, populated, threshold):
  {==}

law zero_common_is_rejected:
  for +populated: U32
  for +threshold: U32
  {score(0, populated, threshold) == 0 : U32}

def zero_common_is_rejected(populated, threshold):
  {==}
