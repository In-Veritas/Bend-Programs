import Base
import ./rom.bend as ROM

# A pure COSMAC VIP CHIP-8 emulator for Bend2 Core. The host-facing result is
# a self-checking Bool because Core currently has no IO driver. See README.md.

type Status:
  Running{}
  Waiting{register: U32}
  Releasing{register: U32, key: U32}
  Halted{code: U32}

type Core:
  Core{
    memory: Array<U32>,
    registers: Array<U32>,
    stack: Array<U32>,
    pixels: Array<U32>,
    keys: Array<U32>,
    pc: U32,
    index: U32,
    sp: U32,
    delay: U32,
    sound: U32,
    rng: U32
  }

type Machine:
  Machine{core: Core, status: Status}

type HexChar:
  HexSkip{}
  HexDigit{value: U32}
  HexBad{}

type LoadResult:
  LoadOK{memory: Array<U32>, next: U32}
  LoadFail{code: U32}

type BootResult:
  BootOK{machine: Machine}
  BootFail{code: U32}

type FetchResult:
  Fetched{opcode: U32, core: Core}
  FetchFailed{core: Core}

type Decoded:
  Decoded{group: U32, x: U32, y: U32, n: U32, nn: U32, nnn: U32}

# Core's affine U32 values need explicit fan-out.
def u32_pair(value: U32) -> U32 & U32:
  ((a, ea), (b, eb)) = U32.copy(value)
  (a, b)

def u32_triple(value: U32) -> U32 & (U32 & U32):
  (a, rest) = u32_pair(value)
  (b, c) = u32_pair(rest)
  (a, (b, c))

def u32_quad(value: U32) -> U32 & (U32 & (U32 & U32)):
  (a, rest) = u32_pair(value)
  (b, more) = u32_pair(rest)
  (c, d) = u32_pair(more)
  (a, (b, (c, d)))

def byte(value: U32) -> U32:
  U32.and(value, U32.from_nat(255n))

def address(value: U32) -> U32:
  U32.and(value, U32.from_nat(4095n))

def bool_byte(value: Bool) -> U32:
  match value:
    case False{}:
      U32.zero()
    case True{}:
      U32.one()

def timer_tick(value: U32) -> U32:
  (test, keep) = u32_pair(value)
  match U32.is_zero(test):
    case True{}:
      keep
    case False{}:
      U32.sub(keep, U32.one())

# Structural array duplication. Building one subtree and copying it lets the
# checker see one strictly decreasing recursive fill call instead of two calls
# on proof-copies of the same predecessor.
def array_copy(array: Array<U32>) -> Array<U32> & Array<U32>:
  match array:
    case ALeaf{value}:
      (v1, v2) = u32_pair(value)
      (ALeaf{v1}, ALeaf{v2})
    case ANode{left, right}:
      (l1, l2) = array_copy(left)
      (r1, r2) = array_copy(right)
      (ANode{l1, r1}, ANode{l2, r2})

# A full binary Array of depth n. CHIP-8 uses depths 12, 11 and 4.
def array_fill(depth: Nat, value: U32) -> Array<U32>:
  match depth:
    case 0n:
      ALeaf{value}
    case 1n+pred:
      (left, right) = array_copy(array_fill(pred, value))
      ANode{left, right}

def array_get(array: Array<U32>, slot: U32) -> Array<U32> & U32:
  (s1, s2) = u32_pair(slot)
  (array1, value) = Array.swap(U32, array, s1, U32.zero())
  (v1, v2) = u32_pair(value)
  (array2, dropped) = Array.swap(U32, array1, s2, v1)
  (array2, v2)

def array_put(array: Array<U32>, slot: U32, value: U32) -> Array<U32>:
  (next, old) = Array.swap(U32, array, slot, value)
  next

def hex_char(char: Char) -> HexChar:
  match char:
    case Chr{code}:
      match U32.to_nat(code):
        case 32n:
          HexSkip{}
        case 9n:
          HexSkip{}
        case 10n:
          HexSkip{}
        case 13n:
          HexSkip{}
        case 48n:
          HexDigit{U32.zero()}
        case 49n:
          HexDigit{U32.one()}
        case 50n:
          HexDigit{U32.from_nat(2n)}
        case 51n:
          HexDigit{U32.from_nat(3n)}
        case 52n:
          HexDigit{U32.from_nat(4n)}
        case 53n:
          HexDigit{U32.from_nat(5n)}
        case 54n:
          HexDigit{U32.from_nat(6n)}
        case 55n:
          HexDigit{U32.from_nat(7n)}
        case 56n:
          HexDigit{U32.from_nat(8n)}
        case 57n:
          HexDigit{U32.from_nat(9n)}
        case 65n:
          HexDigit{U32.from_nat(10n)}
        case 66n:
          HexDigit{U32.from_nat(11n)}
        case 67n:
          HexDigit{U32.from_nat(12n)}
        case 68n:
          HexDigit{U32.from_nat(13n)}
        case 69n:
          HexDigit{U32.from_nat(14n)}
        case 70n:
          HexDigit{U32.from_nat(15n)}
        case 97n:
          HexDigit{U32.from_nat(10n)}
        case 98n:
          HexDigit{U32.from_nat(11n)}
        case 99n:
          HexDigit{U32.from_nat(12n)}
        case 100n:
          HexDigit{U32.from_nat(13n)}
        case 101n:
          HexDigit{U32.from_nat(14n)}
        case 102n:
          HexDigit{U32.from_nat(15n)}
        case other:
          HexBad{}

def load_hex(text: String, high: Maybe<U32>, memory: Array<U32>, at: U32) -> LoadResult:
  match text high:
    case SNil{} None{}:
      LoadOK{memory, at}
    case SNil{} Some{orphan}:
      LoadFail{U32.from_nat(5n)}
    case SCon{head, tail} None{}:
      match hex_char(head):
        case HexSkip{}:
          load_hex(tail, None{}, memory, at)
        case HexBad{}:
          LoadFail{U32.from_nat(5n)}
        case HexDigit{digit}:
          load_hex(tail, Some{digit}, memory, at)
    case SCon{head, tail} Some{upper}:
      match hex_char(head):
        case HexSkip{}:
          load_hex(tail, Some{upper}, memory, at)
        case HexBad{}:
          LoadFail{U32.from_nat(5n)}
        case HexDigit{digit}:
          (bound, (slot, next)) = u32_triple(at)
          match U32.is_lt(bound, U32.from_nat(4096n)):
            case False{}:
              LoadFail{U32.from_nat(6n)}
            case True{}:
              value = U32.or(U32.shln(4n, upper), digit)
              load_hex(tail, None{}, array_put(memory, slot, value), U32.inc(next))

def font_source() -> String:
  "F0 90 90 90 F0 20 60 20 20 70 F0 10 F0 80 F0 F0 10 F0 10 F0 90 90 F0 10 10 F0 80 F0 10 F0 F0 80 F0 90 F0 F0 10 20 40 40 F0 90 F0 90 F0 F0 90 F0 10 F0 F0 90 F0 90 90 E0 90 E0 90 E0 F0 80 80 80 F0 E0 90 90 90 E0 F0 80 F0 80 F0 F0 80 F0 80 80"

def initial_rng() -> U32:
  U32.or(U32.shln(16n, U32.from_nat(192n)), U32.or(U32.shln(8n, U32.from_nat(255n)), U32.from_nat(238n)))

def boot(text: String) -> BootResult:
  match load_hex(font_source(), None{}, array_fill(12n, U32.zero()), U32.from_nat(80n)):
    case LoadFail{code}:
      BootFail{code}
    case LoadOK{memory, font_end}:
      match load_hex(text, None{}, memory, U32.from_nat(512n)):
        case LoadFail{code}:
          BootFail{code}
        case LoadOK{memory, rom_end}:
          BootOK{Machine{Core{
            memory,
            array_fill(4n, U32.zero()),
            array_fill(4n, U32.zero()),
            array_fill(11n, U32.zero()),
            array_fill(4n, U32.zero()),
            U32.from_nat(512n),
            U32.zero(),
            U32.zero(),
            U32.zero(),
            U32.zero(),
            initial_rng()
          }, Running{}}}

def core_running(core: Core) -> Machine:
  Machine{core, Running{}}

def core_halted(core: Core, code: U32) -> Machine:
  Machine{core, Halted{code}}

def core_waiting(core: Core, register: U32) -> Machine:
  Machine{core, Waiting{register}}

def core_releasing(core: Core, register: U32, key: U32) -> Machine:
  Machine{core, Releasing{register, key}}

def core_tick(core: Core) -> Core:
  match core:
    case Core{memory, registers, stack, pixels, keys, pc, index, sp, delay, sound, rng}:
      Core{memory, registers, stack, pixels, keys, pc, index, sp, timer_tick(delay), timer_tick(sound), rng}

def core_reg_get(core: Core, slot: U32) -> Core & U32:
  match core:
    case Core{memory, registers, stack, pixels, keys, pc, index, sp, delay, sound, rng}:
      (registers, value) = array_get(registers, slot)
      (Core{memory, registers, stack, pixels, keys, pc, index, sp, delay, sound, rng}, value)

def core_reg_put(core: Core, slot: U32, value: U32) -> Core:
  match core:
    case Core{memory, registers, stack, pixels, keys, pc, index, sp, delay, sound, rng}:
      Core{memory, array_put(registers, slot, byte(value)), stack, pixels, keys, pc, index, sp, delay, sound, rng}

def core_mem_get(core: Core, slot: U32) -> Core & U32:
  match core:
    case Core{memory, registers, stack, pixels, keys, pc, index, sp, delay, sound, rng}:
      (memory, value) = array_get(memory, slot)
      (Core{memory, registers, stack, pixels, keys, pc, index, sp, delay, sound, rng}, value)

def core_mem_put(core: Core, slot: U32, value: U32) -> Core:
  match core:
    case Core{memory, registers, stack, pixels, keys, pc, index, sp, delay, sound, rng}:
      Core{array_put(memory, slot, byte(value)), registers, stack, pixels, keys, pc, index, sp, delay, sound, rng}

def core_stack_get(core: Core, slot: U32) -> Core & U32:
  match core:
    case Core{memory, registers, stack, pixels, keys, pc, index, sp, delay, sound, rng}:
      (stack, value) = array_get(stack, slot)
      (Core{memory, registers, stack, pixels, keys, pc, index, sp, delay, sound, rng}, value)

def core_stack_put(core: Core, slot: U32, value: U32) -> Core:
  match core:
    case Core{memory, registers, stack, pixels, keys, pc, index, sp, delay, sound, rng}:
      Core{memory, registers, array_put(stack, slot, value), pixels, keys, pc, index, sp, delay, sound, rng}

def core_pixel_get(core: Core, slot: U32) -> Core & U32:
  match core:
    case Core{memory, registers, stack, pixels, keys, pc, index, sp, delay, sound, rng}:
      (pixels, value) = array_get(pixels, slot)
      (Core{memory, registers, stack, pixels, keys, pc, index, sp, delay, sound, rng}, value)

def core_pixel_put(core: Core, slot: U32, value: U32) -> Core:
  match core:
    case Core{memory, registers, stack, pixels, keys, pc, index, sp, delay, sound, rng}:
      Core{memory, registers, stack, array_put(pixels, slot, U32.and(value, U32.one())), keys, pc, index, sp, delay, sound, rng}

def core_key_get(core: Core, slot: U32) -> Core & U32:
  match core:
    case Core{memory, registers, stack, pixels, keys, pc, index, sp, delay, sound, rng}:
      (keys, value) = array_get(keys, slot)
      (Core{memory, registers, stack, pixels, keys, pc, index, sp, delay, sound, rng}, value)

def core_key_put(core: Core, slot: U32, value: U32) -> Core:
  match core:
    case Core{memory, registers, stack, pixels, keys, pc, index, sp, delay, sound, rng}:
      Core{memory, registers, stack, pixels, array_put(keys, slot, U32.and(value, U32.one())), pc, index, sp, delay, sound, rng}

def core_pc_get(core: Core) -> Core & U32:
  match core:
    case Core{memory, registers, stack, pixels, keys, pc, index, sp, delay, sound, rng}:
      (p1, p2) = u32_pair(pc)
      (Core{memory, registers, stack, pixels, keys, p1, index, sp, delay, sound, rng}, p2)

def core_pc_set(core: Core, pc: U32) -> Core:
  match core:
    case Core{memory, registers, stack, pixels, keys, old, index, sp, delay, sound, rng}:
      Core{memory, registers, stack, pixels, keys, pc, index, sp, delay, sound, rng}

def core_pc_skip(core: Core, condition: Bool) -> Core:
  match condition:
    case False{}:
      core
    case True{}:
      (core, pc) = core_pc_get(core)
      core_pc_set(core, U32.add(pc, U32.from_nat(2n)))

def core_index_get(core: Core) -> Core & U32:
  match core:
    case Core{memory, registers, stack, pixels, keys, pc, index, sp, delay, sound, rng}:
      (i1, i2) = u32_pair(index)
      (Core{memory, registers, stack, pixels, keys, pc, i1, sp, delay, sound, rng}, i2)

def core_index_set(core: Core, index: U32) -> Core:
  match core:
    case Core{memory, registers, stack, pixels, keys, pc, old, sp, delay, sound, rng}:
      Core{memory, registers, stack, pixels, keys, pc, address(index), sp, delay, sound, rng}

def core_sp_get(core: Core) -> Core & U32:
  match core:
    case Core{memory, registers, stack, pixels, keys, pc, index, sp, delay, sound, rng}:
      (s1, s2) = u32_pair(sp)
      (Core{memory, registers, stack, pixels, keys, pc, index, s1, delay, sound, rng}, s2)

def core_sp_set(core: Core, sp: U32) -> Core:
  match core:
    case Core{memory, registers, stack, pixels, keys, pc, index, old, delay, sound, rng}:
      Core{memory, registers, stack, pixels, keys, pc, index, sp, delay, sound, rng}

def core_delay_get(core: Core) -> Core & U32:
  match core:
    case Core{memory, registers, stack, pixels, keys, pc, index, sp, delay, sound, rng}:
      (d1, d2) = u32_pair(delay)
      (Core{memory, registers, stack, pixels, keys, pc, index, sp, d1, sound, rng}, d2)

def core_delay_set(core: Core, delay: U32) -> Core:
  match core:
    case Core{memory, registers, stack, pixels, keys, pc, index, sp, old, sound, rng}:
      Core{memory, registers, stack, pixels, keys, pc, index, sp, byte(delay), sound, rng}

def core_sound_set(core: Core, sound: U32) -> Core:
  match core:
    case Core{memory, registers, stack, pixels, keys, pc, index, sp, delay, old, rng}:
      Core{memory, registers, stack, pixels, keys, pc, index, sp, delay, byte(sound), rng}

def rng_left13(rng: U32) -> U32:
  (a1, a2) = u32_pair(rng)
  U32.xor(a1, U32.shln(13n, a2))

def rng_right17(rng: U32) -> U32:
  (a1, a2) = u32_pair(rng)
  U32.xor(a1, U32.shrn(17n, a2))

def rng_left5(rng: U32) -> U32:
  (a1, a2) = u32_pair(rng)
  U32.xor(a1, U32.shln(5n, a2))

def rng_step(rng: U32) -> U32:
  rng_left5(rng_right17(rng_left13(rng)))

def core_random(core: Core) -> Core & U32:
  match core:
    case Core{memory, registers, stack, pixels, keys, pc, index, sp, delay, sound, rng}:
      (r1, r2) = u32_pair(rng_step(rng))
      (Core{memory, registers, stack, pixels, keys, pc, index, sp, delay, sound, r1}, byte(r2))

def core_clear(core: Core) -> Core:
  match core:
    case Core{memory, registers, stack, pixels, keys, pc, index, sp, delay, sound, rng}:
      Core{memory, registers, stack, array_fill(11n, U32.zero()), keys, pc, index, sp, delay, sound, rng}

def decode(opcode: U32) -> Decoded:
  (whole, parts) = u32_pair(opcode)
  (a, (b, (c, rest))) = u32_quad(parts)
  (d, e) = u32_pair(rest)
  Decoded{
    U32.shrn(12n, a),
    U32.and(U32.shrn(8n, b), U32.from_nat(15n)),
    U32.and(U32.shrn(4n, c), U32.from_nat(15n)),
    U32.and(d, U32.from_nat(15n)),
    U32.and(e, U32.from_nat(255n)),
    U32.and(whole, U32.from_nat(4095n))
  }

def fetch(core: Core) -> FetchResult:
  (core, pc) = core_pc_get(core)
  (bound, (first, next)) = u32_triple(pc)
  match U32.is_lt(bound, U32.from_nat(4095n)):
    case False{}:
      FetchFailed{core}
    case True{}:
      (core, hi) = core_mem_get(core, first)
      (core, lo) = core_mem_get(core, U32.inc(next))
      (core, old_pc) = core_pc_get(core)
      core = core_pc_set(core, U32.add(old_pc, U32.from_nat(2n)))
      Fetched{U32.or(U32.shln(8n, hi), lo), core}

def find_key(fuel: Nat, slot: U32, core: Core) -> Core & Maybe<U32>:
  match fuel:
    case 0n:
      (core, None{})
    case 1n+pred:
      (read_slot, next_slot) = u32_pair(slot)
      (core, pressed) = core_key_get(core, read_slot)
      match U32.is_zero(pressed):
        case False{}:
          (core, Some{next_slot})
        case True{}:
          find_key(pred, U32.inc(next_slot), core)

def store_registers(fuel: Nat, reg: U32, at: U32, core: Core) -> Core & U32:
  match fuel:
    case 0n:
      (core, at)
    case 1n+pred:
      (r1, r2) = u32_pair(reg)
      (a1, a2) = u32_pair(at)
      (core, value) = core_reg_get(core, r1)
      core = core_mem_put(core, a1, value)
      store_registers(pred, U32.inc(r2), U32.inc(a2), core)

def load_registers(fuel: Nat, reg: U32, at: U32, core: Core) -> Core & U32:
  match fuel:
    case 0n:
      (core, at)
    case 1n+pred:
      (r1, r2) = u32_pair(reg)
      (a1, a2) = u32_pair(at)
      (core, value) = core_mem_get(core, a1)
      core = core_reg_put(core, r1, value)
      load_registers(pred, U32.inc(r2), U32.inc(a2), core)

def draw_bits(fuel: Nat, sprite: U32, x: U32, y: U32, mask: U32, core: Core, collision: Bool) -> Core & Bool:
  match fuel:
    case 0n:
      (core, collision)
    case 1n+pred:
      (s1, s2) = u32_pair(sprite)
      (x1, (x2, x3)) = u32_triple(x)
      (y1, (y2, y3)) = u32_triple(y)
      (m1, m2) = u32_pair(mask)
      match Bool.and(
        Bool.and(U32.is_lt(x1, U32.from_nat(64n)), U32.is_lt(y1, U32.from_nat(32n))),
        U32.is_ne(U32.and(s1, m1), U32.zero())):
        case False{}:
          draw_bits(pred, s2, U32.inc(x2), y3, U32.shr(m2), core, collision)
        case True{}:
          (pixel1, pixel2) = u32_pair(U32.add(U32.shln(6n, y2), x3))
          (core, old) = core_pixel_get(core, pixel1)
          (old1, old2) = u32_pair(old)
          core = core_pixel_put(core, pixel2, U32.xor(old1, U32.one()))
          draw_bits(pred, s2, U32.inc(x2), y3, U32.shr(m2), core, Bool.or(collision, U32.is_ne(old2, U32.zero())))

def draw_rows(fuel: Nat, at: U32, x: U32, y: U32, core: Core, collision: Bool) -> Core & Bool:
  match fuel:
    case 0n:
      (core, collision)
    case 1n+pred:
      (a1, a2) = u32_pair(at)
      (x1, x2) = u32_pair(x)
      (y1, y2) = u32_pair(y)
      (core, sprite) = core_mem_get(core, a1)
      (core, collision) = draw_bits(8n, sprite, x1, y1, U32.from_nat(128n), core, collision)
      draw_rows(pred, U32.inc(a2), x2, U32.inc(y2), core, collision)

def execute_0(nnn: U32, core: Core) -> Machine:
  match U32.to_nat(nnn):
    case 224n:
      core_running(core_clear(core))
    case 238n:
      (core, sp) = core_sp_get(core)
      (test, keep) = u32_pair(sp)
      match U32.is_zero(test):
        case True{}:
          core_halted(core, U32.from_nat(3n))
        case False{}:
          (s1, s2) = u32_pair(U32.sub(keep, U32.one()))
          (core, target) = core_stack_get(core, s1)
          core_running(core_pc_set(core_sp_set(core, s2), target))
    case sys:
      core_halted(core, U32.one())

def execute_call(target: U32, core: Core) -> Machine:
  (core, sp) = core_sp_get(core)
  (bound, (slot, next)) = u32_triple(sp)
  match U32.is_lt(bound, U32.from_nat(12n)):
    case False{}:
      core_halted(core, U32.from_nat(4n))
    case True{}:
      (core, return_pc) = core_pc_get(core)
      core = core_stack_put(core, slot, return_pc)
      core = core_sp_set(core, U32.inc(next))
      core_running(core_pc_set(core, target))

def execute_skip_byte(x: U32, nn: U32, equal: Bool, core: Core) -> Machine:
  match equal:
    case True{}:
      (core, value) = core_reg_get(core, x)
      core_running(core_pc_skip(core, U32.is_eq(value, nn)))
    case False{}:
      (core, value) = core_reg_get(core, x)
      core_running(core_pc_skip(core, Bool.not(U32.is_eq(value, nn))))

def execute_skip_regs(x: U32, y: U32, equal: Bool, core: Core) -> Machine:
  match equal:
    case True{}:
      (core, vx) = core_reg_get(core, x)
      (core, vy) = core_reg_get(core, y)
      core_running(core_pc_skip(core, U32.is_eq(vx, vy)))
    case False{}:
      (core, vx) = core_reg_get(core, x)
      (core, vy) = core_reg_get(core, y)
      core_running(core_pc_skip(core, Bool.not(U32.is_eq(vx, vy))))

def execute_8(x: U32, y: U32, n: U32, core: Core) -> Machine:
  match U32.to_nat(n):
    case 0n:
      (core, vy) = core_reg_get(core, y)
      core_running(core_reg_put(core, x, vy))
    case 1n:
      (xr, xw) = u32_pair(x)
      (core, vx) = core_reg_get(core, xr)
      (core, vy) = core_reg_get(core, y)
      core = core_reg_put(core, xw, U32.or(vx, vy))
      core_running(core_reg_put(core, U32.from_nat(15n), U32.zero()))
    case 2n:
      (xr, xw) = u32_pair(x)
      (core, vx) = core_reg_get(core, xr)
      (core, vy) = core_reg_get(core, y)
      core = core_reg_put(core, xw, U32.and(vx, vy))
      core_running(core_reg_put(core, U32.from_nat(15n), U32.zero()))
    case 3n:
      (xr, xw) = u32_pair(x)
      (core, vx) = core_reg_get(core, xr)
      (core, vy) = core_reg_get(core, y)
      core = core_reg_put(core, xw, U32.xor(vx, vy))
      core_running(core_reg_put(core, U32.from_nat(15n), U32.zero()))
    case 4n:
      (xr, xw) = u32_pair(x)
      (core, vx) = core_reg_get(core, xr)
      (core, vy) = core_reg_get(core, y)
      (test, result) = u32_pair(U32.add(vx, vy))
      carry = U32.is_gt(test, U32.from_nat(255n))
      core = core_reg_put(core, xw, result)
      core_running(core_reg_put(core, U32.from_nat(15n), bool_byte(carry)))
    case 5n:
      (xr, xw) = u32_pair(x)
      (core, vx) = core_reg_get(core, xr)
      (core, vy) = core_reg_get(core, y)
      (vx1, vx2) = u32_pair(vx)
      (vy1, vy2) = u32_pair(vy)
      flag = U32.is_ge(vx1, vy1)
      core = core_reg_put(core, xw, U32.sub(vx2, vy2))
      core_running(core_reg_put(core, U32.from_nat(15n), bool_byte(flag)))
    case 6n:
      (core, vy) = core_reg_get(core, y)
      (source, result) = u32_pair(vy)
      flag = U32.and(source, U32.one())
      core = core_reg_put(core, x, U32.shr(result))
      core_running(core_reg_put(core, U32.from_nat(15n), flag))
    case 7n:
      (xr, xw) = u32_pair(x)
      (core, vx) = core_reg_get(core, xr)
      (core, vy) = core_reg_get(core, y)
      (vx1, vx2) = u32_pair(vx)
      (vy1, vy2) = u32_pair(vy)
      flag = U32.is_ge(vy1, vx1)
      core = core_reg_put(core, xw, U32.sub(vy2, vx2))
      core_running(core_reg_put(core, U32.from_nat(15n), bool_byte(flag)))
    case 14n:
      (core, vy) = core_reg_get(core, y)
      (source, result) = u32_pair(vy)
      flag = U32.and(U32.shrn(7n, source), U32.one())
      core = core_reg_put(core, x, U32.shl(result))
      core_running(core_reg_put(core, U32.from_nat(15n), flag))
    case invalid:
      core_halted(core, U32.one())

def execute_b(target: U32, core: Core) -> Machine:
  (core, v0) = core_reg_get(core, U32.zero())
  (bound, keep) = u32_pair(U32.add(target, v0))
  match U32.is_lt(bound, U32.from_nat(4096n)):
    case False{}:
      core_halted(core, U32.from_nat(2n))
    case True{}:
      core_running(core_pc_set(core, keep))

def execute_c(x: U32, nn: U32, core: Core) -> Machine:
  (core, random) = core_random(core)
  core_running(core_reg_put(core, x, U32.and(random, nn)))

def execute_d(x: U32, y: U32, n: U32, core: Core) -> Machine:
  (core, vx) = core_reg_get(core, x)
  (core, vy) = core_reg_get(core, y)
  (core, at) = core_index_get(core)
  (at1, at2) = u32_pair(at)
  ((rows1, er1), (rows2, er2)) = Nat.copy(U32.to_nat(n))
  match U32.is_le(U32.add(at1, U32.from_nat(rows1)), U32.from_nat(4096n)):
    case False{}:
      core_halted(core, U32.from_nat(2n))
    case True{}:
      (core, collision) = draw_rows(
        rows2,
        at2,
        U32.mod(vx, U32.from_nat(64n)),
        U32.mod(vy, U32.from_nat(32n)),
        core,
        False{})
      core_running(core_reg_put(core, U32.from_nat(15n), bool_byte(collision)))

def key_condition(expect: Bool, pressed: U32) -> Bool:
  match expect:
    case False{}:
      U32.is_zero(pressed)
    case True{}:
      U32.is_ne(pressed, U32.zero())

def execute_key_skip(x: U32, expect: Bool, core: Core) -> Machine:
  (core, key) = core_reg_get(core, x)
  (core, pressed) = core_key_get(core, U32.and(key, U32.from_nat(15n)))
  core_running(core_pc_skip(core, key_condition(expect, pressed)))

def execute_e(x: U32, nn: U32, core: Core) -> Machine:
  match U32.to_nat(nn):
    case 158n:
      execute_key_skip(x, True{}, core)
    case 161n:
      execute_key_skip(x, False{}, core)
    case invalid:
      core_halted(core, U32.one())

def execute_bcd(x: U32, core: Core) -> Machine:
  (core, value) = core_reg_get(core, x)
  (v1, (v2, v3)) = u32_triple(value)
  (core, at) = core_index_get(core)
  (bound, (a1, (a2, a3))) = u32_quad(at)
  match U32.is_lt(bound, U32.from_nat(4094n)):
    case False{}:
      core_halted(core, U32.from_nat(2n))
    case True{}:
      core = core_mem_put(core, a1, U32.div(v1, U32.from_nat(100n)))
      core = core_mem_put(core, U32.inc(a2), U32.mod(U32.div(v2, U32.from_nat(10n)), U32.from_nat(10n)))
      core = core_mem_put(core, U32.add(a3, U32.from_nat(2n)), U32.mod(v3, U32.from_nat(10n)))
      core_running(core)

def execute_store(x: U32, core: Core) -> Machine:
  (x_count, x_bound) = u32_pair(x)
  (core, at) = core_index_get(core)
  (at_bound, at_loop) = u32_pair(at)
  match U32.is_lt(U32.add(at_bound, x_bound), U32.from_nat(4096n)):
    case False{}:
      core_halted(core, U32.from_nat(2n))
    case True{}:
      (core, next) = store_registers(Nat.add(U32.to_nat(x_count), 1n), U32.zero(), at_loop, core)
      core_running(core_index_set(core, next))

def execute_load(x: U32, core: Core) -> Machine:
  (x_count, x_bound) = u32_pair(x)
  (core, at) = core_index_get(core)
  (at_bound, at_loop) = u32_pair(at)
  match U32.is_lt(U32.add(at_bound, x_bound), U32.from_nat(4096n)):
    case False{}:
      core_halted(core, U32.from_nat(2n))
    case True{}:
      (core, next) = load_registers(Nat.add(U32.to_nat(x_count), 1n), U32.zero(), at_loop, core)
      core_running(core_index_set(core, next))

def execute_f(x: U32, nn: U32, core: Core) -> Machine:
  match U32.to_nat(nn):
    case 7n:
      (core, delay) = core_delay_get(core)
      core_running(core_reg_put(core, x, delay))
    case 10n:
      core_waiting(core, x)
    case 21n:
      (core, value) = core_reg_get(core, x)
      core_running(core_delay_set(core, value))
    case 24n:
      (core, value) = core_reg_get(core, x)
      core_running(core_sound_set(core, value))
    case 30n:
      (core, value) = core_reg_get(core, x)
      (core, at) = core_index_get(core)
      core_running(core_index_set(core, address(U32.add(at, value))))
    case 41n:
      (core, value) = core_reg_get(core, x)
      digit = U32.mod(value, U32.from_nat(16n))
      core_running(core_index_set(core, U32.add(U32.from_nat(80n), U32.mul(digit, U32.from_nat(5n)))))
    case 51n:
      execute_bcd(x, core)
    case 85n:
      execute_store(x, core)
    case 101n:
      execute_load(x, core)
    case invalid:
      core_halted(core, U32.one())

def execute(decoded: Decoded, core: Core) -> Machine:
  match decoded:
    case Decoded{group, x, y, n, nn, nnn}:
      match U32.to_nat(group):
        case 0n:
          execute_0(nnn, core)
        case 1n:
          core_running(core_pc_set(core, nnn))
        case 2n:
          execute_call(nnn, core)
        case 3n:
          execute_skip_byte(x, nn, True{}, core)
        case 4n:
          execute_skip_byte(x, nn, False{}, core)
        case 5n:
          match U32.is_zero(n):
            case True{}:
              execute_skip_regs(x, y, True{}, core)
            case False{}:
              core_halted(core, U32.one())
        case 6n:
          core_running(core_reg_put(core, x, nn))
        case 7n:
          (xr, xw) = u32_pair(x)
          (core, value) = core_reg_get(core, xr)
          core_running(core_reg_put(core, xw, U32.add(value, nn)))
        case 8n:
          execute_8(x, y, n, core)
        case 9n:
          match U32.is_zero(n):
            case True{}:
              execute_skip_regs(x, y, False{}, core)
            case False{}:
              core_halted(core, U32.one())
        case 10n:
          core_running(core_index_set(core, nnn))
        case 11n:
          execute_b(nnn, core)
        case 12n:
          execute_c(x, nn, core)
        case 13n:
          execute_d(x, y, n, core)
        case 14n:
          execute_e(x, nn, core)
        case 15n:
          execute_f(x, nn, core)
        case invalid:
          core_halted(core, U32.one())

def machine_step(machine: Machine) -> Machine:
  match machine:
    case Machine{core, status}:
      match status:
        case Halted{code}:
          Machine{core, Halted{code}}
        case Waiting{register}:
          (core, key) = find_key(16n, U32.zero(), core_tick(core))
          match key:
            case None{}:
              core_waiting(core, register)
            case Some{value}:
              core_releasing(core, register, value)
        case Releasing{register, key}:
          (read_key, keep_key) = u32_pair(key)
          (core, pressed) = core_key_get(core_tick(core), read_key)
          match U32.is_zero(pressed):
            case False{}:
              core_releasing(core, register, keep_key)
            case True{}:
              core_running(core_reg_put(core, register, keep_key))
        case Running{}:
          match fetch(core_tick(core)):
            case FetchFailed{core}:
              core_halted(core, U32.from_nat(2n))
            case Fetched{opcode, core}:
              execute(decode(opcode), core)

def machine_run(fuel: Nat, machine: Machine) -> Machine:
  match fuel:
    case 0n:
      machine
    case 1n+pred:
      machine_run(pred, machine_step(machine))

# This is the future IO integration seam. An input driver can set or clear a
# CHIP-8 key without changing any emulation logic.
def machine_key(machine: Machine, key: U32, pressed: Bool) -> Machine:
  match machine:
    case Machine{core, status}:
      (bound, slot) = u32_pair(key)
      match U32.is_lt(bound, U32.from_nat(16n)):
        case False{}:
          core_halted(core, U32.from_nat(7n))
        case True{}:
          Machine{core_key_put(core, slot, bool_byte(pressed)), status}

def pixel_sum(pixels: Array<U32>) -> U32:
  match pixels:
    case ALeaf{value}:
      value
    case ANode{left, right}:
      U32.add(pixel_sum(left), pixel_sum(right))

def verify(machine: Machine) -> Bool:
  match machine:
    case Machine{Core{memory, registers, stack, pixels, keys, pc, index, sp, delay, sound, rng}, status}:
      match status:
        case Halted{code}:
          False{}
        case Waiting{register}:
          False{}
        case Releasing{register, key}:
          False{}
        case Running{}:
          (registers, v0) = array_get(registers, U32.zero())
          (registers, v2) = array_get(registers, U32.from_nat(2n))
          (registers, v6) = array_get(registers, U32.from_nat(6n))
          (registers, v8) = array_get(registers, U32.from_nat(8n))
          (registers, v9) = array_get(registers, U32.from_nat(9n))
          (registers, vf) = array_get(registers, U32.from_nat(15n))
          (memory, b0) = array_get(memory, U32.from_nat(768n))
          (memory, b1) = array_get(memory, U32.from_nat(769n))
          (memory, b2) = array_get(memory, U32.from_nat(770n))
          a = U32.is_eq(v0, U32.from_nat(9n))
          b = U32.is_eq(v2, U32.zero())
          c = U32.is_eq(v6, U32.from_nat(4n))
          d = U32.is_eq(v8, U32.from_nat(20n))
          e = U32.is_eq(v9, U32.from_nat(15n))
          f = U32.is_eq(vf, U32.zero())
          g = U32.is_eq(b0, U32.zero())
          h = U32.is_eq(b1, U32.zero())
          j = U32.is_eq(b2, U32.from_nat(9n))
          k = U32.is_eq(pixel_sum(pixels), U32.from_nat(14n))
          m = U32.is_eq(pc, U32.from_nat(552n))
          n = U32.is_eq(index, U32.from_nat(130n))
          o = U32.is_eq(sp, U32.zero())
          ab = Bool.and(a, b)
          cd = Bool.and(c, d)
          ef = Bool.and(e, f)
          gh = Bool.and(g, h)
          jk = Bool.and(j, k)
          mn = Bool.and(m, n)
          Bool.and(ab, Bool.and(cd, Bool.and(ef, Bool.and(gh, Bool.and(jk, Bool.and(mn, o))))))

def main() -> Bool:
  match boot(ROM.source()):
    case BootFail{code}:
      False{}
    case BootOK{machine}:
      verify(machine_run(40n, machine))
