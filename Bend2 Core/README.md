# Bend2 Core ports

Ports of Gabriel's Bend3 programs that were first written for the
experimental `bend2-core` affine dependent core (checked against `bend2-core`
commit `26cddb7` on 2026-08-17). That compiler is gone; bend2-core was the
direct ancestor of the released **Bend 2.0.40**, and every program here is now
ported to it. See [GUIDE.md](GUIDE.md) for the language differences and
porting rules.

## Layout

- `programs/` contains fourteen ports of Gabriel's Bend3 programs plus the
  CHIP-8 emulator in `programs/chip8/`. Pure `main` functions are compact
  self-checks: `True{}` means the expected result was reproduced. `gabs1` and
  `gabs4` use IO and were unsupported under Core; see
  `programs/UNSUPPORTED.md`.
- `demos/README.md` records the port decision for every Bend3 demo package.

## Run

With the `bend` CLI (Bend 2.0.40) on `PATH`:

```sh
cd "Bend2 Core/programs"
bend insertion_sort.bend --check-only          # ALL PROOFS CHECK
bend insertion_sort.bend                       # normalizes main: True{}
bend insertion_sort.bend -o /tmp/insertion_sort && /tmp/insertion_sort
bend insertion_sort.bend -o /tmp/insertion_sort.js && bun /tmp/insertion_sort.js
bend gabs4.bend fixtures/reference.txt fixtures/other.txt
```

Every program checks with `ALL PROOFS CHECK` and uses neither the old
`#[halts]` license nor `@unsafe`. All pure entries return the same answer
(`True{}`, or `{==}` for `nat_proofs.bend`) through the normalizer, a native
build and the JS build. `tournament.bend` normalizes in about two seconds now
(Core's normalizer did not finish it in 18 minutes).

The CHIP-8 emulator's `main` is an IO shell: with no argument it runs the
bundled smoke ROM from `rom.bend` and prints `True{}`; given a `.ch8` file it
runs it and prints the framebuffer. See its [README](programs/chip8/README.md).
