import Base
import ./rom.bend as ROM

# A COSMAC VIP CHIP-8 emulator. The emulation itself is pure: a Machine is a
# reusable Data value and one `machine_step` executes one instruction. `main`
# is the IO shell: it loads a binary ROM file named on the command line (or,
# with no argument, runs the bundled smoke ROM from rom.bend as a self-test)
# and prints the 64x32 framebuffer. See README.md.

type Status is Data:
  Running{}
  Waiting{register: U32}
  Releasing{register: U32, key: U32}
  Halted{code: U32}

# Persistent binary RAM. Bend's Array is an affine Type, and every read hands
# it back inside a pair that only a def parameter may destructure; a Data tree
# instead lets the whole Core be a reusable `+Core`, so reads are plain values
# and a write path-copies one root-to-leaf spine. Indexes wrap like Array's.
type Mem is Data:
  Cell{value: U32}
  Fork{lo: Mem, hi: Mem}

type Core is Data:
  Core{
    memory: Mem,
    registers: Mem,
    stack: Mem,
    pixels: Mem,
    keys: Mem,
    pc: U32,
    index: U32,
    sp: U32,
    delay: U32,
    sound: U32,
    rng: U32
  }

type Machine is Data:
  Machine{core: Core, status: Status}

type HexChar is Data:
  HexSkip{}
  HexDigit{value: U32}
  HexBad{}

type LoadResult is Data:
  LoadOK{memory: Mem, next: U32}
  LoadFail{code: U32}

type BootResult is Data:
  BootOK{machine: Machine}
  BootFail{code: U32}

type FetchResult is Data:
  Fetched{opcode: U32, core: Core}
  FetchFailed{core: Core}

type Decoded is Data:
  Decoded{group: U32, x: U32, y: U32, n: U32, nn: U32, nnn: U32}

type Drawn is Data:
  Drawn{core: Core, collision: Bool}

# Bend matches only parameters, so a computed Bool picks one of two thunks
# here; only the chosen branch runs.
def branch(-A: Type, c: Bool, t: Unit -> A, f: Unit -> A) -> A:
  match c:
    case True{}:
      t(Unit{})
    case False{}:
      f(Unit{})

def byte(value: U32) -> U32:
  U32.and(value, 255)

def address(value: U32) -> U32:
  U32.and(value, 4095)

def bool_byte(value: Bool) -> U32:
  match value:
    case False{}:
      0
    case True{}:
      1

def timer_tick(+value: U32) -> U32:
  Bool.pick(U32, U32.is_zero(value), value, U32.sub(value, 1))

# Memory trees
# ------------
# `mask` selects the index bit of the current level, top bit first.

def mem_fill(+depth: Nat, +value: U32) -> Mem:
  match depth:
    case 0n:
      Cell{value}
    case 1n+p:
      +half = mem_fill(p, value)
      Fork{half, half}

def mem_get(mem: Mem, +mask: U32, +slot: U32) -> U32:
  match mem:
    case Cell{value}:
      value
    case Fork{lo, hi}:
      branch(U32, U32.is_zero(U32.and(slot, mask)),
        u => mem_get(lo, U32.shr(mask), slot),
        u => mem_get(hi, U32.shr(mask), slot))

def mem_set(+mem: Mem, +mask: U32, +slot: U32, +value: U32) -> Mem:
  match mem:
    case Cell{old}:
      Cell{value}
    case Fork{lo, hi}:
      branch(Mem, U32.is_zero(U32.and(slot, mask)),
        u => Fork{mem_set(lo, U32.shr(mask), slot, value), hi},
        u => Fork{lo, mem_set(hi, U32.shr(mask), slot, value)})

# 4096 RAM cells (depth 12), 2048 pixels (depth 11), and 16 registers, stack
# entries and keys (depth 4).
def ram_mask() -> U32:
  2048

def pixel_mask() -> U32:
  1024

def small_mask() -> U32:
  8

def mem_sum(mem: Mem) -> U32:
  match mem:
    case Cell{value}:
      value
    case Fork{lo, hi}:
      U32.add(mem_sum(lo), mem_sum(hi))

# ROM text
# --------

def hex_code(code: Nat) -> HexChar:
  match code:
    case 32n:
      HexSkip{}
    case 9n:
      HexSkip{}
    case 10n:
      HexSkip{}
    case 13n:
      HexSkip{}
    case 48n:
      HexDigit{0}
    case 49n:
      HexDigit{1}
    case 50n:
      HexDigit{2}
    case 51n:
      HexDigit{3}
    case 52n:
      HexDigit{4}
    case 53n:
      HexDigit{5}
    case 54n:
      HexDigit{6}
    case 55n:
      HexDigit{7}
    case 56n:
      HexDigit{8}
    case 57n:
      HexDigit{9}
    case 65n:
      HexDigit{10}
    case 66n:
      HexDigit{11}
    case 67n:
      HexDigit{12}
    case 68n:
      HexDigit{13}
    case 69n:
      HexDigit{14}
    case 70n:
      HexDigit{15}
    case 97n:
      HexDigit{10}
    case 98n:
      HexDigit{11}
    case 99n:
      HexDigit{12}
    case 100n:
      HexDigit{13}
    case 101n:
      HexDigit{14}
    case 102n:
      HexDigit{15}
    case other:
      HexBad{}

def hex_char(char: Char) -> HexChar:
  match char:
    case Chr{code}:
      hex_code(U32.to_nat(code))

def hex_case(h: HexChar, skip: Unit -> LoadResult, digit: U32 -> LoadResult) -> LoadResult:
  match h:
    case HexSkip{}:
      skip(Unit{})
    case HexBad{}:
      LoadFail{5}
    case HexDigit{value}:
      digit(value)

# One byte stored at `at`, unless `at` is past the end of RAM.
def load_put(+at: U32, +memory: Mem, +value: U32, rest: Mem -> LoadResult) -> LoadResult:
  branch(LoadResult, U32.is_lt(at, 4096),
    u => rest(mem_set(memory, ram_mask(), at, value)),
    u => LoadFail{6})

# Pairs of hex digits, separated by any whitespace, loaded from `at` on.
def load_hex(text: String, high: Maybe<&2, U32>, +memory: Mem, +at: U32) -> LoadResult:
  match text high:
    case SNil{} None{}:
      LoadOK{memory, at}
    case SNil{} Some{orphan}:
      LoadFail{5}
    case SCon{head, +tail} None{}:
      hex_case(hex_char(head),
        u => load_hex(tail, None{}, memory, at),
        d => load_hex(tail, Some{d}, memory, at))
    case SCon{head, +tail} Some{+upper}:
      hex_case(hex_char(head),
        u => load_hex(tail, Some{upper}, memory, at),
        d => load_put(at, memory, U32.or(U32.shln(upper, 4n), d),
          m => load_hex(tail, None{}, m, U32.inc(at))))

# Raw ROM bytes (from a .ch8 file), loaded from `at` on.
def load_bytes(bytes: List<&2, U32>, +memory: Mem, +at: U32) -> LoadResult:
  match bytes:
    case Nil{}:
      LoadOK{memory, at}
    case Con{b, +rest}:
      load_put(at, memory, byte(b), m => load_bytes(rest, m, U32.inc(at)))

def font_source() -> String:
  "F0 90 90 90 F0 20 60 20 20 70 F0 10 F0 80 F0 F0 10 F0 10 F0 90 90 F0 10 10 F0 80 F0 10 F0 F0 80 F0 90 F0 F0 10 20 40 40 F0 90 F0 90 F0 F0 90 F0 10 F0 F0 90 F0 90 90 E0 90 E0 90 E0 F0 80 80 80 F0 E0 90 90 90 E0 F0 80 F0 80 F0 F0 80 F0 80 80"

# xorshift32 seed 0x00C0FFEE
def initial_rng() -> U32:
  U32.or(U32.shln(192, 16n), U32.or(U32.shln(255, 8n), 238))

# Booting
# -------

def boot.fin(r: LoadResult) -> BootResult:
  match r:
    case LoadFail{code}:
      BootFail{code}
    case LoadOK{memory, rom_end}:
      BootOK{Machine{Core{
        memory,
        mem_fill(4n, 0),
        mem_fill(4n, 0),
        mem_fill(11n, 0),
        mem_fill(4n, 0),
        512,
        0,
        0,
        0,
        0,
        initial_rng()
      }, Running{}}}

# RAM with the font at 0x050, or the load failure
def boot.font() -> LoadResult:
  load_hex(font_source(), None{}, mem_fill(12n, 0), 80)

def boot.hex(r: LoadResult, text: String) -> BootResult:
  match r:
    case LoadFail{code}:
      BootFail{code}
    case LoadOK{memory, font_end}:
      boot.fin(load_hex(text, None{}, memory, 512))

def boot.raw(r: LoadResult, bytes: List<&2, U32>) -> BootResult:
  match r:
    case LoadFail{code}:
      BootFail{code}
    case LoadOK{memory, font_end}:
      boot.fin(load_bytes(bytes, memory, 512))

# A machine running the whitespace-separated hex ROM `text` from 0x200
def boot(text: String) -> BootResult:
  boot.hex(boot.font(), text)

# A machine running the raw ROM `bytes` from 0x200
def boot_bytes(bytes: List<&2, U32>) -> BootResult:
  boot.raw(boot.font(), bytes)

# Core fields
# -----------

def core_running(core: Core) -> Machine:
  Machine{core, Running{}}

def core_halted(core: Core, code: U32) -> Machine:
  Machine{core, Halted{code}}

def core_tick(core: Core) -> Core:
  match core:
    case Core{memory, registers, stack, pixels, keys, pc, index, sp, delay, sound, rng}:
      Core{memory, registers, stack, pixels, keys, pc, index, sp, timer_tick(delay), timer_tick(sound), rng}

def core_reg(+core: Core, +slot: U32) -> U32:
  match core:
    case Core{memory, registers, stack, pixels, keys, pc, index, sp, delay, sound, rng}:
      mem_get(registers, small_mask(), slot)

def core_reg_put(+core: Core, +slot: U32, +value: U32) -> Core:
  match core:
    case Core{memory, registers, stack, pixels, keys, pc, index, sp, delay, sound, rng}:
      Core{memory, mem_set(registers, small_mask(), slot, byte(value)), stack, pixels, keys, pc, index, sp, delay, sound, rng}

def core_mem(+core: Core, +slot: U32) -> U32:
  match core:
    case Core{memory, registers, stack, pixels, keys, pc, index, sp, delay, sound, rng}:
      mem_get(memory, ram_mask(), slot)

def core_mem_put(+core: Core, +slot: U32, +value: U32) -> Core:
  match core:
    case Core{memory, registers, stack, pixels, keys, pc, index, sp, delay, sound, rng}:
      Core{mem_set(memory, ram_mask(), slot, byte(value)), registers, stack, pixels, keys, pc, index, sp, delay, sound, rng}

def core_stack(+core: Core, +slot: U32) -> U32:
  match core:
    case Core{memory, registers, stack, pixels, keys, pc, index, sp, delay, sound, rng}:
      mem_get(stack, small_mask(), slot)

def core_stack_put(+core: Core, +slot: U32, +value: U32) -> Core:
  match core:
    case Core{memory, registers, stack, pixels, keys, pc, index, sp, delay, sound, rng}:
      Core{memory, registers, mem_set(stack, small_mask(), slot, value), pixels, keys, pc, index, sp, delay, sound, rng}

def core_pixel(+core: Core, +slot: U32) -> U32:
  match core:
    case Core{memory, registers, stack, pixels, keys, pc, index, sp, delay, sound, rng}:
      mem_get(pixels, pixel_mask(), slot)

def core_pixel_put(+core: Core, +slot: U32, +value: U32) -> Core:
  match core:
    case Core{memory, registers, stack, pixels, keys, pc, index, sp, delay, sound, rng}:
      Core{memory, registers, stack, mem_set(pixels, pixel_mask(), slot, U32.and(value, 1)), keys, pc, index, sp, delay, sound, rng}

def core_key(+core: Core, +slot: U32) -> U32:
  match core:
    case Core{memory, registers, stack, pixels, keys, pc, index, sp, delay, sound, rng}:
      mem_get(keys, small_mask(), slot)

def core_key_put(+core: Core, +slot: U32, +value: U32) -> Core:
  match core:
    case Core{memory, registers, stack, pixels, keys, pc, index, sp, delay, sound, rng}:
      Core{memory, registers, stack, pixels, mem_set(keys, small_mask(), slot, U32.and(value, 1)), pc, index, sp, delay, sound, rng}

def core_pc(+core: Core) -> U32:
  match core:
    case Core{memory, registers, stack, pixels, keys, pc, index, sp, delay, sound, rng}:
      pc

def core_pc_set(core: Core, pc: U32) -> Core:
  match core:
    case Core{memory, registers, stack, pixels, keys, old, index, sp, delay, sound, rng}:
      Core{memory, registers, stack, pixels, keys, pc, index, sp, delay, sound, rng}

def core_pc_skip(+core: Core, condition: Bool) -> Core:
  match condition:
    case False{}:
      core
    case True{}:
      core_pc_set(core, U32.add(core_pc(core), 2))

def core_index(+core: Core) -> U32:
  match core:
    case Core{memory, registers, stack, pixels, keys, pc, index, sp, delay, sound, rng}:
      index

def core_index_set(core: Core, index: U32) -> Core:
  match core:
    case Core{memory, registers, stack, pixels, keys, pc, old, sp, delay, sound, rng}:
      Core{memory, registers, stack, pixels, keys, pc, address(index), sp, delay, sound, rng}

def core_sp(+core: Core) -> U32:
  match core:
    case Core{memory, registers, stack, pixels, keys, pc, index, sp, delay, sound, rng}:
      sp

def core_sp_set(core: Core, sp: U32) -> Core:
  match core:
    case Core{memory, registers, stack, pixels, keys, pc, index, old, delay, sound, rng}:
      Core{memory, registers, stack, pixels, keys, pc, index, sp, delay, sound, rng}

def core_delay(+core: Core) -> U32:
  match core:
    case Core{memory, registers, stack, pixels, keys, pc, index, sp, delay, sound, rng}:
      delay

def core_delay_set(core: Core, delay: U32) -> Core:
  match core:
    case Core{memory, registers, stack, pixels, keys, pc, index, sp, old, sound, rng}:
      Core{memory, registers, stack, pixels, keys, pc, index, sp, byte(delay), sound, rng}

def core_sound_set(core: Core, sound: U32) -> Core:
  match core:
    case Core{memory, registers, stack, pixels, keys, pc, index, sp, delay, old, rng}:
      Core{memory, registers, stack, pixels, keys, pc, index, sp, delay, byte(sound), rng}

def core_rng(+core: Core) -> U32:
  match core:
    case Core{memory, registers, stack, pixels, keys, pc, index, sp, delay, sound, rng}:
      rng

def core_rng_set(core: Core, rng: U32) -> Core:
  match core:
    case Core{memory, registers, stack, pixels, keys, pc, index, sp, delay, sound, old}:
      Core{memory, registers, stack, pixels, keys, pc, index, sp, delay, sound, rng}

def core_clear(core: Core) -> Core:
  match core:
    case Core{memory, registers, stack, pixels, keys, pc, index, sp, delay, sound, rng}:
      Core{memory, registers, stack, mem_fill(11n, 0), keys, pc, index, sp, delay, sound, rng}

# xorshift32
def rng_step(+a: U32) -> U32:
  +b = U32.xor(a, U32.shln(a, 13n))
  +c = U32.xor(b, U32.shrn(b, 17n))
  U32.xor(c, U32.shln(c, 5n))

# Fetch and decode
# ----------------

def decode(+opcode: U32) -> Decoded:
  Decoded{
    U32.shrn(opcode, 12n),
    U32.and(U32.shrn(opcode, 8n), 15),
    U32.and(U32.shrn(opcode, 4n), 15),
    U32.and(opcode, 15),
    U32.and(opcode, 255),
    U32.and(opcode, 4095)
  }

def fetch.at(+core: Core, +pc: U32) -> FetchResult:
  branch(FetchResult, U32.is_lt(pc, 4095),
    u => Fetched{
      U32.or(U32.shln(core_mem(core, pc), 8n), core_mem(core, U32.inc(pc))),
      core_pc_set(core, U32.add(pc, 2))},
    u => FetchFailed{core})

def fetch(+core: Core) -> FetchResult:
  fetch.at(core, core_pc(core))

# Fuelled loops
# -------------

# the first pressed key from `slot` on, if any
def find_key(+fuel: Nat, +slot: U32, +core: Core) -> Maybe<&2, U32>:
  match fuel:
    case 0n:
      None{}
    case 1n+p:
      branch(Maybe<&2, U32>, U32.is_zero(core_key(core, slot)),
        u => find_key(p, U32.inc(slot), core),
        u => Some{slot})

def store_registers(+fuel: Nat, +reg: U32, +at: U32, +core: Core) -> Core:
  match fuel:
    case 0n:
      core
    case 1n+p:
      store_registers(p, U32.inc(reg), U32.inc(at), core_mem_put(core, at, core_reg(core, reg)))

def load_registers(+fuel: Nat, +reg: U32, +at: U32, +core: Core) -> Core:
  match fuel:
    case 0n:
      core
    case 1n+p:
      load_registers(p, U32.inc(reg), U32.inc(at), core_reg_put(core, reg, core_mem(core, at)))

# XOR one pixel on, recording whether it was already lit
def draw_pixel(on: Bool, +slot: U32, st: Drawn) -> Drawn:
  match on:
    case False{}:
      st
    case True{}:
      match st:
        case Drawn{+core, collision}:
          +old = core_pixel(core, slot)
          Drawn{core_pixel_put(core, slot, U32.xor(old, 1)), Bool.or(collision, U32.is_ne(old, 0))}

# one sprite row, its bits from `mask` down; off-screen pixels are clipped
def draw_bits(+fuel: Nat, +sprite: U32, +x: U32, +y: U32, +mask: U32, st: Drawn) -> Drawn:
  match fuel:
    case 0n:
      st
    case 1n+p:
      on = Bool.and(
        Bool.and(U32.is_lt(x, 64), U32.is_lt(y, 32)),
        U32.is_ne(U32.and(sprite, mask), 0))
      draw_bits(p, sprite, U32.inc(x), y, U32.shr(mask), draw_pixel(on, U32.add(U32.shln(y, 6n), x), st))

def draw_row(+at: U32, +x: U32, +y: U32, st: Drawn) -> Drawn:
  match st:
    case Drawn{+core, collision}:
      draw_bits(8n, core_mem(core, at), x, y, 128, Drawn{core, collision})

def draw_rows(+fuel: Nat, +at: U32, +x: U32, +y: U32, st: Drawn) -> Drawn:
  match fuel:
    case 0n:
      st
    case 1n+p:
      draw_rows(p, U32.inc(at), x, U32.inc(y), draw_row(at, x, y, st))

# Instructions
# ------------

def execute_ret(+core: Core, +sp: U32) -> Machine:
  branch(Machine, U32.is_zero(sp),
    u => core_halted(core, 3),
    u => core_running(core_pc_set(core_sp_set(core, U32.sub(sp, 1)), core_stack(core, U32.sub(sp, 1)))))

def execute_0(nnn: Nat, +core: Core) -> Machine:
  match nnn:
    case 224n:
      core_running(core_clear(core))
    case 238n:
      execute_ret(core, core_sp(core))
    case sys:
      core_halted(core, 1)

def execute_call(+target: U32, +core: Core, +sp: U32) -> Machine:
  branch(Machine, U32.is_lt(sp, 12),
    u => core_running(core_pc_set(core_sp_set(core_stack_put(core, sp, core_pc(core)), U32.inc(sp)), target)),
    u => core_halted(core, 4))

def execute_skip_byte(+x: U32, +nn: U32, equal: Bool, +core: Core) -> Machine:
  match equal:
    case True{}:
      core_running(core_pc_skip(core, U32.is_eq(core_reg(core, x), nn)))
    case False{}:
      core_running(core_pc_skip(core, Bool.not(U32.is_eq(core_reg(core, x), nn))))

def execute_skip_regs(+x: U32, +y: U32, equal: Bool, +core: Core) -> Machine:
  match equal:
    case True{}:
      core_running(core_pc_skip(core, U32.is_eq(core_reg(core, x), core_reg(core, y))))
    case False{}:
      core_running(core_pc_skip(core, Bool.not(U32.is_eq(core_reg(core, x), core_reg(core, y)))))

# Vx is written before VF, so VF's flag wins when x is F
def set_with_flag(+core: Core, +x: U32, +value: U32, +flag: U32) -> Machine:
  core_running(core_reg_put(core_reg_put(core, x, value), 15, flag))

def execute_8(n: Nat, +x: U32, +vx: U32, +vy: U32, +core: Core) -> Machine:
  match n:
    case 0n:
      core_running(core_reg_put(core, x, vy))
    case 1n:
      set_with_flag(core, x, U32.or(vx, vy), 0)
    case 2n:
      set_with_flag(core, x, U32.and(vx, vy), 0)
    case 3n:
      set_with_flag(core, x, U32.xor(vx, vy), 0)
    case 4n:
      +sum = U32.add(vx, vy)
      set_with_flag(core, x, sum, bool_byte(U32.is_gt(sum, 255)))
    case 5n:
      set_with_flag(core, x, U32.sub(vx, vy), bool_byte(U32.is_ge(vx, vy)))
    case 6n:
      set_with_flag(core, x, U32.shr(vy), U32.and(vy, 1))
    case 7n:
      set_with_flag(core, x, U32.sub(vy, vx), bool_byte(U32.is_ge(vy, vx)))
    case 14n:
      set_with_flag(core, x, U32.shl(vy), U32.and(U32.shrn(vy, 7n), 1))
    case invalid:
      core_halted(core, 1)

def execute_b(+target: U32, +core: Core) -> Machine:
  +to = U32.add(target, core_reg(core, 0))
  branch(Machine, U32.is_lt(to, 4096),
    u => core_running(core_pc_set(core, to)),
    u => core_halted(core, 2))

def execute_c(+x: U32, +nn: U32, +core: Core) -> Machine:
  +next = rng_step(core_rng(core))
  core_running(core_reg_put(core_rng_set(core, next), x, U32.and(byte(next), nn)))

def draw.fin(st: Drawn) -> Machine:
  match st:
    case Drawn{core, collision}:
      core_running(core_reg_put(core, 15, bool_byte(collision)))

def execute_d(+x: U32, +y: U32, +n: U32, +core: Core) -> Machine:
  +at = core_index(core)
  branch(Machine, U32.is_le(U32.add(at, n), 4096),
    u => draw.fin(draw_rows(U32.to_nat(n), at,
      U32.mod(core_reg(core, x), 64),
      U32.mod(core_reg(core, y), 32),
      Drawn{core, False{}})),
    u => core_halted(core, 2))

def key_condition(expect: Bool, pressed: U32) -> Bool:
  match expect:
    case False{}:
      U32.is_zero(pressed)
    case True{}:
      U32.is_ne(pressed, 0)

# the VIP key skips use only the low nibble of Vx
def execute_key_skip(+x: U32, expect: Bool, +core: Core) -> Machine:
  +pressed = core_key(core, U32.and(core_reg(core, x), 15))
  core_running(core_pc_skip(core, key_condition(expect, pressed)))

def execute_e(nn: Nat, +x: U32, +core: Core) -> Machine:
  match nn:
    case 158n:
      execute_key_skip(x, True{}, core)
    case 161n:
      execute_key_skip(x, False{}, core)
    case invalid:
      core_halted(core, 1)

def execute_bcd(+value: U32, +at: U32, +core: Core) -> Machine:
  branch(Machine, U32.is_lt(at, 4094),
    u => core_running(
      core_mem_put(
        core_mem_put(
          core_mem_put(core, at, U32.div(value, 100)),
          U32.inc(at), U32.mod(U32.div(value, 10), 10)),
        U32.add(at, 2), U32.mod(value, 10))),
    u => core_halted(core, 2))

# Fx55 and Fx65 move V0..Vx and leave I just past the block (original VIP)
def execute_store(+x: U32, +at: U32, +core: Core) -> Machine:
  branch(Machine, U32.is_lt(U32.add(at, x), 4096),
    u => core_running(core_index_set(store_registers(Nat.add(U32.to_nat(x), 1n), 0, at, core), U32.add(at, U32.inc(x)))),
    u => core_halted(core, 2))

def execute_load(+x: U32, +at: U32, +core: Core) -> Machine:
  branch(Machine, U32.is_lt(U32.add(at, x), 4096),
    u => core_running(core_index_set(load_registers(Nat.add(U32.to_nat(x), 1n), 0, at, core), U32.add(at, U32.inc(x)))),
    u => core_halted(core, 2))

def execute_f(nn: Nat, +x: U32, +core: Core) -> Machine:
  match nn:
    case 7n:
      core_running(core_reg_put(core, x, core_delay(core)))
    case 10n:
      Machine{core, Waiting{x}}
    case 21n:
      core_running(core_delay_set(core, core_reg(core, x)))
    case 24n:
      core_running(core_sound_set(core, core_reg(core, x)))
    case 30n:
      core_running(core_index_set(core, address(U32.add(core_index(core), core_reg(core, x)))))
    case 41n:
      core_running(core_index_set(core, U32.add(80, U32.mul(U32.mod(core_reg(core, x), 16), 5))))
    case 51n:
      execute_bcd(core_reg(core, x), core_index(core), core)
    case 85n:
      execute_store(x, core_index(core), core)
    case 101n:
      execute_load(x, core_index(core), core)
    case invalid:
      core_halted(core, 1)

def execute_group(group: Nat, +x: U32, +y: U32, +n: U32, +nn: U32, +nnn: U32, +core: Core) -> Machine:
  match group:
    case 0n:
      execute_0(U32.to_nat(nnn), core)
    case 1n:
      core_running(core_pc_set(core, nnn))
    case 2n:
      execute_call(nnn, core, core_sp(core))
    case 3n:
      execute_skip_byte(x, nn, True{}, core)
    case 4n:
      execute_skip_byte(x, nn, False{}, core)
    case 5n:
      branch(Machine, U32.is_zero(n),
        u => execute_skip_regs(x, y, True{}, core),
        u => core_halted(core, 1))
    case 6n:
      core_running(core_reg_put(core, x, nn))
    case 7n:
      core_running(core_reg_put(core, x, U32.add(core_reg(core, x), nn)))
    case 8n:
      execute_8(U32.to_nat(n), x, core_reg(core, x), core_reg(core, y), core)
    case 9n:
      branch(Machine, U32.is_zero(n),
        u => execute_skip_regs(x, y, False{}, core),
        u => core_halted(core, 1))
    case 10n:
      core_running(core_index_set(core, nnn))
    case 11n:
      execute_b(nnn, core)
    case 12n:
      execute_c(x, nn, core)
    case 13n:
      execute_d(x, y, n, core)
    case 14n:
      execute_e(U32.to_nat(nn), x, core)
    case 15n:
      execute_f(U32.to_nat(nn), x, core)
    case invalid:
      core_halted(core, 1)

def execute(decoded: Decoded, core: Core) -> Machine:
  match decoded:
    case Decoded{group, x, y, n, nn, nnn}:
      execute_group(U32.to_nat(group), x, y, n, nn, nnn, core)

# Stepping
# --------

def step.fetched(f: FetchResult) -> Machine:
  match f:
    case FetchFailed{core}:
      core_halted(core, 2)
    case Fetched{opcode, core}:
      execute(decode(opcode), core)

def step.found(key: Maybe<&2, U32>, core: Core, register: U32) -> Machine:
  match key:
    case None{}:
      Machine{core, Waiting{register}}
    case Some{value}:
      Machine{core, Releasing{register, value}}

def step.wait(+core: Core, register: U32) -> Machine:
  step.found(find_key(16n, 0, core), core, register)

# Fx0A completes when the latched key is released
def step.release(+core: Core, +register: U32, +key: U32) -> Machine:
  branch(Machine, U32.is_zero(core_key(core, key)),
    u => core_running(core_reg_put(core, register, key)),
    u => Machine{core, Releasing{register, key}})

# Timers tick once per emulated instruction (and while waiting for a key).
def machine_step(machine: Machine) -> Machine:
  match machine:
    case Machine{core, status}:
      match status:
        case Halted{code}:
          Machine{core, Halted{code}}
        case Waiting{register}:
          step.wait(core_tick(core), register)
        case Releasing{register, key}:
          step.release(core_tick(core), register, key)
        case Running{}:
          step.fetched(fetch(core_tick(core)))

def machine_run(fuel: Nat, machine: Machine) -> Machine:
  match fuel:
    case 0n:
      machine
    case 1n+pred:
      machine_run(pred, machine_step(machine))

# The input seam: a driver sets or clears a CHIP-8 key without touching any
# emulation logic. An out-of-range key halts with code 7.
def machine_key(machine: Machine, +key: U32, pressed: Bool) -> Machine:
  match machine:
    case Machine{+core, status}:
      branch(Machine, U32.is_lt(key, 16),
        u => Machine{core_key_put(core, key, bool_byte(pressed)), status},
        u => core_halted(core, 7))

# Self-test
# ---------
# The bundled smoke ROM's expected final state after 40 steps.

def verify(+machine: Machine) -> Bool:
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
          a = U32.is_eq(mem_get(registers, small_mask(), 0), 9)
          b = U32.is_eq(mem_get(registers, small_mask(), 2), 0)
          c = U32.is_eq(mem_get(registers, small_mask(), 6), 4)
          d = U32.is_eq(mem_get(registers, small_mask(), 8), 20)
          e = U32.is_eq(mem_get(registers, small_mask(), 9), 15)
          f = U32.is_eq(mem_get(registers, small_mask(), 15), 0)
          g = U32.is_eq(mem_get(memory, ram_mask(), 768), 0)
          h = U32.is_eq(mem_get(memory, ram_mask(), 769), 0)
          j = U32.is_eq(mem_get(memory, ram_mask(), 770), 9)
          k = U32.is_eq(mem_sum(pixels), 14)
          m = U32.is_eq(pc, 552)
          n = U32.is_eq(index, 130)
          o = U32.is_eq(sp, 0)
          ab = Bool.and(a, b)
          cd = Bool.and(c, d)
          ef = Bool.and(e, f)
          gh = Bool.and(g, h)
          jk = Bool.and(j, k)
          mn = Bool.and(m, n)
          Bool.and(ab, Bool.and(cd, Bool.and(ef, Bool.and(gh, Bool.and(jk, Bool.and(mn, o))))))

def selftest.boot(r: BootResult) -> Bool:
  match r:
    case BootFail{code}:
      False{}
    case BootOK{machine}:
      verify(machine_run(40n, machine))

def selftest() -> Bool:
  selftest.boot(boot(ROM.source()))

# Display
# -------

def screen_row(+fuel: Nat, +core: Core, +at: U32, acc: String) -> String:
  match fuel:
    case 0n:
      acc
    case 1n+p:
      cell = Bool.pick(String, U32.is_zero(core_pixel(core, at)), ".", "#")
      screen_row(p, core, U32.inc(at), acc ++ cell)

def screen_rows(+fuel: Nat, +core: Core, +y: U32, acc: String) -> String:
  match fuel:
    case 0n:
      acc
    case 1n+p:
      screen_rows(p, core, U32.inc(y), acc ++ screen_row(64n, core, U32.shln(y, 6n), "") ++ "\n")

def status_text(status: Status) -> String:
  match status:
    case Running{}:
      "running"
    case Waiting{register}:
      "waiting for a key into V" ++ U32.hex(register)
    case Releasing{register, key}:
      "waiting for key " ++ U32.hex(key) ++ " to be released"
    case Halted{code}:
      "halted with code " ++ U32.show(code)

def report(machine: Machine) -> String:
  match machine:
    case Machine{+core, status}:
      screen_rows(32n, core, 0, "") ++ "status: " ++ status_text(status) ++ ", pc " ++ U32.hex(core_pc(core)) ++ ", I " ++ U32.hex(core_index(core))

# IO shell
# --------

def run_booted(r: BootResult, steps: Nat) -> IO(Unit):
  match r:
    case BootFail{code}:
      IO.die(Unit, 1, "chip8: ROM rejected with code " ++ U32.show(code))
    case BootOK{machine}:
      IO.print(report(machine_run(steps, machine)))

def run_read(m: File & Result<&1, &1, U32 & String, List<&2, U32>>, steps: Nat) -> IO(Unit):
  (f, r) = m
  do IO<Unit>:
    File.close(f)
    bytes : List<&2, U32> <- IO.pass(List<&2, U32>, r)
    run_booted(boot_bytes(bytes), steps)

def run_file(path: String, steps: Nat) -> IO(Unit):
  do IO<Unit>:
    f : File <- IO.try(File, File.open(path, "r"))
    m : File & Result<&1, &1, U32 & String, List<&2, U32>> <- File.read_bytes(f, 3584)
    run_read(m, steps)

def steps_arg(args: List<String>) -> Nat:
  match args:
    case Nil{}:
      U32.to_nat(1000)
    case Con{text, rest}:
      U32.to_nat(Maybe.default(&2, U32, U32.read(text), 1000))

def selftest_text(ok: Bool) -> String:
  match ok:
    case True{}:
      "True{}"
    case False{}:
      "False{}"

def start(args: List<String>) -> IO(Unit):
  match args:
    case Con{program, Con{path, rest}}:
      run_file(path, steps_arg(rest))
    case other:
      do IO<Unit>:
        IO.print(selftest_text(selftest()))

def main() -> IO(Unit):
  do IO<Unit>:
    args : List<String> <- IO.args()
    start(args)
