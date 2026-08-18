# Bend2 Core ports

Ports of Gabriel's Bend3 programs to the experimental `bend2-core` affine
dependent core. They were checked against `bend2-core` commit `26cddb7` on
2026-08-17. See [GUIDE.md](GUIDE.md) for the language differences and porting
rules.

## Layout

- `programs/` contains twelve ports of Gabriel's pure Bend3 programs plus the
  pure CHIP-8 emulator in `programs/chip8/`. Computational `main` functions are
  compact self-checks: `True{}` means the expected result was reproduced.
- `programs/UNSUPPORTED.md` records the two IO programs that cannot be made
  runnable without an effect runtime.
- `demos/README.md` records the port decision for every Bend3 demo package.

## Run

From the sibling `bend2-core` checkout:

```sh
bun src/main.ts "../Bend-Programs/Bend2 Core/programs/insertion_sort.bend"
bun src/main.ts "../Bend-Programs/Bend2 Core/programs/insertion_sort.bend" --to /tmp/insertion_sort.js
bun /tmp/insertion_sort.js
```

For `tournament.bend`, always use `--to`: direct normalization expands the
structural implementations of U32 arithmetic and copying and was still using
CPU after 18 minutes, while generated JS and C both finish immediately with
`True{}`.

All computational entries check during emission, compile to JavaScript and C,
and return `True{}` through both generated backends. `nat_proofs.bend`
evaluates to `{==}` in the normalizer; its
erased proof has no runtime payload, so the JS backend prints `-`, while the C
emitter rejects equality as an unsupported `main` answer type.

The CHIP-8 emulator interprets a hexadecimal ROM string imported from its own
`rom.bend`, and its Core-generated C compiles to a native executable. See its
[README](programs/chip8/README.md) for the temporary no-IO input bridge and the
explicit removal note for when Core gains an effect runtime.

The Poker observer in `demos/poker/` also exercises Core's dependent proof
surface. It carries hand-written existential witnesses for outcome sensitivity
and seat reachability plus exhaustive finite equality proofs for its published
odds rows. The generated viewer exposes a proof audit while the JS backend
erases the proof payloads.

`demos/bend_a_beet/` is a 3D seeded farm simulation built from separate
physics, graphics, and ray-tracing Core libraries. Its generated 1,086-frame
report covers five seconds of growth, simultaneous uprooting, and individual
break, spring, or recovery responses. The libraries carry 28 erased, explicit
Core theorems; see its README for their exact scope and the browser boundary.
