# Unexpected behavior and limitations

- Bend2 Core's JavaScript emitter always appends an immediate `main` printer.
  `build.mjs` verifies and replaces that exact footer to expose the pure result
  to a browser. It fails loudly if the compiler changes the footer.
- Core has no browser/clock/input effect runner, so playback controls belong to
  the viewer. The complete state sequence remains Bend-owned.
- A custom-ADT `main` is supported by generated JavaScript but is outside the C
  driver's primitive result printer. This demo deliberately targets the JS
  backend requested for the comparison hub.
