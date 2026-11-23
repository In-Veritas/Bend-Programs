# Probability comparison used when LZ-ANI has both a distant >=11 anchor and
# a nearby >=7 seed. Upstream computes (1 - 4^-length)^trials in binary64.
# Bend Core exposes F32, so compare -log probabilities with the first three
# convergent terms. Powers below binary64's subtraction precision are clamped
# exactly as upstream's `1 - p` rounds to 1.0 at lengths >= 27.
import Base

def choose(-A: Type, condition: Bool, branches: Bool -> A) -> A:
  branches(condition)

def probability_cost(+length: U32, +trials: U32) -> F32:
  choose(F32, U32.is_ge(length, 27), \{
    True: 0.0
    False: (
      +x = {F32.pow(4.0, F32.neg(U32.to_f32(length))) : F32}
      +x2 = {F32.mul(x, x) : F32}
      +x3 = {F32.mul(x2, x) : F32}
      +series = {F32.add(x,
        F32.add(F32.div(x2, 2.0), F32.div(x3, 3.0))) : F32}
      F32.mul(U32.to_f32(trials), series)
    )
  })

law anchor_preferred:
  for +anchor_length: U32
  for +close_length: U32
  for +reference_length: U32
  for +literal_run: U32
  Bool

def anchor_preferred(anchor_length, close_length, reference_length,
                     literal_run):
  +anchor_trials = {U32.mul(2,
    U32.sub(U32.add(reference_length, 1), anchor_length)) : U32}
  # Deliberately wrapping U32 subtraction matches the upstream uint32 exponent
  # conversion when a close factor is longer than the nominal search window.
  +close_trials = {U32.sub(U32.add(literal_run, 41), close_length) : U32}
  F32.is_lt(probability_cost(anchor_length, anchor_trials),
    probability_cost(close_length, close_trials))
