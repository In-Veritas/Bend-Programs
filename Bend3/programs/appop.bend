# branchless: operators trail the line to continue the expression
def appop(o: U32, a: U32, b: U32) -> U32:
  ((((o == 43) * (a + b)) +
  ((o == 45) * (a - b))) +
  ((o == 42) * (a * b))) +
  ((o == 47) * (a / (b + (b == 0))))

def main() -> U32:
  (appop(42, 6, 7) + appop(43, 1, 1)) + appop(47, 84, 2)
