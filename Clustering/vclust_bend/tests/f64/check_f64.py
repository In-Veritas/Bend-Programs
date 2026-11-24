#!/usr/bin/env python3
"""Check soft-float lines `op ah al bh bl rh rl` (hex) against host doubles.
ops: 0 add, 1 mul, 2 div, 3 sub, 4 fma(a, b, c) (line has ch cl too),
5 exp(a)."""
import math, struct, sys
from fractions import Fraction as Fr

def d(h, l):
    h = h.lstrip('x') or '0'; l = l.lstrip('x') or '0'
    return struct.unpack('<d', struct.pack('<Q', (int(h, 16) << 32) | int(l, 16)))[0]
def bits(x): return struct.unpack('<Q', struct.pack('<d', x))[0]

def fma(a, b, c):
    if not all(math.isfinite(v) for v in (a, b, c)):
        return a * b + c
    v = Fr(a) * Fr(b) + Fr(c)
    if v == 0:
        return a * b + c
    try:
        return float(v)
    except OverflowError:
        return math.copysign(math.inf, v)

bad = n = 0
for ln in sys.stdin:
    f = ln.split()
    if not f or not f[0].isdigit():
        continue
    op = int(f[0]); n += 1
    a = d(f[1], f[2])
    try:
        if op == 4:
            b = d(f[3], f[4]); c = d(f[5], f[6]); want = fma(a, b, c); got = d(f[7], f[8])
        elif op == 6:
            b = d(f[3], f[4]); want = ''.join(str(int(v)) for v in (a < b, a <= b, a == b, a >= b))
            if want != f[5]:
                bad += 1; print('CMP MISMATCH', ln.strip(), want)
            continue
        elif op == 5:
            try: want = math.exp(a)
            except OverflowError: want = math.inf
            got = d(f[3], f[4])
        else:
            b = d(f[3], f[4]); got = d(f[5], f[6])
            if op == 0: want = a + b
            elif op == 1: want = a * b
            elif op == 3: want = a - b
            else:
                if not (math.isfinite(a) and math.isfinite(b)): continue
                want = (a / b) if b != 0 else (math.nan if a == 0 or math.isnan(a) else math.copysign(math.inf, a) * math.copysign(1, b))
    except (OverflowError, ZeroDivisionError):
        continue
    if math.isnan(want) and math.isnan(got):
        continue
    if bits(want) != bits(got):
        bad += 1
        if bad <= 10:
            print('MISMATCH', ln.strip(), 'want', want.hex(), 'got', got.hex())
print(f'{n} checked, {bad} mismatches')
sys.exit(1 if bad else 0)
