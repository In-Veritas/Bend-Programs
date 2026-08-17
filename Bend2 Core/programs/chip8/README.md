# CHIP-8 emulator for Bend2 Core

This is a CHIP-8 emulator written in Bend2 Core. It interprets CHIP-8 bytecode;
it is not a Bend-to-CHIP-8 compiler. `chip8.bend` itself can be lowered by the
Core compiler to JavaScript or native C/machine code.

The compatibility profile is the original COSMAC VIP CHIP-8: 4 KiB memory,
program start at `0x200`, sixteen 8-bit V registers, a 12-entry call stack,
64×32 XOR graphics, the `Vy` source for shifts, and an incremented `I` after
`Fx55`/`Fx65`. Partially off-screen sprites are clipped after their starting
coordinates are reduced modulo the display dimensions. SUPER-CHIP and XO-CHIP
extensions are intentionally outside this program.

## Temporary ROM input

Bend2 Core declares effect data but does not yet provide an IO runtime. For
now, [`rom.bend`](rom.bend) exports `source()`, a whitespace-separated
hexadecimal `String`. The emulator imports it, parses pairs of hex digits, and
loads those bytes at CHIP-8 address `0x200`. Replace the string to run another
ROM; malformed or odd-length hex is rejected.

**Remove this embedded-ROM bridge when Bend2 Core gains implemented IO.** At
that point a host/file loader should supply ROM bytes and `rom.bend` should no
longer be part of the runtime path. The same future host integration can call
`machine_key` to update the 16-key state and render the exposed 64×32 pixel
array.

The current embedded ROM is a small deterministic smoke program. It exercises
clear, loads, wrapping 8-bit addition and carry, BCD memory stores,
call/return, original shift semantics, deterministic random masking, the font
address instruction, sprite drawing, delay timers, an unpressed-key skip, and
an infinite jump. `main` runs a fixed instruction budget and returns `True{}`
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

- There is no wall clock, so both timers tick once per emulated instruction
  (and while waiting for a key). A future IO scheduler should drive 60 Hz ticks
  separately.
- There is no display interrupt, so `Dxyn` completes in one VM step instead of
  waiting for the VIP vertical blank. A future display driver should supply
  that pacing separately.
- `Cxnn` uses a reproducible xorshift32 generator, making compiled tests stable.
- `Fx0A` changes the machine to `Waiting`, latches the first pressed key, then
  remains in `Releasing` until that key is released, matching the VIP manual.
  Without host key updates it remains waiting.
- Sound is represented by the sound-timer value. No audio is emitted.
- `0NNN` host-machine calls and invalid opcodes halt with an explicit status.

The VIP key-skip instructions use only the low nibble of their V register.
Halt codes are stable test-facing values: `1` unsupported/invalid opcode,
`2` memory/fetch bounds, `3` stack underflow, `4` stack overflow, `5` malformed
hex, `6` ROM overflow, and `7` an invalid host-supplied key index.

## Check and compile

From the sibling `bend2-core` checkout:

```sh
bun src/main.ts "../Bend-Programs/Bend2 Core/programs/chip8/chip8.bend"
bun src/main.ts "../Bend-Programs/Bend2 Core/programs/chip8/chip8.bend" --to /tmp/chip8.js
bun /tmp/chip8.js
bun src/main.ts "../Bend-Programs/Bend2 Core/programs/chip8/chip8.bend" --to /tmp/chip8.c
clang -O2 /tmp/chip8.c -o /tmp/chip8
/tmp/chip8
```

The normalizer and both compiled backends should report `True{}`.
For the native path alone, `./build.sh [output-path]` performs the C emission
and clang build; it defaults to `/tmp/bend2-core-chip8`. Set
`BEND2_CORE_REPO=/path/to/bend2-core` when the sibling checkout is elsewhere.

## References

- RCA, [*COSMAC VIP Instruction Manual* (1978)](https://www.bitsavers.org/components/rca/cosmac/COSMAC_VIP_Instruction_Manual_1978.pdf),
  section III and Appendix C.
- CHIP-8 extensions and compatibility, original CHIP-8 instruction table and
  COSMAC VIP compatibility notes: <https://chip-8.github.io/extensions/>
- Timendus CHIP-8 test suite, baseline and opcode/quirk descriptions:
  <https://github.com/Timendus/chip8-test-suite>
