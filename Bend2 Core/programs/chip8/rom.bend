import Base

# CHIP-8 programs are temporarily supplied as hexadecimal text because
# Bend2 Core has no file or standard-input runtime. The emulator parses this
# String and loads its bytes at address 0x200.
def source() -> String:
  "00 E0 60 FA 61 0A 80 14 70 05 A3 00 F0 33 22 2C C2 0F 63 0A F3 29 64 00 65 00 D4 55 65 05 F5 15 F6 07 67 10 E7 A1 60 00 12 28 00 00 68 03 88 16 88 1E 6F 01 69 FF 6A 0F 89 A2 00 EE"
