import ./transtyping.bend as Port
# The original gabs5 intentionally duplicates gabs3; this import preserves
# that regression-test identity without maintaining a second implementation.

def main() -> Bool:
  Port.main()
