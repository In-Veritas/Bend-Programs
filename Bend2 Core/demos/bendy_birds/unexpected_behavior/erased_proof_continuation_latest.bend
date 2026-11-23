import Base

# Latest-Bend port of erased_proof_continuation.bend: a checked equality proof
# used only in an erased constructor field combines the proofs returned by two
# sequential calls. Bend matches only parameters, so the two call results are
# opened by a helper def instead of nested `match f(x):` continuations.

type Box is Data:
  Box{value: Nat}

type Claim<-A: Type, -P: @-value: A -> Type> is Type:
  Claim{value: A, -proof: P(value)}

def box_claim(box: Box) -> Claim<Box, output => {output == box : Box}>:
  Claim{box, {==}}

def list_claim.join(-head: Box, -tail: +List<Box>, hc: Claim<Box, output => {output == head : Box}>, tc: Claim<+List<Box>, output => {output == tail : +List<Box>}>) -> Claim<+List<Box>, output => {output == Con{head, tail} : +List<Box>}>:
  match hc tc:
    case Claim{head_output, head_exact} Claim{tail_output, tail_exact}:
      Claim{
        Con{head_output, tail_output},
        Equal.trans(
          +List<Box>,
          Con{head_output, tail_output},
          Con{head, tail_output},
          Con{head, tail},
          Equal.cong(Box, +List<Box>, value => Con{value, tail_output}, head_output, head, head_exact),
          Equal.cong(+List<Box>, +List<Box>, values => Con{head, values}, tail_output, tail, tail_exact)
        )
      }

def list_claim(boxes: +List<Box>) -> Claim<+List<Box>, output => {output == boxes : +List<Box>}>:
  match boxes:
    case Nil{}:
      Claim{Nil{}, {==}}
    case Con{head, tail}:
      list_claim.join(head, tail, box_claim(head), list_claim(tail))

def check.open(c: Claim<+List<Box>, output => {output == [Box{0n}, Box{1n}] : +List<Box>}>) -> Bool:
  match c:
    case Claim{output, proof}:
      True{}

def check() -> Bool:
  check.open(list_claim([Box{0n}, Box{1n}]))

def show_bool(value: Bool) -> IO(Unit):
  match value:
    case False{}:
      IO.print("False{}")
    case True{}:
      IO.print("True{}")

def main() -> IO(Unit):
  show_bool(check())
