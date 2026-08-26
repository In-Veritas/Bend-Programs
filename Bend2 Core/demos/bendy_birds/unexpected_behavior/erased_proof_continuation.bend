import Base

# A checked equality proof used only in an erased constructor field crosses
# two sequential calls. The JavaScript emitter omits the proof continuation
# capture but still emits a read of its source binder.

type Box:
  Box{value: Nat}

type Claim<-A: Type, -P: @-value: A -> Type>:
  Claim{value: A, -proof: P(value)}

assert box_claim:
  forall box: Box
  Claim<Box, output => {output == box : Box}>

def box_claim(box):
  Claim{box, {==}}

assert list_claim:
  forall boxes: List<Box>
  Claim<List<Box>, output => {output == boxes : List<Box>}>

def list_claim(boxes):
  match boxes:
    case Nil{}:
      Claim{Nil{}, {==}}
    case Con{head, tail}:
      match box_claim!(head):
        case Claim{head_output, head_exact}:
          match list_claim(tail):
            case Claim{tail_output, tail_exact}:
              Claim{
                Con{head_output, tail_output},
                Equal.trans(
                  List<Box>,
                  Con{head_output, tail_output},
                  Con{head, tail_output},
                  Con{head, tail},
                  Equal.cong(
                    Box,
                    List<Box>,
                    value => Con{value, tail_output},
                    head_output,
                    head,
                    head_exact
                  ),
                  Equal.cong(
                    List<Box>,
                    List<Box>,
                    values => Con{head, values},
                    tail_output,
                    tail,
                    tail_exact
                  )
                )
              }

assert check:
  Bool

def check():
  match list_claim(Con{Box{0n}, Con{Box{1n}, Nil{}}}):
    case Claim{output, proof}:
      True{}

assert show_bool:
  forall value: Bool
  IO(Unit)

def show_bool(value):
  match value:
    case False{}:
      IO.print("False{}")
    case True{}:
      IO.print("True{}")

assert main:
  IO(Unit)

def main():
  show_bool(check!())
