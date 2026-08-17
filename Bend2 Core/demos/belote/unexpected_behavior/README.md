# Unexpected behavior and limitations

- Bend2 Core's JavaScript emitter invokes and prints `main` immediately.
  `build.mjs` verifies and replaces that exact footer to expose the pure report
  in a browser; it deliberately fails if the emitter shape changes.
- Core has no DOM, clock, input, HTTP, or random effect runner. Playback buttons
  and scheduling therefore live in the viewer, while the entire state timeline
  remains Bend-owned.
- Direct normalization succeeds, but prints an extremely large structural
  representation because the result contains 36 full snapshots. Generated
  JavaScript is the practical execution path for the browser.
- A custom-ADT `main` works with the JavaScript backend but is outside the C
  driver's primitive result printer. This demo intentionally targets JS.
- The hand demonstrates classic play rules and contract scoring without optional
  announcements such as tierce, carré, or belote-rebelote.
