import ./transtyping.bend as Port
# The original gabs3 is the same transtyping program; this wrapper preserves
# its authored filename while reusing the checked Bend2 Core port.

def main() -> Bool:
  Port.main()
