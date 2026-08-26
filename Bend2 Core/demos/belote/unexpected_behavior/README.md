# Historical backend behavior

This log was originally recorded against Bend2 Core revision `26cddb7` and is
preserved as part of the package history. At that revision:

- the JavaScript emitter invoked and printed `main` immediately, so
  `build.mjs` had to verify and replace that exact footer to expose the pure
  report in a browser;
- direct normalization succeeded but printed a very large structural value for
  the 36 complete snapshots; and
- a custom-ADT `main` ran in JavaScript but the C entry driver could print only
  primitive result types.

Revision `c5b919a` changed this boundary, and `c5d69a1` retains it. Compiled
`main` must be `IO<T>` and both generated backends execute the same IO loop. The Belote kernel keeps
its report in `main_value`, the native and JavaScript entries both print
`Ready{}`, and the browser builder replaces the checked IO footer with an
explicit call to that pure report root. The old C answer-type mismatch is
therefore resolved for this program.

The current compiler also emits only definitions reachable from an executable
root. That is documented whole-program elimination, not treated here as a
defect; browser builders retain a pure export by adding a temporary nullary IO
root before compilation.
