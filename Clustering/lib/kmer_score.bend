# Pure Kmer-db ani-shorter decision seam, isolated for BendTT verification.
import Base

def minimum(+left: U32, +right: U32) -> U32:
  Bool.pick(U32, U32.is_lt(left, right), left, right)

def ani_shorter(+common: U32, +left: U32, +right: U32) -> F32:
  +denominator = {minimum(left, right) : U32}
  Bool.pick(F32, U32.is_eq(common, 0) || U32.is_eq(denominator, 0), 0.0,
    F32.sub(1.0, F32.mul(F32.neg(0.04),
      F32.log(F32.div(
        F32.mul(2.0, F32.div(U32.to_f32(common), U32.to_f32(denominator))),
        F32.add(F32.div(U32.to_f32(common), U32.to_f32(denominator)),
          1.0))))))

def candidate_accept(+common: U32, +left: U32, +right: U32,
                     +minimum_common: U32, +minimum_identity: U32) -> Bool:
  U32.is_ge(common, minimum_common)
    && F32.is_ge(ani_shorter(common, left, right),
      F32.div(U32.to_f32(minimum_identity), 10000.0))

# A positive common-kmer minimum makes a zero-overlap pair definitionally
# ineligible. This is exactly the seam needed to omit zero-overlap pairs from
# sparse inverted candidate discovery.
law zero_common_is_rejected:
  for +left: U32
  for +right: U32
  {candidate_accept(0, left, right, 20, 7000) == False{} : Bool}

def zero_common_is_rejected(left, right):
  {==}
