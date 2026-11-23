# CHIP-8 emulator (Bend 2 port of the Bend2 Core emulator)

This is a CHIP-8 emulator written in Bend. It interprets CHIP-8 bytecode; it
is not a Bend-to-CHIP-8 compiler. It was written for the old bend2-core and is
now ported to the latest Bend (bendlang/bend, `bend 2.0.40`), which compiles it to a native binary (or JS).

The compatibility profile is the original COSMAC VIP CHIP-8: 4 KiB memory,
program start at `0x200`, sixteen 8-bit V registers, a 12-entry call stack,
64×32 XOR graphics, the `Vy` source for shifts, and an incremented `I` after
`Fx55`/`Fx65`. Partially off-screen sprites are clipped after their starting
coordinates are reduced modulo the display dimensions. SUPER-CHIP and XO-CHIP
extensions are intentionally outside this program.

## Usage

```sh
bend chip8.bend -o /tmp/chip8          # or ./build.sh [output-path]
/tmp/chip8                             # self-test with the bundled ROM: True{}
/tmp/chip8 digits.ch8                  # run a ROM file for 1000 instructions
/tmp/chip8 game.ch8 5000               # ... or for a given instruction budget
```

`bend chip8.bend [rom.ch8 [steps]]` does the same without keeping a binary.
With a ROM path, `main` reads the raw `.ch8` bytes (at most 3584, the space
from `0x200` to the end of RAM), loads them at `0x200`, runs the given number
of instructions and prints the 64×32 framebuffer (`#` lit, `.` dark) followed
by the machine status, `pc` and `I` in hex. `digits.ch8` is a 36-byte test ROM
that draws the sixteen font digits in two rows.

## Bundled self-test ROM

The old Bend2 Core had no IO runtime, so the ROM had to be embedded as a hex
`String` in [`rom.bend`](rom.bend). The owner's later Core revision gained an
IO loop and file operations, but still no argv, so it kept the embedded ROM
and wrapped the pure self-check as `main_value()` printed by an IO `main`.
The latest Bend has `IO.args`, so real ROMs now come from files named on the
command line and the embedded-ROM bridge is no longer on the runtime path for
them; `rom.bend` remains only as the self-test fixture used when no ROM path
is given, and `main_value()` (the owner's name) is that self-check. The hex parser (pairs of hex digits, any whitespace between them;
malformed or odd-length text halts with code 5) is kept for that fixture.

There is still no real-time keyboard: `machine_key` is the pure input seam a
window/keyboard driver (for example Bend's `App.run`) would call to update the
16-key state, and the framebuffer is exposed through `core_pixel`.

The bundled ROM is a small deterministic smoke program. It exercises
clear, loads, wrapping 8-bit addition and carry, BCD memory stores,
call/return, original shift semantics, deterministic random masking, the font
address instruction, sprite drawing, delay timers, an unpressed-key skip, and
an infinite jump. The self-test runs 40 instructions and prints `True{}`
only when the final registers, memory, framebuffer, index, program counter,
and stack match the expected state.

The bundled byte string corresponds to this CHIP-8 program (addresses are
hexadecimal):

```text
200  00E0       clear
202  60FA       V0 = 250
204  610A       V1 = 10
206  8014       V0 += V1; VF = carry
208  7005       V0 += 5                 # wraps to 9
20A  A300       I = 300
20C  F033       BCD(V0) -> RAM[I..I+2]
20E  222C       call 22C
210  C20F       V2 = random & 0F
212  630A       V3 = digit A
214  F329       I = font(V3)
216  6400       V4 = 0
218  6500       V5 = 0
21A  D455       draw five-byte digit at (V4,V5)
21C  6505       V5 = 5
21E  F515       delay = V5
220  F607       V6 = delay
222  6710       V7 = 10
224  E7A1       skip if low-nibble key 0 is not pressed
226  6000       failure path: clobber V0
228  1228       stable final loop
22C  6803       V8 = 3
22E  8816       V8 = V1 >> 1            # original Vy-source shift
230  881E       V8 = V1 << 1
232  6F01       VF = 1
234  69FF       V9 = FF
236  6A0F       VA = 0F
238  89A2       V9 &= VA; VF = 0        # original logic-flag reset
23A  00EE       return
```

## Deterministic headless behavior

- Both timers tick once per emulated instruction (and while waiting for a
  key), not at 60 Hz, so runs are reproducible. A real-time driver should
  tick them from `IO.now` instead.
- There is no display interrupt, so `Dxyn` completes in one VM step instead of
  waiting for the VIP vertical blank. A future display driver should supply
  that pacing separately.
- `Cxnn` uses a reproducible xorshift32 generator, making compiled tests stable.
- `Fx0A` changes the machine to `Waiting`, latches the first pressed key, then
  remains in `Releasing` until that key is released, matching the VIP manual.
  Without key updates it remains waiting.
- Sound is represented by the sound-timer value. No audio is emitted.
- `0NNN` host-machine calls and invalid opcodes halt with an explicit status.

The VIP key-skip instructions use only the low nibble of their V register.
Halt codes are stable test-facing values: `1` unsupported/invalid opcode,
`2` memory/fetch bounds, `3` stack underflow, `4` stack overflow, `5` malformed
hex, `6` ROM overflow, and `7` an invalid host-supplied key index.

## Check and compile

```sh
bend chip8.bend --check-only           # ALL PROOFS CHECK
bend chip8.bend -o /tmp/chip8 && /tmp/chip8
bend chip8.bend -o /tmp/chip8.js && bun /tmp/chip8.js
```

The native binary and the JS build both print `True{}`, and print identical
framebuffers for `digits.ch8`.

## Port notes (bend2-core to Bend 2.0.40)

- The machine is `Data` end to end. Bend's `Array` is an affine `Type`, and a
  read hands the array back in a pair that only a def parameter may
  destructure (`(core, v) = core_reg_get(core, x)` is rejected), so RAM,
  registers, stack, keys and pixels are persistent binary `Mem` trees with the
  same wrap-around indexing. Reads are plain values on a reusable `+Core`; a
  write path-copies one spine. The old `U32.copy`/`u32_pair` fan-out is gone.
- Every branch on a computed value goes through a helper (`branch` with
  thunks, or a def matching a `Nat`/`Bool` parameter), because Bend matches
  only parameters and pattern variables.
- Pair-returning loops became state-passing: sprite drawing threads a
  `Drawn{core, collision}` value, and the register block moves return the core.
- Still no `#[halts]` and no `@unsafe`: every loop is structural or counts
  down a `Nat` fuel.

## References

- RCA, [*COSMAC VIP Instruction Manual* (1978)](https://www.bitsavers.org/components/rca/cosmac/COSMAC_VIP_Instruction_Manual_1978.pdf),
  section III and Appendix C.
- CHIP-8 extensions and compatibility, original CHIP-8 instruction table and
  COSMAC VIP compatibility notes: <https://chip-8.github.io/extensions/>
- Timendus CHIP-8 test suite, baseline and opcode/quirk descriptions:
  <https://github.com/Timendus/chip8-test-suite>
